import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../config/app_config.dart';
import '../services/ice_config_service.dart';
import '../services/pairing_store.dart';
import '../services/recording_service.dart';
import '../services/signaling_service.dart';
import '../services/webrtc_service.dart';
import '../services/webrtc_signaling_codec.dart';
import '../theme/app_theme.dart';
import '../widgets/branding_header.dart';
import 'pairing_screen.dart';
import 'recordings_screen.dart';

/// The camera's single main screen. Owns the pairing session, the camera
/// capture and the WebRTC connection, so there is no hand-off between screens
/// that could miss a viewer's request.
class StreamingScreen extends StatefulWidget {
  const StreamingScreen({super.key});

  @override
  State<StreamingScreen> createState() => _StreamingScreenState();
}

class _StreamingScreenState extends State<StreamingScreen> {
  final _localRenderer = RTCVideoRenderer();
  final _webrtc = CameraWebRTC();
  final _recording = RecordingService();
  CameraSignaling? _signaling;

  String? _code;
  String _status = 'Starting camera…';
  String _iceState = '-';
  bool _viewerConnected = false;
  bool _firebaseOnline = true;
  bool _disposed = false;

  int _serial = 0;
  Future<void> _chain = Future.value();

  Timer? _recordTimer;
  Duration _recordedFor = Duration.zero;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await WakelockPlus.enable();
      await _localRenderer.initialize();
      final stream = await _webrtc.openCamera();
      _localRenderer.srcObject = stream;
      if (mounted) setState(() {});
    } catch (e) {
      _setStatus('Camera error: $e\nAllow camera and microphone permission, then reopen the app.');
      return;
    }

    _webrtc.onIceCandidate = (c) => _signaling?.sendCameraIce(iceCandidateToMap(c));
    _webrtc.onIceState = _onIceState;
    _webrtc.iceServers = AppConfig.fallbackIceServers;

    final code = await PairingStore.loadOrCreate();
    if (_disposed) return;
    await _startSignaling(code);

    // Load optional TURN servers in the background; applies to the next connection.
    IceConfigService.load().then((servers) {
      if (!_disposed) _webrtc.iceServers = servers;
    });
  }

  Future<void> _startSignaling(String code) async {
    final s = CameraSignaling(code);
    s.onViewerRequest = _onViewerRequest;
    s.onAnswer = (m) {
      _webrtc.setRemoteAnswer(sdpFromMap(m)).catchError((_) {});
    };
    s.onViewerIce = (m) {
      _webrtc.addRemoteCandidate(iceCandidateFromMap(m));
    };
    s.onFirebaseConnection = (ok) {
      if (mounted) setState(() => _firebaseOnline = ok);
    };
    _signaling = s;
    if (mounted) {
      setState(() {
        _code = code;
        _viewerConnected = false;
        _iceState = '-';
        _status = 'Waiting for viewer…';
      });
    }
    s.start();
  }

  void _onViewerRequest(String attemptId) {
    final serial = ++_serial;
    _chain = _chain.then((_) => _runAttempt(attemptId, serial));
  }

  Future<void> _runAttempt(String attemptId, int serial) async {
    if (serial != _serial || _disposed) return;
    _setStatus('Viewer connecting…');
    try {
      // Listen for this attempt's answer/candidates first, then build the connection.
      _signaling?.beginAttempt(attemptId);
      await _webrtc.newPeerConnection();
      if (serial != _serial || _disposed) return;
      final offer = await _webrtc.createOffer();
      if (serial != _serial || _disposed) return;
      _signaling?.sendOffer(sdpToMap(offer));
    } catch (e) {
      _setStatus('Connection error: $e\nWaiting for viewer to retry…');
    }
  }

  void _onIceState(RTCIceConnectionState s) {
    if (!mounted) return;
    final name = s.toString().split('.').last.replaceFirst('RTCIceConnectionState', '');
    setState(() {
      _iceState = name;
      if (s == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          s == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        _viewerConnected = true;
        _status = 'Live — viewer connected';
      } else if (s == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
        _status = 'Connection unstable…';
      } else if (s == RTCIceConnectionState.RTCIceConnectionStateFailed ||
          s == RTCIceConnectionState.RTCIceConnectionStateClosed) {
        _viewerConnected = false;
        _status = 'Viewer left — waiting for viewer…';
      }
    });
  }

  void _setStatus(String text) {
    if (mounted) setState(() => _status = text);
  }

  Future<void> _resetCode() async {
    _serial++;
    final old = _signaling;
    _signaling = null;
    await _webrtc.closeConnection();
    old?.deleteSession();
    final code = await PairingStore.createNew();
    if (_disposed) return;
    await _startSignaling(code);
  }

  void _openPairing() {
    final code = _code;
    if (code == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PairingScreen(code: code, onResetCode: _resetCode),
      ),
    );
  }

  Future<void> _toggleRecording() async {
    if (_recording.isRecording) {
      await _recording.stop();
      _recordTimer?.cancel();
      if (mounted) {
        setState(() => _recordedFor = Duration.zero);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Clip saved to Recordings')));
      }
    } else {
      final tracks = _webrtc.localStream?.getVideoTracks() ?? [];
      if (tracks.isEmpty) return;
      await _recording.start(tracks.first);
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordedFor += const Duration(seconds: 1));
      });
    }
    if (mounted) setState(() {});
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _disposed = true;
    _serial++;
    _recordTimer?.cancel();
    if (_recording.isRecording) _recording.stop();
    _signaling?.stop();
    _webrtc.dispose();
    _localRenderer.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const DigiforgeBrandHeader(appLabel: 'Camera'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2),
            tooltip: 'Pairing code & QR',
            onPressed: _code == null ? null : _openPairing,
          ),
          IconButton(
            icon: const Icon(Icons.video_library_outlined),
            tooltip: 'Recordings',
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const RecordingsScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                RTCVideoView(_localRenderer,
                    mirror: false,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                Positioned(top: 16, left: 16, child: _liveBadge()),
                if (_recording.isRecording)
                  Positioned(top: 16, right: 16, child: _recBadge()),
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: FloatingActionButton(
                    heroTag: 'record-fab',
                    backgroundColor: _recording.isRecording
                        ? DigiforgeBrand.danger
                        : DigiforgeBrand.accent,
                    onPressed: _toggleRecording,
                    child: Icon(
                      _recording.isRecording ? Icons.stop : Icons.fiber_manual_record,
                      color: const Color(0xFF04211D),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: DigiforgeBrand.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Pairing code',
                              style: TextStyle(
                                  color: DigiforgeBrand.textSecondary, fontSize: 12)),
                          Text(_code ?? '······',
                              style: const TextStyle(
                                  color: DigiforgeBrand.textPrimary,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 5)),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _code == null ? null : _openPairing,
                      icon: const Icon(Icons.qr_code_2),
                      label: const Text('Show QR'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(_status, style: const TextStyle(color: DigiforgeBrand.textPrimary)),
                const SizedBox(height: 4),
                Text(
                  'Connection: $_iceState${_firebaseOnline ? '' : '   •   Internet/Firebase offline'}',
                  style: const TextStyle(color: DigiforgeBrand.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration:
          BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.fiber_manual_record, color: DigiforgeBrand.danger, size: 12),
        const SizedBox(width: 6),
        Text('REC ${_formatDuration(_recordedFor)}',
            style: const TextStyle(
                color: DigiforgeBrand.danger, fontWeight: FontWeight.bold, fontSize: 12)),
      ]),
    );
  }

  Widget _liveBadge() {
    final color = _viewerConnected ? DigiforgeBrand.accent : DigiforgeBrand.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration:
          BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(_viewerConnected ? 'LIVE' : 'STANDBY',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      ]),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../config/app_config.dart';
import '../services/ice_config_service.dart';
import '../services/recent_camera_store.dart';
import '../services/recording_service.dart';
import '../services/signaling_service.dart';
import '../services/webrtc_service.dart';
import '../services/webrtc_signaling_codec.dart';
import '../theme/app_theme.dart';
import '../widgets/branding_header.dart';

class LiveViewScreen extends StatefulWidget {
  final String pairingCode;
  const LiveViewScreen({super.key, required this.pairingCode});

  @override
  State<LiveViewScreen> createState() => _LiveViewScreenState();
}

class _LiveViewScreenState extends State<LiveViewScreen> {
  final _remoteRenderer = RTCVideoRenderer();
  final _webrtc = ViewerWebRTC();
  final _recording = RecordingService();
  late final ViewerSignaling _signaling;

  String _status = 'Connecting…';
  String _iceState = '-';
  bool _live = false;
  bool _iceUp = false;
  bool _cameraOnline = true;
  bool _fatal = false;
  bool _offerHandled = false;
  bool _disposed = false;
  MediaStream? _remoteStream;

  int _serial = 0;
  int _retries = 0;
  Future<void> _chain = Future.value();

  Timer? _connectTimer;
  Timer? _disconnectTimer;
  Timer? _retryTimer;
  Timer? _recordTimer;
  Duration _recordedFor = Duration.zero;

  @override
  void initState() {
    super.initState();
    _signaling = ViewerSignaling(widget.pairingCode);
    _boot();
  }

  Future<void> _boot() async {
    await _remoteRenderer.initialize();
    _webrtc.iceServers = AppConfig.fallbackIceServers;
    _webrtc.onRemoteStream = _onRemoteStream;
    _webrtc.onIceCandidate = (c) => _signaling.sendIceCandidate(iceCandidateToMap(c));
    _webrtc.onIceState = _onIceState;
    _signaling.onOffer = _onOffer;
    _signaling.onCameraIce = (m) => _webrtc.addRemoteCandidate(iceCandidateFromMap(m));
    _signaling.onCameraOnline = (online) {
      if (mounted) setState(() => _cameraOnline = online);
    };

    _setStatus('Checking pairing code…');
    try {
      final exists = await _signaling.sessionExists();
      if (_disposed) return;
      if (!exists) {
        _markFatal('No camera found for code ${widget.pairingCode}.\n'
            'Check the code shown on the camera phone.');
        return;
      }
    } catch (_) {
      // Could not verify (weak/no internet): keep trying below.
    }

    _webrtc.iceServers = await IceConfigService.load();
    if (_disposed) return;
    _signaling.watchCameraOnline();
    _startAttempt();
  }

  void _markFatal(String message) {
    if (!mounted) return;
    setState(() {
      _fatal = true;
      _live = false;
      _status = message;
    });
  }

  void _startAttempt() {
    if (_disposed || _fatal) return;
    final serial = ++_serial;
    _connectTimer?.cancel();
    _disconnectTimer?.cancel();
    _retryTimer?.cancel();
    _chain = _chain.then((_) => _runAttempt(serial));
  }

  Future<void> _runAttempt(int serial) async {
    if (serial != _serial || _disposed || _fatal) return;
    _offerHandled = false;
    _iceUp = false;
    if (_recording.isRecording) await _toggleRecording();
    _signaling.endAttempt();
    if (mounted) {
      setState(() {
        _live = false;
        _iceState = '-';
        _status = _retries == 0 ? 'Connecting to camera…' : 'Reconnecting…';
      });
    }

    if (_retries > 0) {
      try {
        final exists = await _signaling.sessionExists();
        if (serial != _serial || _disposed) return;
        if (!exists) {
          _markFatal('This camera code is no longer valid.\n'
              'Ask for the new code on the camera phone.');
          return;
        }
      } catch (_) {}
    }

    try {
      await _webrtc.newPeerConnection();
      if (serial != _serial || _disposed) return;
      _signaling.beginAttempt();
      _connectTimer = Timer(const Duration(seconds: 25), () {
        if (!_live) _scheduleRetry('timed out');
      });
    } catch (e) {
      _scheduleRetry('error');
    }
  }

  Future<void> _onOffer(Map<String, dynamic> m) async {
    if (_offerHandled || _disposed) return;
    _offerHandled = true;
    final serial = _serial;
    try {
      await _webrtc.setRemoteOffer(sdpFromMap(m));
      final answer = await _webrtc.createAnswer();
      if (serial != _serial || _disposed) return;
      _signaling.sendAnswer(sdpToMap(answer));
      _setStatus('Negotiating connection…');
    } catch (e) {
      _scheduleRetry('negotiation error');
    }
  }

  void _onRemoteStream(MediaStream stream) {
    _remoteRenderer.srcObject = stream;
    _remoteStream = stream;
    _refreshLive();
  }

  void _onIceState(RTCIceConnectionState s) {
    if (_disposed) return;
    final name = s.toString().split('.').last.replaceFirst('RTCIceConnectionState', '');
    if (mounted) setState(() => _iceState = name);

    if (s == RTCIceConnectionState.RTCIceConnectionStateConnected ||
        s == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
      _iceUp = true;
      _disconnectTimer?.cancel();
      _refreshLive();
    } else if (s == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
      // Often recovers by itself (short network blip). Give it a few seconds.
      _iceUp = false;
      if (mounted) setState(() => _status = 'Connection unstable…');
      _disconnectTimer?.cancel();
      _disconnectTimer = Timer(const Duration(seconds: 8), () {
        if (!_iceUp) _scheduleRetry('connection lost');
      });
    } else if (s == RTCIceConnectionState.RTCIceConnectionStateFailed) {
      _iceUp = false;
      _scheduleRetry('connection failed');
    }
  }

  void _refreshLive() {
    final live = _iceUp && _remoteStream != null;
    if (live) {
      _connectTimer?.cancel();
      _disconnectTimer?.cancel();
      _retries = 0;
      RecentCameraStore.save(widget.pairingCode);
    }
    if (mounted) {
      setState(() {
        _live = live;
        if (live) _status = 'Live';
      });
    }
  }

  /// Never gives up: retries forever with a growing (max 15s) delay.
  void _scheduleRetry(String reason) {
    if (_disposed || _fatal) return;
    _connectTimer?.cancel();
    _disconnectTimer?.cancel();
    _retryTimer?.cancel();
    _retries++;
    final secs = (_retries * 2).clamp(2, 15);
    if (mounted) {
      setState(() {
        _live = false;
        _iceUp = false;
        _status = 'Reconnecting in ${secs}s… ($reason)';
      });
    }
    _retryTimer = Timer(Duration(seconds: secs), _startAttempt);
  }

  void _retryNow() {
    _retries = 0;
    _startAttempt();
  }

  void _setStatus(String text) {
    if (mounted) setState(() => _status = text);
  }

  Future<void> _toggleRecording() async {
    if (_recording.isRecording) {
      await _recording.stop();
      _recordTimer?.cancel();
      if (mounted) {
        setState(() => _recordedFor = Duration.zero);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Clip saved to Clips')));
      }
    } else {
      final tracks = _remoteStream?.getVideoTracks() ?? [];
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
    _connectTimer?.cancel();
    _disconnectTimer?.cancel();
    _retryTimer?.cancel();
    _recordTimer?.cancel();
    if (_recording.isRecording) _recording.stop();
    _signaling.dispose();
    _webrtc.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const DigiforgeBrandHeader(appLabel: 'Live View')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                RTCVideoView(_remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain),
                if (!_live) _overlay(),
                if (_recording.isRecording)
                  Positioned(top: 16, right: 16, child: _recBadge()),
                if (_live)
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: FloatingActionButton(
                      heroTag: 'viewer-record-fab',
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: DigiforgeBrand.surface,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _live ? DigiforgeBrand.accent : DigiforgeBrand.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _live ? 'Live  •  ${widget.pairingCode}' : 'Not live  •  ${widget.pairingCode}',
                    style: const TextStyle(color: DigiforgeBrand.textPrimary),
                  ),
                ),
                Text(
                  'ICE: $_iceState${_cameraOnline ? '' : '  •  camera offline'}',
                  style: const TextStyle(color: DigiforgeBrand.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _overlay() {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_fatal) const CircularProgressIndicator(color: DigiforgeBrand.accent),
              if (_fatal)
                const Icon(Icons.error_outline, color: DigiforgeBrand.danger, size: 40),
              const SizedBox(height: 16),
              Text(_status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: DigiforgeBrand.textPrimary, fontSize: 16)),
              if (!_cameraOnline && !_fatal) ...[
                const SizedBox(height: 8),
                const Text('The camera app looks offline. Make sure it is open and has internet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: DigiforgeBrand.textSecondary, fontSize: 13)),
              ],
              if (_retries >= 2 && !_fatal) ...[
                const SizedBox(height: 8),
                const Text(
                    'Still not connecting? Your network may block direct connections. '
                    'A relay (TURN) server fixes this — see docs/CONNECTION_SETUP.md.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: DigiforgeBrand.textSecondary, fontSize: 13)),
              ],
              const SizedBox(height: 12),
              if (_fatal)
                ElevatedButton(
                    onPressed: () => Navigator.pop(context), child: const Text('Back'))
              else
                TextButton(
                  onPressed: _retryNow,
                  child: const Text('Retry now',
                      style: TextStyle(color: DigiforgeBrand.accent)),
                ),
            ],
          ),
        ),
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
}

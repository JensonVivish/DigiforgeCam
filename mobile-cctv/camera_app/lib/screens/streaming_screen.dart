import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/signaling_service.dart';
import '../services/webrtc_service.dart';
import '../services/webrtc_signaling_codec.dart';
import '../services/recording_service.dart';
import '../theme/app_theme.dart';
import '../widgets/branding_header.dart';
import 'recordings_screen.dart';

class StreamingScreen extends StatefulWidget {
  final String pairingCode;
  final SignalingService signaling;
  const StreamingScreen({super.key, required this.pairingCode, required this.signaling});

  @override
  State<StreamingScreen> createState() => _StreamingScreenState();
}

class _StreamingScreenState extends State<StreamingScreen> {
  final _localRenderer = RTCVideoRenderer();
  
  final _webrtc = WebRTCService();
  late final SignalingService _signaling;
  final _recording = RecordingService();

  bool _viewerConnected = false;
  String _status = 'Waiting for viewer to scan pairing code…';
  Timer? _recordTimer;
  Duration _recordedFor = Duration.zero;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _signaling = widget.signaling;
    await WakelockPlus.enable();
    await _localRenderer.initialize();

    final stream = await _webrtc.getLocalStream();
    _localRenderer.srcObject = stream;
    if (mounted) setState(() {});

    await _webrtc.initPeerConnection();

    _webrtc.onIceCandidate = (candidate) {
      _signaling.sendIceCandidate(iceCandidateToMap(candidate));
    };

    _signaling.onViewerJoined = () async {
      if (!mounted) return;
      setState(() {
        _viewerConnected = true;
        _status = 'Viewer connected — starting stream…';
      });
      final offer = await _webrtc.createOffer();
      await _signaling.sendOffer(sdpToMap(offer));
    };

    _signaling.onSignal = (data) async {
      if (data['kind'] == 'answer') {
        final answer = sdpFromMap(Map<String, dynamic>.from(data['payload']));
        await _webrtc.setRemoteAnswer(answer);
        if (mounted) setState(() => _status = 'Live — streaming to viewer');
      } else if (data['kind'] == 'ice-candidate') {
        final candidate = iceCandidateFromMap(Map<String, dynamic>.from(data['payload']));
        await _webrtc.addIceCandidate(candidate);
      }
    };

    _signaling.onPeerDisconnected = () {
      if (!mounted) return;
      setState(() {
        _viewerConnected = false;
        _status = 'Viewer disconnected — waiting…';
      });
    };
  }

  Future<void> _toggleRecording() async {
    if (_recording.isRecording) {
      await _recording.stop();
      _recordTimer?.cancel();
      if (mounted) setState(() => _recordedFor = Duration.zero);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clip saved to Recordings')),
        );
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

  @override
  void dispose() {
    _localRenderer.dispose();
    _signaling.dispose();
    _webrtc.dispose();
    _recordTimer?.cancel();
    if (_recording.isRecording) _recording.stop();
    WakelockPlus.disable();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const DigiforgeBrandHeader(appLabel: 'Camera'),
        actions: [
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
                const Text('Pairing code',
                    style: TextStyle(color: DigiforgeBrand.textSecondary, fontSize: 12)),
                Text(widget.pairingCode,
                    style: const TextStyle(
                        color: DigiforgeBrand.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4)),
                const SizedBox(height: 8),
                Text(_status,
                    style: const TextStyle(color: DigiforgeBrand.textSecondary)),
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
                color: DigiforgeBrand.danger,
                fontWeight: FontWeight.bold,
                fontSize: 12)),
      ]),
    );
  }

  Widget _liveBadge() {
    final color =
        _viewerConnected ? DigiforgeBrand.accent : DigiforgeBrand.textSecondary;
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
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      ]),
    );
  }
}

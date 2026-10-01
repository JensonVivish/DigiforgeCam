import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/signaling_service.dart';
import '../services/webrtc_service.dart';
import '../services/webrtc_signaling_codec.dart';
import '../services/recording_service.dart';
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
  final _signaling = SignalingService();
  final _webrtc = WebRTCService();
  final _recording = RecordingService();
  String _status = 'Connecting to camera…';
  MediaStream? _remoteStream;
  Timer? _recordTimer;
  Duration _recordedFor = Duration.zero;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _remoteRenderer.initialize();
    await _webrtc.initPeerConnection();

    _webrtc.onRemoteStream = (stream) {
      _remoteRenderer.srcObject = stream;
      _remoteStream = stream;
      if (mounted) setState(() => _status = 'Live');
    };

    _webrtc.onIceCandidate = (candidate) {
      _signaling.sendIceCandidate(iceCandidateToMap(candidate));
    };

    _signaling.onSignal = (data) async {
      if (data['kind'] == 'offer') {
        final offer = sdpFromMap(Map<String, dynamic>.from(data['payload']));
        await _webrtc.setRemoteOffer(offer);
        final answer = await _webrtc.createAnswer();
        await _signaling.sendAnswer(sdpToMap(answer));
      } else if (data['kind'] == 'ice-candidate') {
        final candidate =
            iceCandidateFromMap(Map<String, dynamic>.from(data['payload']));
        await _webrtc.addIceCandidate(candidate);
      }
    };

    _signaling.onPeerDisconnected = () {
      if (mounted) setState(() => _status = 'Camera disconnected');
    };

    _signaling.onError = (message) {
      if (mounted) setState(() => _status = 'Error: $message');
    };

    await _signaling.joinSession(widget.pairingCode);
  }

  Future<void> _toggleRecording() async {
    if (_recording.isRecording) {
      await _recording.stop();
      _recordTimer?.cancel();
      if (mounted) setState(() => _recordedFor = Duration.zero);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clip saved to Clips')),
        );
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
    _remoteRenderer.dispose();
    _signaling.dispose();
    _webrtc.dispose();
    _recordTimer?.cancel();
    if (_recording.isRecording) _recording.stop();
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
                if (_recording.isRecording)
                  Positioned(top: 16, right: 16, child: _recBadge()),
                if (_remoteStream != null)
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
                        _recording.isRecording
                            ? Icons.stop
                            : Icons.fiber_manual_record,
                        color: const Color(0xFF04211D),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: DigiforgeBrand.surface,
            child: Text(_status,
                style: const TextStyle(color: DigiforgeBrand.textSecondary)),
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
}

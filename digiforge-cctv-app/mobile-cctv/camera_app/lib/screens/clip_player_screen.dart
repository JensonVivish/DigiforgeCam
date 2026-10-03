import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_theme.dart';
import '../widgets/branding_header.dart';

class ClipPlayerScreen extends StatefulWidget {
  final String filePath;
  const ClipPlayerScreen({super.key, required this.filePath});

  @override
  State<ClipPlayerScreen> createState() => _ClipPlayerScreenState();
}

class _ClipPlayerScreenState extends State<ClipPlayerScreen> {
  late VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.filePath))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const DigiforgeBrandHeader(appLabel: 'Clip')),
      body: Center(
        child: _ready
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio == 0 ? 16 / 9 : _controller.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    VideoPlayer(_controller),
                    VideoProgressIndicator(
                      _controller,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                          playedColor: DigiforgeBrand.accent, backgroundColor: Colors.white24),
                    ),
                  ],
                ),
              )
            : const CircularProgressIndicator(color: DigiforgeBrand.accent),
      ),
      floatingActionButton: _ready
          ? FloatingActionButton(
              backgroundColor: DigiforgeBrand.accent,
              onPressed: () => setState(() {
                _controller.value.isPlaying ? _controller.pause() : _controller.play();
              }),
              child: Icon(_controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: const Color(0xFF04211D)),
            )
          : null,
    );
  }
}


import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerWidget extends StatefulWidget {
  final List<String> videoPaths;

  const VideoPlayerWidget({super.key, required this.videoPaths});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _videoPlayerController;
  int _currentVideoIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  void _initializeVideo() {
    if (_currentVideoIndex < widget.videoPaths.length) {
      String videoPath = widget.videoPaths[_currentVideoIndex];
      print('Cargando video: $videoPath');
      _videoPlayerController = VideoPlayerController.file(File(videoPath))
        ..initialize().then((_) {
          setState(() {}); // Actualiza el estado cuando el video esté listo
          _videoPlayerController.play();
          _videoPlayerController.addListener(_videoListener);
        });
    }
  }

  void _videoListener() {
    if (_videoPlayerController.value.position == _videoPlayerController.value.duration) {
      _currentVideoIndex++;
      if (_currentVideoIndex < widget.videoPaths.length) {
        _videoPlayerController.removeListener(_videoListener);
        _initializeVideo();
      }
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _videoPlayerController.value.isInitialized
        ? AspectRatio(
            aspectRatio: _videoPlayerController.value.aspectRatio,
            child: VideoPlayer(_videoPlayerController),
          )
        : const CircularProgressIndicator();
  }
}

import 'dart:io';
import 'package:video_player/video_player.dart';
import '../models/video_model.dart';

class VideoController {
  late VideoPlayerController _videoPlayerController;

  VideoPlayerController get videoPlayerController => _videoPlayerController;

  void initialize(VideoModel videoModel) {
    _videoPlayerController = VideoPlayerController.file(File(videoModel.videoPath))
      ..initialize().then((_) {
        _videoPlayerController.play();
      });
  }

  void dispose() {
    _videoPlayerController.dispose();
  }
}
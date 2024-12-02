
import 'dart:io';
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:path_provider/path_provider.dart';
import '../models/translation_model.dart';

class TranslationController {
  Future<TranslationModel> translate(String text) async {
    List<String> words = text.split(' ');
    List<String> videoPaths = [];
 
    for (String word in words) {
      String normalizedWord = _normalize(word);
      String assetPath = 'assets/videos/$normalizedWord.mp4';
      if (await _assetExists(assetPath)) {
        String videoPath = await _copyAssetToLocalPath(assetPath, normalizedWord);
        videoPaths.add(videoPath);
      }
    }
    return TranslationModel(originalText: text, translatedText: videoPaths.join(','));
  }

  String _normalize(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  Future<bool> _assetExists(String assetPath) async {
    try {
      await rootBundle.load(assetPath);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<String> _copyAssetToLocalPath(String assetPath, String fileName) async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String path = '${appDocDir.path}/videos';
    Directory videosDir = Directory(path);

    if (!await videosDir.exists()) {
      await videosDir.create(recursive: true);
    }

    String videoPath = '$path/$fileName.mp4';
    ByteData data = await rootBundle.load(assetPath);
    List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await File(videoPath).writeAsBytes(bytes);
    return videoPath;
  }
}
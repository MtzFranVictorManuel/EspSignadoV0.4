import 'dart:io';
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:path_provider/path_provider.dart';
import '../models/translation_model.dart';
import 'video_merger_controller.dart';

class TranslationController {
  final VideoMergerController _videoMerger = VideoMergerController();
  
  // Mapa de frases compuestas que deben tratarse como una sola unidad
  static const Map<String, String> _compoundPhrases = {
    'buenas noches': 'buenas_noches',
    'buenos días': 'buenos_dias',
    'buenas tardes': 'buenas_tardes',
    'muchas gracias': 'muchas_gracias',
    'de nada': 'de_nada',
    'por favor': 'por_favor',
    'lo siento': 'lo_siento',
    'con permiso': 'con_permiso',
    'hasta luego': 'hasta_luego',
    'hasta mañana': 'hasta_manana',
    // Agrega más frases según tus videos disponibles
  };

  /// Traduce texto en español a una lista de rutas de videos de LSM
  ///
  /// Recibe el [text] a traducir y devuelve un [TranslationModel] con los resultados
  /// y estadísticas de la traducción.
  Future<TranslationModel> translate(String text) async {
    List<String> processedWords = _processCompoundPhrases(text);
    
    List<String> videoPaths = [];
 
    for (String word in processedWords) {
      String normalizedWord = _normalize(word);
      String assetPath = 'assets/videos/$normalizedWord.mp4';
      
      if (await _assetExists(assetPath)) {
        String videoPath = await _copyAssetToLocalPath(assetPath, normalizedWord);
        videoPaths.add(videoPath);
      }
    }
    
    return TranslationModel(originalText: text, translatedText: videoPaths.join(','));
  }

  /// Procesa el texto para identificar frases compuestas que tienen
  /// un único video correspondiente en los assets
  /// 
  /// Devuelve una lista de palabras/frases normalizadas listas para ser buscadas
  /// como videos individuales.
  List<String> _processCompoundPhrases(String text) {
    String normalizedText = _removeAccents(text.toLowerCase());
    // Eliminar signos de puntuación para buscar frases compuestas correctamente
    String cleanText = normalizedText.replaceAll(RegExp(r'[^\w\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    
    List<String> result = [];
    
    // Verificar si hay frases compuestas en el texto
    String remainingText = cleanText;
    
    while (remainingText.isNotEmpty) {
      bool foundPhrase = false;
      
      // Buscar la frase compuesta más larga que coincida
      for (String phrase in _compoundPhrases.keys) {
        if (remainingText.startsWith(phrase)) {
          String videoName = _compoundPhrases[phrase]!;
          result.add(videoName);
          remainingText = remainingText.substring(phrase.length).trim();
          foundPhrase = true;
          break;
        }
      }
      if (!foundPhrase) {
        List<String> words = remainingText.split(' ');
        if (words.isNotEmpty && words.first.isNotEmpty) {
          result.add(words.first);
          words.removeAt(0);
          remainingText = words.join(' ').trim();
        } else {
          break;
        }
      }
    }
    
    return result;
  }

  /// Normaliza un texto para usarlo como nombre de archivo
  /// 
  /// Convierte a minúsculas, elimina acentos y caracteres especiales
  String _normalize(String input) {
    String normalizedText = _removeAccents(input);
    return normalizedText.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
  }

  /// Remueve acentos y caracteres especiales de un texto
  String _removeAccents(String input) {
    // Mapa de caracteres con acentos a caracteres sin acentos
    const Map<String, String> accentMap = {
      'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ā': 'a', 'ã': 'a',
      'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e', 'ē': 'e',
      'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i', 'ī': 'i',
      'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'ō': 'o', 'õ': 'o',
      'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u', 'ū': 'u',
      'ñ': 'n',
      'ç': 'c',
      'Á': 'A', 'À': 'A', 'Ä': 'A', 'Â': 'A', 'Ā': 'A', 'Ã': 'A',
      'É': 'E', 'È': 'E', 'Ë': 'E', 'Ê': 'E', 'Ē': 'E',
      'Í': 'I', 'Ì': 'I', 'Ï': 'I', 'Î': 'I', 'Ī': 'I',
      'Ó': 'O', 'Ò': 'O', 'Ö': 'O', 'Ô': 'O', 'Ō': 'O', 'Õ': 'O',
      'Ú': 'U', 'Ù': 'U', 'Ü': 'U', 'Û': 'U', 'Ū': 'U',
      'Ñ': 'N',
      'Ç': 'C',
    };

    String result = input;
    accentMap.forEach((accented, plain) {
      result = result.replaceAll(accented, plain);
    });
    
    return result;
  }

  /// Verifica si un asset existe en el bundle de la aplicación
  /// 
  /// [assetPath] Ruta del asset a verificar
  /// Retorna true si el asset existe, false en caso contrario
  Future<bool> _assetExists(String assetPath) async {
    try {
      await rootBundle.load(assetPath);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Copia un archivo de video desde los assets al almacenamiento local
  /// 
  /// [assetPath] Ruta del video en los assets
  /// [fileName] Nombre del archivo para guardar
  /// Retorna la ruta completa del archivo copiado
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

  /// Traduce texto y une todos los videos encontrados en un solo archivo
  /// 
  /// [text] Texto a traducir
  /// [outputFileName] Nombre del archivo de salida (opcional)
  /// Retorna TranslationModel con la ruta del video unido o un paquete de videos
  Future<TranslationModel> translateAndMerge(String text, {String? outputFileName}) async {
    // Primero hacer la traducción normal
    TranslationModel translation = await translate(text);
    
    // Si no hay videos, retornar la traducción original
    if (translation.translatedText.isEmpty) {
      return translation;
    }
    
    // Obtener las rutas de los videos
    List<String> videoPaths = translation.translatedText.split(',');
    
    // Generar nombre de archivo si no se proporciona
    String fileName = outputFileName ?? 'merged_${DateTime.now().millisecondsSinceEpoch}';
    
    // Unir los videos
    String? mergedVideoPath = await _videoMerger.mergeVideos(videoPaths, fileName);
    
    if (mergedVideoPath != null) {
      return TranslationModel(
        originalText: text, 
        translatedText: mergedVideoPath
      );
    } else {
      return translation;
    }
  }
}
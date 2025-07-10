
import 'dart:io';
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:path_provider/path_provider.dart';
import '../models/translation_model.dart';

class TranslationController {
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

  Future<TranslationModel> translate(String text) async {
    print('=== INICIO TRADUCCIÓN ==='); //
    print('Texto original: "$text"'); // --- IGNORE ---
    
    List<String> processedWords = _processCompoundPhrases(text);
    print('Palabras procesadas: $processedWords'); // --- IGNORE ---
    
    List<String> videoPaths = [];
 
    for (String word in processedWords) {
      String normalizedWord = _normalize(word);
      String assetPath = 'assets/videos/$normalizedWord.mp4';
      
      print('Buscando: "$word" -> "$normalizedWord" -> "$assetPath"'); // --- IGNORE ---
      
      if (await _assetExists(assetPath)) {
        print('✅ Asset encontrado: $assetPath');  // --- IGNORE ---
        String videoPath = await _copyAssetToLocalPath(assetPath, normalizedWord);
        print('✅ Video copiado a: $videoPath');  // --- IGNORE ---
        videoPaths.add(videoPath);
      } else {
        print('❌ Asset NO encontrado: $assetPath'); // --- IGNORE ---
      }
    }
    
    print('Videos finales: $videoPaths');// --- IGNORE ---
    print('=== FIN TRADUCCIÓN ===');// --- IGNORE ---
    
    return TranslationModel(originalText: text, translatedText: videoPaths.join(','));
  }

  List<String> _processCompoundPhrases(String text) {
    String normalizedText = _removeAccents(text.toLowerCase());
    // Eliminar signos de puntuación para buscar frases compuestas correctamente
    String cleanText = normalizedText.replaceAll(RegExp(r'[^\w\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    print('Texto normalizado: "$normalizedText"');
    print('Texto limpio para búsqueda: "$cleanText"');
    
    List<String> result = [];
    
    // Verificar si hay frases compuestas en el texto
    String remainingText = cleanText;
    
    while (remainingText.isNotEmpty) {
      bool foundPhrase = false;
      
      // Buscar la frase compuesta más larga que coincida
      for (String phrase in _compoundPhrases.keys) {
        if (remainingText.startsWith(phrase)) {
          String videoName = _compoundPhrases[phrase]!;
          print('Frase compuesta encontrada: "$phrase" -> "$videoName"');
          result.add(videoName);
          remainingText = remainingText.substring(phrase.length).trim();
          foundPhrase = true;
          break;
        }
      }
      
      // Si no se encontró una frase compuesta, tomar la siguiente palabra
      if (!foundPhrase) {
        List<String> words = remainingText.split(' ');
        if (words.isNotEmpty && words.first.isNotEmpty) {
          print('Palabra individual: "${words.first}"');
          result.add(words.first);
          // Remover la primera palabra y continuar
          words.removeAt(0);
          remainingText = words.join(' ').trim();
        } else {
          break;
        }
      }
    }
    
    return result;
  }

  String _normalize(String input) {
    // Primero eliminar acentos y caracteres especiales
    String normalizedText = _removeAccents(input);
    // Luego convertir a minúsculas y eliminar signos ortográficos, PERO preservar guiones bajos
    return normalizedText.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
  }

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
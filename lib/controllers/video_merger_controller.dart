import 'dart:io';
import 'package:path_provider/path_provider.dart';

class VideoMergerController {
  static final VideoMergerController _instance = VideoMergerController._internal();
  factory VideoMergerController() => _instance;
  VideoMergerController._internal();

  bool _ffmpegAvailable = false;
  String? _ffmpegPath;

  bool get isFFmpegAvailable => _ffmpegAvailable;
  String? get ffmpegPath => _ffmpegPath;

  /// Verifica si FFmpeg está disponible en el sistema
  Future<bool> checkFFmpegAvailability() async {
    try {
      print('🔍 Verificando disponibilidad de FFmpeg...');
      
      // Lista de posibles ubicaciones de FFmpeg, empezando por la más común en M1
      final possiblePaths = [
        '/opt/homebrew/bin/ffmpeg',        // Homebrew Apple Silicon (M1/M2)
        '/usr/local/bin/ffmpeg',           // Homebrew Intel
        'ffmpeg',                          // En PATH
        '/usr/bin/ffmpeg',                 // Linux estándar
        '/usr/local/share/ffmpeg',         // Otra ubicación común
      ];

      for (final path in possiblePaths) {
        print('🔍 Probando FFmpeg en: $path');
        if (await _testFFmpegPath(path)) {
          _ffmpegAvailable = true;
          _ffmpegPath = path;
          print('✅ FFmpeg encontrado en: $path');
          return true;
        } else {
          print('❌ FFmpeg no funciona en: $path');
        }
      }

      print('⚠️ FFmpeg no encontrado - usando modo de compatibilidad');
      _ffmpegAvailable = false;
      _ffmpegPath = null;
      return false;
    } catch (e) {
      print('❌ Error al verificar FFmpeg: $e');
      _ffmpegAvailable = false;
      _ffmpegPath = null;
      return false;
    }
  }

  /// Prueba si una ruta específica de FFmpeg funciona
  Future<bool> _testFFmpegPath(String path) async {
    try {
      // Verificar si el archivo existe antes de intentar ejecutarlo
      final file = File(path);
      if (path != 'ffmpeg' && !await file.exists()) {
        print('   📁 Archivo no existe: $path');
        return false;
      }
      
      print('   🔧 Probando ejecución de: $path');
      final result = await Process.run(path, ['-version']).timeout(
        const Duration(seconds: 10),
      );
      
      bool isValid = result.exitCode == 0 && result.stdout.toString().contains('ffmpeg');
      
      if (isValid) {
        print('   ✅ FFmpeg válido y funcionando');
      } else {
        print('   ❌ FFmpeg no responde correctamente (exit code: ${result.exitCode})');
      }
      
      return isValid;
    } catch (e) {
      print('   ❌ Error ejecutando FFmpeg: $e');
      return false;
    }
  }

  /// Establece una ruta personalizada de FFmpeg
  Future<bool> setCustomFFmpegPath(String path) async {
    try {
      print('🔧 Probando FFmpeg personalizado: $path');
      
      if (await _testFFmpegPath(path)) {
        _ffmpegAvailable = true;
        _ffmpegPath = path;
        print('✅ FFmpeg personalizado configurado: $path');
        return true;
      } else {
        print('❌ La ruta de FFmpeg no es válida: $path');
        return false;
      }
    } catch (e) {
      print('❌ Error al configurar FFmpeg personalizado: $e');
      return false;
    }
  }

  /// Redetecta FFmpeg (alias para checkFFmpegAvailability)
  Future<bool> redetectFFmpeg() async {
    return await checkFFmpegAvailability();
  }

  /// Obtiene la ruta actual de FFmpeg
  String? getCurrentFFmpegPath() {
    return _ffmpegPath;
  }

  /// Une múltiples videos en uno solo
  Future<String?> mergeVideos(List<String> videoPaths, String outputDirectory) async {
    if (videoPaths.isEmpty) {
      print('❌ No hay videos para unir');
      return null;
    }

    if (videoPaths.length == 1) {
      // Si solo hay un video, lo copiamos directamente
      return await _copySingleVideo(videoPaths.first, outputDirectory);
    }

    try {
      print('🎬 Iniciando unión de ${videoPaths.length} videos...');
      
      // Crear archivo de salida
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '$outputDirectory/video_unido_$timestamp.mp4';
      
      // Si FFmpeg está disponible, intentar usar la unión real
      if (_ffmpegAvailable && _ffmpegPath != null) {
        String? mergedPath = await _mergeWithFFmpeg(videoPaths, outputPath);
        if (mergedPath != null) {
          return mergedPath;
        }
      }
      
      // Fallback 1: crear paquete de videos numerados
      print('🔄 FFmpeg no disponible, creando paquete de videos...');
      String? packagePath = await createVideoPackage(videoPaths, outputDirectory);
      if (packagePath != null) {
        return packagePath;
      }
      
      // Fallback 2: copiar solo el primer video
      print('🔄 Usando último fallback: copiando primer video');
      return await _copySingleVideo(videoPaths.first, outputDirectory);
    } catch (e) {
      print('❌ Error inesperado al unir videos: $e');
      // Fallback: copiar el primer video
      return await _copySingleVideo(videoPaths.first, outputDirectory);
    }
  }

  /// Intenta unir videos usando FFmpeg del sistema
  Future<String?> _mergeWithFFmpeg(List<String> videoPaths, String outputPath) async {
    try {
      // Crear archivo temporal de lista para FFmpeg
      final tempDir = await getTemporaryDirectory();
      final listFile = File('${tempDir.path}/video_list.txt');
      
      // Escribir lista de videos
      final listContent = videoPaths.map((path) => "file '$path'").join('\n');
      await listFile.writeAsString(listContent);
      
      print('📝 Lista de videos creada: ${listFile.path}');
      print('📁 Archivo de salida: $outputPath');
      
      // Comando FFmpeg para concatenar videos
      final arguments = [
        '-f', 'concat',
        '-safe', '0',
        '-i', listFile.path,
        '-c', 'copy',
        outputPath
      ];
      
      print('🔧 Ejecutando FFmpeg: $_ffmpegPath ${arguments.join(' ')}');
      final result = await Process.run(_ffmpegPath!, arguments).timeout(
        const Duration(minutes: 5),
      );
      
      // Limpiar archivo temporal
      try {
        await listFile.delete();
      } catch (e) {
        print('⚠️ No se pudo eliminar archivo temporal: $e');
      }
      
      if (result.exitCode == 0) {
        // Verificar que el archivo se creó correctamente
        final outputFile = File(outputPath);
        if (await outputFile.exists()) {
          final fileSize = await outputFile.length();
          print('✅ Video unido exitosamente: $outputPath (${fileSize} bytes)');
          return outputPath;
        } else {
          print('❌ El archivo de salida no se creó');
          return null;
        }
      } else {
        print('❌ Error en FFmpeg: ${result.stderr}');
        return null;
      }
    } catch (e) {
      print('❌ Error al ejecutar FFmpeg: $e');
      return null;
    }
  }

  /// Copia un solo video al directorio de salida (fallback)
  Future<String?> _copySingleVideo(String videoPath, String outputDirectory) async {
    try {
      final sourceFile = File(videoPath);
      if (!await sourceFile.exists()) {
        print('❌ El archivo de video no existe: $videoPath');
        return null;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = videoPath.split('/').last.replaceAll('.mp4', '');
      final outputPath = '$outputDirectory/${fileName}_$timestamp.mp4';
      
      print('📁 Copiando video a: $outputPath');
      await sourceFile.copy(outputPath);
      
      final outputFile = File(outputPath);
      if (await outputFile.exists()) {
        final fileSize = await outputFile.length();
        print('✅ Video copiado exitosamente: $outputPath (${fileSize} bytes)');
        return outputPath;
      } else {
        print('❌ Error al copiar el video');
        return null;
      }
    } catch (e) {
      print('❌ Error al copiar video: $e');
      return null;
    }
  }

  /// Convierte video a GIF (funcionalidad adicional)
  Future<String?> convertToGif(String videoPath, String outputDirectory) async {
    if (!_ffmpegAvailable || _ffmpegPath == null) {
      print('❌ FFmpeg no disponible para conversión a GIF');
      // En lugar de fallar, podemos copiar el video original
      return await _copySingleVideo(videoPath, outputDirectory);
    }

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final paletteFile = '$outputDirectory/palette_$timestamp.png';
      final outputPath = '$outputDirectory/video_$timestamp.gif';
      
      print('🎨 Convirtiendo a GIF: $outputPath');
      
      // Primer comando: generar paleta de colores
      final paletteArgs = [
        '-i', videoPath,
        '-vf', 'fps=10,scale=320:-1:flags=lanczos,palettegen',
        '-y', paletteFile
      ];
      
      print('🔧 Generando paleta de colores...');
      final paletteResult = await Process.run(_ffmpegPath!, paletteArgs).timeout(
        const Duration(minutes: 2),
      );
      
      if (paletteResult.exitCode != 0) {
        print('❌ Error generando paleta para GIF: ${paletteResult.stderr}');
        return null;
      }
      
      // Segundo comando: crear GIF usando la paleta
      final gifArgs = [
        '-i', videoPath,
        '-i', paletteFile,
        '-lavfi', 'fps=10,scale=320:-1:flags=lanczos [x]; [x][1:v] paletteuse',
        '-y', outputPath
      ];
      
      print('🔧 Creando GIF...');
      final gifResult = await Process.run(_ffmpegPath!, gifArgs).timeout(
        const Duration(minutes: 5),
      );
      
      // Limpiar archivo de paleta temporal
      try {
        await File(paletteFile).delete();
      } catch (e) {
        print('⚠️ No se pudo eliminar archivo de paleta: $e');
      }
      
      if (gifResult.exitCode == 0) {
        final outputFile = File(outputPath);
        if (await outputFile.exists()) {
          final fileSize = await outputFile.length();
          print('✅ GIF creado exitosamente: $outputPath (${fileSize} bytes)');
          return outputPath;
        }
      }
      
      print('❌ Error al crear GIF: ${gifResult.stderr}');
      return null;
    } catch (e) {
      print('❌ Error inesperado al crear GIF: $e');
      return null;
    }
  }

  /// Crea un paquete de videos en una carpeta cuando FFmpeg no está disponible
  Future<String?> createVideoPackage(List<String> videoPaths, String outputDirectory) async {
    if (videoPaths.isEmpty) {
      print('❌ No hay videos para empaquetar');
      return null;
    }

    try {
      // Crear carpeta para el paquete de videos
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final packageDir = '$outputDirectory/video_package_$timestamp';
      final packageDirectory = Directory(packageDir);
      
      print('📦 Creando paquete de videos en: $packageDir');
      await packageDirectory.create(recursive: true);
      
      // Copiar todos los videos al paquete
      for (int i = 0; i < videoPaths.length; i++) {
        final sourcePath = videoPaths[i];
        final fileName = sourcePath.split('/').last;
        final destinationPath = '$packageDir/${(i + 1).toString().padLeft(2, '0')}_$fileName';
        
        try {
          await File(sourcePath).copy(destinationPath);
          print('📁 Copiado: $fileName');
        } catch (e) {
          print('❌ Error copiando $fileName: $e');
        }
      }
      
      // Crear un archivo de información
      final infoFile = File('$packageDir/README.txt');
      final infoContent = '''Paquete de Videos - Traductor Español Signado
Creado: ${DateTime.now()}
Total de videos: ${videoPaths.length}

Instrucciones:
- Los videos están numerados en orden de secuencia
- Puedes reproducirlos en orden para ver la traducción completa
- Para unir los videos, usa cualquier editor de video

Videos incluidos:
${videoPaths.asMap().entries.map((entry) => '${(entry.key + 1).toString().padLeft(2, '0')}. ${entry.value.split('/').last}').join('\n')}
''';
      
      await infoFile.writeAsString(infoContent);
      
      print('✅ Paquete de videos creado exitosamente: $packageDir');
      return packageDir;
    } catch (e) {
      print('❌ Error creando paquete de videos: $e');
      return null;
    }
  }
}

import 'package:flutter/material.dart';
import '../widgets/video_player_widget.dart';
import '../controllers/video_merger_controller.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class VideoView extends StatefulWidget {
  final List<String> videoPaths;

  const VideoView({super.key, required this.videoPaths});

  @override
  State<VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<VideoView> {
  final VideoMergerController _videoMerger = VideoMergerController();
  bool _isExporting = false;
  bool _isTranslating = false;
  String? _selectedDirectory;
  /// Almacena el estado de disponibilidad de FFmpeg:
  /// null = no verificado, true = disponible, false = no disponible
  bool? _ffmpegAvailable;

  @override
  void initState() {
    super.initState();
    _checkFFmpegStatus(); 
  }

  /// Verifica la disponibilidad de FFmpeg en el sistema y actualiza la UI con el resultado
  Future<void> _checkFFmpegStatus() async {
    try {
      bool isAvailable = await _videoMerger.redetectFFmpeg();
      
      setState(() {
        _ffmpegAvailable = isAvailable;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showFFmpegStatusBanner();
      });
    } catch (e) {
      setState(() {
        _ffmpegAvailable = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showFFmpegStatusBanner();
      });
    }
  }

  /// Permite al usuario seleccionar manualmente la ruta al ejecutable de FFmpeg
  Future<void> _selectCustomFFmpegPath() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Selecciona el ejecutable de FFmpeg',
        type: FileType.any,
        allowMultiple: false,
      );
      
      if (result != null && result.files.single.path != null) {
        String selectedPath = result.files.single.path!;
        
        setState(() {
          _isExporting = true;
        });
        
        bool isValid = await _videoMerger.setCustomFFmpegPath(selectedPath);
        
        setState(() {
          _isExporting = false;
          _ffmpegAvailable = isValid;
        });
        
        if (isValid) {
          _showSnackBar('✅ FFmpeg configurado correctamente', Colors.green);
        } else {
          _showSnackBar('❌ El archivo seleccionado no es un FFmpeg válido', Colors.red);
        }
      }
    } catch (e) {
      setState(() {
        _isExporting = false;
      });
      _showSnackBar('❌ Error al seleccionar FFmpeg: $e', Colors.red);
    }
  }

  /// Permite al usuario seleccionar una carpeta para guardar los videos exportados
  /// Si falla, intenta usar la carpeta de documentos como fallback
  Future<void> _selectOutputDirectory() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Selecciona una carpeta para guardar el video',
        lockParentWindow: true,
      );
      
      if (selectedDirectory != null) {
        setState(() {
          _selectedDirectory = selectedDirectory;
        });
        _showSnackBar('📁 Carpeta seleccionada: ${selectedDirectory.split('/').last}', Colors.blue);
        print('Carpeta seleccionada: $selectedDirectory');
      } else {
        print('Usuario canceló la selección de carpeta');
        _showSnackBar('❌ Selección de carpeta cancelada', Colors.orange);
      }
    } catch (e) {
      print('Error al seleccionar carpeta: $e');
      _showSnackBar('❌ Error al seleccionar carpeta: $e', Colors.red);
      
      try {
        final directory = await getApplicationDocumentsDirectory();
        setState(() {
          _selectedDirectory = directory.path;
        });
        _showSnackBar('📁 Usando carpeta por defecto: Documentos', Colors.blue);
      } catch (fallbackError) {
        print('Error en fallback: $fallbackError');
      }
    }
  }

  /// Exporta la secuencia de videos como un solo archivo MP4
  /// Si FFmpeg no está disponible, creará un paquete de videos numerados
  Future<void> _exportVideo() async {
    if (widget.videoPaths.isEmpty) {
      _showSnackBar('No hay videos para exportar', Colors.red);
      return;
    }

    if (_selectedDirectory == null) {
      bool shouldSelectFolder = await _showFolderSelectionDialog();
      if (!shouldSelectFolder) return;
      
      await _selectOutputDirectory();
      if (_selectedDirectory == null) return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      String? mergedVideoPath = await _videoMerger.mergeVideos(widget.videoPaths, _selectedDirectory!);
      
      if (mergedVideoPath != null) {
        _showSnackBar('✅ Video exportado exitosamente a: $mergedVideoPath', Colors.green);
        print('Video exportado en: $mergedVideoPath');
        
      } else {
        _showSnackBar('❌ Error al exportar el video', Colors.red);
      }
    } catch (e) {
      _showSnackBar('❌ Error inesperado: $e', Colors.red);
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

  /// Convierte la secuencia de videos en un GIF animado
  /// Requiere que FFmpeg esté disponible en el sistema
  Future<void> _convertToGif() async {
    if (widget.videoPaths.isEmpty) {
      _showSnackBar('No hay videos para convertir', Colors.red);
      return;
    }

    if (_selectedDirectory == null) {
      bool shouldSelectFolder = await _showFolderSelectionDialog();
      if (!shouldSelectFolder) return;
      
      await _selectOutputDirectory();
      if (_selectedDirectory == null) return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      String? videoToConvert;
      
      if (widget.videoPaths.length == 1) {
        videoToConvert = widget.videoPaths.first;
      } else {
        videoToConvert = await _videoMerger.mergeVideos(widget.videoPaths, _selectedDirectory!);
      }
      
      if (videoToConvert != null) {
        String? gifPath = await _videoMerger.convertToGif(videoToConvert, _selectedDirectory!);
        
        if (gifPath != null) {
          _showSnackBar('✅ GIF creado exitosamente: $gifPath', Colors.green);
          print('GIF creado en: $gifPath');
        } else {
          _showSnackBar('❌ Error al crear el GIF', Colors.red);
        }
      } else {
        _showSnackBar('❌ Error al preparar el video para conversión', Colors.red);
      }
    } catch (e) {
      _showSnackBar('❌ Error inesperado: $e', Colors.red);
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

  /// Muestra un diálogo para preguntar al usuario si desea seleccionar una carpeta personalizada
  /// 
  /// Retorna true si el usuario acepta seleccionar una carpeta, false si cancela
  Future<bool> _showFolderSelectionDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Seleccionar carpeta'),
          content: const Text('¿Deseas seleccionar una carpeta personalizada para guardar el video?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Seleccionar carpeta'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  /// Muestra un banner informativo sobre el estado de FFmpeg en la aplicación
  void _showFFmpegStatusBanner() {
    String message;
    Color backgroundColor;
    IconData icon;

    if (_ffmpegAvailable == null) {
      message = '🔍 Verificando FFmpeg...';
      backgroundColor = Colors.grey[700]!;
      icon = Icons.help_outline;
    } else if (_ffmpegAvailable!) {
      message = '✅ FFmpeg disponible - Unión de videos habilitada';
      backgroundColor = Colors.green[600]!;
      icon = Icons.check_circle;
    } else {
      message = '⚠️ FFmpeg no disponible - Se creará paquete de videos';
      backgroundColor = Colors.orange[600]!;
      icon = Icons.warning;
    }

    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        backgroundColor: backgroundColor,
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
            },
            child: const Text(
              'OK',
              style: TextStyle(color: Colors.white),
            ),
          ),
          if (_ffmpegAvailable == false)
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                _selectCustomFFmpegPath();
              },
              child: const Text(
                'Configurar',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
    );

    // Auto-ocultar el banner después de 4 segundos
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
      }
    });
  }

  /// Muestra un mensaje de notificación tipo SnackBar
  /// 
  /// [message] Mensaje a mostrar
  /// [backgroundColor] Color de fondo del SnackBar
  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey,
        title: const Text('Español - Español signado'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [            Container(
              width: 300,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(20.0),
              ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20.0),
                  child: VideoPlayerWidget(videoPaths: widget.videoPaths),
                ),
              ),
              const SizedBox(height: 10.0),            if (_isTranslating || _isExporting)
                Container(
                  width: 300,
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _isTranslating 
                          ? 'Generando videos...' 
                          : 'Exportando video...',
                        style: const TextStyle(color: Colors.white, fontSize: 14.0),
                      ),
                      const SizedBox(height: 10.0),
                      const LinearProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                        backgroundColor: Colors.grey,
                      ),
                    ],
                  ),
                ),
              if (_isTranslating || _isExporting) const SizedBox(height: 10.0),
              const SizedBox(height: 20.0),            ElevatedButton(
                onPressed: (_isTranslating || _isExporting) ? null : _convertToGif,
                style: ElevatedButton.styleFrom(
                  backgroundColor: (_isTranslating || _isExporting) ? Colors.grey : Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 40.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                ),
                child: const Text(
                  'Convertir a Gif',
                  style: TextStyle(color: Colors.white, fontSize: 16.0),
                ),
              ),
              const SizedBox(height: 15.0),            ElevatedButton.icon(
                onPressed: (_isTranslating || _isExporting) ? null : _selectOutputDirectory,
                icon: const Icon(Icons.folder_open, color: Colors.white),
                label: Text(
                  _selectedDirectory != null 
                    ? 'Carpeta: ${_selectedDirectory!.split('/').last}'
                    : 'Seleccionar carpeta',
                  style: const TextStyle(color: Colors.white, fontSize: 14.0),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: (_isTranslating || _isExporting) 
                    ? Colors.grey 
                    : (_selectedDirectory != null ? Colors.orange : Colors.grey[600]),
                  padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 30.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                ),
              ),
              const SizedBox(height: 15.0),            ElevatedButton(
                onPressed: (_isExporting || _isTranslating) ? null : _exportVideo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: (_isExporting || _isTranslating) ? Colors.grey : Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 40.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                ),
                child: _isExporting 
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Exportando...',
                          style: TextStyle(color: Colors.white, fontSize: 16.0),
                        ),
                      ],
                    )
                  : const Text(
                      'Exportar Video',
                      style: TextStyle(color: Colors.white, fontSize: 16.0),
                    ),
              ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.grey[300],
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home, color: Colors.black),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.share, color: Colors.black),
            label: '',
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../widgets/video_player_widget.dart';

class VideoView extends StatelessWidget {
  final List<String> videoPaths;

  const VideoView({super.key, required this.videoPaths});

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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Video container
            Container(
              width: 300,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20.0),
                child: VideoPlayerWidget(videoPaths: videoPaths),
              ),
            ),
            const SizedBox(height: 20.0),
            // Convert to Gif Button
            ElevatedButton(
              onPressed: () {
                // Aquí puedes agregar la lógica para convertir el video a GIF.
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
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
          ],
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

import 'package:flutter/material.dart';
import 'video_view.dart';
import '../controllers/translation_controller.dart';
import '../models/translation_model.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final TextEditingController _controller = TextEditingController();
  String _translatedText = '';

  void _translateText() async {
    TranslationController translationController = TranslationController();
    TranslationModel translation = await translationController.translate(_controller.text);
    setState(() {
      _translatedText = translation.translatedText;
    });
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoView(videoPaths: _translatedText.split(',')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Traductor Español a Español Signado'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Text Input Field
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey[800],
                hintText: 'Type text here...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20.0),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 20.0),
            // Translate Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _translateText,
                child: const Text('Traducir'),
              ),
            ),
            const SizedBox(height: 20.0),
            // Translated Text
            Text(
              _translatedText,
              style: const TextStyle(color: Colors.white, fontSize: 18.0),
            ),
          ],
        ),
      ),
    );
  }
}
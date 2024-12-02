import 'package:flutter/material.dart';
import 'views/home_view.dart'; // Importa la vista

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false, // Para quitar la etiqueta de debug
      home: HomeView(), // Define HomeView como la vista inicial
    );
  }
}

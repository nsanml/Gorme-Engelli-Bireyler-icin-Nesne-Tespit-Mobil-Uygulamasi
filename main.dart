import 'package:flutter/material.dart';
import 'screens/camera_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EngelsizAsistanApp());
}

class EngelsizAsistanApp extends StatelessWidget {
  const EngelsizAsistanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Görme Engelli Asistanı',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        brightness: Brightness.dark,
      ),
      home: const CameraScreen(),
    );
  }
}

import 'package:flutter/material.dart';

// LIRIDGE CORE: Entry Point
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LiridgeApp());
}

class LiridgeApp extends StatelessWidget {
  const LiridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LIRIDGE Core',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const Scaffold(
        body: Center(
          child: Text(
            '[SYSTEM READY]\nWaiting for PiP Initialization...',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.greenAccent,
              fontFamily: 'Courier',
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

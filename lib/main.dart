import 'package:flutter/material.dart';

void main() {
  runApp(const LiridgeApp());
}

class LiridgeApp extends StatelessWidget {
  const LiridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LIRIDGE Core',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'LIRIDGE SYSTEM READY',
            style: TextStyle(color: Colors.greenAccent, fontSize: 24),
          ),
        ),
      ),
    );
  }
}

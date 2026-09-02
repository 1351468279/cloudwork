import 'package:flutter/material.dart';
import 'views/commander_screen.dart';

void main() {
  runApp(const CloudWorkApp());
}

class CloudWorkApp extends StatelessWidget {
  const CloudWorkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CloudWork 指挥官',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF58A6FF),
          secondary: Color(0xFF238636),
          surface: Color(0xFF161B22),
        ),
      ),
      home: const CommanderScreen(),
    );
  }
}

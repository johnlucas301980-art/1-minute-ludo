import 'package:flutter/material.dart';

void main() {
  runApp(const OneLudoApp());
}

/// Root application widget for 1 Minute Ludo.
class OneLudoApp extends StatelessWidget {
  const OneLudoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '1 Minute Ludo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A1A2E)),
        useMaterial3: true,
      ),
      home: const _PlaceholderHome(),
    );
  }
}

/// Temporary placeholder — will be replaced with the actual router/shell.
class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          '1 Minute Ludo',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'pages/landingPage.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color seed = Color(0xFF0F1724);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: seed,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: seed,
      ),
      home: const LandingPageUI(),
    );
  }
}

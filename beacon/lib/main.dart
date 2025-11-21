import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pages/landingPage.dart';
import 'providers/beacon_provider.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color seed = Color(0xFF0F1724);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BeaconProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: seed,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: seed,
        ),
        home: const LandingPageUI(),
      ),
    );
  }
}

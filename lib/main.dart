import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './views/loadingScreen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Opcional: forzar inicialización de SharedPreferences
  await SharedPreferences.getInstance();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BlessHealth24',
      home: const SplashScreen(),
    );
  }
}

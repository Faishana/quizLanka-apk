import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quiz_lanka/Login.dart';
import 'package:quiz_lanka/Splash.dart';

void main() {
  runApp(
    ChangeNotifierProvider(create: (_) => AuthProvider(), child: const MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuizLanka AI',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
        fontFamily: 'Poppins',
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

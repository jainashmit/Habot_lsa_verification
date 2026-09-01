import 'package:flutter/material.dart';
import 'screens/lsa_verification_screen.dart';

void main() {
  runApp(const HabotApp());
}

class HabotApp extends StatelessWidget {
  const HabotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HabotConnect LSA Verification',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1A3A6B),
      ),
      home: const LsaVerificationScreen(),
    );
  }
}
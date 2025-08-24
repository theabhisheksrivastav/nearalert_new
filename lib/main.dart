import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const NearAlertApp());
}

class NearAlertApp extends StatelessWidget {
  const NearAlertApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "NearAlert",
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
    );
  }
}

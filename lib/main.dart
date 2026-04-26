import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'pages/teacher_home_page.dart';
import 'pages/student_home_page.dart';
import 'pages/login_page.dart';

// The main entry point of the Flutter application
void main() async {
  // Required to ensure Flutter framework is fully initialized before using plugins (like Firebase)
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize Firebase connection using auto-generated config file
    await Firebase.initializeApp();
  } catch (e) {
    // Print error to console if Firebase fails to connect (e.g. no internet or wrong config)
    debugPrint("Firebase init failed: $e");
  }
  
  // Start the Flutter app by running the root widget
  runApp(const MyApp());
}

// The root widget of the application
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MaterialApp sets up the core routing and visual theme for the app
    return MaterialApp(
      // Hides the "DEBUG" banner in the top right corner during development
      debugShowCheckedModeBanner: false,
      title: 'AttenQR',
      // Define the global visual theme (colors, fonts, etc.)
      theme: ThemeData(
        primarySwatch: Colors.teal, // Sets the default accent color for buttons/bars
        scaffoldBackgroundColor: const Color(0xFFF6F7FB), // Sets a light grayish-blue background everywhere
      ),
      // The first screen the user sees when the app launches
      home: const LoginPage(),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:flutter_native_splash/flutter_native_splash.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'firebase_options.dart';
// import 'splash_screen.dart';
// import 'services/notification_service.dart'; // <-- Your fixed service

// void main() async {
//   WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

//   // Keep splash screen until everything is ready
//   FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

//   try {
//     // 1. Initialize Firebase
//     await Firebase.initializeApp(
//       options: DefaultFirebaseOptions.currentPlatform,
//     );

//     // 2. Initialize local notifications (creates channel + prepares everything)
//     await NotificationService().init(); // <-- This is the correct call now

//     // Optional: You can pre-request notification permission here (recommended)
//     // await NotificationService().requestPermission();  // uncomment if you want permission immediately
//   } catch (e) {
//     debugPrint("Initialization error: $e");
//   } finally {
//     // Remove splash after everything is ready (you can increase delay if needed)
//     await Future.delayed(const Duration(seconds: 1));
//     FlutterNativeSplash.remove();
//   }

//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       title: 'RiderHub',
//       theme: ThemeData(
//         primarySwatch: Colors.purple,
//         fontFamily: 'Inter',
//         useMaterial3: true,
//       ),
//       home: const SplashScreen(),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:riderhub/screens/login.dart';
import 'firebase_options.dart';
import 'splash_screen.dart';
import 'services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/customer/customer_home_screen.dart'; // ← adjust path if needed
import 'screens/rider/rider_homescreen.dart'; // ← adjust path if needed // or wherever LoginScreen lives

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await NotificationService().init();
    // await NotificationService().requestPermission(); // optional
  } catch (e) {
    debugPrint("Initialization error: $e");
  } finally {
    await Future.delayed(const Duration(seconds: 1));
    FlutterNativeSplash.remove();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RiderHub',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      home: const AuthWrapper(), // ← changed from SplashScreen
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();

    final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final String? userType = prefs.getString('user_type');

    if (!mounted) return;

    if (isLoggedIn && userType != null) {
      // Already logged in → go directly to the correct home screen
      Widget homeScreen;

      if (userType == 'rider') {
        homeScreen = const RiderHomeScreen();
      } else {
        homeScreen = const CustomerHomeScreen();
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => homeScreen),
      );
    } else {
      // Not logged in → go to LoginScreen (you can keep SplashScreen first if you want)
      // Option A: straight to login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );

      // Option B: show your SplashScreen for 2-3 seconds, then login
      // Navigator.pushReplacement(
      //   context,
      //   MaterialPageRoute(builder: (context) => const SplashScreen()),
      // );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Shown very briefly while we check login status
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

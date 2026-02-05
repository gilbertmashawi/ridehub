import 'dart:async';
import 'package:flutter/material.dart';
import 'package:riderhub/screens/customer/customer_home_screen.dart';
import 'package:riderhub/screens/rider/rider_homescreen.dart';
import 'package:riderhub/screens/landing.dart';

import 'package:riderhub/screens/login.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // Wait 2 seconds then go to homepage
    Timer(const Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        // MaterialPageRoute(builder: (context) => const RiderHomeScreen()),
        // MaterialPageRoute(builder: (context) => const CustomerHomeScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Icon(
          Icons.delivery_dining, // 🚚 built-in Flutter icon
          size: 150,
          color: Colors.black,
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gusto/features/auth/screens/login_screen.dart'; // Ensure this path is correct
import 'package:gusto/features/home/screens/root_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SmartSplashScreen extends StatefulWidget {
  const SmartSplashScreen({super.key});

  @override
  State<SmartSplashScreen> createState() => _SmartSplashScreenState();
}

class _SmartSplashScreenState extends State<SmartSplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Keep the splash visible for 3 seconds
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      _navigateToHome();
    }
  }

  void _navigateToHome() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    
    // Determine the next screen
    Widget nextScreen = isLoggedIn
        ? const RootScreen()
        : const FoodAppLoginPage();

    if (!mounted) return;

    // Premium Fade + Scale transition
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 1000), // Slower, smoother fade
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFF9966), // Soft Apricot
              Color(0xFFFF5E62), // Vibrant Coral
            ],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background decoration
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // THE POP-OUT LOGO
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.elasticOut, // Gives it that "pop" bounce
                  builder: (context, value, child) {
                    return Transform.scale(scale: value, child: child);
                  },
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.5),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'images/Gusto_logo.png',
                        height: 150,
                        width: 150,
                      ),
                    ),
                ),

                const SizedBox(height: 40),

                // Typography
                Text(
                  "GUSTO",
                  style: GoogleFonts.poppins(
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  "Food you love, delivered Home.",
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),

            // Loading indicator
            const Positioned(
              bottom: 60,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

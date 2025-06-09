import 'package:flutter/material.dart';
import 'package:flutter_application_2/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoAnimation;
  late Animation<double> _textAnimation;
  bool _isFirstLaunch = true;

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
    _initAnimation();
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    _isFirstLaunch = prefs.getBool('is_first_launch') ?? true;
    if (_isFirstLaunch) {
      await prefs.setBool('is_first_launch', false);
    }
  }

  void _initAnimation() {
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _logoAnimation = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _textAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _controller.forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _checkSessionAndNavigate();
      }
    });
  }

  Future<void> _checkSessionAndNavigate() async {
    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;

    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      if (session != null) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final scaleFactor = (screenWidth / 375.0).clamp(1.0, 1.3);
    return Scaffold(
      backgroundColor: const Color(0xFFEBE6F2),
      body: Stack(
        children: [
          // Фоновый градиент
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFEBE6F2),
                  Color(0xFFFCE1DB),
                ],
              ),
            ),
          ),
          
          // Логотип
          Positioned(
            left: screenWidth * 0.35,
            top: screenHeight * 0.41,
            child: AnimatedBuilder(
              animation: _logoAnimation,
              builder: (context, child) {
                 return Transform(
                 transform: Matrix4.identity()
                  ..translate(_logoAnimation.value * screenWidth)
                  ..scale(scaleFactor),
                alignment: Alignment.center,
                child: Hero(
                  tag: 'logo',
                  child: Image.asset(
                    'assets/logo.png',
                    width: screenWidth * 0.3,
                    height: screenWidth * 0.3,
                    cacheWidth: max(1, (screenWidth * 0.3).toInt()),
                    cacheHeight: max(1, (screenWidth * 0.3).toInt()),
                  ),
                ),
              );
            },
          ),
        ),

          // Текст "Мамин Гид"
          Positioned(
            left: screenWidth * 0.52,
            top: screenHeight * 0.41,
            child: AnimatedBuilder(
              animation: _textAnimation,
              builder: (context, child) {
                return Transform(
                  transform: Matrix4.identity()
                    ..translate(_textAnimation.value * screenWidth)
                    ..scale(scaleFactor),
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: screenWidth * 0.3,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              Color.fromARGB(255, 54, 6, 56),
                              Color.fromARGB(255, 190, 125, 183),
                            ],
                          ).createShader(bounds),
                          child: Text(
                            'Мамин',
                            style: TextStyle(
                               fontSize: 18 * scaleFactor,
                              height: 1,
                              fontFamily: 'Comfortaa',
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 0),
                          Text(
                          'Гид',
                          style: TextStyle(
                            fontSize: 18 * scaleFactor,
                            fontFamily: 'Comfortaa',
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFBE7DBC),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_application_2/home_screen.dart';
import 'package:flutter_application_2/splash_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'reset_password_screen.dart';
import 'login_screen.dart';

// Глобальный ключ навигатора
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://gctfgjrvavtbfbykxjqr.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdjdGZnanJ2YXZ0YmZieWt4anFyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDczMjM2NDksImV4cCI6MjA2Mjg5OTY0OX0.ov37m0GnrYoGU4ZVPiZQ-MQXW_7yHWj1a0ESePgk46E',
  );

  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  Uri? _initialUri;
  bool _isInitialized = false;
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        _initialUri = await _appLinks.getInitialAppLink();
        print('Initial URI: $_initialUri');
        if (_initialUri != null) {
          _handleDeepLink(_initialUri!);
        }

        _linkSubscription = _appLinks.uriLinkStream.listen((Uri? uri) {
          print('Received URI: $uri');
          if (uri != null) {
            _handleDeepLink(uri);
          }
        }, onError: (err) {
          print('Error receiving URI: $err');
        });
      } catch (e) {
        print('Error initializing deep links: $e');
      }
    }
    setState(() {
      _isInitialized = true;
    });
  }

  void _handleDeepLink(Uri uri) {
  print('Handling deep link: $uri');

  // Для deep link вида myapp://reset-password?code=...
  if (uri.host == 'reset-password') {
    final token = uri.queryParameters['code']; // или 'token', если Supabase его так передаёт
    if (token != null && token.isNotEmpty) {
      print('Reset password token: $token');
      if (navigatorKey.currentState != null) {
        print('Navigating to ResetPasswordScreen from handler...');
        navigatorKey.currentState?.pushReplacement(MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(token: token),
        ));
      } else {
        print('NavigatorState is null from handler!');
      }
    } else {
      print('Token is null or empty');
    }
  } else {
    print('Unhandled deep link in handler: $uri');
  }
}


  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Мамин Гид',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      routes: {
        '/login': (context) => const LoginScreen(),
        
        '/': (context) => const SplashScreen(),
        '/home': (context) => const HomeScreen(),
      },
      initialRoute: '/',
    );
  }
}



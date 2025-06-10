import 'package:flutter/material.dart';
import 'package:flutter_application_2/home_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'registration_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;
  bool _obscurePassword = true;

  double opacity = 0.0; 

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 600), () {
      setState(() {
        opacity = 1.0; 
      });
    });
  }

  void showCustomError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        content: Container(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            message,
            style: TextStyle(
              fontSize: 17,
              fontFamily: 'Comfortaa',
              fontWeight: FontWeight.w700,
              color: Color(0xFF360638),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        duration: Duration(seconds: 3),
      ),
    );
  }

  // Функция для форматирования ошибок Supabase
  String _formatErrorMessage(dynamic error) {
    print('Raw error: $error'); 
    
    if (error is AuthException) {
      switch (error.message) {
        case 'Invalid login credentials':
          return 'Неверный email или пароль';
        case 'Email not confirmed':
          return 'Email не подтвержден. Проверьте почту';
        case 'Invalid email':
          return 'Некорректный формат email';
        default:
          if (error.message.contains('Failed host lookup') || error.message.contains('SocketException')){
             return 'Не удалось подключиться к серверу. Проверьте ваше интернет-соединение.';
          }
          print('Unhandled AuthException: ${error.message}');
          return 'Ошибка: ${error.message}';
      }
    } else if (error.toString().contains('SocketException') || error.toString().contains('Failed host lookup')) {
       return 'Не удалось подключиться к серверу. Проверьте ваше интернет-соединение.';
    }
    
    print('Unhandled error type: ${error.runtimeType}');
    return 'Произошла ошибка. Попробуйте позже';
  }

  Future<void> signIn() async {
    setState(() {
      isLoading = true;
    });

    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      showCustomError(context, "Заполните все поля");
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.session != null) {
        // Сохраняем сессию
        await supabase.auth.setSession(response.session!.refreshToken!);
        
        if (mounted) {
          showCustomError(context, "Успешный вход!");
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      }
    } catch (error) {
      final errorMessage = _formatErrorMessage(error);
      if (mounted) {
        showCustomError(context, errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromARGB(157, 235, 230, 242),
              Color.fromARGB(255, 252, 225, 219),
            ],
            stops: const [0.0, 1.0],
          ),
        ),
        child: AnimatedOpacity(
          opacity: opacity,
          duration: const Duration(milliseconds: 500),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 24),
                    Text(
                      'С возвращением!',
                      style: TextStyle(
                        fontSize: 28,
                        fontFamily: 'Comfortaa',
                        fontWeight: FontWeight.w900,
                        color: Color.fromARGB(255, 54, 6, 56),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Продолжайте свое путешествие с нами!',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Comfortaa',
                        fontWeight: FontWeight.w400,
                        color: Color.fromARGB(255, 54, 6, 56),
                      ),
                    ),
                    SizedBox(height: 32),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Электронная почта',
                            style: TextStyle(
                              fontSize: 15,
                              fontFamily: 'Comfortaa',
                              fontWeight: FontWeight.w900,
                              color: Color.fromARGB(255, 54, 6, 56),
                            ),
                          ),
                          TextSpan(
                            text: '*',
                            style: TextStyle(
                              fontSize: 15,
                              fontFamily: 'Comfortaa',
                              fontWeight: FontWeight.w900,
                              color: Color.fromARGB(255, 243, 32, 32),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: emailController,
                      decoration: InputDecoration(
                        hintText: 'example@gmail.com',
                        filled: true,
                        fillColor: Color(0xFFE0CAE6).withOpacity(0.4),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: TextStyle(
                        fontSize: 15,
                        fontFamily: 'Comfortaa',
                      ),
                    ),
                    SizedBox(height: 20),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Пароль',
                            style: TextStyle(
                              fontSize: 15,
                              fontFamily: 'Comfortaa',
                              fontWeight: FontWeight.w900,
                              color: Color.fromARGB(255, 54, 6, 56),
                            ),
                          ),
                          TextSpan(
                            text: '*',
                            style: TextStyle(
                              fontSize: 15,
                              fontFamily: 'Comfortaa',
                              fontWeight: FontWeight.w900,
                              color: Color.fromARGB(255, 243, 32, 32),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        hintText: 'введите пароль',
                        filled: true,
                        fillColor: Color(0xFFE0CAE6).withOpacity(0.4),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: Color(0xFF360638),
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      style: TextStyle(
                        fontSize: 15,
                        fontFamily: 'Comfortaa',
                      ),
                    ),
                    SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => ForgotPasswordScreen()),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          minimumSize: Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Забыли пароль?',
                          style: TextStyle(
                            fontSize: 15,
                            fontFamily: 'Comfortaa',
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF360638),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 60),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : signIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color.fromARGB(255, 190, 125, 183),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: isLoading
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text(
                                'Войти',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontFamily: 'Comfortaa',
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Нет аккаунта?',
                            style: TextStyle(
                              fontSize: 13,
                              fontFamily: 'Comfortaa',
                              fontWeight: FontWeight.w400,
                              color: Color.fromARGB(255, 54, 6, 56),
                            ),
                          ),
                          SizedBox(width: 4),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  transitionDuration: Duration(milliseconds: 500),
                                  pageBuilder: (context, animation, secondaryAnimation) => RegistrationScreen(),
                                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    );
                                  },
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Зарегистрируйтесь',
                              style: TextStyle(
                                fontSize: 13,
                                fontFamily: 'Comfortaa',
                                fontWeight: FontWeight.w900,
                                color: Color.fromARGB(255, 54, 6, 56),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

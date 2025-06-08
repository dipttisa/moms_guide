import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController emailController = TextEditingController();
  double opacity = 0.0;
  bool isLoading = false;
  final SupabaseClient supabase = Supabase.instance.client;

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
    print('Raw error: $error'); // Логируем оригинальную ошибку
    
    if (error is AuthException) {
      switch (error.message) {
        case 'User not found':
          return 'Учетная запись с таким email не найдена';
        case 'Invalid email':
          return 'Некорректный формат email';
        case 'Invalid login credentials':
          return 'Не удалось отправить ссылку. Возможно, email не подтвержден или произошла ошибка.';
        default:
          print('Unhandled AuthException: ${error.message}');
          return 'Ошибка: ${error.message}';
      }
    }
    
    print('Unhandled error type: ${error.runtimeType}');
    return 'Произошла ошибка. Попробуйте позже';
  }

  Future<void> sendResetLink() async {
    setState(() { isLoading = true; });
    final email = emailController.text.trim();
    if (email.isEmpty) {
      showCustomError(context, 'Введите e-mail');
      setState(() { isLoading = false; });
      return;
    }

    try {
      // Убираем проверку существования пользователя через signInWithPassword
      await supabase.auth.resetPasswordForEmail(email);
      showCustomError(context, 'Ссылка для сброса отправлена на почту!');
    } catch (e) {
      // Теперь обрабатываем только ошибки, которые могут прийти от resetPasswordForEmail
      final errorMessage = _formatErrorMessage(e);
      showCustomError(context, errorMessage);
    } finally {
      setState(() { isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    SizedBox(height: 32),
                    Text(
                      'Восстановление пароля',
                      style: TextStyle(
                        fontSize: 28,
                        fontFamily: 'Comfortaa',
                        fontWeight: FontWeight.w900,
                        color: Color.fromARGB(255, 54, 6, 56),
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Введите e-mail, на который зарегистрирован аккаунт. Мы отправим ссылку для сброса пароля.',
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
                    SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : sendResetLink,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color.fromARGB(255, 190, 125, 183),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: isLoading
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text(
                                'Восстановить пароль',
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Вспомнили пароль?',
                          style: TextStyle(
                            fontSize: 15,
                            fontFamily: 'Comfortaa',
                            fontWeight: FontWeight.w400,
                            color: Color.fromARGB(255, 54, 6, 56),
                          ),
                        ),
                        SizedBox(width: 4),
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              PageRouteBuilder(
                                transitionDuration: Duration(milliseconds: 500),
                                pageBuilder: (context, animation, secondaryAnimation) => LoginScreen(),
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
                            'Войти',
                            style: TextStyle(
                              fontSize: 15,
                              fontFamily: 'Comfortaa',
                              fontWeight: FontWeight.w900,
                              color: Color.fromARGB(255, 54, 6, 56),
                            ),
                          ),
                        ),
                      ],
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
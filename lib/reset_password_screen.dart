import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String token;
  const ResetPasswordScreen({super.key, required this.token});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  bool isLoading = false;
  double opacity = 0.0;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 600), () {
      setState(() {
        opacity = 1.0;
      });
    });
    // Проверяем текущего пользователя или сессию при загрузке экрана
    final currentUser = supabase.auth.currentUser;
    print('ResetPasswordScreen: Current User ID: ${currentUser?.id}');
    print('ResetPasswordScreen: Current Session: ${currentUser != null ? "Exists" : "Does not exist"}');
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

  String _formatErrorMessage(dynamic error) {
    if (error is AuthException) {
      print('ResetPasswordScreen: Handling AuthException: ${error.message}');
      switch (error.message) {
        case 'Password should be at least 6 characters.': // Убедимся, что обрабатываем точное сообщение
          return 'Пароль должен содержать минимум 6 символов';
        case 'Invalid token':
          return 'Ссылка для сброса пароля недействительна или устарела';
        case 'Token expired':
          return 'Срок действия ссылки истек. Запросите новую ссылку';
        // Добавим обработку для ошибки, если нет активной сессии/пользователя
        case 'Invalid claim: expiration': // Пример ошибки, если токен истек/неправильный и нет сессии
        case 'JWT expired':
          return 'Срок действия ссылки истек. Запросите новую ссылку';
        case 'Auth session not found': // Пример ошибки, если нет активной сессии
          return 'Сессия для сброса пароля не найдена. Попробуйте еще раз.';
        case 'New password should be different from the old password.': // Добавляем обработку для ошибки совпадения паролей
          return 'Новый пароль должен отличаться от старого.';
        default:
          print('ResetPasswordScreen: Unhandled AuthException: ${error.message}');
          return 'Ошибка: ${error.message}';
      }
    }
    
    print('ResetPasswordScreen: Unhandled error type: ${error.runtimeType}');
    print('ResetPasswordScreen: Unhandled error: $error');
    return 'Произошла ошибка. Попробуйте позже';
  }

  Future<void> resetPassword() async {
    final password = passwordController.text.trim();
    final repeatPassword = confirmPasswordController.text.trim();
    if (password.isEmpty || repeatPassword.isEmpty) {
      showCustomError(context, 'Заполните все поля');
      return;
    }
    if (password != repeatPassword) {
      showCustomError(context, 'Пароли не совпадают');
      return;
    }
    setState(() { isLoading = true; });
    try {
      // Используем Supabase updateUser для смены пароля (если пользователь уже авторизован по deep link)
      await supabase.auth.updateUser(
        UserAttributes(password: password),
      );
      showCustomError(context, 'Пароль успешно изменён!');
      // Возможно, здесь нужно перенаправить пользователя на экран входа
      Navigator.pushReplacementNamed(context, '/login'); // Предполагая, что у вас есть маршрут '/login'
    } catch (e) {
      print('ResetPasswordScreen: Error during password reset: $e'); // Логируем ошибку при сбросе
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
                      'Сброс пароля',
                      style: TextStyle(
                        fontSize: 28,
                        fontFamily: 'Comfortaa',
                        fontWeight: FontWeight.w900,
                        color: Color.fromARGB(255, 54, 6, 56),
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Введите новый пароль для вашего аккаунта.',
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
                            text: 'Новый пароль',
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
                        hintText: 'Введите новый пароль',
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
                    SizedBox(height: 20),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Повторите пароль',
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
                      controller: confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        hintText: 'Повторите новый пароль',
                        filled: true,
                        fillColor: Color(0xFFE0CAE6).withOpacity(0.4),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                            color: Color(0xFF360638),
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword = !_obscureConfirmPassword;
                            });
                          },
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
                        onPressed: isLoading ? null : resetPassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color.fromARGB(255, 190, 125, 183),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: isLoading
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text(
                                'Сбросить пароль',
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
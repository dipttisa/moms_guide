import 'package:flutter/material.dart';
import 'package:flutter_application_2/home_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';


class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController repeatPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureRepeatPassword = true;

  double opacity = 0.0; // Начальная прозрачность
  bool isLoading = false; // Состояние загрузки

  @override
  void initState() {
    super.initState();

    // Запуск анимации через 100 миллисекунд после инициализации
    Future.delayed(const Duration(milliseconds: 600), () {
      setState(() {
        opacity = 1.0; // Конечная прозрачность
      });
    });
  }

  // Функция для валидации email
  bool _validateEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  // Функция для валидации ФИО
  bool _validateName(String name) {
    final nameRegex = RegExp(r'^[А-Яа-яЁё\s-]+$');
    return nameRegex.hasMatch(name);
  }

  // Добавляю функцию для красивого вывода ошибок
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
        case 'User already registered':
          return 'У вас уже есть учетная запись. Попробуйте войти в аккаунт';
        case 'Password should be at least 6 characters.':
          return 'Пароль должен содержать минимум 6 символов';
        case 'AuthApiException: Password should be at least 6 characters.':
          return 'Пароль должен содержать минимум 6 символов';
        case 'Invalid email':
          return 'Некорректный формат email';
        default:
          print('Unhandled AuthException: ${error.message}');
          return 'Ошибка: ${error.message}';
      }
    } else if (error is PostgrestException) {
      switch (error.message) {
        case 'duplicate key value violates unique constraint':
          return 'Пользователь с таким email уже существует';
        default:
          print('Unhandled PostgrestException: ${error.message}');
          return 'Ошибка базы данных: ${error.message}';
      }
    }
    
    print('Unhandled error type: ${error.runtimeType}');
    return 'Произошла ошибка. Попробуйте позже';
  }

  // Функция для регистрации
  Future<void> _register() async {
    setState(() {
      isLoading = true;
    });

    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final name = nameController.text.trim();
    final repeatPassword = repeatPasswordController.text.trim();

    // Проверка на пустые поля
    if (email.isEmpty || password.isEmpty || name.isEmpty || repeatPassword.isEmpty) {
      showCustomError(context, 'Все поля обязательны для заполнения');
      setState(() {
        isLoading = false;
      });
      return;
    }

    // Валидация email
    if (!_validateEmail(email)) {
      showCustomError(context, 'Некорректный формат email');
      setState(() {
        isLoading = false;
      });
      return;
    }

    // Валидация ФИО
    if (!_validateName(name)) {
      showCustomError(context, 'Имя должно быть в формате: Мария');
      setState(() {
        isLoading = false;
      });
      return;
    }

    // Добавляем проверку совпадения паролей
    if (password != repeatPassword) {
      showCustomError(context, 'Пароли не совпадают');
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      // Регистрация пользователя в Supabase
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // Сохранение дополнительных данных в таблице профилей
        await supabase.from('user').insert({
          'id': response.user!.id,
          'email': email,
          'name': name,
          'trimestr_id': null,
        });
          if (mounted) {
        showCustomError(context, "Учетная запись успешно создана!");
         Navigator.pushReplacement(
         context,
         MaterialPageRoute(builder: (context) => const HomeScreen()),    
         );
        } 
      }
    } catch (e) {
      final errorMessage = _formatErrorMessage(e);
      showCustomError(context, errorMessage);
    } finally {
      setState(() {
        isLoading = false;
      });
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 24),
                    Text(
                      'Привет, будущая мама!',
                      style: TextStyle(
                        fontSize: 28,
                        fontFamily: 'Comfortaa',
                        fontWeight: FontWeight.w900,
                        color: Color.fromARGB(255, 54, 6, 56),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Сделайте свою беременность максимально комфортной и информативной!',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'Comfortaa',
                        fontWeight: FontWeight.w400,
                        color: Color.fromARGB(255, 54, 6, 56),
                      ),
                    ),
                    SizedBox(height: 15),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Имя',
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
                      controller: nameController,
                      decoration: InputDecoration(
                        hintText: 'Имя',
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
                      controller: repeatPasswordController,
                      obscureText: _obscureRepeatPassword,
                      decoration: InputDecoration(
                        hintText: 'повторите пароль',
                        filled: true,
                        fillColor: Color(0xFFE0CAE6).withOpacity(0.4),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureRepeatPassword ? Icons.visibility_off : Icons.visibility,
                            color: Color(0xFF360638),
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureRepeatPassword = !_obscureRepeatPassword;
                            });
                          },
                        ),
                      ),
                      style: TextStyle(
                        fontSize: 15,
                        fontFamily: 'Comfortaa',
                      ),
                    ),
                    SizedBox(height: 55),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color.fromARGB(255, 190, 125, 183),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: isLoading
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text(
                                'Зарегистрироваться',
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
                          'Есть аккаунт?',
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
                            Navigator.push(
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
                            'Войдите',
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
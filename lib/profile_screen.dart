import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';

import 'dart:io';
import 'shared/bottom_nav.dart';
import 'home_screen.dart';
import 'favorites_screen.dart';
import 'calendar_screen.dart';
import 'login_screen.dart';
import 'package:device_info_plus/device_info_plus.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  final TextEditingController emailController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController dateOfMonthlyPeriodController = TextEditingController();
  int _currentTrimester = 1;
  File? _profileImage;
  bool isLoading = false;
  bool isInitialLoading = true;
  final int _currentIndex = 3;
  int _pregnancyWeek = 0;
  Timer? _updateTimer;
  String deviceInfo = '';

  void showCustomError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            message,
            style: const TextStyle(
              fontSize: 17,
              fontFamily: 'Comfortaa',
              fontWeight: FontWeight.w700,
              color: Color(0xFF360638),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatErrorMessage(dynamic error) {
    return 'Ошибка: ${error.toString()}';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _getDeviceInfo();
    // Start timer to update pregnancy week every minute
    _updateTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _updatePregnancyWeek();
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  // Calculate pregnancy week based on last period date
  int _calculatePregnancyWeek(DateTime lastPeriodDate) {
    final now = DateTime.now();
    final difference = now.difference(lastPeriodDate);
    return (difference.inDays / 7).floor();
  }

  // Update pregnancy week and trimester
  Future<void> _updatePregnancyWeek() async {
    if (dateOfMonthlyPeriodController.text.isEmpty) return;

    try {
      final dateParts = dateOfMonthlyPeriodController.text.split('.');
      if (dateParts.length != 3) return;

      final lastPeriodDate = DateTime(
        int.parse(dateParts[2]),
        int.parse(dateParts[1]),
        int.parse(dateParts[0]),
      );

      final newWeek = _calculatePregnancyWeek(lastPeriodDate);
      if (newWeek != _pregnancyWeek) {
        setState(() {
          _pregnancyWeek = newWeek;
          // Обновляем триместр на основе недели
          _currentTrimester = _pregnancyWeek <= 13 ? 1 : _pregnancyWeek <= 26 ? 2 : 3;
        });

        // Update trimester in database
        final user = supabase.auth.currentUser;
        if (user != null) {
          await supabase
              .from('user')
              .update({'trimestr_id': _currentTrimester})
              .eq('id', user.id);
        }
      }
    } catch (e) {
      print('Error updating pregnancy week: $e');
    }
  }

  Future<void> _loadData() async {
    setState(() {
      isInitialLoading = true;
    });
    
    try {
      await Future.wait([
        _loadUserData(),
      ]);
    } catch (e) {
      print('Error loading data: $e');
      showCustomError(context, 'Ошибка при загрузке данных. Попробуйте обновить страницу.');
    } finally {
      setState(() {
        isInitialLoading = false;
      });
    }
  }

  Future<void> _loadUserData() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      try {
        print('Loading user data for ID: ${user.id}');
        print('User email: ${user.email}');
        
        final response = await supabase
            .from('user')
            .select('name, trimestr_id, last_period_date, image')
            .eq('id', user.id)
            .single()
            .timeout(const Duration(seconds: 10));
        
        print('Response from Supabase: $response');

        if (mounted) {
          setState(() {
            try {
              emailController.text = user.email ?? '';
              nameController.text = response['name']?.toString() ?? '';
              
              final imagePath = response['image']?.toString();
              if (imagePath != null && imagePath.isNotEmpty) {
                _loadProfileImage(imagePath);
              }
              
              // Устанавливаем триместр из базы данных
              if (response['trimestr_id'] != null) {
                _currentTrimester = int.parse(response['trimestr_id'].toString());
              }
              
              final dateStr = response['last_period_date']?.toString();
              if (dateStr != null && dateStr.isNotEmpty) {
                try {
                  final date = DateTime.parse(dateStr);
                  dateOfMonthlyPeriodController.text = '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
                  // Calculate initial pregnancy week
                  _pregnancyWeek = _calculatePregnancyWeek(date);
                  
                  // Обновляем триместр на основе недели
                  _currentTrimester = _pregnancyWeek <= 13 ? 1 : _pregnancyWeek <= 26 ? 2 : 3;
                  
                  // Update trimester in database if different
                  if (response['trimestr_id']?.toString() != _currentTrimester.toString()) {
                    supabase
                        .from('user')
                        .update({'trimestr_id': _currentTrimester})
                        .eq('id', user.id);
                  }
                } catch (e) {
                  print('Error parsing date: $e');
                  dateOfMonthlyPeriodController.text = '';
                }
              } else {
                dateOfMonthlyPeriodController.text = '';
              }
            } catch (e) {
              print('Error setting state: $e');
              showCustomError(context, 'Ошибка при обработке данных профиля');
            }
          });
        }
      } catch (e) {
        print('Error loading user data: $e');
        if (mounted) {
          if (e is PostgrestException) {
            showCustomError(context, 'Ошибка базы данных: ${e.message}');
          } else {
            showCustomError(context, 'Ошибка при загрузке данных профиля');
          }
        }
        rethrow;
      }
    } else {
      print('No user found in auth');
      if (mounted) {
        showCustomError(context, 'Пользователь не авторизован');
      }
    }
  }

  Future<void> _loadProfileImage(String imagePath) async {
    try {
      final response = await supabase.storage.from('avatars').download(imagePath);
      final tempDir = await Directory.systemTemp.createTemp();
      final file = File('${tempDir.path}/profile_image.jpg');
      await file.writeAsBytes(response);
      setState(() {
        _profileImage = file;
      });
        } catch (e) {
      print('Error loading profile image: $e');
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _updateProfile() async {
    setState(() => isLoading = true);
    final user = supabase.auth.currentUser;
    if (user == null) {
      showCustomError(context, 'Пользователь не авторизован');
      setState(() => isLoading = false);
      return;
    }

    try {
      if (nameController.text.trim().isEmpty) {
        showCustomError(context, 'Пожалуйста, введите имя');
        setState(() => isLoading = false);
        return;
      }

      String? imagePath;
      if (_profileImage != null) {
        try {
          imagePath = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
          await supabase.storage
              .from('avatars')
              .upload(imagePath, _profileImage!, fileOptions: const FileOptions(upsert: true));
          print('Image uploaded successfully to path: $imagePath');
        } catch (e) {
          print('Error uploading image: $e');
          showCustomError(context, 'Ошибка при загрузке изображения');
          setState(() => isLoading = false);
          return;
        }
      }

      final updateData = {
        'name': nameController.text.trim(),
        'trimestr_id': _currentTrimester,
        'last_period_date': dateOfMonthlyPeriodController.text.isNotEmpty
            ? dateOfMonthlyPeriodController.text.split('.').reversed.join('-')
            : null,
        if (imagePath != null) 'image': imagePath,
      };

      print('Updating profile with data: $updateData');

      final response = await supabase
          .from('user')
          .update(updateData)
          .eq('id', user.id)
          .select();

      print('Update response: $response');
      showCustomError(context, 'Профиль успешно обновлен');
    } catch (e) {
      print('Error updating profile: $e');
      if (e is PostgrestException) {
        showCustomError(context, 'Ошибка базы данных: ${e.message}');
      } else {
        showCustomError(context, 'Ошибка при обновлении профиля');
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
             colorScheme: const ColorScheme.light(primary: Color.fromARGB(255, 190, 125, 183)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        dateOfMonthlyPeriodController.text = '${picked.day.toString().padLeft(2, '0')}.${picked.month.toString().padLeft(2, '0')}.${picked.year}';
      });
      _updatePregnancyWeek();
    }
  }

  Future<void> _signOut() async {
    try {
      setState(() {
        isLoading = true;
      });

      await supabase.auth.signOut();
      
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        showCustomError(context, 'Ошибка при выходе из аккаунта');
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _getDeviceInfo() async {
    final deviceInfoPlugin = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        setState(() {
          deviceInfo = '${androidInfo.brand} ${androidInfo.model}';
        });
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        setState(() {
          deviceInfo = '${iosInfo.name} ${iosInfo.model}';
        });
      }
    } catch (e) {
      print('Error getting device info: $e');
    }
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.fromARGB(255, 235, 230, 242),
                  Color.fromARGB(255, 252, 225, 219),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'О приложении',
                  style: TextStyle(
                    fontSize: 20,
                    fontFamily: 'Comfortaa',
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF360638),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Версия 1.0.0',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Comfortaa',
                    color: Color(0xFF360638),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Устройство: $deviceInfo',
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'Comfortaa',
                    color: Color(0xFF360638),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Связаться с разработчиком:',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Comfortaa',
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF360638),
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () {
                    // Здесь можно добавить функционал для открытия почты
                  },
                  child: const Text(
                    'maria05kuznetsova.work@gmail.com',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'Comfortaa',
                      color: Color(0xFF360638),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 190, 125, 183),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Закрыть',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'Comfortaa',
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      
    );
  }
  
void _onNavigationTap(int index) {
    if (index == _currentIndex) return;
    
    switch (index) {
      case 0: // Home
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
        break;
      case 1: // Favorites
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const FavoritesScreen()),
        );
        break;
      case 2: // Calculator
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const CalendarScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
        break;
      case 3: // Profile
        // Already on profile
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromARGB(255, 235, 230, 242),
              Color.fromARGB(255, 252, 225, 219),
            ],
          ),
        ),
        child: SafeArea(
          child: isInitialLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF360638),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                               onTap: _pickImage,
                               child: CircleAvatar(
                                 radius: 40,
                                 backgroundColor: Color.fromARGB(255, 190, 125, 183).withOpacity(0.3),
                                 backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                                 child: _profileImage == null 
                                     ? const Icon(
                                         Icons.person,
                                         size: 60,
                                         color: Color(0xFF360638),
                                       ) 
                                     : null,
                               ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                   Text(
                                    nameController.text.isNotEmpty ? nameController.text : 'Загрузка...',
                                    style: const TextStyle(
                                       fontSize: 18,
                                      fontFamily: 'Comfortaa',
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF360638),
                                    ),
                                     overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                   Text(
                                    emailController.text.isNotEmpty ? emailController.text : 'Загрузка...',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontFamily: 'Comfortaa',
                                      fontWeight: FontWeight.w400,
                                      color: Color(0xFF360638),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ]
                              ),
                            ),
                          ]
                        ),
                        const SizedBox(height: 24),
                        const Divider(color: Color.fromARGB(255, 190, 125, 183)),
                        const SizedBox(height: 24),
                        _buildLabel('Имя*'),
                        _buildTextField(nameController, 'Введите ваше Имя'),
                        const SizedBox(height: 20),
                        _buildLabel('Триместр'),
                        _buildDropdown(),
                        const SizedBox(height: 40),
                        _buildLabel('Дата последних месячных'),
                        _buildDatePickerField(context),
                        const SizedBox(height: 40),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _updateProfile,
                             style: ElevatedButton.styleFrom(
                                backgroundColor: Color.fromARGB(255, 190, 125, 183),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            child: isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text(
                                    'Сохранить',
                                     style: TextStyle(
                                        fontSize: 17,
                                        fontFamily: 'Comfortaa',
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _signOut,
                             style: ElevatedButton.styleFrom(
                                backgroundColor: Color.fromARGB(255, 150, 90, 140),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            child: isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text(
                                    'Выйти из аккаунта',
                                     style: TextStyle(
                                        fontSize: 17,
                                        fontFamily: 'Comfortaa',
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: GestureDetector(
                            onTap: _showAboutDialog,
                            child: const Text(
                              'О приложении',
                              style: TextStyle(
                                fontSize: 15,
                                fontFamily: 'Comfortaa',
                                color: Color(0xFF360638),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ]
                    ),
                  ),
                ),
        ),
      ),
        bottomNavigationBar: BottomNav(
        currentIndex: _currentIndex,
        onTap: _onNavigationTap,
      ),
    );
  }

  Widget _buildLabel(String text) => Text(
    text,
    style: const TextStyle(fontSize: 15, fontFamily: 'Comfortaa', fontWeight: FontWeight.w900, color: Color(0xFF360638)),
  );

  Widget _buildTextField(TextEditingController controller, String hintText) => TextField(
    controller: controller,
    decoration: InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: const Color(0xFFE0CAE6).withOpacity(0.4),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    ),
    style: const TextStyle(fontSize: 15, fontFamily: 'Comfortaa'),
  );

  Widget _buildDropdown() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
    decoration: BoxDecoration(
      color: const Color(0xFFE0CAE6).withOpacity(0.4),
      borderRadius: BorderRadius.circular(12)
    ),
    child: Text(
      '$_currentTrimester триместр',
      style: const TextStyle(
        fontSize: 15,
        fontFamily: 'Comfortaa',
        color: Color(0xFF360638),
      ),
    ),
  );

  Widget _buildDatePickerField(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        controller: dateOfMonthlyPeriodController,
        readOnly: true,
        decoration: InputDecoration(
          hintText: 'Выберите дату',
          filled: true,
          fillColor: const Color(0xFFE0CAE6).withOpacity(0.4),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          suffixIcon: IconButton(
            icon: const Icon(Icons.calendar_today, color: Color(0xFF360638)),
            onPressed: () => _selectDate(context),
          ),
        ),
        style: const TextStyle(fontSize: 15, fontFamily: 'Comfortaa'),
      ),
    ],
  );
}


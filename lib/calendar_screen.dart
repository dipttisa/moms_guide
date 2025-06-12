import 'package:flutter/material.dart';
import 'package:flutter_application_2/main.dart';
import 'package:flutter_application_2/shared/medical_norm_modal.dart';
import 'package:timezone/timezone.dart' as tz;
import 'shared/bottom_nav.dart';
import 'home_screen.dart';
import 'favorites_screen.dart';
import 'profile_screen.dart';
import 'dart:ui'; 
import 'package:supabase_flutter/supabase_flutter.dart'; 
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'shared/custom_snackbar.dart';
import 'information_article_detail_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart'; 
import 'shared/reminder_modal.dart';
import 'shared/symptom_warning_modal.dart';
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>  {
  @override
  

  // Add fetal movement tracking variables
  bool _isTrackingMovements = false;
  DateTime? _movementStartTime;
  int _movementCount = 0;
  Duration _trackingDuration = Duration.zero;
  Timer? _movementTimer;
  String? _currentTrackingId;
  List<Map<String, dynamic>> _weeklyMovements = [];
  bool _isLoadingWeeklyData = false;
  DateTime? _lastMovementTime;
  bool _symptomChangesPending = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadUserData();
    _loadLastPeriodDate();
    _loadJournalEntry();
    _loadDailyData();
    _loadMedicalData();
    _loadWeeklyMovements();
    _loadMonthlyMedicalData();
    _loadReminders();
    _loadFetalMovements(); 
  }

  final int _currentIndex = 2;
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  String _userName = '';
  String _userEmail = '';
  String? _selectedCategory;
  List<String> _symptoms = [];
  int _currentTrimester = 1;
  int _pregnancyWeek = 0;
  DateTime? _lastPeriodDate;
  Timer? _updateTimer;
  DateTime? _estimatedDeliveryDate;
  
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _systolicController = TextEditingController();
  final TextEditingController _diastolicController = TextEditingController();
  final TextEditingController _temperatureController = TextEditingController();

  Map<String, dynamic>? _dailyData;
  bool _isLoadingDailyData = false;
  
  final SupabaseClient supabase = Supabase.instance.client; 

  // Add state for information cards
  List<Map<String, dynamic>> _informationCards = [];
  bool _isLoadingInfoCards = false;

  // Add state for screening photos
  final List<String> _screeningPhotos = []; 

  // Add state variables
  final TextEditingController _noteController = TextEditingController();
  List<String> _selectedSymptoms = [];
  List<String> _selectedSymptomsWarnings = [];
  List<String> _ultrasoundPhotos = [];
  bool _isLoading = false;
  bool _isEditingDailyData = false;

  bool _isOnline = true;
  Timer? _networkCheckTimer;

  // Add new state for medical data
  bool _isEditingMedicalData = false;
  final TextEditingController _hemoglobinController = TextEditingController();
  final TextEditingController _glucoseController1 = TextEditingController();
  final TextEditingController _glucoseController2 = TextEditingController();
  final TextEditingController _medicalSystolicController = TextEditingController();
  final TextEditingController _medicalDiastolicController = TextEditingController();
  bool _isLoadingMedicalData = false;
  Map<String, dynamic>? _medicalData;

  // --- MONTHLY MEDICAL CHART ---
  List<Map<String, dynamic>> _monthlyMedicalData = [];
  bool _isLoadingMonthlyMedical = false;

  // Добавляем переменные для напоминаний
  List<Map<String, dynamic>> _reminders = [];
  bool _isLoadingReminders = false;
  final TextEditingController _reminderTitleController = TextEditingController();
  final TextEditingController _reminderDescriptionController = TextEditingController();
  DateTime? _selectedReminderDate;
  TimeOfDay? _selectedReminderTime;

  Future<void> _loadMonthlyMedicalData() async {
    if (_isLoadingMonthlyMedical) return;
    setState(() => _isLoadingMonthlyMedical = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final firstDay = DateTime(_focusedDay.year, _focusedDay.month, 1);
      final lastDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
      final response = await supabase
          .from('medical_indicators')
          .select('*')
          .eq('user_id', user.id)
          .gte('date', firstDay.toIso8601String())
          .lte('date', lastDay.toIso8601String())
          .order('date');
      setState(() {
        _monthlyMedicalData = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Ошибка загрузки месячных мед. данных: $e');
      setState(() {
        _monthlyMedicalData = [];
      });
    } finally {
      setState(() => _isLoadingMonthlyMedical = false);
    }
  }

  Future<List<String>> _loadWarningSymptoms() async {
    final response = await supabase
        .from('symptom_warnings')
        .select('symptom_name');
    if (response == null) return [];
    return (response as List)
        .map((item) => item['symptom_name'] as String)
        .toSet()
        .toList();
  }
Future<void> _saveSymptoms() async {
  setState(() => _isLoading = true);
  try {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final dateStr = _selectedDate.toIso8601String();
      final trimesterResponse = await supabase
          .from('trimester')
          .select('id')
          .eq('number', _currentTrimester)
          .single();

    final trimesterId = trimesterResponse['id'];
    final trimesterSymptomsResponse = await supabase
    .from('trimester_symptoms')
    .select('symptom: symptom_id(name)')
    .eq('trimester_id', trimesterId);

final trimesterSymptomNames = trimesterSymptomsResponse
    .map<String>((item) => item['symptom']['name'] as String)
    .toSet();  // множества удобны для быстрой проверки
    // 1. Найти журнал на эту дату
    final calendarRow = await supabase
        .from('calendar')
        .select('id, journal_id')
        .eq('user_id', user.id)
        .eq('date', dateStr)
        .maybeSingle();

    String journalId;
    if (calendarRow != null && calendarRow['journal_id'] != null) {
      journalId = calendarRow['journal_id'];
    } else {
      final insertedJournal = await supabase
          .from('journal')
          .insert({}).select('id').single();
      journalId = insertedJournal['id'];

      await supabase.from('calendar').insert({
        'user_id': user.id,
        'date': dateStr,
        'journal_id': journalId,
      });
    }

    await supabase
        .from('journal_symptom')
        .delete()
        .eq('journal_id', journalId);

    
    for (final symptomName in _selectedSymptoms) {
  if (!trimesterSymptomNames.contains(symptomName)) {
    continue;
  }

  final symptomRow = await supabase
      .from('symptom')
      .select('id')
      .eq('name', symptomName)
      .maybeSingle();

  if (symptomRow != null) {
    final symptomId = symptomRow['id'];
    if (symptomId is String) {
      await supabase.from('journal_symptom').insert({
        'journal_id': journalId,
        'symptom_id': symptomId,
      });
    } else {
      print('symptom_id is not a String (UUID): $symptomId');
    }
  }
}
    for (final symptomNameWarning in _selectedSymptoms) {
  final warningRow = await supabase
      .from('symptom_warnings')
      .select('*') // важно выбрать все поля
      .eq('symptom_name', symptomNameWarning)
      .maybeSingle();

  if (warningRow != null) {
    final warningId = warningRow['id'];

    if (warningId is String) {
      await supabase.from('journal_symptom_warning').insert({
        'journal_id': journalId,
        'symptom_id': warningId,
      });

       

    } else {
      print('symptom_id is not a String (UUID): $warningId');
    }
  }
}
    
    showCustomSnackbar(context, 'Симптомы сохранены');
    setState(() => _symptomChangesPending = false);
  } catch (e) {
    print('Ошибка сохранения симптомов: $e');
    showCustomSnackbar(context, 'Ошибка при сохранении', success: false);
  } finally {
    setState(() => _isLoading = false);
  }
}
  

  @override
  void initState() {
    super.initState();
    _initNetworkCheck();
    _loadUserData();
    _loadLastPeriodDate();
    _loadJournalEntry();
    _loadDailyData();
    _loadWeeklyMovements();
    _loadMedicalData();
    _loadMonthlyMedicalData();
    _loadReminders();
    _checkAndShowMonthlyReport();
    _updateTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _updatePregnancyWeek();
    });
  }

  void _checkAndShowMonthlyReport() {
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    if (now.day == lastDay) {
      _generateMonthlyReport();
    }
  }

  @override
  void dispose() {
    _networkCheckTimer?.cancel();
    _updateTimer?.cancel();
    _noteController.dispose();
    _weightController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _temperatureController.dispose();
    _reminderTitleController.dispose();
    _reminderDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _initNetworkCheck() async {
    _checkNetworkStatus();
    _networkCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkNetworkStatus();
    });
  }

  Future<void> _checkNetworkStatus() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      final isConnected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      if (mounted && _isOnline != isConnected) {
        setState(() {
          _isOnline = isConnected;
        });
        if (isConnected) {
          _loadUserData();
          _loadLastPeriodDate();
          _loadJournalEntry();
          _loadDailyData();
        }
      }
    } on SocketException catch (_) {
      if (mounted && _isOnline) {
        setState(() {
          _isOnline = false;
        });
      }
    }
  }
void _onNavigationTap(int index) {
    if (index == _currentIndex) return;
    
    if (!mounted) return; 
    
    switch (index) {
      case 0: // Home
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
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
        break;
      case 1: // Favorites
         Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const FavoritesScreen(),
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
      case 2: 
        break;
      case 3: 
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const ProfileScreen(),
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
    }
  }
  Future<void> _loadUserData() async {
    if (!mounted) return;

    await Future.microtask(() async {
      try {
        final user = supabase.auth.currentUser;
        if (user != null) {
          final response = await supabase
              .from('user')
              .select('name, email')
              .eq('id', user.id)
              .single();

          if (mounted) {
            setState(() {
              _userName = response['name'] ?? '';
              _userEmail = response['email'] ?? '';
            });
          }
        }
      } catch (e) {
        print('Error loading user data: $e');
        // Consider showing a less intrusive error message or handling silently
      }
    });
  }

  // Calculate pregnancy week based on last period date
  int _calculatePregnancyWeek(DateTime lastPeriodDate) {
    final now = DateTime.now();
    final difference = now.difference(lastPeriodDate);
    return (difference.inDays / 7).floor();
  }

  // Update pregnancy week and trimester with retry logic
  Future<void> _updatePregnancyWeek() async {
    if (_lastPeriodDate == null || !mounted) return;

    // This logic is relatively light, keep it outside microtask unless profiling shows it's a bottleneck
    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries && mounted) {
      try {
        final newWeek = _calculatePregnancyWeek(_lastPeriodDate!);
        if (newWeek != _pregnancyWeek) {
          setState(() {
            _pregnancyWeek = newWeek;
            // Update trimester based on week
            if (_pregnancyWeek <= 13) {
              _currentTrimester = 1;
            } else if (_pregnancyWeek <= 26) {
              _currentTrimester = 2;
            } else {
              _currentTrimester = 3;
            }
            

          });

          // Reload symptoms for new trimester
          await _loadSymptomsForTrimester();
          _calculateEstimatedDeliveryDate();
           // Calculate EDD when week updates
          return; // Exit on success
        }
        return; // Exit if week hasn't changed
      } catch (e) {
        print('Attempt ${retryCount + 1} failed: $e');
        retryCount++;
        
        if (retryCount == maxRetries && mounted) {
          print('Error updating pregnancy week after $maxRetries attempts: $e');
          showCustomSnackbar(context, 'Ошибка обновления недели беременности', success: false);
        } else if (mounted) {
          await Future.delayed(Duration(seconds: 1 * retryCount));
        }
      }
    }
  }
      
  // Add method to set last period date with retry logic
  Future<void> _setLastPeriodDate(DateTime date) async {
     if (!mounted) return;

    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries && mounted) {
      try {
        final user = supabase.auth.currentUser;
        if (user != null) {
          // First try to update the date
          await supabase
              .from('user')
              .update({'last_period_date': date.toIso8601String()})
              .eq('id', user.id);

          // If successful, update local state
          if(mounted) {
            setState(() {
              _lastPeriodDate = date;
            });
          }
          
          // Show success message
          if(mounted) {
             showCustomSnackbar(context, 'Дата успешно сохранена', success: true);
          }
         
          // Update pregnancy week after successful save
          _updatePregnancyWeek();
          _calculateEstimatedDeliveryDate(); // Calculate EDD after setting date
          return; // Exit on success
        }
      } catch (e) {
        print('Attempt ${retryCount + 1} failed: $e');
        retryCount++;
        
        if (retryCount == maxRetries && mounted) {
          // Show error message on final attempt
          showCustomSnackbar(context, 'Ошибка сохранения даты. Проверьте подключение к интернету.', success: false);
          print('Error setting last period date after $maxRetries attempts: $e');
        } else if (mounted) {
          // Wait before retrying
          await Future.delayed(Duration(seconds: 1 * retryCount));
        }
      }
    }
  }

  // Load last period date from database with retry logic
  Future<void> _loadLastPeriodDate() async {
    if (!mounted) return;

    await Future.microtask(() async {
      int retryCount = 0;
      const maxRetries = 3;

      while (retryCount < maxRetries && mounted) {
        try {
          final user = supabase.auth.currentUser;
          if (user != null) {
            final response = await supabase
                .from('user')
                .select('last_period_date')
                .eq('id', user.id)
                .single();

            if (response['last_period_date'] != null) {
              if(mounted) {
                 setState(() {
                  _lastPeriodDate = DateTime.parse(response['last_period_date']);
                });
              }
              _updatePregnancyWeek();
              _calculateEstimatedDeliveryDate(); // Calculate EDD after loading date
              return; // Exit on success
            }
             return; // Exit if no date found
          }
           return; // Exit if no user
        } catch (e) {
          print('Attempt ${retryCount + 1} failed: $e');
          retryCount++;
          
          if (retryCount == maxRetries && mounted) {
            print('Error loading last period date after $maxRetries attempts: $e');
            showCustomSnackbar(context, 'Ошибка загрузки даты. Проверьте подключение к интернету.', success: false);
          } else if (mounted) {
            await Future.delayed(Duration(seconds: 1 * retryCount));
          }
        }
      }
    });
  }

  // Add method to load symptoms for current trimester
  Future<void> _loadSymptomsForTrimester() async {
    if (!mounted) return;

    await Future.microtask(() async {
      try {
        print('Loading symptoms for trimester: $_currentTrimester'); // Debug print
        
        // First get the trimester ID
        final trimesterResponse = await supabase
            .from('trimester')
            .select('id')
            .eq('number', _currentTrimester)
            .single();
            
        print('Trimester response: $trimesterResponse');
        
        final trimesterId = trimesterResponse['id'];
        
        // Then get symptoms for this trimester
        final response = await supabase
            .from('trimester_symptoms')
            .select('symptom: symptom_id(name)')
            .eq('trimester_id', trimesterId);

        print('Response from DB: $response'); // Debug print

        // Get warning symptoms
        final warningSymptoms = await _loadWarningSymptoms();
        
        if (mounted) {
          setState(() {
            // Combine trimester symptoms with warning symptoms
            final trimesterSymptoms = response
                .map((item) => item['symptom']['name'] as String)
                .toList();
            _symptoms = {...trimesterSymptoms, ...warningSymptoms}.toList();
            print('Loaded symptoms: $_symptoms'); // Debug print
          });
        }
      } catch (e) {
        print('Error loading symptoms: $e');
        if (mounted) {
          setState(() {
            _symptoms = [];
          });
          showCustomSnackbar(context, 'Ошибка загрузки симптомов. Проверьте подключение к интернету.', success: false);
        }
      }
    });
  }

  // Add helper functions for calendar
  String _getMonthName(int month) {
    const months = [
      'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
    ];
    return months[month - 1];
  }

  String _getWeekdayName(int weekday) {
    const weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return weekdays[weekday - 1];
  }

  String _getDayName(int day) {
    const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return days[day - 1];
  }

  int _getDaysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  bool _isLoadingAll = false;

Future<void> _onDaySelected(DateTime selectedDay, DateTime focusedDay) async {
  if (_isLoadingAll) return;
  _isLoadingAll = true;

  setState(() {
    _selectedDate = selectedDay;
    _focusedDay = focusedDay;
  });

  await Future.wait([
    _loadJournalEntry(),
    _loadDailyData(),
    _loadMedicalData(),
    _loadMonthlyMedicalData(),
    _loadReminders(),
    _loadFetalMovements(),
  ]);

  _isLoadingAll = false;
}

  void _onPreviousMonth() {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1);
      _focusedDay = _selectedDate;
    });
    _loadMedicalData();
    _loadMonthlyMedicalData();
    _getMonthlyReport(); 
    _loadFetalMovements(); 
  }

  void _onNextMonth() {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1);
      _focusedDay = _selectedDate;
    });
    _loadMedicalData();
    _loadMonthlyMedicalData();
    _getMonthlyReport(); 
    _loadFetalMovements();
  }

  void _showCustomCalendar() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) { 
        return StatefulBuilder( 
          builder: (BuildContext context, StateSetter setState) { 
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 21),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 21),
                  // Month Navigation
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () {
                            setState(() {
                              _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1);
                            });
                          },
                          color: const Color.fromARGB(255, 54, 6, 56),
                        ),
                        Row(
                          children: [
                            Text(
                              '${_getMonthName(_selectedDate.month)} ${_selectedDate.year}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontFamily: 'Comfortaa',
                                fontWeight: FontWeight.w700,
                                color: Color.fromARGB(255, 54, 6, 56),
                              ),
                            ),
                           
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () {
                            setState(() {
                              _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1);
                            });
                          },
                          color: const Color.fromARGB(255, 54, 6, 56),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Weekday Labels
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(7, (index) {
                        return SizedBox(
                          width: 40,
                          child: Text(
                            _getWeekdayName(index + 1),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontFamily: 'Comfortaa',
                              fontWeight: FontWeight.w500,
                              color: Color.fromARGB(255, 54, 6, 56),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Calendar Grid
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        childAspectRatio: 1,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: 42,
                      itemBuilder: (context, index) {
                        final firstDayOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
                        final firstDayOffset = (firstDayOfMonth.weekday + 6) % 7;
                        final dayNumber = index - firstDayOffset + 1;
                        final daysInMonth = _getDaysInMonth(_selectedDate.year, _selectedDate.month);

                        if (dayNumber < 1 || dayNumber > daysInMonth) {
                          return const SizedBox();
                        }

                        final date = DateTime(_selectedDate.year, _selectedDate.month, dayNumber);
                        final isSelected = date.year == _selectedDate.year &&
                            date.month == _selectedDate.month &&
                            date.day == _selectedDate.day;
                        final isToday = date.year == DateTime.now().year &&
                            date.month == DateTime.now().month &&
                            date.day == DateTime.now().day;

                        return GestureDetector(
                          onTap: () {
                            _onDaySelected(date, _selectedDate);
                            Navigator.pop(context);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFBE7DBC)
                                  : isToday
                                      ? const Color(0xFFF2E4E1)
                                      : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                dayNumber.toString(),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontFamily: 'Comfortaa',
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color.fromARGB(255, 54, 6, 56).withOpacity(0.5),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _loadJournalEntry() async {
    if (!mounted) return;

    await Future.microtask(() async {
      try {
        final user = supabase.auth.currentUser;
        if (user == null) {
          if (mounted) {
            showCustomSnackbar(context, 'Пожалуйста, войдите в аккаунт', success: false);
          }
          return;
        }

        final response = await supabase
            .from('calendar')
            .select('''
              journal:journal_id(
                id,
                note,
                analysis_result,
                journal_symptom(
                  symptom:symptom_id(
                    name
                  )
                ),
                journal_symptom_warning(
                symptom_warnings(
                    symptom_name
                  )
                )
              )
            ''')
            .eq('user_id', user.id)
            .eq('date', _selectedDate.toIso8601String())
            .maybeSingle();

        if (!mounted) return;

        if (response != null && response['journal'] != null) {
          final journal = response['journal'];
          setState(() {
            _noteController.text = journal['note'] ?? '';
            if (journal['analysis_result'] != null) {
              _ultrasoundPhotos = (journal['analysis_result'] as String).split(',');
            }
            if (journal['journal_symptom'] != null) {
              final symptoms = (journal['journal_symptom'] as List)
                  .map((js) => js['symptom']['name'] as String)
                  .toList();
              _selectedSymptoms = symptoms;
            } else {
              _selectedSymptoms = [];
            }
            if (journal['journal_symptom_warning'] != null) {
              final symptoms_warnings = (journal['journal_symptom_warning'] as List)
                  .map((js) => js['symptom_warnings']['symptom_name'] as String)
                  .toList();
              _selectedSymptomsWarnings = symptoms_warnings;
            } else {
              _selectedSymptomsWarnings = [];
            }
          });
        } else {
          if (mounted) {
            setState(() {
              _noteController.text = '';
              _ultrasoundPhotos = [];
              _selectedSymptoms = [];
              _selectedSymptomsWarnings = [];
            });
          }
        }
      } catch (e) {
        print('Error loading journal entry: $e');
        if (mounted) {
          showCustomSnackbar(context, 'Ошибка загрузки данных', success: false);
        }
      }
    });
  }

  // Add method to load daily data
  Future<void> _loadDailyData() async {
    if (_isLoadingDailyData) return;
    if (!mounted) return;
    if (!_isOnline) {
      showCustomSnackbar(context, 'Нет подключения к интернету', success: false);
      return;
    }

    await Future.microtask(() async {
      try {
        setState(() => _isLoadingDailyData = true);
        
        final user = supabase.auth.currentUser;
        if (user == null) {
          if (mounted) {
            showCustomSnackbar(context, 'Пожалуйста, войдите в аккаунт', success: false);
          }
          return;
        }

        final response = await supabase
            .from('daily_data')
            .select('*')
            .eq('user_id', user.id)
            .eq('date', _selectedDate.toIso8601String())
            .maybeSingle()
            .timeout(const Duration(seconds: 10));

        if (!mounted) return;

        if (response != null) {
          setState(() {
            _dailyData = response;
            _weightController.text = response['weight']?.toString() ?? '';
            _systolicController.text = response['systolic_pressure']?.toString() ?? '';
            _diastolicController.text = response['diastolic_pressure']?.toString() ?? '';
            _temperatureController.text = response['temperature']?.toString() ?? '';
          });
        } else {
          setState(() {
            _dailyData = null;
            _weightController.clear();
            _systolicController.clear();
            _diastolicController.clear();
            _temperatureController.clear();
          });
        }
      } on TimeoutException {
        if (mounted) {
          showCustomSnackbar(context, 'Превышено время ожидания ответа от сервера', success: false);
        }
      } catch (e) {
        print('Error loading daily data: $e');
        if (mounted) {
          showCustomSnackbar(context, 'Ошибка загрузки данных', success: false);
        }
      } finally {
        if (mounted) {
          setState(() => _isLoadingDailyData = false);
        }
      }
    });
  }

  Future<void> _saveDailyData() async {
    if (_isLoadingDailyData) return;
    if (!mounted) return;
    if (!_isOnline) {
      showCustomSnackbar(context, 'Нет подключения к интернету', success: false);
      return;
    }

    await Future.microtask(() async {
      try {
        setState(() => _isLoadingDailyData = true);
        
        final user = supabase.auth.currentUser;
        if (user == null) {
          if (mounted) {
            showCustomSnackbar(context, 'Пожалуйста, войдите в аккаунт', success: false);
          }
          return;
        }

        double? weight;
        int? systolic;
        int? diastolic;
        double? temperature;

        try {
          weight = _weightController.text.isNotEmpty 
              ? double.tryParse(_weightController.text.replaceAll(',', '.'))
              : null;
          systolic = _systolicController.text.isNotEmpty 
              ? int.tryParse(_systolicController.text)
              : null;
          diastolic = _diastolicController.text.isNotEmpty 
              ? int.tryParse(_diastolicController.text)
              : null;
          temperature = _temperatureController.text.isNotEmpty 
              ? double.tryParse(_temperatureController.text.replaceAll(',', '.'))
              : null;
        } catch (e) {
          print('Error parsing numbers: $e');
          if (mounted) {
            showCustomSnackbar(context, 'Проверьте правильность введенных данных', success: false);
          }
          return;
        }

        final data = {
          'user_id': user.id,
          'date': _selectedDate.toIso8601String(),
          'weight': weight,
          'systolic_pressure': systolic,
          'diastolic_pressure': diastolic,
          'temperature': temperature,
        };

        if (_dailyData != null) {
          await supabase
              .from('daily_data')
              .update(data)
              .eq('id', _dailyData!['id'])
              .timeout(const Duration(seconds: 10));
        } else {
          await supabase
              .from('daily_data')
              .insert(data)
              .timeout(const Duration(seconds: 10));
        }

        if (!mounted) return;

        showCustomSnackbar(context, 'Ежедневные данные сохранены');
        await _loadDailyData();
      } on TimeoutException {
        if (mounted) {
          showCustomSnackbar(context, 'Превышено время ожидания ответа от сервера', success: false);
        }
      } catch (e) {
        print('Error saving daily data: $e');
        if (mounted) {
          showCustomSnackbar(context, 'Ошибка сохранения данных. Проверьте формат ввода', success: false);
        }
      } finally {
        if (mounted) {
          setState(() => _isLoadingDailyData = false);
        }
      }
    });
  }

  Future<void> _clearDay() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      await supabase
          .from('daily_data')
          .delete()
          .eq('user_id', user.id)
          .eq('date', _selectedDate.toIso8601String());

      setState(() {
        _weightController.clear();
        _systolicController.clear();
        _diastolicController.clear();
        _temperatureController.clear();
        _dailyData = null;
      });

      final existingEntries = await supabase
          .from('calendar')
          .select('journal:journal_id(*)')
          .eq('user_id', user.id)
          .eq('date', _selectedDate.toIso8601String());

      if (existingEntries.isNotEmpty) {
        for (final entry in existingEntries) {
          if (entry['journal'] != null) {
            final journalId = entry['journal']['id'];
            
            await supabase
                .from('journal_symptom')
                .delete()
                .eq('journal_id', journalId);

            await supabase
                .from('journal')
                .delete()
                .eq('id', journalId);
          }
        }

        await supabase
            .from('calendar')
            .delete()
            .eq('user_id', user.id)
            .eq('date', _selectedDate.toIso8601String());

        if (mounted) {
          setState(() {
            _noteController.text = '';
            _ultrasoundPhotos = [];
            _selectedSymptoms = [];
            _selectedSymptomsWarnings = [];
          });

          showCustomSnackbar(context, 'День успешно очищен', success: true);
        }
      } else {
        if (mounted) {
          setState(() {
            _noteController.text = '';
            _ultrasoundPhotos = [];
            _selectedSymptoms = [];
            _selectedSymptomsWarnings = [];
          });
        }
      }
      
      _loadLastPeriodDate();

    } catch (e) {
      print('Error clearing day: $e');
      showCustomSnackbar(context, 'Ошибка при очистке дня: ${e.toString()}', success: false);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveJournalEntry() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      await _saveDailyData();

      if (_selectedSymptoms.isEmpty && _selectedSymptomsWarnings.isEmpty && _noteController.text.isEmpty && _ultrasoundPhotos.isEmpty) {
        showCustomSnackbar(context, 'Добавьте хотя бы одину заметку или фото', success: false);
        return;
      }

      final user = supabase.auth.currentUser;
      if (user == null) return;

      final existingEntry = await supabase
          .from('calendar')
          .select('journal:journal_id(*)')
          .eq('user_id', user.id)
          .eq('date', _selectedDate.toIso8601String())
          .maybeSingle();

      String journalId;
      if (existingEntry != null && existingEntry['journal'] != null) {
        journalId = existingEntry['journal']['id'];
        await supabase
            .from('journal')
            .update({
              'note': _noteController.text,
              'analysis_result': _ultrasoundPhotos.isNotEmpty ? _ultrasoundPhotos.join(',') : null,
            })
            .eq('id', journalId);

        
      } else {
        final journalResponse = await supabase
            .from('journal')
            .insert({
              'note': _noteController.text,
              'analysis_result': _ultrasoundPhotos.isNotEmpty ? _ultrasoundPhotos.join(',') : null,
            })
            .select()
            .single();
        
        journalId = journalResponse['id'];

        await supabase
            .from('calendar')
            .insert({
              'user_id': user.id,
              'date': _selectedDate.toIso8601String(),
              'journal_id': journalId,
            });
          }

      await _loadJournalEntry();
    } catch (e) {
      print('Error saving entry: $e');
      showCustomSnackbar(context, 'Ошибка при сохранении: ${e.toString()}', success: false);
    } finally {
      setState(() => _isLoading = false);
    }
  }
  Future<void> _pickUltrasoundPhoto() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() => _isLoading = true);

        final user = supabase.auth.currentUser;
        if (user == null) {
          throw Exception('User not authenticated');
        }

        final fileExt = pickedFile.path.split('.').last;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final filePath = '${user.id}/$fileName';

        final file = File(pickedFile.path);
        await supabase.storage
            .from('analysis')
            .upload(filePath, file);

        final imageUrl = supabase.storage
            .from('analysis')
            .getPublicUrl(filePath);

        setState(() {
          _ultrasoundPhotos.add(imageUrl);
        });

        showCustomSnackbar(context, 'Фото успешно загружено', success: true);
      }
    } catch (e) {
      print('Error picking ultrasound photo: $e');
      showCustomSnackbar(context, 'Ошибка при загрузке фото: ${e.toString()}', success: false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteUltrasoundPhoto(String photoUrl) async {
    try {
      setState(() => _isLoading = true);

      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final uri = Uri.parse(photoUrl);
      final pathSegments = uri.pathSegments;
      final filePath = pathSegments.sublist(pathSegments.indexOf('analysis') + 1).join('/');

      await supabase.storage
          .from('analysis')
          .remove([filePath]);

      setState(() {
        _ultrasoundPhotos.remove(photoUrl);
      });

      showCustomSnackbar(context, 'Фото успешно удалено', success: true);
    } catch (e) {
      print('Error deleting ultrasound photo: $e');
      showCustomSnackbar(context, 'Ошибка при удалении фото: ${e.toString()}', success: false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _markMovement() {
    setState(() {
      _movementCount++;
      _lastMovementTime = DateTime.now();
    });
    _saveFetalMovements();
  }

  Future<void> _stopMovementTracking() async {
    if (!_isTrackingMovements) return;
    await _saveFetalMovements();
    setState(() {
      _isTrackingMovements = false;
      _movementTimer?.cancel();
      _movementTimer = null;
      _movementCount = 0;
      _movementStartTime = null;
      _trackingDuration = Duration.zero;
      _currentTrackingId = null;
    });
    if (mounted) {
      showCustomSnackbar(context, 'Шевеления сохранены', success: true);
      Navigator.of(context).pop();
    }
  }
  void _showMovementDialog() {
    final bool isTrackingAvailable = _pregnancyWeek >= 16;

    
    if (!_isTrackingMovements) {

      
      setState(() {
        _isTrackingMovements = true;
        _movementStartTime = DateTime.now();
        _movementCount = 0;
        _trackingDuration = Duration.zero;
        _currentTrackingId = null;
      });
      _startMovementTimer();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final startTimeStr = _movementStartTime != null
                ? '${_movementStartTime!.hour.toString().padLeft(2, '0')}:${_movementStartTime!.minute.toString().padLeft(2, '0')}'
                : '--:--';
            final durationStr = _movementStartTime != null
                ? _formatDuration(DateTime.now().difference(_movementStartTime!))
                : '00:00:00';
            final intervalStr = _lastMovementTime != null
                ? _formatInterval(DateTime.now().difference(_lastMovementTime!))
                : '00:00:00';
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 10,
              backgroundColor: Colors.white,
              titlePadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 0.0),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              title: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 25.0),
                    child: Align(
                      alignment: Alignment.center,
                      child: Text(
                        'Шевеление плода',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Comfortaa',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color.fromARGB(255, 54, 6, 56),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -10,
                    right: -4,
                    child: IconButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      icon: Icon(
                        Icons.close,
                        color: Color.fromARGB(255, 54, 6, 56).withOpacity(0.7),
                        size: 24,
                      ),
                      tooltip: 'Закрыть',
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: ListBody(
                  children: [
                    Text(
                        'Начало отслеживания: ${_movementStartTime?.hour.toString().padLeft(2, '0')}:${_movementStartTime?.minute.toString().padLeft(2, '0')}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Comfortaa',
                          fontSize: 14,
                          color: Color.fromARGB(255, 54, 6, 56).withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Длительность: ${_trackingDuration.inHours.toString().padLeft(2, '0')}:${(_trackingDuration.inMinutes % 60).toString().padLeft(2, '0')}:${(_trackingDuration.inSeconds % 60).toString().padLeft(2, '0')}.${(_trackingDuration.inMilliseconds % 1000).toString().padLeft(3, '0')}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Comfortaa',
                          fontSize: 14,
                          color: Color.fromARGB(255, 54, 6, 56).withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Интервал между шевелениями: ${_movementCount > 0 ? (_trackingDuration.inMinutes / _movementCount).toStringAsFixed(1) : "0"} мин',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Comfortaa',
                          fontSize: 14,
                          color: Color.fromARGB(255, 54, 6, 56).withOpacity(0.8),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      '${_movementCount}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Comfortaa',
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFBE7DBC),
                      ),
                    ),
                    Text(
                      'шевелений',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Comfortaa',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color.fromARGB(255, 54, 6, 56).withOpacity(0.7),
                      ),
                    ),
                    if (_isTrackingMovements) ...[
                      const SizedBox(height: 16),
                      
                    ],
                  ],
                ),
              ),
              actions: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () {
                          _stopMovementTracking();
                        },
                        child: Text(
                          'Остановить отслеживание',
                          style: TextStyle(
                            fontFamily: 'Comfortaa',
                            fontSize: 14,
                            color: Color(0xFFBE7DBC),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isTrackingAvailable
                              ? () async {
                                  await SystemSound.play(SystemSoundType.click);
                                  setState(() {
                                    _movementCount++;
                                    if (_movementCount >= 10) {
                                      showCustomSnackbar(
                                        context,
                                        'Достигнута норма шевелений!',
                                        success: true,
                                      );
                                    }
                                  });
                                  await _saveFetalMovements();
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isTrackingAvailable ? Color(0xFFBE7DBC) : Colors.grey,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Отметить шевеление',
                            style: TextStyle(
                              fontFamily: 'Comfortaa',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              actionsAlignment: MainAxisAlignment.center,
            );
          },
        );
      },
    );
  }

  Future<void> _saveFetalMovements() async {

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        return;
      }
      final now = DateTime.now();
      final startTime = _movementStartTime ?? now;
      final endTime = (_isTrackingMovements ? startTime : now);
      final durationMinutes = endTime != null 
          ? endTime.difference(startTime).inMinutes 
          : _trackingDuration.inMinutes;

      if (_currentTrackingId != null) {
        final updateData = {
          'movement_count': _movementCount,
          'duration_minutes': durationMinutes,
          'is_complete': !_isTrackingMovements,
        };
        
        if (endTime != null) {
          updateData['end_time'] = endTime.toIso8601String() as Object;
        }

        await supabase
            .from('fetal_movements')
            .update(updateData)
            .eq('id', _currentTrackingId ?? '');
      } else {
        final insertData = {
          'user_id': user.id,
          'date': _selectedDate.toIso8601String(),
          'start_time': startTime.toIso8601String(),
          'movement_count': _movementCount,
          'duration_minutes': durationMinutes,
          'is_complete': !_isTrackingMovements,
        };
        
        if (endTime != null) {
          insertData['end_time'] = endTime.toIso8601String() as Object;
        }

        final response = await supabase
            .from('fetal_movements')
            .insert(insertData)
            .select()
            .single();
        _currentTrackingId = response['id'];
      }

      if (!_isTrackingMovements) {       
         await supabase
            .from('fetal_movement_details')
            .delete()
            .eq('fetal_movement_id', _currentTrackingId!);
    
        final details = List.generate(
          _movementCount,
          (index) => {
            'fetal_movement_id': _currentTrackingId,
            'movement_number': index + 1,
            'timestamp': now.toIso8601String(),
          },
        );
        await supabase
            .from('fetal_movement_details')
            .insert(details);
      }
      
    } catch (e, stackTrace) {
      print('Ошибка: $e');
      print('Stack trace: $stackTrace');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка сохранения данных'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadFetalMovements() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        return;
      }
      final response = await supabase
          .from('fetal_movements')
          .select('*, fetal_movement_details(*)')
          .eq('user_id', user.id)
          .eq('date', _selectedDate.toIso8601String())
          .order('start_time', ascending: false)
          .limit(1)
          .maybeSingle();
      if (response != null) {
        final startTime = DateTime.parse(response['start_time']);
        final endTime = response['end_time'] != null ? DateTime.parse(response['end_time']) : null;
        
        setState(() {
          _movementCount = response['movement_count'] ?? 0;
          _movementStartTime = startTime;
          _trackingDuration = endTime != null 
              ? endTime.difference(startTime)
              : (DateTime.now().difference(startTime).isNegative 
                  ? Duration.zero 
                  : DateTime.now().difference(startTime));
          _currentTrackingId = response['id'];
          _isTrackingMovements = endTime == null;
        });

        if (_isTrackingMovements) {
          _startMovementTimer();
        }
      } else {
        setState(() {
          _movementCount = 0;
          _movementStartTime = null;
          _trackingDuration = Duration.zero;
          _currentTrackingId = null;
          _isTrackingMovements = false;
        });
      }
    } catch (e, stackTrace) {
      print('Ошибка загрузки данных о шевелениях:');
      print('Ошибка: $e');
      print('Stack trace: $stackTrace');
      
      setState(() {
        _movementCount = 0;
        _movementStartTime = null;
        _trackingDuration = Duration.zero;
        _currentTrackingId = null;
        _isTrackingMovements = false;
      });
    }
  }

  void _startMovementTimer() {
    _movementTimer?.cancel();
    _movementTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_isTrackingMovements && _movementStartTime != null) {
        setState(() {
          final now = DateTime.now();
          final duration = now.difference(_movementStartTime!);
          _trackingDuration = duration.isNegative ? Duration.zero : duration;
        });
      }
    });
  }

  Future<void> _loadWeeklyMovements() async {
    if (_isLoadingWeeklyData) return;
    setState(() => _isLoadingWeeklyData = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      
      final response = await supabase
          .from('fetal_movements')
          .select('*')
          .eq('user_id', user.id)
          .gte('date', monday.toIso8601String())
          .lte('date', monday.add(Duration(days: 6)).toIso8601String())
          .order('date');

      setState(() {
        _weeklyMovements = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Ошибка загрузки данных за неделю: $e');
    } finally {
      setState(() => _isLoadingWeeklyData = false);
    }
  }
  Widget _buildMovementChart() {
    if (_isLoadingWeeklyData) {
      return Center(child: CircularProgressIndicator());
    }

    if (_weeklyMovements.isEmpty) {
      return Center(
        child: Text(
          'Нет данных за неделю',
          style: TextStyle(
            fontFamily: 'Comfortaa',
            fontSize: 14,
            color: Color.fromARGB(255, 54, 6, 56).withOpacity(0.7),
          ),
        ),
      );
    }

    return Container(
      height: 200,
      padding: EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      fontFamily: 'Comfortaa',
                      fontSize: 10,
                      color: Color.fromARGB(255, 54, 6, 56),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value >= 0 && value < _weeklyMovements.length) {
                    final date = DateTime.parse(_weeklyMovements[value.toInt()]['date']);
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            fontFamily: 'Comfortaa',
                            fontSize: 10,
                            color: Color.fromARGB(255, 54, 6, 56),
                          ),
                        ),
                        Text(
                          _getWeekdayName(date.weekday),
                          style: TextStyle(
                            fontFamily: 'Comfortaa',
                            fontSize: 8,
                            color: Color.fromARGB(255, 54, 6, 56).withOpacity(0.7),
                          ),
                        ),
                      ],
                    );
                  }
                  return Text('');
                },
                reservedSize: 30,
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: _weeklyMovements.asMap().entries.map((entry) {
                return FlSpot(
                  entry.key.toDouble(),
                  (entry.value['movement_count'] as num).toDouble(),
                );
              }).toList(),
              isCurved: true,
              color: Color(0xFFBE7DBC),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Color(0xFFBE7DBC).withOpacity(0.2),
              ),
            ),
          ],
          minY: 0,
          maxY: 20,
        ),
      ),
    );
  }

  Widget _buildMovementReport() {
    final bool isReportAvailable = _pregnancyWeek >= 16;

    if (!isReportAvailable) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF2E4E1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFBE7DBC).withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              'Отчет о шевелениях будет доступен с 16 недели (сейчас $_pregnancyWeek)',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Comfortaa',
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Отчет о шевелениях плода',
                  style: TextStyle(
                    fontSize: 18,
                    fontFamily: 'Comfortaa',
                    fontWeight: FontWeight.w700,
                    color: Color.fromARGB(255, 54, 6, 56),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(Icons.refresh, color: Color(0xFFBE7DBC)),
                onPressed: _loadWeeklyMovements,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFBE7DBC).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                _buildMovementChart(),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      'Среднее',
                      '${_calculateAverageMovements()}',
                      Icons.trending_up,
                    ),
                    _buildStatItem(
                      'Максимум',
                      '${_calculateMaxMovements()}',
                      Icons.arrow_upward,
                    ),
                    _buildStatItem(
                      'Минимум',
                      '${_calculateMinMovements()}',
                      Icons.arrow_downward,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_weeklyMovements.isNotEmpty) ...[
                  const Text(
                    'Детальная статистика',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Comfortaa',
                      fontWeight: FontWeight.w700,
                      color: Color.fromARGB(255, 54, 6, 56),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._weeklyMovements.map((movement) {
                    final date = DateTime.parse(movement['date']);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${date.day} ${_getMonthName(date.month)} (${_getWeekdayName(date.weekday)})',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'Comfortaa',
                              color: Color.fromARGB(255, 54, 6, 56),
                            ),
                          ),
                          Text(
                            '${movement['movement_count']} движений',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'Comfortaa',
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFBE7DBC),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Color(0xFFBE7DBC), size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Comfortaa',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color.fromARGB(255, 54, 6, 56),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Comfortaa',
            fontSize: 12,
            color: Color.fromARGB(255, 54, 6, 56).withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  int _calculateAverageMovements() {
    if (_weeklyMovements.isEmpty) return 0;
    final sum = _weeklyMovements.fold<int>(
      0,
      (sum, item) => sum + (item['movement_count'] as num).toInt(),
    );
    return (sum / _weeklyMovements.length).round();
  }

  int _calculateMaxMovements() {
    if (_weeklyMovements.isEmpty) return 0;
    return _weeklyMovements
        .map((item) => (item['movement_count'] as num).toInt())
        .reduce((max, count) => count > max ? count : max);
  }

  int _calculateMinMovements() {
    if (_weeklyMovements.isEmpty) return 0;
    return _weeklyMovements
        .map((item) => (item['movement_count'] as num).toInt())
        .reduce((min, count) => count < min ? count : min);
  }

  @override
  Widget build(BuildContext context) {
    // Define colors based on the mockup palette
    const Color primaryPurple = Color(0xFFBE7DBC);
    const Color lightBackgroundPurple = Color(0xFFF3E5F5);
    const Color textColor = Color.fromARGB(255, 54, 6, 56);
    const Color textColorLight = Color.fromARGB(204, 54, 6, 56); // 80% opacity

    return Scaffold(
      backgroundColor: lightBackgroundPurple,
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromARGB(157, 235, 230, 242),
              Color.fromARGB(255, 252, 225, 219),
            ],
            stops: [0.0, 1.0],
          ),
        ),
        child: Stack(
          children: [
            SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _CalendarHeaderDelegate(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Color.fromARGB(117, 235, 230, 242).withOpacity(0.8),
                        ),
                        child: ClipRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _userName.isNotEmpty ? _userName : 'Загрузка...',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontFamily: 'Comfortaa',
                                          fontWeight: FontWeight.w900,
                                          color: Color.fromARGB(255, 54, 6, 56),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _userEmail.isNotEmpty ? _userEmail : 'Загрузка...',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontFamily: 'Comfortaa',
                                          fontWeight: FontWeight.w400,
                                          color: Color.fromARGB(255, 54, 6, 56),
                                        ),
                                      ),
                                      
                                    ],
                                  ),
                                  GestureDetector(
                                    onTap: _showCustomCalendar,
                                    child: Row(
                                      children: [
                                        Text(
                                          _getMonthName(_selectedDate.month),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontFamily: 'Comfortaa',
                                            fontWeight: FontWeight.w700,
                                            color: Color.fromARGB(255, 54, 6, 56),
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF2E4E1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.calendar_today,
                                            size: 20,
                                            color: Color.fromARGB(255, 54, 6, 56),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Horizontal Days List
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5.0), 
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 80,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(7, (index) {
                                final date = DateTime.now().add(Duration(days: index));
                                final isSelected = date.year == _selectedDate.year &&
                                    date.month == _selectedDate.month &&
                                    date.day == _selectedDate.day;
                                final isToday = date.year == DateTime.now().year &&
                                    date.month == DateTime.now().month &&
                                    date.day == DateTime.now().day;

                                return Expanded(
                                  child: GestureDetector(
                                    onTap: () => _onDaySelected(date, _selectedDate),
                                    child: Container(
                                      margin: EdgeInsets.symmetric(horizontal: 0.0), 
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFFFFF0F0)
                                            : isToday
                                                ? const Color(0xFFF2E4E1)
                                                : Colors.transparent,
                                        borderRadius: BorderRadius.circular(16), 
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0), 
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            // Day Number
                                            Text(
                                              date.day.toString(),
                                              style: TextStyle(
                                                fontSize: 24,
                                                fontFamily: 'Comfortaa',
                                                fontWeight: FontWeight.w700,
                                                color: isSelected
                                                    ? const Color(0xFFBB7CB2)
                                                    : const Color(0xFFBB7CB2),
                                              ),
                                            ),
                                            const SizedBox(height: 0), 
                                            // Weekday Name
                                            Text(
                                              _getDayName(date.weekday),
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontFamily: 'Comfortaa',
                                                fontWeight: FontWeight.w400,
                                                color: isSelected
                                                    ? const Color.fromARGB(255, 54, 6, 56).withOpacity(0.5)
                                                    : const Color.fromARGB(255, 54, 6, 56).withOpacity(0.5),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(height: 1), 
                          Center(
                            child: Stack( 
                              alignment: Alignment.center, 
                              children: [
                                Image.asset(
                                  'assets/corner.png', 
                                  height: 240, 
                                  fit: BoxFit.contain,
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 12.0, right: 12.0), 
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min, 
                                    children: [
                                      Column( 
                                        mainAxisAlignment: MainAxisAlignment.center, 
                                        children: [
                                          Text(
                                            '${_selectedDate.day}', 
                                            style: const TextStyle(
                                              fontSize: 40, 
                                              fontFamily: 'Comfortaa',
                                              fontWeight: FontWeight.w700,
                                              color: Color.fromARGB(164, 54, 6, 56), 
                                            ),
                                          ),
                                          const SizedBox(height: 0.0), 
                                          Text(
                                            _getWeekdayName(_selectedDate.weekday), 
                                            style: const TextStyle(
                                              fontSize: 14, 
                                              fontFamily: 'Comfortaa',
                                              fontWeight: FontWeight.w400,
                                              color: Color.fromARGB(164, 54, 6, 56), 
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2), 
                                      // "Clear Day" Button
                                      ElevatedButton(
                                        onPressed: _isLoading ? null : _clearDay,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFBE7DBC),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 1),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(15),
                                          ),
                                        ),
                                        child: _isLoading
                                            ? const SizedBox(
                                                width: 12,
                                                height: 12,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                ),
                                              )
                                            : const Text(
                                                'Очистить день',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontFamily: 'Comfortaa',
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(height: 5), 
                  ),

                  // Divider
                  SliverToBoxAdapter(
                    child: Divider(
                      color: Color(0xFFBE7DBC).withOpacity(0.3),
                      thickness: 1,
                      indent: 16,
                      endIndent: 16,
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: SizedBox(height: 10), 
                  ),

                  SliverToBoxAdapter(
                    child: SizedBox(height: 10),
                  ),

                  SliverToBoxAdapter(
                    child: _buildFetalMovementPanel(),
                  ),

                  SliverToBoxAdapter(
                    child: SizedBox(height: 5),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Ежедневные данные',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontFamily: 'Comfortaa',
                                  fontWeight: FontWeight.w700,
                                  color: Color.fromARGB(255, 54, 6, 56),
                                ),
                              ),
                              IconButton(
                                icon: Icon(_isEditingDailyData ? Icons.close : Icons.edit, color: Color(0xFFBE7DBC)),
                                onPressed: () {
                                  setState(() {
                                    _isEditingDailyData = !_isEditingDailyData;
                                    if (!_isEditingDailyData) _loadDailyData(); 
                                  });
                                },
                                tooltip: _isEditingDailyData ? 'Отмена' : 'Изменить',
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFBE7DBC).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                // Weight
                                Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF2E4E1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.monitor_weight,
                                        color: Color(0xFFBE7DBC),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    IntrinsicWidth(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: 35,
                                            child: TextField(
                                              controller: _weightController,
                                              keyboardType: TextInputType.number,
                                              textAlign: TextAlign.left,
                                              enabled: _isEditingDailyData,
                                              decoration: const InputDecoration(
                                                hintText: 'Вес',
                                                border: InputBorder.none,
                                                isDense: true,
                                                contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 0),
                                                hintStyle: TextStyle(
                                                  fontSize: 14,
                                                  fontFamily: 'Comfortaa',
                                                  fontWeight: FontWeight.w400,
                                                  color: Color.fromARGB(255, 54, 6, 56),
                                                ),
                                              ),
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontFamily: 'Comfortaa',
                                                fontWeight: FontWeight.w400,
                                                color: Color.fromARGB(255, 54, 6, 56),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 1),
                                          const Text(
                                            'кг',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontFamily: 'Comfortaa',
                                              fontWeight: FontWeight.w400,
                                              color: Color.fromARGB(255, 54, 6, 56),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF2E4E1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.favorite,
                                        color: Color(0xFFBE7DBC),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    IntrinsicWidth(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 29,
                                            child: TextField(
                                              controller: _systolicController,
                                              keyboardType: TextInputType.number,
                                              textAlign: TextAlign.left,
                                              enabled: _isEditingDailyData,
                                              decoration: const InputDecoration(
                                                hintText: 'Сист.',
                                                border: InputBorder.none,
                                                isDense: true,
                                                contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 0),
                                                hintStyle: TextStyle(
                                                  fontSize: 14,
                                                  fontFamily: 'Comfortaa',
                                                  fontWeight: FontWeight.w400,
                                                  color: Color.fromARGB(255, 54, 6, 56),
                                                ),
                                              ),
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontFamily: 'Comfortaa',
                                                fontWeight: FontWeight.w400,
                                                color: Color.fromARGB(255, 54, 6, 56),
                                              ),
                                            ),
                                          ),
                                          const Text(' / ', style: TextStyle(fontSize: 14)),
                                          SizedBox(
                                            width: 22,
                                            child: TextField(
                                              controller: _diastolicController,
                                              keyboardType: TextInputType.number,
                                              textAlign: TextAlign.left,
                                              enabled: _isEditingDailyData,
                                              decoration: const InputDecoration(
                                                hintText: 'Диаст.',
                                                border: InputBorder.none,
                                                isDense: true,
                                                contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 0),
                                                hintStyle: TextStyle(
                                                  fontSize: 14,
                                                  fontFamily: 'Comfortaa',
                                                  fontWeight: FontWeight.w400,
                                                  color: Color.fromARGB(255, 54, 6, 56),
                                                ),
                                              ),
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontFamily: 'Comfortaa',
                                                fontWeight: FontWeight.w400,
                                                color: Color.fromARGB(255, 54, 6, 56),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 1),
                                          const Text(
                                            'мм рт.ст.',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontFamily: 'Comfortaa',
                                              fontWeight: FontWeight.w400,
                                              color: Color.fromARGB(255, 54, 6, 56),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF2E4E1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.thermostat,
                                        color: Color(0xFFBE7DBC),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    IntrinsicWidth(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: 35,
                                            child: TextField(
                                              controller: _temperatureController,
                                              keyboardType: TextInputType.number,
                                              textAlign: TextAlign.left,
                                              enabled: _isEditingDailyData,
                                              decoration: const InputDecoration(
                                                
                                                border: InputBorder.none,
                                                isDense: true,
                                                contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 0),
                                                hintStyle: TextStyle(
                                                  fontSize: 14,
                                                  fontFamily: 'Comfortaa',
                                                  fontWeight: FontWeight.w400,
                                                  color: Color.fromARGB(255, 54, 6, 56),
                                                ),
                                              ),
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontFamily: 'Comfortaa',
                                                fontWeight: FontWeight.w400,
                                                color: Color.fromARGB(255, 54, 6, 56),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 1),
                                          const Text(
                                            '°C',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontFamily: 'Comfortaa',
                                              fontWeight: FontWeight.w400,
                                              color: Color.fromARGB(255, 54, 6, 56),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (_isEditingDailyData) ...[
                                  const SizedBox(height: 16),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton(
                                      onPressed: _isLoadingDailyData ? null : () async {
                                        await _saveDailyData();
                                        setState(() => _isEditingDailyData = false);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFBE7DBC),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: _isLoadingDailyData
                                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                          : const Text('Сохранить', style: TextStyle(fontSize: 14, fontFamily: 'Comfortaa', fontWeight: FontWeight.w700)),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Симптомы за день', 
                            style: TextStyle(
                              fontSize: 18,
                              fontFamily: 'Comfortaa',
                              fontWeight: FontWeight.w700,
                              color: Color.fromARGB(255, 54, 6, 56),
                            ),
                          ),
                          const SizedBox(height: 16), 
                                if (_symptoms.isEmpty) 
                                  Center(
                                    child: Text(
                                      _isLoading 
                                          ? 'Загрузка симптомов...'
                                          : 'Симптомы для вашего триместра пока не добавлены.',
                                      textAlign: TextAlign.center,
                                       style: TextStyle(
                                        fontFamily: 'Comfortaa',
                                        fontSize: 14,
                                        color: Color.fromARGB(255, 54, 6, 56).withOpacity(0.7),
                                      ),
                                    ),
                                  ) else
                                Wrap(
                                  spacing: 4.0, 
                                  children: _symptoms.map((symptom) {
                                    final isSelected = _selectedSymptoms.contains(symptom);
                                    final isSelectedWarning = _selectedSymptomsWarnings.contains(symptom);
                                    return FilterChip(
                                      label: Text(symptom),
                                      selected: isSelected || isSelectedWarning,
                                      onSelected: (selected) async {
                                        setState(() {
                                          if (selected) {
                                            _selectedSymptoms.add(symptom);
                                            _selectedSymptomsWarnings.add(symptom);
                                            _checkSymptomWarnings(symptom);
                                           
                                          } else {
                                            _selectedSymptoms.remove(symptom);
                                            _selectedSymptomsWarnings.remove(symptom);
                                          }
                                          _symptomChangesPending = true;   
                                        });
                                        print('Selected symptoms: $_selectedSymptoms'); 
                                      },
                                      backgroundColor: Colors.white, 
                                      selectedColor:isSelectedWarning
                                      ? const Color(0xFFBE7DBC)
                                      : const Color(0xFFBE7DBC),
                                      labelStyle: TextStyle(
                                        fontSize: 14,
                                        fontFamily: 'Comfortaa',
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w700, 
                                        color: isSelected || isSelectedWarning
                                         ? Colors.white : const Color.fromARGB(216, 54, 6, 56), 
                                      ),
                                      elevation: 4, // Тень для эффекта парения
                                      shadowColor: Colors.black.withOpacity(0.2),
                                      showCheckmark: false, 
                                      pressElevation: 4, 
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20.0), 
                                        side: BorderSide.none, 
                                      ),
                                    );
                                  }).toList(),
                                ),
                                if (_symptomChangesPending)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16.0),
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _saveSymptoms ,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFBE7DBC),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: const Text(
                                        'Сохранить симптомы',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontFamily: 'Comfortaa',
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: SizedBox(height: 5), 
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Информация о беременности',
                            style: TextStyle(
                              fontSize: 18,
                              fontFamily: 'Comfortaa',
                              fontWeight: FontWeight.w700,
                              color: Color.fromARGB(255, 54, 6, 56),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildPregnancyInfo(),
                        ],
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: SizedBox(height: 16), 
                  ),

                  SliverToBoxAdapter(
                    child: _buildMovementReport(),
                  ),

                  SliverToBoxAdapter(
                    child: SizedBox(height: 16), 
                  ),

                  SliverToBoxAdapter(
                    child: _buildMedicalSection(),
                  ),

                  SliverToBoxAdapter(
                    child: _buildMonthlyReportSection(),
                  ),

                  SliverToBoxAdapter(
                    child: SizedBox(height: 16),
                  ),

                  SliverToBoxAdapter(
                    child: _buildNotesSection(),
                  ),

                  SliverToBoxAdapter(
                    child: SizedBox(height: 16), 
                  ),

                  SliverToBoxAdapter(
                    child: _buildUltrasoundSection(),
                  ),

                  SliverToBoxAdapter(
                    child: SizedBox(height: 16), 
                  ),

                  SliverToBoxAdapter(
                    child: _buildRemindersSection(),
                  ),

                  SliverToBoxAdapter(
                    child: _buildSaveButton(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNav(
        currentIndex: _currentIndex,
        onTap: _onNavigationTap,
      ),
    );
  }
  Widget _buildPregnancyInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFBE7DBC).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          if (_lastPeriodDate == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: ElevatedButton(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    await _setLastPeriodDate(date);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBE7DBC),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  'Установить дату последних месячных',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Comfortaa',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2E4E1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.calendar_today,
                  color: Color(0xFFBE7DBC),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  _lastPeriodDate != null 
                    ? 'Неделя беременности: $_pregnancyWeek'
                    : 'Установите дату последних месячных',
                  style: const TextStyle(
                    fontSize: 14,
                    fontFamily: 'Comfortaa',
                    fontWeight: FontWeight.w400,
                    color: Color.fromARGB(255, 54, 6, 56),
                  ),
                ),
              ),
            ],
          ),
          if (_lastPeriodDate != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2E4E1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.event,
                    color: Color(0xFFBE7DBC),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _lastPeriodDate ?? DateTime.now(),
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        await _setLastPeriodDate(date);
                      }
                    },
                    child: Text(
                      'Дата последних месячных: ${_lastPeriodDate != null ? '${_lastPeriodDate!.day}.${_lastPeriodDate!.month}.${_lastPeriodDate!.year}' : 'Не указана'}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: 'Comfortaa',
                        fontWeight: FontWeight.w400,
                        color: Color.fromARGB(255, 54, 6, 56),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16), 
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2E4E1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.baby_changing_station, 
                    color: Color(0xFFBE7DBC),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _estimatedDeliveryDate != null
                            ? 'Предполагаемая дата родов: ${_estimatedDeliveryDate!.day}.${_estimatedDeliveryDate!.month}.${_estimatedDeliveryDate!.year}'
                            : 'Дата родов не рассчитана',
                        style: const TextStyle(
                          fontSize: 14,
                          fontFamily: 'Comfortaa',
                          fontWeight: FontWeight.w400,
                          color: Color.fromARGB(255, 54, 6, 56),
                        ),
                      ),
                      if (_estimatedDeliveryDate != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Осталось дней: ${_estimatedDeliveryDate!.difference(DateTime.now().toLocal()).inDays}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'Comfortaa',
                            fontWeight: FontWeight.w700, 
                            color: Color(0xFFBE7DBC), 
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Заметка',
            style: TextStyle(
              fontSize: 18,
              fontFamily: 'Comfortaa',
              fontWeight: FontWeight.w700,
              color: Color.fromARGB(255, 54, 6, 56),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFBE7DBC).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: TextField(
              controller: _noteController,
              maxLines: null, 
              decoration: const InputDecoration(
                hintText: 'Введите заметку...',
                border: InputBorder.none,
                hintStyle: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Comfortaa',
                  fontWeight: FontWeight.w400,
                  color: Color.fromARGB(255, 54, 6, 56),
                ),
              ),
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'Comfortaa',
                fontWeight: FontWeight.w400,
                color: Color.fromARGB(255, 54, 6, 56),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUltrasoundSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'УЗИ и скрининги',
            style: TextStyle(
              fontSize: 18,
              fontFamily: 'Comfortaa',
              fontWeight: FontWeight.w700,
              color: Color.fromARGB(255, 54, 6, 56),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFBE7DBC).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_ultrasoundPhotos.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _ultrasoundPhotos.map((photoUrl) {
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              photoUrl,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => 
                                Container(
                                  width: 100,
                                  height: 100,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.broken_image),
                                ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _deleteUltrasoundPhoto(photoUrl),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  )
                else
                  const Center(
                    child: Text(
                      'Нажмите на плюс, чтобы добавить фото',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Comfortaa',
                        fontWeight: FontWeight.w400,
                        color: Color.fromARGB(255, 54, 6, 56),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Center(
                  child: GestureDetector(
                    onTap: _isLoading ? null : _pickUltrasoundPhoto,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFBE7DBC).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 30,
                              height: 30,
                              child: CircularProgressIndicator(
                                color: Color(0xFFBE7DBC),
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.add,
                              size: 30,
                              color: Color(0xFFBE7DBC),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFetalMovementPanel() {
    final bool isReportAvailable = _pregnancyWeek >= 16;

  if (!isReportAvailable) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF2E4E1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFBE7DBC).withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            'Отслеживание шевелений будет доступно с 16 недели (сейчас $_pregnancyWeek)',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Comfortaa',
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GestureDetector(
        onTap: _showMovementDialog,
        child: Container(
          width: double.infinity,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: const Color(0xFFBE7DBC).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFBE7DBC).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isTrackingMovements ? Icons.pause : Icons.add,
                  size: 24,
                  color: const Color(0xFFBE7DBC),
                ),
              ),
              const SizedBox(height: 8),
              // Заголовок
              Text(
                'Шевеление плода',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'Comfortaa',
                  fontWeight: FontWeight.w700,
                  color: const Color.fromARGB(255, 54, 6, 56),
                ),
              ),
              if (_isTrackingMovements) ...[
                const SizedBox(height: 4),
                Text(
                  '$_movementCount движений',
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'Comfortaa',
                    color: const Color(0xFFBE7DBC),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveJournalEntry,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFBE7DBC),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                'Сохранить',
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Comfortaa',
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  void _calculateEstimatedDeliveryDate() {
    if (_lastPeriodDate == null) {
      setState(() {
        _estimatedDeliveryDate = null;
      });
      return;
    }
    final estimatedDate = _lastPeriodDate!.add(const Duration(days: 280));
    setState(() {
      _estimatedDeliveryDate = estimatedDate;
    });
  }
  Widget _buildMedicalIndicatorsSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Важные показатели',
                style: TextStyle(
                  fontSize: 18,
                  fontFamily: 'Comfortaa',
                  fontWeight: FontWeight.w700,
                  color: Color.fromARGB(255, 54, 6, 56),
                ),
              ),
              IconButton(
                icon: Icon(_isEditingMedicalData ? Icons.close : Icons.edit, color: Color(0xFFBE7DBC)),
                onPressed: () {
                  setState(() {
                    _isEditingMedicalData = !_isEditingMedicalData;
                    if (!_isEditingMedicalData) _loadMedicalData();
                  });
                },
                tooltip: _isEditingMedicalData ? 'Отмена' : 'Изменить',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFBE7DBC).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
            children: [
              _buildMedicalIndicatorRow(
                'Гемоглобин',
                _hemoglobinController,
                'г/л',
                Icons.bloodtype,
              ),
              const SizedBox(height: 16),
              _buildMedicalIndicatorRow(
                'Глюкоза (до еды)',
                _glucoseController1,
                'ммоль/л',
                Icons.monitor_heart,
              ),
              const SizedBox(height: 16),
              _buildMedicalIndicatorRow(
                'Глюкоза (через 1 час после еды)',
                _glucoseController2,
                'ммоль/л',
                Icons.monitor_heart,
              ),
              if (_isEditingMedicalData) ...[
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _isLoadingMedicalData ? null : () async {
                      await _saveMedicalData();
                      setState(() => _isEditingMedicalData = false);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFBE7DBC),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoadingMedicalData
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Сохранить', style: TextStyle(fontSize: 14, fontFamily: 'Comfortaa', fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}
  Widget _buildMedicalIndicatorRow(
  String label,
  TextEditingController controller,
  String unit,
  IconData icon,
) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center, 
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5.0),
          width: 35,
          height: 35,
          alignment: Alignment.center,
          child: Icon(
            icon,
            color: const Color(0xFFBE7DBC),
            size: 35,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: TextFormField(
            controller: controller,
            enabled: _isEditingMedicalData,
            readOnly: !_isEditingMedicalData,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              fontSize: 14,
              fontFamily: 'Comfortaa',
              color: Color(0xFF360638),
            ),
            decoration: InputDecoration(
              labelText: label,
              floatingLabelBehavior: FloatingLabelBehavior.auto,
              labelStyle: const TextStyle(
                fontSize: 14,
                fontFamily: 'Comfortaa',
                color: Color(0xFF360638),
              ),
              floatingLabelStyle: const TextStyle(
                fontSize: 13,
                fontFamily: 'Comfortaa',
                color: Color(0xFFBE7DBC),
              ),
              suffixText: unit,
              suffixStyle: const TextStyle(
                fontFamily: 'Comfortaa',
                fontSize: 14,
                color: Color.fromARGB(164, 54, 6, 56),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: const Color(0xFFBE7DBC).withOpacity(0.3),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFBE7DBC),
                  width: 2,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: const Color(0xFFBE7DBC).withOpacity(0.2),
                  width: 1,
                ),
              ),
              filled: true,
              fillColor: _isEditingMedicalData
                  ? Colors.white
                  : const Color(0xFFF9F9F9),
            ),
          ),
        ),
      ],
    ),
  );
}
Widget _buildMedicalSection() {
  return Padding(
    padding: const EdgeInsets.all(16.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Важные показатели',
              style: TextStyle(
                fontSize: 18,
                fontFamily: 'Comfortaa',
                fontWeight: FontWeight.w700,
                color: Color.fromARGB(255, 54, 6, 56),
              ),
            ),
            IconButton(
              icon: Icon(
                _isEditingMedicalData ? Icons.close : Icons.edit,
                color: Color(0xFFBE7DBC),
              ),
              onPressed: () {
                setState(() {
                  _isEditingMedicalData = !_isEditingMedicalData;
                  if (!_isEditingMedicalData) _loadMedicalData();
                });
              },
              tooltip: _isEditingMedicalData ? 'Отмена' : 'Изменить',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFBE7DBC).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              _buildMedicalIndicatorRow(
                'Гемоглобин',
                _hemoglobinController,
                'г/л',
                Icons.bloodtype,
              ),
              const SizedBox(height: 12),
              _buildMedicalIndicatorRow(
                'Глюкоза (до еды)',
                _glucoseController1,
                'ммоль/л',
                Icons.monitor_heart,
              ),
              const SizedBox(height: 12),
              _buildMedicalIndicatorRow(
                'Глюкоза (через 1 час после еды)',
                _glucoseController2,
                'ммоль/л',
                Icons.monitor_heart,
              ),
              if (_isEditingMedicalData) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _isLoadingMedicalData ? null : () async {
                      await _saveMedicalData();
                      setState(() => _isEditingMedicalData = false);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFBE7DBC),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoadingMedicalData
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Сохранить',
                            style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'Comfortaa',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

  Future<void> _loadMedicalData() async {
    if (_isLoadingMedicalData) return;
    if (!mounted) return;
    if (!_isOnline) {
      showCustomSnackbar(context, 'Нет подключения к интернету', success: false);
      return;
    }

    await Future.microtask(() async {
      try {
        setState(() => _isLoadingMedicalData = true);
        
        final user = supabase.auth.currentUser;
        if (user == null) {
          if (mounted) {
            showCustomSnackbar(context, 'Пожалуйста, войдите в аккаунт', success: false);
          }
          return;
        }

        final response = await supabase
            .from('medical_indicators')
            .select('*')
            .eq('user_id', user.id)
            .eq('date', _selectedDate.toIso8601String())
            .maybeSingle()
            .timeout(const Duration(seconds: 10));

        if (!mounted) return;

        if (response != null) {
          setState(() {
            _medicalData = response;
            _hemoglobinController.text = response['hemoglobin']?.toString() ?? '';
            _glucoseController1.text = response['glucose1']?.toString() ?? '';
            _glucoseController2.text = response['glucose2']?.toString() ?? '';
            
          });
        } else {
          setState(() {
            _medicalData = null;
            _hemoglobinController.clear();
            _glucoseController1.clear();
            _glucoseController2.clear();
          });
        }
      } on TimeoutException {
        if (mounted) {
          showCustomSnackbar(context, 'Превышено время ожидания ответа от сервера', success: false);
        }
      } catch (e) {
        print('Error loading medical data: $e');
        if (mounted) {
          showCustomSnackbar(context, 'Ошибка загрузки данных', success: false);
        }
      } finally {
        if (mounted) {
          setState(() => _isLoadingMedicalData = false);
        }
      }
    });
  }

 Future<void> _saveMedicalData() async { 
  if (_isLoadingMedicalData) return;
  if (!mounted) return;
  if (!_isOnline) {
    showCustomSnackbar(context, 'Нет подключения к интернету', success: false);
    return;
  }

  await Future.microtask(() async {
    try {
      setState(() => _isLoadingMedicalData = true);

      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) {
          showCustomSnackbar(context, 'Пожалуйста, войдите в аккаунт', success: false);
        }
        return;
      }
      double? hemoglobin;
      double? glucose1;
      double? glucose2;
      double? glucose2hAfterMeal;
      try {
        hemoglobin = _hemoglobinController.text.isNotEmpty 
            ? double.tryParse(_hemoglobinController.text.replaceAll(',', '.'))
            : null;

        glucose1 = _glucoseController1.text.isNotEmpty 
            ? double.tryParse(_glucoseController1.text.replaceAll(',', '.'))
            : null;

        glucose2 = _glucoseController2.text.isNotEmpty 
            ? double.tryParse(_glucoseController2.text.replaceAll(',', '.'))
            : null;
      } catch (e) {
        print('Error parsing numbers: $e');
        if (mounted) {
          showCustomSnackbar(context, 'Проверьте правильность введенных данных', success: false);
        }
        return;
      }

      final data = {
        'user_id': user.id,
        'date': _selectedDate.toIso8601String(),
        'hemoglobin': hemoglobin,
        'glucose1': glucose1,
        'glucose2': glucose2,
      };

      if (_medicalData != null) {
        await supabase
            .from('medical_indicators')
            .update(data)
            .eq('id', _medicalData!['id'])
            .timeout(const Duration(seconds: 10));
      } else {
        await supabase
            .from('medical_indicators')
            .insert(data)
            .timeout(const Duration(seconds: 10));
      }

      if (!mounted) return;

      showCustomSnackbar(context, 'Медицинские показатели сохранены');
      print('[SAVE] Сохраняем медицинские данные...');
      await _loadMedicalData();
      MedicalNormModal.show(
        context: context,
        trimester: _currentTrimester,
        hemoglobin: hemoglobin ?? 0.0,
        glucoseFasting: glucose1 ?? 0.0,
        glucose1hAfterMeal: glucose2,
      );

    } on TimeoutException {
      if (mounted) {
        showCustomSnackbar(context, 'Превышено время ожидания ответа от сервера', success: false);
      }
    } catch (e) {
      print('Error saving medical data: $e');
      if (mounted) {
        showCustomSnackbar(context, 'Ошибка сохранения данных. Проверьте формат ввода', success: false);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingMedicalData = false);
      }
    }
  });
}

  Future<void> _generateMonthlyReport() async {
    if (!mounted) return;
    if (!_isOnline) {
      showCustomSnackbar(context, 'Нет подключения к интернету', success: false);
      return;
    }

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final firstDay = DateTime(_selectedDate.year, _selectedDate.month, 1);
      final lastDay = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);

      final response = await supabase
          .from('medical_indicators')
          .select('*')
          .eq('user_id', user.id)
          .gte('date', firstDay.toIso8601String())
          .lte('date', lastDay.toIso8601String())
          .order('date');

      if (response.isEmpty) {
        showCustomSnackbar(context, 'Нет данных за ${_getMonthName(_selectedDate.month)} ${_selectedDate.year}', success: false);
        return;
      }

      final firstRecord = response.first;
      final lastRecord = response.last;
      
      String report = 'Отчет за ${_getMonthName(_selectedDate.month)} ${_selectedDate.year}:\n\n';
      
      if (firstRecord['hemoglobin'] != null && lastRecord['hemoglobin'] != null) {
        final change = lastRecord['hemoglobin'] - firstRecord['hemoglobin'];
        report += 'Гемоглобин: ${change > 0 ? '+' : ''}$change г/л\n';
        if (change < -10) {
          report += '⚠️ Значительное снижение гемоглобина. Рекомендуется консультация врача.\n';
        }
      }

      if (firstRecord['glucose'] != null && lastRecord['glucose'] != null) {
        final change = lastRecord['glucose'] - firstRecord['glucose'];
        report += 'Глюкоза: ${change > 0 ? '+' : ''}$change ммоль/л\n';
        if (change > 1) {
          report += '⚠️ Повышение уровня глюкозы. Рекомендуется консультация врача.\n';
        }
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Месячный отчет'),
            content: SingleChildScrollView(
              child: Text(report),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Закрыть'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('Error generating monthly report: $e');
      if (mounted) {
        showCustomSnackbar(context, 'Ошибка при формировании отчета', success: false);
      }
    }
  }

  Future<void> _loadReminders() async {
    if (_isLoadingReminders) return;
    setState(() => _isLoadingReminders = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final response = await supabase
          .from('reminders')
          .select('*')
          .eq('user_id', user.id)
          .gte('reminder_date', startOfDay.toIso8601String())
          .lt('reminder_date', endOfDay.toIso8601String())
          .order('reminder_date');

      print('Loaded reminders: $response'); // Debug print

      setState(() {
        _reminders = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Ошибка загрузки напоминаний: $e');
      setState(() {
        _reminders = [];
      });
    } finally {
      setState(() => _isLoadingReminders = false);
    }
  }

  void _showAddReminderDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReminderModal(
        onSave: (String title, String description, DateTime date, TimeOfDay time) async {
          try {
            final user = supabase.auth.currentUser;
            if (user == null) return;

            await supabase.from('reminders').insert({
              'user_id': user.id,
              'title': title,
              'description': description,
              'reminder_date': date.toIso8601String(),
              'is_completed': false,
            });

            await _loadReminders(); 
          } catch (e) {
            print('Ошибка добавления напоминания: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Ошибка добавления напоминания',
                  style: TextStyle(
                    fontFamily: 'Comfortaa',
                    fontSize: 14,
                  ),
                ),
                backgroundColor: Color(0xFFBE7DBC),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                margin: EdgeInsets.all(16),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildRemindersSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Напоминания',
                style: TextStyle(
                  fontSize: 18,
                  fontFamily: 'Comfortaa',
                  fontWeight: FontWeight.w700,
                  color: Color.fromARGB(255, 54, 6, 56),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Color(0xFFBE7DBC)),
                    onPressed: _loadReminders,
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: Color(0xFFBE7DBC)),
                    onPressed: _showAddReminderDialog,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoadingReminders)
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFBE7DBC),
              ),
            )
          else if (_reminders.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFBE7DBC).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  'Нет напоминаний на ${_selectedDate.day}.${_selectedDate.month}.${_selectedDate.year}',
                  style: TextStyle(
                    fontFamily: 'Comfortaa',
                    fontSize: 14,
                    color: Color.fromARGB(255, 54, 6, 56).withOpacity(0.7),
                  ),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _reminders.length,
              itemBuilder: (context, index) {
                final reminder = _reminders[index];
                final reminderDate = DateTime.parse(reminder['reminder_date']);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  child: ListTile(
                    title: Text(
                      reminder['title'],
                      style: TextStyle(
                        fontFamily: 'Comfortaa',
                        fontWeight: FontWeight.w600,
                        color: Color.fromARGB(255, 54, 6, 56),
                        decoration: reminder['is_completed'] ?? false ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (reminder['description'] != null && reminder['description'].isNotEmpty)
                          Text(
                            reminder['description'],
                            style: TextStyle(
                              fontFamily: 'Comfortaa',
                              color: Color.fromARGB(255, 54, 6, 56).withOpacity(0.7),
                            ),
                          ),
                        Text(
                          '${reminderDate.hour.toString().padLeft(2, '0')}:${reminderDate.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontFamily: 'Comfortaa',
                            color: Color(0xFFBE7DBC),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: reminder['is_completed'] ?? false,
                          onChanged: (value) async {
                            try {
                              await supabase
                                  .from('reminders')
                                  .update({'is_completed': value})
                                  .eq('id', reminder['id']);
                              _loadReminders();
                              showCustomSnackbar(context, 'Напоминание обновлено', success: true); // Use custom snackbar
                            } catch (e) {
                              print('Error updating reminder: $e');
                              showCustomSnackbar(context, 'Ошибка обновления напоминания', success: false); // Use custom snackbar
                            }
                          },
                          activeColor: const Color(0xFFBE7DBC),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Color(0xFFBE7DBC)),
                          onPressed: () async {
                            try {
                              await supabase
                                  .from('reminders')
                                  .delete()
                                  .eq('id', reminder['id']);
                              _loadReminders();
                              showCustomSnackbar(context, 'Напоминание удалено', success: true); // Use custom snackbar
                            } catch (e) {
                              print('Error deleting reminder: $e');
                              showCustomSnackbar(context, 'Ошибка удаления напоминания', success: false); // Use custom snackbar
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
  void _handleReminderSave(String title, String description, DateTime date, TimeOfDay time) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final reminderDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );

      final reminder = {
        'user_id': user.id,
        'title': title,
        'description': description,
        'reminder_date': reminderDateTime.toIso8601String(),
        'is_completed': false,
      };

      await supabase.from('reminders').insert(reminder);
      await _loadReminders(); 
      showCustomSnackbar(context, 'Напоминание успешно создано', success: true);
    } catch (e) {
      print('Ошибка сохранения напоминания: $e');
      showCustomSnackbar(context, 'Ошибка создания напоминания', success: false);
    }
  }

  Future<void> _checkSymptomWarnings(String symptomName) async {
    try {
      final response = await supabase
          .from('symptom_warnings')
          .select('*')
          .eq('symptom_name', symptomName)
          .maybeSingle();

      if (response != null) {
        if (!mounted) return;
        
        await SymptomWarningModal.show(
          context: context,
          symptomName: response['symptom_name'],
          warningMessage: response['warning_message'],
          severityLevel: response['severity_level'],
        );
      }
    } catch (e) {
      print('Error checking symptom warnings: $e');
    }
  }

  Widget _buildMonthlyReportSection() {
    final lastDay = DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;
    final isLastDayOfMonth = _selectedDate.day == lastDay;

    if (!isLastDayOfMonth) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFBE7DBC).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Месячный отчет',
              style: TextStyle(
                fontSize: 18,
                fontFamily: 'Comfortaa',
                fontWeight: FontWeight.w700,
                color: Color.fromARGB(255, 54, 6, 56),
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<String>(
              future: _getMonthlyReport(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Text(
                    'Ошибка загрузки отчета: ${snapshot.error}',
                    style: const TextStyle(
                      fontFamily: 'Comfortaa',
                      fontSize: 14,
                      color: Colors.red,
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Text(
                    'Нет данных для отчета',
                    style: TextStyle(
                      fontFamily: 'Comfortaa',
                      fontSize: 14,
                      color: Color.fromARGB(255, 54, 6, 56),
                    ),
                  );
                }
                return Text(
                  snapshot.data!,
                  style: const TextStyle(
                    fontFamily: 'Comfortaa',
                    fontSize: 14,
                    color: Color.fromARGB(255, 54, 6, 56),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _getMonthlyReport() async {
    if (!_isOnline) {
      return 'Нет подключения к интернету';
    }

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return 'Пожалуйста, войдите в аккаунт';

      // Get first and last day of selected month
      final firstDay = DateTime(_selectedDate.year, _selectedDate.month, 1);
      final lastDay = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);

      // Get all medical data for the month
      final response = await supabase
          .from('medical_indicators')
          .select('*')
          .eq('user_id', user.id)
          .gte('date', firstDay.toIso8601String())
          .lte('date', lastDay.toIso8601String())
          .order('date');

      if (response.isEmpty) {
        return 'Нет данных за ${_getMonthName(_selectedDate.month)} ${_selectedDate.year}';
      }

      // Calculate changes and generate report
      final firstRecord = response.first;
      final lastRecord = response.last;
      
      String report = 'Отчет за ${_getMonthName(_selectedDate.month)} ${_selectedDate.year}:\n\n';
      
      // Hemoglobin changes
      if (firstRecord['hemoglobin'] != null && lastRecord['hemoglobin'] != null) {
        final change = lastRecord['hemoglobin'] - firstRecord['hemoglobin'];
        report += 'Гемоглобин: ${change > 0 ? '+' : ''}$change г/л\n';
        if (change < -10) {
          report += '⚠️ Значительное снижение гемоглобина. Рекомендуется консультация врача.\n';
        }
      }

      // Glucose changes
      if (firstRecord['glucose1'] != null && lastRecord['glucose1'] != null) {
        final change = lastRecord['glucose1'] - firstRecord['glucose1'];
        report += 'Глюкоза: ${change > 0 ? '+' : ''}$change ммоль/л\n';
        if (change > 1) {
          report += '⚠️ Повышение уровня глюкозы до еды. Рекомендуется консультация врача.\n';
        }
      }

        if (firstRecord['glucose2'] != null && lastRecord['glucose2'] != null) {
        final change = lastRecord['glucose2'] - firstRecord['glucose2'];
        report += 'Глюкоза: ${change > 0 ? '+' : ''}$change ммоль/л\n';
        if (change > 1) {
          report += '⚠️ Повышение уровня глюкозы через 1 час после еды . Рекомендуется консультация врача.\n';
        }
      }
      

      return report;
    } catch (e) {
      print('Error generating monthly report: $e');
      return 'Ошибка при формировании отчета';
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _formatInterval(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
  
class _CalendarHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _CalendarHeaderDelegate({required this.child});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  double get maxExtent => 89.0; 

  @override
  double get minExtent => 89.0; 

  @override
  bool shouldRebuild(_CalendarHeaderDelegate oldDelegate) {
    return child != oldDelegate.child;
  }
} 


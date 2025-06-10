import 'package:flutter/material.dart';
import 'package:flutter_application_2/calendar_screen.dart';
import 'package:flutter_application_2/favorites_screen.dart';
import 'package:flutter_application_2/main.dart';
import 'package:flutter_application_2/profile_screen.dart';
import 'package:flutter_application_2/shared/bottom_nav.dart';
import 'package:flutter_application_2/shared/reminder_modal.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'story_screen.dart'; // Import StoryScreen
import 'dart:ui'; // Import for ImageFilter
import 'information_article_detail_screen.dart'; // Import InformationArticleDetailScreen
import 'filter_modal.dart'; // Import FilterModal
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'shared/custom_snackbar.dart';
import 'package:fl_chart/fl_chart.dart';
import 'shared/symptom_warning_modal.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // State variables
  String _userName = ''; // User name for header
  String _userEmail = ''; // User email for header
  List<Map<String, dynamic>> _relevantItems = []; // Data for stories
  List<Map<String, dynamic>> _categoryNames = []; // Data for categories
  int _selectedCategoryIndex = 0; // Selected category index
  List<Map<String, dynamic>> _categoryItems = []; // Data for vertical grid
  bool _isLoadingItems = false; // Loading state for vertical grid items
  List<Map<String, dynamic>> _filteredItems = []; // Filtered data for vertical grid
  Set<String> _favoritedArticleIds = {}; // Set to store IDs of favorited articles
  final int _currentIndex = 0; // Current navigation index
  List<String> _selectedSymptomIds = [];
  bool _isFiltered = false;
  List<String> _todaySymptoms = []; // Add this line to store today's symptoms
  List<Map<String, dynamic>> _todayReminders = []; // Add this line for today's reminders
  bool _isLoadingReminders = false; // Add loading state for reminders

  // Add pregnancy tracking variables
  DateTime? _lastPeriodDate;
  int _pregnancyWeek = 0;
  DateTime? _estimatedDeliveryDate;

  final SupabaseClient supabase = Supabase.instance.client;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController(); 

  @override
  void initState() {
    super.initState();
    _loadUserData(); 
    _loadRelevantItems(); 
    _loadCategories();
    _loadUserFavorites();
     _loadFavoritedArticleIds();
    _searchController.addListener(_performSearch);
    _loadLastPeriodDate();
    _loadTodayReminders();
  }

  // Dispose controllers
  @override
  void dispose() {
    _searchController.dispose(); 
    _scrollController.dispose();
    super.dispose();
  }
Future<void> _loadFavoritedArticleIds() async {
  final user = supabase.auth.currentUser;
  if (user == null) return;

  final response = await supabase
      .from('favourites')
      .select('information_article_id')
      .eq('user_id', user.id);

  if (mounted) {
    setState(() {
      _favoritedArticleIds = response.map<String>((e) => e['information_article_id'] as String).toSet();
    });
  }
}
  Future<void> _loadUserData() async {
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
      // print('Error loading user data: $e');
    }
  }

  Future<void> _loadRelevantItems() async {
    try {
      if (_pregnancyWeek > 0) {
        final response = await supabase
            .from('relevant_for_the_week')
            .select('''
              id,
              image,
              pregnancy_week,
              symptom:symptom_id (
                id,
                name
              ),
              trimester:trimester_id (
                id,
                number
              )
            ''')
            .eq('pregnancy_week', _pregnancyWeek);
        if (mounted) {
          setState(() {
            _relevantItems = List<Map<String, dynamic>>.from(response);
            // print('Loaded items count: ${_relevantItems.length}'); 
            // print('Current pregnancy week: $_pregnancyWeek'); 
            // print('Items pregnancy weeks: ${_relevantItems.map((item) => item['pregnancy_week']).toList()}'); 
          });
        }
      } else {
        // print('No pregnancy week set, loading all items'); 
        final response = await supabase
            .from('relevant_for_the_week')
            .select('''
              id,
              image,
              pregnancy_week,
              symptom:symptom_id (
                id,
                name
              ),
              trimester:trimester_id (
                id,
                number
              )
            ''');
        if (mounted) {
          setState(() {
            _relevantItems = List<Map<String, dynamic>>.from(response);
          });
        }
      }
    } catch (e) {
      // print('Error loading relevant items: $e');
    }
  }

  Future<void> _loadCategories() async {
    try {
      final response = await supabase
          .from('category')
          .select('id, name');

      if (mounted) {
        setState(() {
          _categoryNames = [
            {'id': 'for_you', 'name': 'Для вас'}, 
            ...List<Map<String, dynamic>>.from(response)
          ];
          if (_categoryNames.isNotEmpty) {
             _loadCategoryItems(_categoryNames[_selectedCategoryIndex]['id']);
          }
        });
      }
    } catch (e) {
      // print('Error loading category names: $e');
    }
  }

  Future<void> _loadUserFavorites() async {
    try {
      final user = supabase.auth.currentUser; 
      if (user == null) {
        // print('User not logged in. Cannot load favorites.');
        return; 
      }

      final response = await supabase
          .from('favourites')
          .select('information_article_id')
          .eq('user_id', user.id);

      if (mounted) {
        setState(() {
          _favoritedArticleIds = Set<String>.from(
            response.map((item) => item['information_article_id'] as String?)
                    .where((id) => id != null)
                    .cast<String>() 
                    .toList(),
          );
          // print('Loaded ${_favoritedArticleIds.length} favorited articles.');
        });
      }
    } catch (e) {
      // print('Error loading user favorites: $e');
    }
  }

  int _calculatePregnancyWeek(DateTime lastPeriodDate) {
    final now = DateTime.now();
    final difference = now.difference(lastPeriodDate);
    final week = (difference.inDays / 7).floor();
    // print('Calculated pregnancy week: $week from last period date: $lastPeriodDate');
    return week;
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

  Future<void> _loadLastPeriodDate() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final response = await supabase
            .from('user')
            .select('last_period_date')
            .eq('id', user.id)
            .single();

        if (response['last_period_date'] != null) {
          setState(() {
            _lastPeriodDate = DateTime.parse(response['last_period_date']);
            _pregnancyWeek = _calculatePregnancyWeek(_lastPeriodDate!);
            // print('Updated pregnancy week to: $_pregnancyWeek'); 
          });
          _calculateEstimatedDeliveryDate();
          _loadRelevantItems(); 
        }
      }
    } catch (e) {
      // print('Error loading last period date: $e');
    }
  }
  Future<void> _setLastPeriodDate(DateTime date) async {
    try {
      await supabase
          .from('user')
          .update({'last_period_date': date.toIso8601String()})
          .eq('id', supabase.auth.currentUser!.id);

      setState(() {
        _lastPeriodDate = date;
        _pregnancyWeek = _calculatePregnancyWeek(date);
        _calculateEstimatedDeliveryDate();
      });
      _showCustomSnackbar('Дата успешно сохранена', success: true);
    } catch (e) {
      // print('Error setting last period date: $e');
      _showCustomSnackbar('Ошибка сохранения даты', success: false);
    }
  }

  void _showCustomSnackbar(String message, {bool success = true}) {
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
            boxShadow: [
              BoxShadow(
                color: Colors.black12, 
                blurRadius: 16, 
                offset: const Offset(0, 4), 
              ),
            ],
          ),
          child: Text(
            message,
            style: const TextStyle(
              fontSize: 17, // Font size
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

  Future<void> _toggleFavoriteStatus(String articleId) async {
    final user = supabase.auth.currentUser; 
    if (user == null) {
      // print('User not logged in. Cannot toggle favorite.');
      return; 
    }

    final isFavorited = _favoritedArticleIds.contains(articleId);

    try {
      if (isFavorited) {
        await supabase
            .from('favourites')
            .delete()
            .eq('user_id', user.id)
            .eq('information_article_id', articleId);

        if (mounted) {
          setState(() {
            _favoritedArticleIds.remove(articleId); 
          });
        }
        // print('Removed article $articleId from favorites.');
      } else {
        await supabase.from('favourites').insert({
          'user_id': user.id,
          'information_article_id': articleId,
        });

        if (mounted) {
          setState(() {
            _favoritedArticleIds.add(articleId); 
          });
        }
        // print('Added article $articleId to favorites.');
      }
    } catch (e) {
      // print('Error toggling favorite status for article $articleId: $e');
    }
  }

  Future<void> _loadCategoryItems(String categoryId) async {
    // print('Loading items for categoryId: $categoryId');
    if (mounted) {
      setState(() {
        _isLoadingItems = true;
        _categoryItems = []; 
        _filteredItems = []; 
      });
    }
     try {
        if (categoryId == 'for_you') {
          final user = supabase.auth.currentUser;
          if (user == null) {
            // print('User not logged in. Cannot load personalized articles.');
            return;
          }
          final today = DateTime.now().toIso8601String().split('T')[0];
          final calendarResponse = await supabase
              .from('calendar')
              .select('journal_id')
              .eq('user_id', user.id)
              .eq('date', today)
              .single();

          if (calendarResponse == null || calendarResponse['journal_id'] == null) {
            // print('No journal entry for today');
            if (mounted) {
              setState(() {
                _categoryItems = [];
                _filteredItems = [];
                _isLoadingItems = false;
              });
            }
            return;
          }

          final journalId = calendarResponse['journal_id'] as String;
          final symptomsResponse = await supabase
              .from('journal_symptom')
              .select('symptom_id')
              .eq('journal_id', journalId);

          if (symptomsResponse.isEmpty) {
            // print('No symptoms found for today\'s journal');
            if (mounted) {
              setState(() {
                _categoryItems = [];
                _filteredItems = [];
                _isLoadingItems = false;
              });
            }
            return;
          }

          final symptomIds = symptomsResponse.map((item) => item['symptom_id'] as String).toList();
          // print('Found symptom IDs: $symptomIds'); 
          final articlesResponse = await supabase
              .from('information_article')
              .select('''
                id,
                header,
                image,
                text_of_article,
                article_category!inner (
                  category!inner (
                    id,
                    name
                  )
                )
              ''')
              .inFilter('symptom_id', symptomIds);
          // print('Articles response: $articlesResponse'); 
          if (mounted) {
            final List<Map<String, dynamic>> articles = articlesResponse
                .map((item) {
                  // print('Processing article: $item'); 
                  return {
                    'id': item['id'],
                    'header': item['header'],
                    'image': item['image'],
                    'text_of_article': item['text_of_article'],
                    'category_name': (item['article_category'] as List<dynamic>).isNotEmpty
                        ? (item['article_category'] as List<dynamic>).first['category']['name'] as String
                        : 'Без категории',
                  };
                })
                .toList();

            // print('Processed articles: $articles');

            setState(() {
              _categoryItems = articles;
              _filteredItems = articles;
              _isLoadingItems = false;
            });
          }
        } else {
          final response = await supabase
              .from('article_category')
              .select('''
                article_id!inner (
                  id,
                  header,
                  image,
                  text_of_article
                ),
                category!inner (
                  id,
                  name
                )
              ''')
              .eq('category_id', categoryId);

          // print('Regular category response: $response'); 

          if (mounted) {
            final List<Map<String, dynamic>> fetchedItems = List<Map<String, dynamic>>.from(response);
            final List<Map<String, dynamic>> articles = fetchedItems
                .map((item) {
                  // print('Processing regular article: $item'); 
                  return {
                    ...?item['article_id'] as Map<String, dynamic>,
                    'category_name': item['category']['name'] as String,
                  };
                })
                .toList();
            // print('Processed regular articles: $articles'); 
            setState(() {
              _categoryItems = articles;
              _filteredItems = articles;
              _isLoadingItems = false;
            });
          }
        }
     } catch (e) {
        // print('Error loading category articles: $e');
        if (mounted) {
          setState(() {
             _categoryItems = [];
             _filteredItems = [];
             _isLoadingItems = false;
          });
        }
     }
  }

  void _performSearch() {
    final query = _searchController.text.toLowerCase();
    // print('Search query: $query');
    setState(() {
      if (query.isEmpty) {
        _filteredItems = _categoryItems; 
        // print('Filtered items (empty query): ${_filteredItems.length}');
      } else {
        _filteredItems = _categoryItems.where((item) {
          final header = item['header']?.toLowerCase() ?? ''; 
          // print('Checking item header: $header against query: $query');
          final containsQuery = header.contains(query);
          // print('Contains query: $containsQuery');
          return containsQuery;
        }).toList();
        // print('Filtered items (with query): ${_filteredItems.length}');
      }
    });
  }
  Future<void> _loadFilteredItems(List<String> symptomIds) async {
    if (symptomIds.isEmpty) {
      setState(() {
        _filteredItems = _categoryItems;
        _isFiltered = false;
      });
      return;
    }
    try {
      final response = await supabase
          .from('information_article')
          .select('id, header, image, text_of_article')
          .inFilter('symptom_id', symptomIds);

      if (mounted) {
        setState(() {
          _filteredItems = List<Map<String, dynamic>>.from(response);
          _isFiltered = true;
        });
      }
    } catch (e) {
      // print('Error loading filtered items: $e');
    }
  }
  void _onNavigationTap(int index) {
    if (index == _currentIndex) return;
    
    switch (index) {
      case 0: 
        break;
      case 1:
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

  Future<void> _loadTodayReminders() async {
    if (_isLoadingReminders) return;
    
    if (mounted) {
      setState(() {
        _isLoadingReminders = true;
      });
    }

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _isLoadingReminders = false;
            _todayReminders = [];
          });
        }
        return;
      }

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final response = await supabase
          .from('reminders')
          .select('*')
          .eq('user_id', user.id)
          .gte('reminder_date', startOfDay.toIso8601String())
          .lt('reminder_date', endOfDay.toIso8601String())
          .order('reminder_date');

      // print('Loaded reminders: $response'); 

      if (mounted) {
        setState(() {
          _todayReminders = List<Map<String, dynamic>>.from(response);
          _isLoadingReminders = false;
        });
      }
    } catch (e) {
      // print('Error loading reminders: $e');
      if (mounted) {
        setState(() {
          _isLoadingReminders = false;
          _todayReminders = [];
        });
      }
    }
  }
  Future<void> _toggleReminderCompletion(String reminderId, bool currentStatus) async {
    try {
      await supabase
          .from('reminders')
          .update({'is_completed': !currentStatus})
          .eq('id', reminderId);

      setState(() {
        final index = _todayReminders.indexWhere((r) => r['id'] == reminderId);
        if (index != -1) {
          _todayReminders[index]['is_completed'] = !currentStatus;
        }
      });
      _showCustomSnackbar(!currentStatus ? 'Напоминание выполнено' : 'Напоминание не выполнено', success: true);
    } catch (e) {
      // print('Error toggling reminder completion: $e');
      _showCustomSnackbar('Ошибка при обновлении напоминания', success: false);
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

            final reminderDateTime = DateTime(
              date.year,
              date.month,
              date.day,
              time.hour,
              time.minute,
            );

            await supabase.from('reminders').insert({
              'user_id': user.id,
              'title': title,
              'description': description,
              'reminder_date': reminderDateTime.toIso8601String(),
              'is_completed': false,
            });

            await _loadTodayReminders();
          } catch (e) {
            // print('Ошибка добавления напоминания: $e');
            _showCustomSnackbar('Ошибка добавления напоминания', success: false);
          }
        },
      ),
    );
  }

  Future<void> _deleteReminder(String reminderId) async {
    try {
      await supabase
          .from('reminders')
          .delete()
          .eq('id', reminderId);
      await _loadTodayReminders();
      _showCustomSnackbar('Напоминание удалено', success: true);
    } catch (e) {
      // print('Error deleting reminder: $e');
      _showCustomSnackbar('Ошибка удаления напоминания', success: false);
    }
  }

  String _formatReminderTime(DateTime dateTime) {
    if (dateTime.hour == 0 && dateTime.minute == 0) {
      return 'Весь день';
    }
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  IconData _getReminderIcon(String title) {
    final lowerTitle = title.toLowerCase();
    if (lowerTitle.contains('витамин') || lowerTitle.contains('таблет')) {
      return Icons.medical_services;
    } else if (lowerTitle.contains('вод')) {
      return Icons.water_drop;
    } else if (lowerTitle.contains('прогул')) {
      return Icons.directions_walk;
    } else if (lowerTitle.contains('сон')) {
      return Icons.bedtime;
    } else if (lowerTitle.contains('еда') || lowerTitle.contains('куш')) {
      return Icons.restaurant;
    }
    return Icons.notifications;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        child: SafeArea(
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _UserInfoHeaderDelegate(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Color.fromARGB(117, 235, 230, 242).withOpacity(0.8),
                    ),
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                          child: Column(
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
                                overflow: TextOverflow.ellipsis,
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
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: Color(0xFFE0CAE6).withOpacity(0.4),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: TextField(
                                        controller: _searchController,
                                        decoration: InputDecoration(
                                          hintText: 'Поиск...',
                                          border: InputBorder.none,
                                          prefixIcon: Icon(Icons.search, color: Color.fromARGB(255, 54, 6, 56)),
                                          contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                                        ),
                                        style: TextStyle(fontFamily: 'Comfortaa', fontSize: 15, color: Color.fromARGB(255, 54, 6, 56)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Color(0xFFF2E4E1).withOpacity(0.8),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.filter_list, color: Color.fromARGB(255, 54, 6, 56)),
                                      onPressed: () {
                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          backgroundColor: Colors.transparent,
                                          builder: (context) => FilterModal(
                                            onFiltersApplied: (symptomIds) {
                                              setState(() {
                                                _selectedSymptomIds = symptomIds;
                                              });
                                              _loadFilteredItems(symptomIds);
                                            },
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Divider(
                  color: Color(0xFFBE7DBC).withOpacity(0.3),
                  thickness: 1,
                  indent: 16,
                  endIndent: 16,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
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
                        if (_lastPeriodDate == null)
                          Center(
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
                          )
                        else ...[
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
                                  'Неделя беременности: $_pregnancyWeek',
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
                          if (_estimatedDeliveryDate != null) ...[
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
                                        'Предполагаемая дата родов: ${_estimatedDeliveryDate!.day}.${_estimatedDeliveryDate!.month}.${_estimatedDeliveryDate!.year}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontFamily: 'Comfortaa',
                                          fontWeight: FontWeight.w400,
                                          color: Color.fromARGB(255, 54, 6, 56),
                                        ),
                                      ),
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
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                                Icons.notifications_active,
                                color: Color(0xFFBE7DBC),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Напоминания на сегодня',
                              style: TextStyle(
                                fontSize: 15,
                                fontFamily: 'Comfortaa',
                                fontWeight: FontWeight.w700,
                                color: Color.fromARGB(255, 54, 6, 56),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.refresh,
                                color: Color(0xFFBE7DBC),
                                size: 20,
                              ),
                              onPressed: _loadTodayReminders,
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(
                                Icons.add_circle_outline,
                                color: Color(0xFFBE7DBC),
                                size: 20,
                              ),
                              onPressed: _showAddReminderDialog,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (_isLoadingReminders)
                          const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFBE7DBC)),
                            ),
                          )
                        else if (_todayReminders.isEmpty)
                          Center(
                            child: Column(
                              children: [
                                const SizedBox(height: 16),
                                Text(
                                  'Нет напоминаний на сегодня',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontFamily: 'Comfortaa',
                                    color: Color.fromARGB(255, 54, 6, 56).withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ..._todayReminders.map((reminder) {
                            final reminderDate = DateTime.parse(reminder['reminder_date']);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildReminderItem(
                                icon: _getReminderIcon(reminder['title']),
                                title: reminder['title'],
                                time: _formatReminderTime(reminderDate),
                                isCompleted: reminder['is_completed'] ?? false,
                                onToggle: () => _toggleReminderCompletion(
                                  reminder['id'],
                                  reminder['is_completed'] ?? false,
                                ),
                                reminderId: reminder['id'],
                              ),
                            );
                          }).toList(),
                      ],
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                 child: Padding(
                   padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                   child: Text(
                     'Актуальное на неделе',
                     style: TextStyle(
                       fontSize: 18,
                       fontFamily: 'Comfortaa',
                       fontWeight: FontWeight.w900,
                       color: Color.fromARGB(255, 54, 6, 56),
                     ),
                   ),
                 ),
               ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 160,
                  child: _relevantItems.isEmpty 
                    ? Center(
                        child: Text(
                          'Нет актуальных историй на этой неделе',
                          style: TextStyle(
                            fontFamily: 'Comfortaa',
                            fontSize: 14,
                            color: Color.fromARGB(255, 54, 6, 56),
                          ),
                        ),
                      )
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _relevantItems.length,
                        itemBuilder: (context, index) {
                          final relevantItem = _relevantItems[index];
                          final imageUrl = relevantItem['image'] as String?;
                          final week = relevantItem['pregnancy_week'] as int?;

                          print('Building item $index: Week $week, Item: $relevantItem');

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => StoryScreen(stories: _relevantItems)),
                              );
                            },
                            child: Container(
                              width: 120,
                              margin: EdgeInsets.only(
                                left: index == 0 ? 16.0 : 8.0,
                                right: index == _relevantItems.length - 1 ? 16.0 : 8.0
                              ),
                              decoration: BoxDecoration(
                                color: Color(0xFFE0CAE6).withOpacity(0.4),
                                borderRadius: BorderRadius.circular(12.0),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.0,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12.0),
                                child: imageUrl != null && imageUrl.isNotEmpty
                                  ? Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        // print('Error loading image: $error');
                                        return Center(
                                          child: Icon(
                                            Icons.broken_image,
                                            color: Color(0xFFBE7DBC),
                                          ),
                                        );
                                      },
                                    )
                                  : Center(
                                      child: Text(
                                        'Неделя $week',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontFamily: 'Comfortaa',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Color.fromARGB(255, 54, 6, 56).withOpacity(0.8),
                                        ),
                                      ),
                                    ),
                              ),
                            ),
                          );
                        },
                      ),
                ),
              ),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    SizedBox(height: 5),
                    Divider(
                      color: Color(0xFFBE7DBC).withOpacity(0.3),
                      thickness: 1,
                      indent: 16,
                      endIndent: 16,
                    ),
                    SizedBox(height: 5),
                  ],
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _CategoryHeaderDelegate(
                  categoryNames: _categoryNames,
                  selectedIndex: _selectedCategoryIndex,
                  onCategorySelected: (index) {
                    setState(() {
                      _selectedCategoryIndex = index;
                    });
                    _loadCategoryItems(_categoryNames[_selectedCategoryIndex]['id']);
                  },
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16.0)),
              SliverToBoxAdapter(
                 child: Padding(
                   padding: const EdgeInsets.symmetric(horizontal: 14.0),
                   child: _isLoadingItems 
                       ? Center(child: CircularProgressIndicator()) 
                       : _filteredItems.isNotEmpty 
                           ? GridView.builder(
                               shrinkWrap: true,
                               physics: const NeverScrollableScrollPhysics(),
                               gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                 crossAxisCount: 2,
                                 crossAxisSpacing: 16.0,
                                 mainAxisSpacing: 16.0,
                                 childAspectRatio: 0.7,
                               ),
                               itemCount: _filteredItems.length,
                               itemBuilder: (context, index) {
                                  final categoryItem = _filteredItems[index];
                                  final imageUrl = categoryItem != null ? categoryItem['image'] : null;
                                   final isFavorited = _favoritedArticleIds.contains(categoryItem['id']);
                                   return GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => InformationArticleDetailScreen(
                                            article: categoryItem,
                                            onFavoriteChanged: (articleId, isFavorite) {
                                              setState(() {
                                                if (isFavorite) {
                                                  _favoritedArticleIds.add(articleId);
                                                } else {
                                                  _favoritedArticleIds.remove(articleId);
                                                }
                                              });
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                   child: Container(
                                     decoration: BoxDecoration(
                                       color: Colors.white, 
                                       borderRadius: BorderRadius.circular(12.0),
                                     ),
                                      child: Stack( 
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                if (imageUrl != null && (imageUrl as String).isNotEmpty)
                                                  Column( 
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      SizedBox( 
                                                        height: 150.0,
                                                        child: ClipRRect(
                                                          borderRadius: BorderRadius.circular(8.0),
                                                          child: Image.network(
                                                            imageUrl,
                                                            fit: BoxFit.cover,
                                                            errorBuilder: (context, error, stackTrace) {
                                                              // print('Error loading article image: $imageUrl - $error');
                                                              return Center(child: Icon(Icons.broken_image));
                                                            },
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2), 
                                                      Text(
                                                         categoryItem != null ? categoryItem['header'] ?? 'Заголовок статьи' : 'Заголовок статьи', 
                                                         style: TextStyle(
                                                           fontFamily: 'Comfortaa',
                                                           fontSize: 14,
                                                           fontWeight: FontWeight.w700,
                                                           color: Color.fromARGB(255, 54, 6, 56), // Dark purple color for header
                                                         ),
                                                         maxLines: 2,
                                                         overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ],
                                                  ) 
                                                else
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                       Text(
                                                          categoryItem != null ? categoryItem['header'] ?? 'Заголовок статьи' : 'Заголовок статьи',
                                                          style: TextStyle(
                                                            fontFamily: 'Comfortaa',
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.w700,
                                                            color: Color.fromARGB(255, 54, 6, 56), // Dark purple color for header
                                                          ),
                                                          maxLines: 2,
                                                          overflow: TextOverflow.ellipsis,
                                                       ),
                                                       const SizedBox(height: 4),
                                                       Text(
                                                          categoryItem != null ? categoryItem['text_of_article'] ?? 'Текст статьи...\nПродолжение статьи...' : 'Текст статьи...\nПродолжение статьи...', // Use 'text_of_article' or placeholder
                                                          style: TextStyle(
                                                            fontFamily: 'Comfortaa',
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.w400,
                                                            color: Color.fromARGB(255, 54, 6, 56).withOpacity(0.8), 
                                                          ),
                                                          maxLines: 4, 
                                                          overflow: TextOverflow.ellipsis,
                                                       ),
                                                    ],
                                                  ),

                                                const SizedBox(height: 8), 
                                              ],
                                            ),
                                          ),
                                           Positioned(
                                              top: 8,
                                              right: 8,
                                              child: GestureDetector(
                                                onTap: () => _toggleFavoriteStatus(categoryItem['id'] as String),
                                                child: Container(
                                                  padding: EdgeInsets.all(4),
                                                  decoration: BoxDecoration(
                                                     color: Color(0xFFF2E4E1).withOpacity(0.8),
                                                     borderRadius: BorderRadius.circular(8),
                                                  ),
                                                   child: Icon(
                                                      _favoritedArticleIds.contains(categoryItem['id']) ? Icons.favorite : Icons.favorite_border, 
                                                      size: 18,
                                                      color: _favoritedArticleIds.contains(categoryItem['id']) ? Color(0xFFBE7DBC) : Color(0xFFBE7DBC), 
                                                   ),
                                                ),
                                              ),
                                           ),
                                        ],
                                      ),
                                 )
                                );
                               },
                             )
                           : Center(
                               child: Column(
                                 mainAxisAlignment: MainAxisAlignment.center,
                                 children: [
                                   Icon(
                                     Icons.medical_services_outlined,
                                     size: 48,
                                     color: Color(0xFFBE7DBC).withOpacity(0.5),
                                   ),
                                   SizedBox(height: 16),
                                   Text(
                                     _selectedCategoryIndex == 0 
                                         ? 'Нет статей с симптомами, отметьте симптомы в календаре!'
                                         : 'Ничего не найдено!',
                                     textAlign: TextAlign.center,
                                     style: TextStyle(
                                       fontFamily: 'Comfortaa',
                                       fontSize: 16,
                                       fontWeight: FontWeight.w700,
                                       color: Color.fromARGB(255, 54, 6, 56).withOpacity(0.8),
                                     ),
                                   ),
                                 ],
                               ),
                             ),
                 ),
          ),
        ],
      ),
        ),
      ),
      bottomNavigationBar: BottomNav(
        currentIndex: _currentIndex,
        onTap: _onNavigationTap,
      ),
    );
  }

  Widget _buildReminderItem({
    required IconData icon,
    required String title,
    required String time,
    required bool isCompleted,
    required VoidCallback onToggle,
    required String reminderId,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2E4E1).withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFBE7DBC).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center, 
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF2E4E1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(
                icon,
                color: const Color(0xFFBE7DBC),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12), 
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontFamily: 'Comfortaa',
                    fontWeight: FontWeight.w600,
                    color: Color.fromARGB(255, 54, 6, 56),
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: const Color(0xFFBE7DBC).withOpacity(0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'Comfortaa',
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFFBE7DBC).withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8), 
          Row(
            mainAxisSize: MainAxisSize.min, 
            children: [
              SizedBox(
                width: 24, 
                height: 24, 
                child: Checkbox(
                  value: isCompleted,
                  onChanged: (_) => onToggle(),
                  activeColor: const Color(0xFFBE7DBC),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 4), 
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFBE7DBC),
                  size: 20,
                ),
                onPressed: () => _deleteReminder(reminderId),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                splashRadius: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _CategoryHeaderDelegate({
    required this.categoryNames,
    required this.selectedIndex,
    required this.onCategorySelected,
  });

  final List<Map<String, dynamic>> categoryNames;
  final int selectedIndex;
  final ValueChanged<int> onCategorySelected;

  @override
  double get minExtent => 40.0;

  @override
  double get maxExtent => 40.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), 
        child: Padding(
          padding: const EdgeInsets.only(top: 1.0), 
          child: SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: categoryNames.length,
              itemBuilder: (context, index) {
                final category = categoryNames[index];
                final isSelected = index == selectedIndex;
                return GestureDetector(
                  onTap: () => onCategorySelected(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                    margin: EdgeInsets.only(left: index == 0 ? 16.0 : 8.0, right: index == categoryNames.length - 1 ? 16.0 : 8.0),
                    decoration: BoxDecoration(
                      color: isSelected ? Color(0xFFBE7DBC) : Color.fromARGB(157, 235, 230, 242).withOpacity(0.80),
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Center(
                      child: Text(
                        category['name'] ?? 'Категория',
                        style: TextStyle(
                          fontFamily: 'Comfortaa',
                          color: isSelected ? Colors.white : Color(0xFFBE7DBC).withOpacity(0.9),
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_CategoryHeaderDelegate oldDelegate) {
    return categoryNames != oldDelegate.categoryNames ||
           selectedIndex != oldDelegate.selectedIndex;
  }
}

class _UserInfoHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _UserInfoHeaderDelegate({required this.child});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  double get maxExtent => 153.0; 

  @override
  double get minExtent => 153.0; 

  @override
  bool shouldRebuild(_UserInfoHeaderDelegate oldDelegate) {
    return child != oldDelegate.child;
  }
}



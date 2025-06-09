import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'shared/bottom_nav.dart';
import 'home_screen.dart';
import 'calendar_screen.dart';
import 'profile_screen.dart';
import 'information_article_detail_screen.dart'; // Import InformationArticleDetailScreen
import 'dart:ui'; // Import for ImageFilter
import 'filter_modal.dart'; // Add this import at the top

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  _FavoritesScreenState createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> with AutomaticKeepAliveClientMixin {
  // State variables
  String _userName = ''; // User name for header
  String _userEmail = ''; // User email for header
  // Removed: List<Map<String, dynamic>> _relevantItems = []; // Data for stories
  List<Map<String, dynamic>> _categoryNames = []; // Data for categories
  int _selectedCategoryIndex = 0; // Selected category index
  List<Map<String, dynamic>> _categoryItems = []; // Data for vertical grid
  bool _isLoadingItems = false; // Loading state for vertical grid items
  List<Map<String, dynamic>> _filteredItems = []; // Filtered data for vertical grid
  final int _currentIndex = 1; // Current navigation index - set to 1 for Favorites
  List<String> _selectedSymptomIds = []; // Changed from List<int> to List<String>
  bool _isFiltered = false;
  final SupabaseClient supabase = Supabase.instance.client;
  Set<String> _favoritedArticleIds = {}; 

  // Controllers for search (will be implemented later)
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController(); // For CustomScrollView

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadUserData(); // Load user data for header
    // Removed: _loadRelevantItems(); // Load data for stories
    _loadCategories(); // Load category names
    _searchController.addListener(_performSearch); // Add listener to search controller
    // _loadCategoryItems(_categoryNames[_selectedCategoryIndex]['id']); // Load items for initial category (will call after categories load)
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_categoryNames.isNotEmpty) {
      _loadCategoryItems(_categoryNames[_selectedCategoryIndex]['id']);
    }
  }

  // Dispose controllers
  @override
  void dispose() {
    _searchController.dispose(); // Dispose search controller
    _scrollController.dispose();
    super.dispose();
  }

  // --- Data Loading Methods ---
  Future<void> _loadUserData() async {
    if (!mounted) return;
    
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final response = await supabase
            .from('user')
            .select('name, email')
            .eq('id', user.id)
            .single();

        if (!mounted) return;
        
        setState(() {
          _userName = response['name'] ?? '';
          _userEmail = response['email'] ?? '';
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  // Removed: Future<void> _loadRelevantItems() async { ... }

  Future<void> _loadCategories() async {
    if (!mounted) return;
    
    try {
      final response = await supabase
          .from('category')
          .select('id, name');

      if (!mounted) return;
      
      setState(() {
        _categoryNames = List<Map<String, dynamic>>.from(response);
        if (_categoryNames.isNotEmpty) {
          _loadCategoryItems(_categoryNames[_selectedCategoryIndex]['id']);
        }
      });
    } catch (e) {
      print('Error loading category names: $e');
    }
  }

   Future<void> _loadCategoryItems(String categoryId) async {
    if (!mounted) return;
    
    print('Loading items for categoryId: $categoryId');
    setState(() {
      _isLoadingItems = true;
      _categoryItems = [];
      _filteredItems = [];
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        print('User not logged in. Cannot load favorites.');
        if (!mounted) return;
        setState(() {
          _isLoadingItems = false;
        });
        return;
      }

      final response = await supabase
          .from('favourites')
          .select('information_article!inner(id, header, image, text_of_article, article_category!inner(category!inner(name)))')
          .eq('user_id', user.id)
          .eq('information_article.article_category.category_id', categoryId);

      if (!mounted) return;
      
      final List<Map<String, dynamic>> fetchedItems = List<Map<String, dynamic>>.from(response);
      final List<Map<String, dynamic>> articles = fetchedItems
          .map((item) => {
                ...?item['information_article'] as Map<String, dynamic>,
                'category_name': (item['information_article']['article_category'] as List<dynamic>).isNotEmpty 
                    ? (item['information_article']['article_category'] as List<dynamic>).first['category']['name'] as String 
                    : 'Без категории',
              })
          .toList();

      setState(() {
        _categoryItems = articles;
        _filteredItems = articles;
        _isLoadingItems = false;
      });
    } catch (e) {
      print('Error loading category articles: $e');
      if (!mounted) return;
      setState(() {
        _categoryItems = [];
        _filteredItems = [];
        _isLoadingItems = false;
      });
    }
  }

  // Method to perform search filtering
  void _performSearch() {
    if (!mounted) return;
    
    final query = _searchController.text.toLowerCase();
    print('Search query: $query');
    setState(() {
      if (query.isEmpty) {
        _filteredItems = _categoryItems;
        print('Filtered items (empty query): ${_filteredItems.length}');
      } else {
        _filteredItems = _categoryItems.where((item) {
          final header = item['header']?.toLowerCase() ?? '';
          print('Checking item header: $header against query: $query');
          final containsQuery = header.contains(query);
          print('Contains query: $containsQuery');
          return containsQuery;
        }).toList();
        print('Filtered items (with query): ${_filteredItems.length}');
      }
    });
  }
  void _onNavigationTap(int index) {
    if (index == _currentIndex) return;

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
        // Already on favorites
        break;
      case 2: // CalendarScreen
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

  Future<void> _removeFavorite(String articleId) async {
    final user = supabase.auth.currentUser; // Get current user
    if (user == null) {
      print('User not logged in. Cannot remove favorite.');
      // Optionally show a message to the user
      return; // Exit if user is not logged in
    }

    try {
      await supabase
          .from('favourites')
          .delete()
          .eq('user_id', user.id)
          .eq('information_article_id', articleId);

      if (mounted) {
        setState(() {
          // Remove the article from the local lists
          _categoryItems.removeWhere((item) => item['id'] == articleId);
          _filteredItems.removeWhere((item) => item['id'] == articleId);
        });
      }
      print('Removed article $articleId from favorites.');
    } catch (e) {
      print('Error removing favorite for article $articleId: $e');
      // Optionally show an error message to the user
    }
  }

  Future<void> _loadFilteredItems(List<String> symptomIds) async {
    if (!mounted) return;
    
    try {
      setState(() {
        _isLoadingItems = true;
      });

      if (symptomIds.isEmpty) {
        await _loadFavorites();
        return;
      }

      final response = await supabase
          .from('favourites')
          .select('''
            *,
            information_article!inner (
              id,
              header,
              image,
              text_of_article,
              symptom_id,
              article_category!inner (
                category!inner (
                  id,
                  name
                )
              )
            )
          ''')
          .eq('user_id', supabase.auth.currentUser!.id)
          .filter('information_article.symptom_id', 'in', symptomIds);

      if (!mounted) return;
      
      // Преобразуем данные в нужный формат
      final List<Map<String, dynamic>> articles = response
          .map((item) {
            final article = item['information_article'] as Map<String, dynamic>;
            return {
              'id': article['id'],
              'header': article['header'],
              'image': article['image'],
              'text_of_article': article['text_of_article'],
              'category_name': (article['article_category'] as List<dynamic>).isNotEmpty 
                  ? (article['article_category'] as List<dynamic>).first['category']['name'] as String 
                  : 'Без категории',
            };
          })
          .toList();

      setState(() {
        _filteredItems = articles;
        _isFiltered = true;
        _isLoadingItems = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoadingItems = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при загрузке избранного: $e')),
      );
    }
  }

  Future<void> _loadFavorites() async {
    if (!mounted) return;
    
    try {
      setState(() {
        _isLoadingItems = true;
      });

      final response = await supabase
          .from('favourites')
          .select('''
            *,
            information_article!inner (
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
            )
          ''')
          .eq('user_id', supabase.auth.currentUser!.id);

      if (!mounted) return;
      
      // Преобразуем данные в нужный формат
      final List<Map<String, dynamic>> articles = response
          .map((item) {
            final article = item['information_article'] as Map<String, dynamic>;
            return {
              'id': article['id'],
              'header': article['header'],
              'image': article['image'],
              'text_of_article': article['text_of_article'],
              'category_name': (article['article_category'] as List<dynamic>).isNotEmpty 
                  ? (article['article_category'] as List<dynamic>).first['category']['name'] as String 
                  : 'Без категории',
            };
          })
          .toList();

      setState(() {
        _filteredItems = articles;
        _isFiltered = true;
        _isLoadingItems = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoadingItems = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при загрузке избранного: $e')),
      );
    }
  }

  // --- UI Build Method ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No AppBar in this mockup
      body: Container(
        decoration: BoxDecoration(
           gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromARGB(157, 235, 230, 242), // Lighter purple from registration
              Color.fromARGB(255, 252, 225, 219).withOpacity(0.7), // Peach from registration, now slightly transparent
            ],
            stops: [0.0, 1.0],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Combined Top Section: User Info, Search, Filter, Divider, Categories
              SliverPersistentHeader(
                pinned: true,
                delegate: _CombinedHeaderDelegate(
                  userName: _userName,
                  userEmail: _userEmail,
                  searchController: _searchController,
                  categoryNames: _categoryNames,
                  selectedCategoryIndex: _selectedCategoryIndex,
                  onSearchChanged: (query) => _performSearch(),
                  onCategorySelected: (index) {
                    setState(() {
                      _selectedCategoryIndex = index;
                    });
                    _loadCategoryItems(_categoryNames[index]['id']);
                  },
                  onFilterPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => FilterModal(
                        onFiltersApplied: (symptomIds) {
                          setState(() {
                            _selectedSymptomIds = symptomIds; // No need to convert to int
                          });
                          _loadFilteredItems(_selectedSymptomIds);
                        },
                      ),
                    );
                  },
                ),
              ),

              // Space between Header and Grid
              // Removed SizedBox as spacing is now handled within the combined header or by SliverPadding

              // Vertical Grid (Category Items)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0), // Padding for the grid
                sliver: _isLoadingItems
                    ? SliverFillRemaining( // Use SliverFillRemaining for centered loader/message
                        hasScrollBody: false,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _filteredItems.isEmpty
                        ? SliverFillRemaining(
                            hasScrollBody: false,
                            child: Align(
                               alignment: Alignment.topCenter, // Align to top center
                               child: Padding(
                                 padding: const EdgeInsets.only(top: 24.0), // Add some space from the top
                                 child: Text(
                                     'Нет избранных элементов для этой категории',
                                     textAlign: TextAlign.center, // Ensure text is centered horizontally within its bounds
                                     style: TextStyle(
                                       fontFamily: 'Comfortaa',
                                       fontSize: 16,
                                       fontWeight: FontWeight.w700,
                                       color: Color.fromARGB(255, 54, 6, 56).withOpacity(0.8),
                                     ),
                                 ),
                               ),
                             ),
                          )
                        : SliverGrid.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2, // 2 items per row
                              crossAxisSpacing: 16.0, // Horizontal spacing
                              mainAxisSpacing: 16.0, // Vertical spacing
                              childAspectRatio: 0.7, // Aspect ratio of grid items
                            ),
                            itemCount: _filteredItems.length,
                            itemBuilder: (context, index) {
                               final categoryItem = _filteredItems[index]; // Use item from filtered list
                               final imageUrl = categoryItem != null ? categoryItem['image'] : null;

                               return GestureDetector(
                                 
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => InformationArticleDetailScreen(
                                          article: categoryItem,
                                          onFavoriteChanged: (articleId, isFavorite) {
                                            if (!isFavorite) {
                                              // Удаляем из избранного списка
                                              setState(() {
                                                _categoryItems.removeWhere((item) => item['id'] == articleId);
                                                _filteredItems.removeWhere((item) => item['id'] == articleId);
                                                _favoritedArticleIds.remove(articleId);
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                 child: Container(
                                   decoration: BoxDecoration(
                                     color: Colors.white, // Changed background to white
                                     borderRadius: BorderRadius.circular(12.0),
                                     boxShadow: [
                                       BoxShadow(
                                         color: Colors.grey.withOpacity(0.2),
                                         spreadRadius: 2,
                                         blurRadius: 4,
                                         offset: const Offset(0, 2), // changes position of shadow
                                       ),
                                     ],
                                   ),
                                    child: Stack( // Use Stack for content and "Add to favorites" icon/text
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Conditional content: Image or Header + Text
                                              if (imageUrl != null && (imageUrl as String).isNotEmpty)
                                                // Content with Image (Image + Header)
                                                Column( // Wrap image and header in a Column
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    // Item Image Area
                                                    SizedBox( // Use SizedBox for fixed height
                                                      height: 150.0, // Fixed height for the image area
                                                      child: ClipRRect(
                                                        borderRadius: BorderRadius.circular(8.0),
                                                        child: Image.network(
                                                          imageUrl,
                                                          fit: BoxFit.cover,
                                                          errorBuilder: (context, error, stackTrace) {
                                                            print('Error loading article image: $imageUrl - $error');
                                                            return Center(child: Icon(Icons.broken_image));
                                                          },
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2), // Space between image and header
                                                    // Article Header below the image
                                                    Text(
                                                       categoryItem != null ? categoryItem['header'] ?? 'Заголовок статьи' : 'Заголовок статьи',
                                                       style: TextStyle(
                                                         fontFamily: 'Comfortaa',
                                                         fontSize: 14,
                                                         fontWeight: FontWeight.w700,
                                                         color: Color.fromARGB(255, 54, 6, 56),
                                                       ),
                                                       maxLines: 2,
                                                       overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                )
                                              else
                                                // Header and Text (if no image)
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                     Text(
                                                        categoryItem != null ? categoryItem['header'] ?? 'Заголовок статьи' : 'Заголовок статьи',
                                                        style: TextStyle(
                                                          fontFamily: 'Comfortaa',
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.w700,
                                                          color: Color.fromARGB(255, 54, 6, 56),
                                                        ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                     ),
                                                     const SizedBox(height: 4), // Space between header and text
                                                     Text(
                                                        categoryItem != null ? categoryItem['text_of_article'] ?? 'Текст статьи...\nПродолжение статьи...' : 'Текст статьи...\nПродолжение статьи...',
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
                                              // Placeholder lines (removed)
                                            ],
                                          ),
                                        ),
                                         // Heart icon in the top right corner (FILLED)
                                         Positioned(
                                            top: 8,
                                            right: 8,
                                            child: GestureDetector(
                                              onTap: () => _removeFavorite(categoryItem['id'] as String), // Call remove favorite method
                                              child: Container(
                                                padding: EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                   color: Color(0xFFF2E4E1).withOpacity(0.8),
                                                   borderRadius: BorderRadius.circular(8),
                                                ),
                                                 child: Icon(
                                                    Icons.favorite, // Filled heart icon
                                                    size: 18,
                                                    color: Color(0xFFBE7DBC), // Match category header color
                                                 ),
                                              ),
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
        ),
      ),
     
    bottomNavigationBar: BottomNav(
        currentIndex: _currentIndex,
        onTap: _onNavigationTap,
      ),
    );
  }
}

// Delegates for SliverPersistentHeader (copied from home_screen.dart)

class _CombinedHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _CombinedHeaderDelegate({
    required this.userName,
    required this.userEmail,
    required this.searchController,
    required this.categoryNames,
    required this.selectedCategoryIndex,
    required this.onSearchChanged,
    required this.onCategorySelected,
    required this.onFilterPressed,
  });

  final String userName;
  final String userEmail;
  final TextEditingController searchController;
  final List<Map<String, dynamic>> categoryNames;
  final int selectedCategoryIndex;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int> onCategorySelected;
  final VoidCallback onFilterPressed;

  @override
  double get minExtent => 218.0; // Approximate collapsed height (User Info + Search + Divider + Category List)

  @override
  double get maxExtent => 218.0; // Approximate expanded height (same as min for now)

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    // Apply blur and opacity based on scroll offset for the top header
    // final double opacity = (1.0 - shrinkOffset / maxExtent).clamp(0.0, 1.0); // Opacity effect - disabled for now for simplicity

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromARGB(157, 235, 230, 242), // Lighter purple from registration
              Color.fromARGB(255, 252, 225, 219).withOpacity(0.7), // Peach from registration, now slightly transparent
            ],
            stops: [0.0, 1.0],
          ),
        color: Color.fromARGB(117, 235, 230, 242).withOpacity(0.9), // Semi-transparent background when sticky
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // Apply blur effect
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 7.0, 16.0, 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Name and Email
                 SizedBox(height: 8.0), // Added space below AppBar area
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0), // Adjusted padding
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User Name
                      Text(
                        userName.isNotEmpty ? userName : 'Загрузка...',
                        style: const TextStyle(
                          fontSize: 18,
                          fontFamily: 'Comfortaa',
                          fontWeight: FontWeight.w900,
                          color: Color.fromARGB(255, 54, 6, 56),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // User Email
                      Text(
                        userEmail.isNotEmpty ? userEmail : 'Загрузка...',
                        style: const TextStyle(
                          fontSize: 14,
                          fontFamily: 'Comfortaa',
                          fontWeight: FontWeight.w400,
                          color: Color.fromARGB(255, 54, 6, 56),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16), // Space below user info

                // Search Bar and Filter Button
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
                          controller: searchController,
                          decoration: InputDecoration(
                            hintText: 'Поиск...',
                            border: InputBorder.none,
                            prefixIcon: Icon(Icons.search, color: Color.fromARGB(255, 54, 6, 56)),
                            contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                          ),
                          style: TextStyle(fontFamily: 'Comfortaa', fontSize: 15, color: Color.fromARGB(255, 54, 6, 56)),
                          onChanged: onSearchChanged, // Use the callback
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
                        onPressed: onFilterPressed,
                      ),
                    ),
                  ],
                ),
                 const SizedBox(height: 16.0), // Space below search/filter

                // Divider Line
                 Container(
                  height: 1.0,
                  color: const Color.fromARGB(157, 119, 59, 125).withOpacity(0.3), // Darker line
                 ),
                 const SizedBox(height: 16.0), // Space below divider

                // Categories Horizontal List
                 SizedBox(
                   height: 40.0, // Height for category list
                   child: ListView.builder(
                     scrollDirection: Axis.horizontal,
                     itemCount: categoryNames.length,
                     itemBuilder: (context, index) {
                       final category = categoryNames[index];
                       final isSelected = index == selectedCategoryIndex;
                       return GestureDetector(
                         onTap: () => onCategorySelected(index), // Use the callback
                         child: Container(
                           padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                           margin: EdgeInsets.only(left: index == 0 ? 16.0 : 8.0, right: index == categoryNames.length - 1 ? 16.0 : 8.0),
                           decoration: BoxDecoration(
                             color: isSelected ? Color(0xFFBE7DBC) : Color.fromARGB(157, 235, 230, 242).withOpacity(0.80),
                             borderRadius: BorderRadius.circular(12.0),
                           ),
                           child: Center( // Added Center to match home_screen.dart structure
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_CombinedHeaderDelegate oldDelegate) {
    return userName != oldDelegate.userName ||
           userEmail != oldDelegate.userEmail ||
           searchController != oldDelegate.searchController ||
           categoryNames != oldDelegate.categoryNames ||
           selectedCategoryIndex != oldDelegate.selectedCategoryIndex ||
           onFilterPressed != oldDelegate.onFilterPressed;
  }
} 
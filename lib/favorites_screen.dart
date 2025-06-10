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
  String _userName = ''; 
  String _userEmail = ''; 
  List<Map<String, dynamic>> _categoryNames = []; 
  int _selectedCategoryIndex = 0; 
  List<Map<String, dynamic>> _categoryItems = []; 
  bool _isLoadingItems = false; 
  List<Map<String, dynamic>> _filteredItems = []; 
  final int _currentIndex = 1; 
  List<String> _selectedSymptomIds = []; 
  bool _isFiltered = false;
  final SupabaseClient supabase = Supabase.instance.client;
  Set<String> _favoritedArticleIds = {}; 

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadUserData(); 
    _loadCategories(); 
    _searchController.addListener(_performSearch);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_categoryNames.isNotEmpty) {
      _loadCategoryItems(_categoryNames[_selectedCategoryIndex]['id']);
    }
  }

  @override
  void dispose() {
    _searchController.dispose(); 
    _scrollController.dispose();
    super.dispose();
  }

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
      case 0:
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
      case 1:
        break;
      case 2: 
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

  Future<void> _removeFavorite(String articleId) async {
    final user = supabase.auth.currentUser; 
    if (user == null) {
      print('User not logged in. Cannot remove favorite.');
      return; 
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
           gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromARGB(157, 235, 230, 242), 
              Color.fromARGB(255, 252, 225, 219).withOpacity(0.7), 
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
                            _selectedSymptomIds = symptomIds; 
                          });
                          _loadFilteredItems(_selectedSymptomIds);
                        },
                      ),
                    );
                  },
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0), 
                sliver: _isLoadingItems
                    ? SliverFillRemaining( 
                        hasScrollBody: false,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _filteredItems.isEmpty
                        ? SliverFillRemaining(
                            hasScrollBody: false,
                            child: Align(
                               alignment: Alignment.topCenter, 
                               child: Padding(
                                 padding: const EdgeInsets.only(top: 24.0), 
                                 child: Text(
                                     'Нет избранных элементов для этой категории',
                                     textAlign: TextAlign.center, 
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
                              crossAxisCount: 2, 
                              crossAxisSpacing: 16.0, 
                              mainAxisSpacing: 16.0, 
                              childAspectRatio: 0.7, 
                            ),
                            itemCount: _filteredItems.length,
                            itemBuilder: (context, index) {
                               final categoryItem = _filteredItems[index]; 
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
                                     color: Colors.white, 
                                     borderRadius: BorderRadius.circular(12.0),
                                     boxShadow: [
                                       BoxShadow(
                                         color: Colors.grey.withOpacity(0.2),
                                         spreadRadius: 2,
                                         blurRadius: 4,
                                         offset: const Offset(0, 2), 
                                       ),
                                     ],
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
                                                            print('Error loading article image: $imageUrl - $error');
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
                                                         color: Color.fromARGB(255, 54, 6, 56),
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
                                                          color: Color.fromARGB(255, 54, 6, 56),
                                                        ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                     ),
                                                     const SizedBox(height: 4),
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
                                            ],
                                          ),
                                        ),
                                         Positioned(
                                            top: 8,
                                            right: 8,
                                            child: GestureDetector(
                                              onTap: () => _removeFavorite(categoryItem['id'] as String), 
                                              child: Container(
                                                padding: EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                   color: Color(0xFFF2E4E1).withOpacity(0.8),
                                                   borderRadius: BorderRadius.circular(8),
                                                ),
                                                 child: Icon(
                                                    Icons.favorite,
                                                    size: 18,
                                                    color: Color(0xFFBE7DBC), 
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
  double get minExtent => 218.0; 

  @override
  double get maxExtent => 218.0; 

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromARGB(157, 235, 230, 242), 
              Color.fromARGB(255, 252, 225, 219).withOpacity(0.7), 
            ],
            stops: [0.0, 1.0],
          ),
        color: Color.fromARGB(117, 235, 230, 242).withOpacity(0.9), 
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), 
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 7.0, 16.0, 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 SizedBox(height: 8.0), 
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0), 
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                          controller: searchController,
                          decoration: InputDecoration(
                            hintText: 'Поиск...',
                            border: InputBorder.none,
                            prefixIcon: Icon(Icons.search, color: Color.fromARGB(255, 54, 6, 56)),
                            contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                          ),
                          style: TextStyle(fontFamily: 'Comfortaa', fontSize: 15, color: Color.fromARGB(255, 54, 6, 56)),
                          onChanged: onSearchChanged, 
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
                 const SizedBox(height: 16.0), 
                 Container(
                  height: 1.0,
                  color: const Color.fromARGB(157, 119, 59, 125).withOpacity(0.3), 
                 ),
                 const SizedBox(height: 16.0), 
                 SizedBox(
                   height: 40.0, 
                   child: ListView.builder(
                     scrollDirection: Axis.horizontal,
                     itemCount: categoryNames.length,
                     itemBuilder: (context, index) {
                       final category = categoryNames[index];
                       final isSelected = index == selectedCategoryIndex;
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
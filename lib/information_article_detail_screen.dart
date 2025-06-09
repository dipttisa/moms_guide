import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'shared/custom_snackbar.dart';

class InformationArticleDetailScreen extends StatefulWidget {
  final Map<String, dynamic> article;
   final Function(String articleId, bool isFavorite)? onFavoriteChanged;
  const InformationArticleDetailScreen({
    Key? key,
    required this.article,
    this.onFavoriteChanged,
  }) : super(key: key);

  @override
  State<InformationArticleDetailScreen> createState() => _InformationArticleDetailScreenState();
}

class _InformationArticleDetailScreenState extends State<InformationArticleDetailScreen> {
  List<String> _categories = [];
  bool _isLoadingCategories = true;
  late bool _initialFavoriteStatus;
  bool _isFavorite = false;

  List<Map<String, dynamic>> _comments = [];
  bool _isLoadingComments = true;
  bool _isSendingComment = false;
  final TextEditingController _commentController = TextEditingController();
  String? _editingCommentId;
  final SupabaseClient supabase = Supabase.instance.client;



@override
void initState() {
  super.initState();
  _checkFavoriteStatus();
  _loadArticleCategories();
  _loadArticleComments();
}

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadArticleCategories() async {
    try {
      final articleId = widget.article['id'] as String;
      if (articleId == null) {
        print('Article ID is null, cannot load categories.');
        if (mounted) {
          setState(() {
            _isLoadingCategories = false;
          });
        }
        return;
      }

      final response = await supabase
          .from('article_category')
          .select('category!inner(name)')
          .eq('article_id', articleId);

      if (mounted) {
        setState(() {
          _categories = (response as List<dynamic>)
              .map((item) => item['category']['name'] as String)
              .toList();
          _isLoadingCategories = false;
          print('Loaded categories for article $articleId: $_categories');
        });
      }
    } catch (e) {
      print('Error loading categories: $e');
      if (mounted) {
        setState(() {
          _categories = [];
          _isLoadingCategories = false;
        });
      }
    }
  }

  Future<void> _loadArticleComments() async {
    if (mounted) {
      setState(() {
        _isLoadingComments = true;
      });
    }
    try {
      final articleId = widget.article['id'] as String;
      if (articleId == null) {
        print('Article ID is null, cannot load comments.');
        if (mounted) {
          setState(() {
            _isLoadingComments = false;
          });
        }
        return;
      }

      final response = await supabase
          .from('comments')
          .select('id, comment_content, user:user_id(name)')
          .eq('information_article_id', articleId)
          .order('date_of_creation', ascending: true);

      if (mounted) {
        setState(() {
          _comments = List<Map<String, dynamic>>.from(response);
          _isLoadingComments = false;
          print('Loaded ${_comments.length} comments for article $articleId.');
        });
      }
    } catch (e) {
      print('Error loading comments: $e');
      if (mounted) {
        setState(() {
          _comments = [];
          _isLoadingComments = false;
        });
      }
    }
  }

   Future<void> _checkFavoriteStatus() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final response = await supabase
          .from('favourites')
          .select()
          .eq('user_id', user.id)
          .eq('information_article_id', widget.article['id'])
          .maybeSingle();

      if (mounted) {
        setState(() {
          _isFavorite = response != null;
          _initialFavoriteStatus = _isFavorite;
        });
      }
    } catch (e) {
      print('Error checking favorite status: $e');
    }
  }


Future<void> _toggleFavorite() async {
  final user = supabase.auth.currentUser;
  if (user == null) {
    showCustomSnackbar(context, 'Войдите в аккаунт, чтобы добавить в избранное', success: false);
    return;
  }

  final newFavoriteState = !_isFavorite;

  try {
    if (newFavoriteState) {
      await supabase.from('favourites').insert({
        'user_id': user.id,
        'information_article_id': widget.article['id'],
      });
      showCustomSnackbar(context, 'Добавлено в избранное');
    } else {
      await supabase
          .from('favourites')
          .delete()
          .eq('user_id', user.id)
          .eq('information_article_id', widget.article['id']);
      showCustomSnackbar(context, 'Удалено из избранного');
    }

    if (mounted) {
      setState(() {
        _isFavorite = newFavoriteState;
      });

      // Обновляем родителя
      widget.onFavoriteChanged?.call(widget.article['id'], newFavoriteState);
    }
  } catch (e) {
    print('Ошибка при обновлении избранного: $e');
    showCustomSnackbar(context, 'Произошла ошибка', success: false);
  }
}

  Future<void> _sendComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() {
      _isSendingComment = true;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        print('Пользователь не авторизован');
        return;
      }

      final articleId = widget.article['id'] as String;
      
      if (_editingCommentId != null) {
        // Редактирование существующего комментария
        await supabase
            .from('comments')
            .update({
              'comment_content': _commentController.text.trim(),
            })
            .eq('id', _editingCommentId.toString())
            .eq('user_id', user.id.toString());
      } else {
        // Создание нового комментария
        final now = DateTime.now();
        final timeString = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
        
        await supabase.from('comments').insert({
          'user_id': user.id,
          'information_article_id': articleId,
          'comment_content': _commentController.text.trim(),
          'date_of_creation': timeString,
        });
      }

      _commentController.clear();
      _editingCommentId = null;
      await _loadArticleComments();
    } catch (e) {
      print('Ошибка при отправке комментария: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSendingComment = false;
        });
      }
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      await supabase
          .from('comments')
          .delete()
          .eq('id', commentId)
          .eq('user_id', user.id.toString()); // Преобразуем UUID в строку

      await _loadArticleComments();
    } catch (e) {
      print('Ошибка при удалении комментария: $e');
    }
  }

  void _startEditingComment(Map<String, dynamic> comment) {
    setState(() {
      _editingCommentId = comment['id'];
      _commentController.text = comment['comment_content'];
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingCommentId = null;
      _commentController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.article['image'] as String?;
    final header = widget.article['header'] ?? 'Название статьи';
    final categoryText = _isLoadingCategories
        ? 'Загрузка...'
        : (_categories.isEmpty ? 'Без категории' : _categories.join(', '));
    final text = widget.article['text_of_article'] ?? '';
    final time = widget.article['time'] ?? '2-7';
     return WillPopScope(
  onWillPop: () async {
    if (_initialFavoriteStatus != _isFavorite) {
      Navigator.pop(context, {
        'articleId': widget.article['id'],
        'isFavorite': _isFavorite,
      });
      return true;  // позволяем системе выполнить pop
    } else {
      Navigator.pop(context);
      return true;
    }
  },
      child: Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            Positioned.fill(
              child: Container(
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
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (imageUrl != null && imageUrl.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 48, 16, 0),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      width: double.infinity,
                                      height: 420,
                                      child: Image.network(
                                        imageUrl,
                                        width: double.infinity,
                                        height: 420,
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) => Center(child: Icon(Icons.broken_image, color: Color(0xFFBE7DBC))),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 12,
                                    left: 12,
                                    child: Material(
                                      color: Color(0xFFF2E4E1).withOpacity(0.8),
                                      shape: const CircleBorder(),
                                      elevation: 0,
                                      child: InkWell(
                                        customBorder: const CircleBorder(),
                                        onTap: () {
                                          if (_initialFavoriteStatus != _isFavorite) {
                                            Navigator.pop(context, {
                                              'articleId': widget.article['id'],
                                              'isFavorite': _isFavorite,
                                            });
                                          } else {
                                            Navigator.pop(context);
                                          }
                                        },                                        
                                        child: const Padding(
                                          padding: EdgeInsets.all(10),
                                          child: Icon(Icons.arrow_back, color: Color(0xFFBE7DBC), size: 24),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 12,
                                    right: 12,
                                    child: Material(
                                      color: Color(0xFFF2E4E1).withOpacity(0.8),
                                      shape: const CircleBorder(),
                                      elevation: 0,
                                      child: InkWell(
                                        customBorder: const CircleBorder(),
                                        onTap: _toggleFavorite,
                                        child: Padding(
                                          padding: const EdgeInsets.all(10),
                                          child: AnimatedSwitcher(
                                            duration: Duration(milliseconds: 300),
                                            child: Icon(
                                              _isFavorite ? Icons.favorite : Icons.favorite_border,
                                              key: ValueKey<bool>(_isFavorite),
                                              color: Color(0xFFBE7DBC),
                                              size: 24,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 10,
                                    right: 10,
                                    bottom: 10,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black12,
                                            blurRadius: 6,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            header,
                                            style: const TextStyle(
                                              fontFamily: 'Comfortaa',
                                              fontWeight: FontWeight.w700,
                                              fontSize: 18,
                                              color: Color(0xFF92698C),
                                            ),
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            categoryText,
                                            style: const TextStyle(
                                              fontFamily: 'Comfortaa',
                                              fontWeight: FontWeight.w400,
                                              fontSize: 14,
                                              color: Color(0xFFBE7DBC),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(32, 15, 32, 0),
                              child: Row(
                                children: [
                                  Icon(Icons.timer, color: Color(0xFFBE7DBC), size: 20),
                                  const SizedBox(width: 4),
                                  Text('$time минут', style: const TextStyle(color: Color(0xFFBE7DBC), fontSize: 14, fontFamily: 'Comfortaa')),
                                  const SizedBox(width: 16),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(32, 16, 32, 0),
                              child: Text(
                                text,
                                style: const TextStyle(
                                  fontFamily: 'Comfortaa',
                                  fontSize: 15,
                                  color: Color(0xFF92698C),
                                ),
                              ),
                            ),
                          ] else ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 48, 16, 0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Material(
                                  color: Color(0xFFF2E4E1).withOpacity(0.8),
                                    shape: const CircleBorder(),
                                    elevation: 0,
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: () => Navigator.pop(context),
                                      child: const Padding(
                                        padding: EdgeInsets.all(10),
                                        child: Icon(Icons.arrow_back, color: Color(0xFFBE7DBC), size: 24),
                                      ),
                                    ),
                                  ),
                                  Material(
                                    color: Color(0xFFF2E4E1).withOpacity(0.8),
                                    shape: const CircleBorder(),
                                    elevation: 0,
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: _toggleFavorite,
                                      child: Padding(
                                        padding: const EdgeInsets.all(10),
                                        child: AnimatedSwitcher(
                                          duration: Duration(milliseconds: 300),
                                          child: Icon(
                                            _isFavorite ? Icons.favorite : Icons.favorite_border,
                                            key: ValueKey<bool>(_isFavorite),
                                            color: Color(0xFFBE7DBC),
                                            size: 24,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: Color.fromARGB(255, 250, 247, 246).withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      header,
                                      style: const TextStyle(
                                        fontFamily: 'Comfortaa',
                                        fontWeight: FontWeight.w700,
                                        fontSize: 18,
                                        color: Color(0xFF92698C),
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      categoryText,
                                      style: const TextStyle(
                                        fontFamily: 'Comfortaa',
                                        fontWeight: FontWeight.w400,
                                        fontSize: 14,
                                        color: Color(0xFFBE7DBC),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(32, 10, 32, 0),
                              child: Row(
                                children: [
                                  Icon(Icons.timer, color: Color(0xFFBE7DBC), size: 20),
                                  const SizedBox(width: 4),
                                  Text('$time минут', style: const TextStyle(color: Color(0xFFBE7DBC), fontSize: 14, fontFamily: 'Comfortaa')),
                                  const SizedBox(width: 16),
                                  
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(32, 16, 32, 0),
                              child: Text(
                                text,
                                style: const TextStyle(
                                  fontFamily: 'Comfortaa',
                                  fontSize: 15,
                                  color: Color(0xFF92698C),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 5),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 26),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Комментарии',
                                    style: TextStyle(
                                      fontFamily: 'Comfortaa',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: Color(0xFFBE7DBC),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Color(0xFFBE7DBC).withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _commentController,
                                            decoration: InputDecoration(
                                              hintText: _editingCommentId != null 
                                                  ? 'Редактировать комментарий...' 
                                                  : 'Оставьте комментарий...',
                                              border: InputBorder.none,
                                              hintStyle: TextStyle(
                                                color: Color(0xFFBE7DBC).withOpacity(0.5),
                                                fontFamily: 'Comfortaa',
                                                fontSize: 14,
                                              ),
                                            ),
                                            style: TextStyle(
                                              color: Color(0xFF92698C),
                                              fontFamily: 'Comfortaa',
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        if (_editingCommentId != null)
                                          IconButton(
                                            icon: Icon(Icons.close, color: Color(0xFFBE7DBC)),
                                            onPressed: _cancelEditing,
                                          ),
                                        IconButton(
                                          icon: _isSendingComment 
                                            ? SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFBE7DBC)),
                                                ),
                                              )
                                            : Icon(Icons.send, color: Color(0xFFBE7DBC)),
                                          onPressed: _isSendingComment ? null : _sendComment,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _isLoadingComments
                                      ? Center(child: CircularProgressIndicator())
                                      : _comments.isEmpty
                                          ? Center(
                                              child: Text(
                                                'Комментариев нет, будьте первым',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontFamily: 'Comfortaa',
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w400,
                                                  color: Color(0xFFBE7DBC).withOpacity(0.8),
                                                ),
                                              ),
                                            )
                                          : SizedBox(
                                              height: 200,
                                              child: ListView.builder(
                                                itemCount: _comments.length,
                                                physics: BouncingScrollPhysics(),
                                                itemBuilder: (context, index) {
                                                  final comment = _comments[index];
                                                  final userName = comment['user']['name'] ?? 'Аноним';
                                                  final commentContent = comment['comment_content'] ?? 'Нет текста';
                                                  final isCurrentUser = comment['user_id'] == supabase.auth.currentUser?.id;

                                                  return Padding(
                                                    padding: const EdgeInsets.only(bottom: 10),
                                                    child: Row(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        CircleAvatar(
                                                          radius: 16,
                                                          backgroundColor: Color(0xFFBE7DBC).withOpacity(0.2),
                                                          child: Text(
                                                            userName.isNotEmpty ? userName[0] : '?',
                                                            style: const TextStyle(
                                                              color: Color(0xFFBE7DBC),
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 10),
                                                        Expanded(
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                            decoration: BoxDecoration(
                                                              color: Color(0xFFE9DDF1),
                                                              borderRadius: BorderRadius.circular(12),
                                                            ),
                                                            child: Column(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                Row(
                                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                  children: [
                                                                    Text(
                                                                      userName,
                                                                      style: const TextStyle(
                                                                        fontWeight: FontWeight.w700,
                                                                        fontSize: 13,
                                                                        color: Color(0xFFBE7DBC),
                                                                      ),
                                                                    ),
                                                                    if (isCurrentUser)
                                                                      Row(
                                                                        children: [
                                                                          IconButton(
                                                                            icon: Icon(Icons.edit, size: 16, color: Color(0xFFBE7DBC)),
                                                                            onPressed: () => _startEditingComment(comment),
                                                                          ),
                                                                          IconButton(
                                                                            icon: Icon(Icons.delete, size: 16, color: Color(0xFFBE7DBC)),
                                                                            onPressed: () => _deleteComment(comment['id']),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                  ],
                                                                ),
                                                                const SizedBox(height: 2),
                                                                Text(
                                                                  commentContent,
                                                                  style: const TextStyle(
                                                                    fontSize: 14,
                                                                    color: Color(0xFFBE7DBC),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      )
    );
  }
} 
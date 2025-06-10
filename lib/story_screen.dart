import 'package:flutter/material.dart';
import 'dart:async'; // Import for Timer

class StoryScreen extends StatefulWidget {
  final List<Map<String, dynamic>> stories; // Add a field to accept stories

  const StoryScreen({super.key, required this.stories}); // Add stories to the constructor

  @override
  _StoryScreenState createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  int _currentStoryIndex = 0; 
  Timer? _storyTimer; 
  double _progress = 0.0; 
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

  @override
  void initState() {
    super.initState();
    _startStoryTimer(); 
  }

  void _startStoryTimer() {
    _storyTimer?.cancel(); 
    _progress = 0.0; 

    _storyTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        _progress += 0.05 / 10; 
        if (_progress >= 1.0) {
          _storyTimer?.cancel(); 
          _showNextStory(); 
        }
      });
    });
  }

  void _showNextStory() {
    if (_currentStoryIndex < widget.stories.length - 1) { 
      setState(() {
        _currentStoryIndex++;
      });
      _startStoryTimer(); 
    } else {
      Navigator.pop(context);
    }
  }

  void _showPreviousStory() {
    if (_currentStoryIndex > 0) {
      setState(() {
        _currentStoryIndex--;
      });
      _startStoryTimer(); 
    }
  }

  @override
  void dispose() {
    _storyTimer?.cancel(); 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration( 
          color: Colors.black.withOpacity(0.8), 
        ),
        child: SafeArea(
          child: Stack(
            children: [
              GestureDetector(
                onTapDown: (details) {
                  final screenWidth = MediaQuery.of(context).size.width;
                  if (details.globalPosition.dx < screenWidth / 2) {
                    _showPreviousStory();
                  } else {
                    _showNextStory();
                  }
                },
                onVerticalDragEnd: (details) {
                  if ((details.primaryVelocity ?? 0) > 400) { 
                    Navigator.pop(context);
                  }
                },
                child: Center(
                  child: widget.stories[_currentStoryIndex]['image'] != null && (widget.stories[_currentStoryIndex]['image'] as String).isNotEmpty
                      ? Image.network( // Display image if image URL is available
                          widget.stories[_currentStoryIndex]['image']!,
                          fit: BoxFit.contain, // Adjust fit as needed
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center( 
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            print('Error loading image: ${widget.stories[_currentStoryIndex]['image']} - $error');
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              showCustomError(context, 'Не удалось загрузить изображение истории.'); 
                            });
                            return Center(child: Icon(Icons.error));
                          },
                        )
                      : Text( 
                          widget.stories[_currentStoryIndex]['symptom_id']?.toString() ?? widget.stories[_currentStoryIndex]['trimester_id']?.toString() ?? 'Нет данных', 
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontFamily: 'Comfortaa',
                            fontWeight: FontWeight.w900,
                            color: Color.fromARGB(255, 54, 6, 56),
                          ),
                        ),
                ),
              ),
              Positioned(
                top: 10.0,
                left: 10.0,
                right: 10.0,
                child: Row(
                  children: List.generate(widget.stories.length, (index) { 
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5.0), 
                          child: LinearProgressIndicator(
                            value: index == _currentStoryIndex ? _progress : (index < _currentStoryIndex ? 1.0 : 0.0), 
                            backgroundColor: Colors.grey[700]?.withOpacity(0.5), 
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white), 
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              Positioned(
                top: 10.0,
                right: 10.0,
                child: IconButton(
                  icon: Icon(Icons.close, color: Color(0xFFE0CAE6)), 
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 
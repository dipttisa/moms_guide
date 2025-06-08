import 'package:flutter/material.dart';
import 'dart:async'; // Import for Timer

class StoryScreen extends StatefulWidget {
  final List<Map<String, dynamic>> stories; // Add a field to accept stories

  const StoryScreen({super.key, required this.stories}); // Add stories to the constructor

  @override
  _StoryScreenState createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  // Placeholder for list of stories (will be passed to the widget)
  // final List<String> _stories = [
  //   'История 1: Это первая история', // Placeholder content
  //   'История 2: Вторая история здесь', 
  //   'История 3: Третья история', 
  // ]; // Removed placeholder list
  int _currentStoryIndex = 0; // Index of the story currently being displayed
  Timer? _storyTimer; // Timer to switch between stories
  double _progress = 0.0; // Current progress of the story (0.0 to 1.0)

  // Function to show custom styled error messages (copied from registration_screen.dart)
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
    _startStoryTimer(); // Start the timer when the screen initializes
  }

  void _startStoryTimer() {
    _storyTimer?.cancel(); // Cancel any existing timer
    _progress = 0.0; // Reset progress for the new story

    _storyTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        _progress += 0.05 / 10; // Increment progress (0.05 per 50ms for 10 sec story)
        if (_progress >= 1.0) {
          _storyTimer?.cancel(); // Cancel timer for current story
          _showNextStory(); // Move to the next story
        }
      });
    });
  }

  void _showNextStory() {
    if (_currentStoryIndex < widget.stories.length - 1) { // Use widget.stories
      setState(() {
        _currentStoryIndex++;
      });
      _startStoryTimer(); // Start timer for the next story
    } else {
      // If it's the last story, navigate back
      Navigator.pop(context);
    }
  }

  // New method to show the previous story
  void _showPreviousStory() {
    if (_currentStoryIndex > 0) {
      setState(() {
        _currentStoryIndex--;
      });
      _startStoryTimer(); // Start timer for the previous story
    }
  }

  @override
  void dispose() {
    _storyTimer?.cancel(); // Cancel timer when the widget is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration( // Use BoxDecoration for a single color
          color: Colors.black.withOpacity(0.8), // Dark color with 80% opacity
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Story content wrapped in GestureDetector for navigation
              GestureDetector(
                onTapDown: (details) {
                  final screenWidth = MediaQuery.of(context).size.width;
                  // Check if tap is on the left or right half of the screen
                  if (details.globalPosition.dx < screenWidth / 2) {
                    // Tap on left half - show previous story
                    _showPreviousStory();
                  } else {
                    // Tap on right half - show next story
                    _showNextStory();
                  }
                },
                onVerticalDragEnd: (details) {
                  // If dragged downwards quickly, pop the screen
                  if ((details.primaryVelocity ?? 0) > 400) { // Check if vertical velocity is high and downwards
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
                            return Center( // Show a loading indicator while image is loading
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            print('Error loading image: ${widget.stories[_currentStoryIndex]['image']} - $error');
                            // Show custom error message instead of just printing
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              showCustomError(context, 'Не удалось загрузить изображение истории.'); // Russian error message
                            });
                            return Center(child: Icon(Icons.error)); // Show error icon if image fails to load
                          },
                        )
                      : Text( // Show text content if no image
                          widget.stories[_currentStoryIndex]['symptom_id']?.toString() ?? widget.stories[_currentStoryIndex]['trimester_id']?.toString() ?? 'Нет данных', // Use symptom_id or trimester_id as fallback
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

              // Progress indicators at the top
              Positioned(
                top: 10.0,
                left: 10.0,
                right: 10.0,
                child: Row(
                  children: List.generate(widget.stories.length, (index) { // Use widget.stories.length
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.0),
                        child: ClipRRect( // Wrap with ClipRRect for rounded corners
                          borderRadius: BorderRadius.circular(5.0), // Apply border radius
                          child: LinearProgressIndicator(
                            value: index == _currentStoryIndex ? _progress : (index < _currentStoryIndex ? 1.0 : 0.0), // Progress for current, filled for past, empty for future
                            backgroundColor: Colors.grey[700]?.withOpacity(0.5), // Background color of the progress bar
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white), // Color of the progress
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              // Close button (optional - can navigate back)
              Positioned(
                top: 10.0,
                right: 10.0,
                child: IconButton(
                  icon: Icon(Icons.close, color: Color(0xFFE0CAE6)), // Use specified color
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
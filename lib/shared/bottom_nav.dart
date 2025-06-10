import 'package:flutter/material.dart';

class BottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const Color purpleColor = Color(0xFFBE7DBC);

    return BottomNavigationBar(
      currentIndex: currentIndex,
      type: BottomNavigationBarType.fixed,
      backgroundColor: const Color(0xFFDECCE4),
      selectedItemColor: purpleColor,
      unselectedItemColor: purpleColor.withOpacity(0.5),
      showSelectedLabels: false,
      showUnselectedLabels: false,
      items: [
        BottomNavigationBarItem(
          icon: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                child: Image.asset(
                  currentIndex == 0 ? 'assets/icons/home_w.png' : 'assets/icons/home.png',
                  width: 30,
                  height: 30,
                  key: ValueKey<String>(currentIndex == 0 ? 'home_w' : 'home'),
                ),
              ),
            ],
          ),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                child: Image.asset(
                  currentIndex == 1 ? 'assets/icons/like_w.png' : 'assets/icons/like.png',
                  width: 30,
                  height: 30,
                  key: ValueKey<String>(currentIndex == 1 ? 'like_w' : 'like'),
                ),
              ),
            ],
          ),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                child: Image.asset(
                  currentIndex == 2 ? 'assets/icons/calendar_w.png' : 'assets/icons/calendar.png',
                  width: 30,
                  height: 30,
                  key: ValueKey<String>(currentIndex == 2 ? 'calendar_w' : 'calendar'),
                ),
              ),
            ],
          ),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                child: Image.asset(
                  currentIndex == 3 ? 'assets/icons/profile_w.png' : 'assets/icons/profile.png',
                  width: 30,
                  height: 30,
                  key: ValueKey<String>(currentIndex == 3 ? 'profile_w' : 'profile'),
                ),
              ),
            ],
          ),
          label: '',
        ),
      ],
      onTap: onTap,
    );
  }
} 
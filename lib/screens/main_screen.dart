import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'library_screen.dart';
import 'profile_screen.dart';
import 'onboarding_dialog.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _screens;

  static const List<_PremiumNavItem> _navItems = [
    _PremiumNavItem(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    _PremiumNavItem(
      label: 'Search',
      icon: Icons.search_rounded,
      activeIcon: Icons.manage_search_rounded,
    ),
    _PremiumNavItem(
      label: 'Library',
      icon: Icons.menu_book_outlined,
      activeIcon: Icons.menu_book_rounded,
    ),
    _PremiumNavItem(
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(onGoToSearch: () => _onItemTapped(1)),
      const SearchScreen(),
      const LibraryScreen(),
      const ProfileScreen(),
    ];
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data();
      final hasSeenOnboarding = data?['hasSeenOnboarding'] == true;

      if (!hasSeenOnboarding && mounted) {
        // Give the homescreen time to render and transition completely
        // so the user sees they've landed successfully before the dialog appears.
        await Future.delayed(const Duration(milliseconds: 1500));
        if (!mounted) return;

        showDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black.withOpacity(0.75),
          builder: (_) => OnboardingDialog(
            onComplete: () => _markOnboardingSeen(user.uid),
          ),
        );
      }
    } catch (e) {
      debugPrint('Onboarding check error: $e');
    }
  }

  Future<void> _markOnboardingSeen(String uid) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({'hasSeenOnboarding': true}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Mark onboarding error: $e');
    }
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Keep body above the floating nav so screen content will not be hidden
      // behind the bottom buttons on smaller Android screens.
      extendBody: false,
      backgroundColor: const Color(0xFF0F172A),
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: _PremiumBottomNavBar(
        currentIndex: _selectedIndex,
        items: _navItems,
        onTap: _onItemTapped,
      ),
    );
  }
}

class _PremiumNavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _PremiumNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

class _PremiumBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final List<_PremiumNavItem> items;
  final ValueChanged<int> onTap;

  const _PremiumBottomNavBar({
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  static const Color _cardColor = Color(0xFF1E293B);
  static const Color _accent = Color(0xFF8B5CF6);
  static const Color _pink = Color(0xFFD134B6);
  static const Color _teal = Color(0xFF06B6D4);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            // Slightly taller than before, but each button is also more compact.
            // This prevents the Flutter “bottom overflowed” warning.
            height: 84,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: _cardColor.withOpacity(0.82),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: _accent.withOpacity(0.16),
                  blurRadius: 30,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: List.generate(items.length, (index) {
                final item = items[index];
                final bool isSelected = currentIndex == index;

                return Expanded(
                  child: _PremiumNavButton(
                    item: item,
                    isSelected: isSelected,
                    onTap: () => onTap(index),
                    accent: _accent,
                    pink: _pink,
                    teal: _teal,
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumNavButton extends StatelessWidget {
  final _PremiumNavItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final Color accent;
  final Color pink;
  final Color teal;

  const _PremiumNavButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.accent,
    required this.pink,
    required this.teal,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: item.label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          splashColor: Colors.white.withOpacity(0.06),
          highlightColor: Colors.white.withOpacity(0.04),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: isSelected ? 10 : 6,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      colors: [accent, pink],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isSelected ? null : Colors.transparent,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected
                    ? Colors.white.withOpacity(0.18)
                    : Colors.transparent,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: pink.withOpacity(0.28),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutBack,
                  scale: isSelected ? 1.12 : 1.0,
                  child: Container(
                    padding: EdgeInsets.all(isSelected ? 5 : 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? Colors.white.withOpacity(0.18)
                          : Colors.white.withOpacity(0.05),
                    ),
                    child: Icon(
                      isSelected ? item.activeIcon : item.icon,
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withOpacity(0.42),
                      size: isSelected ? 21 : 20,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withOpacity(0.36),
                    fontSize: isSelected ? 11 : 10,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                    letterSpacing: isSelected ? 0.1 : 0.0,
                  ),
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 1),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: isSelected ? 18 : 4,
                  height: 3,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: isSelected ? Colors.white : Colors.transparent,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: teal.withOpacity(0.65),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

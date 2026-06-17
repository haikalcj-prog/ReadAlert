import 'dart:ui';
import 'package:flutter/material.dart';

// ════════════════════════════════════════════════════════════
//  ONBOARDING INTRODUCTION DIALOG
//
//  A multi-page, animated welcome popup shown to first-time
//  users. Each page highlights a core feature of ReadAlert.
// ════════════════════════════════════════════════════════════

class OnboardingDialog extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingDialog({super.key, required this.onComplete});

  @override
  State<OnboardingDialog> createState() => _OnboardingDialogState();
}

class _OnboardingDialogState extends State<OnboardingDialog>
    with TickerProviderStateMixin {
  // ── Palette ──────────────────────────────────────────────
  static const Color _bg = Color(0xFF0A0E1A);
  static const Color _cardBg = Color(0xFF131A2E);
  static const Color _purple = Color(0xFF8B5CF6);
  static const Color _pink = Color(0xFFD134B6);
  static const Color _cyan = Color(0xFF06B6D4);
  static const Color _gold = Color(0xFFFFBB33);

  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  late AnimationController _entranceCtrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  late AnimationController _pulseCtrl;

  // ── Onboarding Pages Data ────────────────────────────────
  static const List<_OnboardingPage> _pages = [
    _OnboardingPage(
      icon: Icons.auto_stories_rounded,
      iconGradient: [_purple, _cyan],
      title: 'Welcome to ReadAlert!',
      subtitle: 'Your reading adventure starts here',
      description:
          'Track your reading progress, build streaks, earn XP, and level up as you explore the world of books.',
      emoji: '📚',
    ),
    _OnboardingPage(
      icon: Icons.search_rounded,
      iconGradient: [_cyan, Color(0xFF38BDF8)],
      title: 'Discover Books',
      subtitle: 'Search millions of titles',
      description:
          'Find any book instantly using our powerful search. Add books to your library with just a tap and start tracking your progress.',
      emoji: '🔍',
    ),
    _OnboardingPage(
      icon: Icons.local_fire_department_rounded,
      iconGradient: [Color(0xFFFF6B35), _gold],
      title: 'Build Your Streak',
      subtitle: 'Read every day, earn rewards',
      description:
          'Maintain a daily reading streak to earn bonus XP. The longer your streak, the bigger the rewards!',
      emoji: '🔥',
    ),
    _OnboardingPage(
      icon: Icons.emoji_events_rounded,
      iconGradient: [_gold, Color(0xFFFF8C00)],
      title: 'Rank Up & Achieve',
      subtitle: 'From Scribe to Primordial',
      description:
          'Progress through 10 unique ranks, unlock achievements, and collect badges. Show off your reading prowess!',
      emoji: '🏆',
    ),
    _OnboardingPage(
      icon: Icons.rocket_launch_rounded,
      iconGradient: [_purple, _pink],
      title: "You're All Set!",
      subtitle: 'Start your journey now',
      description:
          'Add your first book, read a few pages, and watch your XP grow. Every page counts toward your next rank!',
      emoji: '🚀',
    ),
  ];

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(
      parent: _entranceCtrl,
      curve: Curves.easeOutBack,
    );
    _fadeAnim = CurvedAnimation(
      parent: _entranceCtrl,
      curve: Curves.easeOut,
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _pulseCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageCtrl.animateToPage(
      page,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  void _onNext() {
    if (_currentPage < _pages.length - 1) {
      _goToPage(_currentPage + 1);
    } else {
      _onFinish();
    }
  }

  void _onFinish() {
    widget.onComplete();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420, maxHeight: 540),
                decoration: BoxDecoration(
                  color: _cardBg.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _purple.withOpacity(0.2),
                      blurRadius: 60,
                      spreadRadius: 5,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 30,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // ── Skip button ──────────────────────────
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12, right: 12),
                        child: TextButton(
                          onPressed: _onFinish,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            'Skip',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.35),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ── Page content ─────────────────────────
                    Expanded(
                      child: PageView.builder(
                        controller: _pageCtrl,
                        itemCount: _pages.length,
                        onPageChanged: (i) =>
                            setState(() => _currentPage = i),
                        itemBuilder: (_, i) => _buildPage(_pages[i]),
                      ),
                    ),

                    // ── Dots + Button ────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Column(
                        children: [
                          // Dot indicators
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              _pages.length,
                              (i) => _buildDot(i),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Action button
                          _buildActionButton(),
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
    );
  }

  // ── Individual Page ────────────────────────────────────────
  Widget _buildPage(_OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated icon container
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, child) {
              final pulseValue = _pulseCtrl.value;
              return Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: page.iconGradient[0]
                          .withOpacity(0.15 + pulseValue * 0.1),
                      blurRadius: 30 + pulseValue * 15,
                      spreadRadius: 5 + pulseValue * 5,
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    page.iconGradient[0].withOpacity(0.2),
                    page.iconGradient[1].withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: page.iconGradient[0].withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: ShaderMask(
                  shaderCallback: (b) => LinearGradient(
                    colors: page.iconGradient,
                  ).createShader(b),
                  child: Icon(
                    page.icon,
                    size: 44,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Emoji
          Text(
            page.emoji,
            style: const TextStyle(fontSize: 28),
          ),

          const SizedBox(height: 12),

          // Title
          ShaderMask(
            shaderCallback: (b) => LinearGradient(
              colors: page.iconGradient,
            ).createShader(b),
            child: Text(
              page.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 6),

          // Subtitle
          Text(
            page.subtitle,
            style: TextStyle(
              color: page.iconGradient[0].withOpacity(0.8),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Description
          Text(
            page.description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Dot Indicator ──────────────────────────────────────────
  Widget _buildDot(int index) {
    final isActive = index == _currentPage;
    final page = _pages[_currentPage];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 28 : 8,
      height: 8,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: isActive
            ? LinearGradient(colors: page.iconGradient)
            : null,
        color: isActive ? null : Colors.white.withOpacity(0.15),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: page.iconGradient[0].withOpacity(0.5),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
    );
  }

  // ── Action Button ──────────────────────────────────────────
  Widget _buildActionButton() {
    final isLast = _currentPage == _pages.length - 1;
    final page = _pages[_currentPage];

    return GestureDetector(
      onTap: _onNext,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: isLast
                ? [_purple, _pink]
                : page.iconGradient,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: (isLast ? _purple : page.iconGradient[0])
                  .withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isLast ? "Let's Go!" : 'Next',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isLast
                  ? Icons.rocket_launch_rounded
                  : Icons.arrow_forward_rounded,
              color: Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data class for onboarding pages ──────────────────────────
class _OnboardingPage {
  final IconData icon;
  final List<Color> iconGradient;
  final String title;
  final String subtitle;
  final String description;
  final String emoji;

  const _OnboardingPage({
    required this.icon,
    required this.iconGradient,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.emoji,
  });
}

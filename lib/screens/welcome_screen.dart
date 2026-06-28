import 'package:flutter/material.dart';
import 'auth_widgets.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  static const Color _navy = Color(0xFF050D1F);
  static const Color _purple = Color(0xFF7B3FE4);
  static const Color _cyan = Color(0xFF00C6FF);
  static const Color _pink = Color(0xFFD134B6);

  late AnimationController _floatCtrl;
  late AnimationController _staggerCtrl;
  late Animation<double> _floatAnim;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _floatAnim = Tween<double>(
      begin: -8,
      end: 8,
    ).animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));

    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnim = CurvedAnimation(parent: _staggerCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _staggerCtrl, curve: Curves.easeOutCubic),
        );

    _staggerCtrl.forward();
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _staggerCtrl.dispose();
    super.dispose();
  }

  void _goToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: AuthStarfieldPainter())),
          const Positioned(
            top: -80,
            left: -60,
            child: AuthGlowOrb(color: _purple, size: 280, opacity: 0.18),
          ),
          const Positioned(
            top: 60,
            right: -80,
            child: AuthGlowOrb(color: _cyan, size: 220, opacity: 0.12),
          ),
          const Positioned(
            bottom: -60,
            right: 40,
            child: AuthGlowOrb(color: _pink, size: 200, opacity: 0.14),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedBuilder(
                                animation: _floatAnim,
                                builder: (_, child) => Transform.translate(
                                  offset: Offset(0, _floatAnim.value),
                                  child: child,
                                ),
                                child: Column(
                                  children: [
                                    const AuthLogoBadge(),
                                    const SizedBox(height: 32),
                                    ShaderMask(
                                      shaderCallback: (b) =>
                                          const LinearGradient(
                                            colors: [_purple, _cyan],
                                          ).createShader(b),
                                      child: const Text(
                                        'Welcome to ReadAlert',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 34,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.5,
                                          height: 1.1,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Your personal reading companion.\nTrack your books, earn XP, and level up your reading habits!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 16,
                                  height: 1.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: AuthGradientButton(
                          label: 'Next',
                          isLoading: false,
                          onTap: _goToLogin,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

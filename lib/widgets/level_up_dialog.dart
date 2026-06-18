import 'dart:math' as math;
import 'package:flutter/material.dart';

// ════════════════════════════════════════════════════════════
//  TIER THEME — one source of truth for every tier's colours,
//  background style, badge glow, and accent tint.
//
//  Extracted from home_screen.dart so any screen can use them.
// ════════════════════════════════════════════════════════════
class TierTheme {
  final String name;
  final Color primary;
  final Color secondary;
  final Color bgDark;
  final Color bgMid;
  final Color glowColor;
  final double glowRadius;
  final double glowSpread;

  const TierTheme({
    required this.name,
    required this.primary,
    required this.secondary,
    required this.bgDark,
    required this.bgMid,
    required this.glowColor,
    this.glowRadius = 40,
    this.glowSpread = 6,
  });

  List<Color> get gradient => [primary, secondary];
}

const List<TierTheme> kTierThemes = [
  // 0 – Scribe (silver/slate)
  TierTheme(
    name: 'Scribe',
    primary: Color(0xFFE2E8F0),
    secondary: Color(0xFF94A3B8),
    bgDark: Color(0xFF0D1117),
    bgMid: Color(0xFF161B26),
    glowColor: Color(0xFF94A3B8),
    glowRadius: 28,
    glowSpread: 4,
  ),
  // 1 – Chronicler (emerald)
  TierTheme(
    name: 'Chronicler',
    primary: Color(0xFF86EFAC),
    secondary: Color(0xFF059669),
    bgDark: Color(0xFF051A10),
    bgMid: Color(0xFF0C2A1A),
    glowColor: Color(0xFF34D399),
    glowRadius: 36,
    glowSpread: 6,
  ),
  // 2 – Keeper (sky blue)
  TierTheme(
    name: 'Keeper',
    primary: Color(0xFF7DD3FC),
    secondary: Color(0xFF0284C7),
    bgDark: Color(0xFF050F1A),
    bgMid: Color(0xFF0A1F35),
    glowColor: Color(0xFF38BDF8),
    glowRadius: 38,
    glowSpread: 6,
  ),
  // 3 – Elder (violet)
  TierTheme(
    name: 'Elder',
    primary: Color(0xFFD8B4FE),
    secondary: Color(0xFF7C3AED),
    bgDark: Color(0xFF0D0520),
    bgMid: Color(0xFF160A38),
    glowColor: Color(0xFFA78BFA),
    glowRadius: 42,
    glowSpread: 8,
  ),
  // 4 – Seer (crimson)
  TierTheme(
    name: 'Seer',
    primary: Color(0xFFFCA5A5),
    secondary: Color(0xFFE11D48),
    bgDark: Color(0xFF1A0508),
    bgMid: Color(0xFF2D0A10),
    glowColor: Color(0xFFF87171),
    glowRadius: 40,
    glowSpread: 7,
  ),
  // 5 – Oracle (gold/amber)
  TierTheme(
    name: 'Oracle',
    primary: Color(0xFFFFD700),
    secondary: Color(0xFFFF8C00),
    bgDark: Color(0xFF1A1200),
    bgMid: Color(0xFF2E1F00),
    glowColor: Color(0xFFFBBF24),
    glowRadius: 50,
    glowSpread: 10,
  ),
  // 6 – Ancient (teal/cyan)
  TierTheme(
    name: 'Ancient',
    primary: Color(0xFF67E8F9),
    secondary: Color(0xFF0F766E),
    bgDark: Color(0xFF02111A),
    bgMid: Color(0xFF041E2C),
    glowColor: Color(0xFF22D3EE),
    glowRadius: 52,
    glowSpread: 10,
  ),
  // 7 – Legendary (rose/ruby)
  TierTheme(
    name: 'Legendary',
    primary: Color(0xFFFDA4AF),
    secondary: Color(0xFF9F1239),
    bgDark: Color(0xFF1A0510),
    bgMid: Color(0xFF2D0818),
    glowColor: Color(0xFFFB7185),
    glowRadius: 54,
    glowSpread: 12,
  ),
  // 8 – Mythical (hot pink)
  TierTheme(
    name: 'Mythical',
    primary: Color(0xFFF9A8D4),
    secondary: Color(0xFFBE185D),
    bgDark: Color(0xFF1A0218),
    bgMid: Color(0xFF2D0428),
    glowColor: Color(0xFFF472B6),
    glowRadius: 58,
    glowSpread: 14,
  ),
  // 9 – Primordial (void purple)
  TierTheme(
    name: 'Primordial',
    primary: Color(0xFFFFD700),
    secondary: Color(0xFF7C3AED),
    bgDark: Color(0xFF04010F),
    bgMid: Color(0xFF0A0320),
    glowColor: Color(0xFFA855F7),
    glowRadius: 70,
    glowSpread: 18,
  ),
];

// ════════════════════════════════════════════════════════════
//  LEVEL-UP DIALOG
//  Exact same design as the original in home_screen.dart,
//  just made public so it can be shown from any screen.
// ════════════════════════════════════════════════════════════
class LevelUpDialog extends StatefulWidget {
  final int tier, newLevel;
  final String newTitle;
  final TierTheme theme;

  const LevelUpDialog({
    super.key,
    required this.tier,
    required this.newLevel,
    required this.newTitle,
    required this.theme,
  });

  @override
  State<LevelUpDialog> createState() => _LevelUpDialogState();
}

class _LevelUpDialogState extends State<LevelUpDialog>
    with TickerProviderStateMixin {
  late AnimationController _scaleCtrl, _glowCtrl, _particleCtrl;
  late Animation<double> _scale, _glow;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _scale = CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut);
    _glow = CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut);
    _scaleCtrl.forward();
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    _glowCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final badgeSize = 120.0 + widget.tier * 8.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: LinearGradient(
            colors: [
              Color.lerp(const Color(0xFF1E293B), t.bgMid, 0.6)!,
              Color.lerp(const Color(0xFF0F172A), t.bgDark, 0.7)!,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(color: t.primary.withOpacity(0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: t.glowColor.withOpacity(0.25),
              blurRadius: 40,
              spreadRadius: 4,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Stack(
            children: [
              // Particle effect background
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _particleCtrl,
                  builder: (_, __) => CustomPaint(
                    painter: _ParticlePainter(
                      progress: _particleCtrl.value,
                      color: t.primary,
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── "LEVEL UP!" header ──────────────────────
                    ShaderMask(
                      shaderCallback: (b) =>
                          LinearGradient(colors: t.gradient).createShader(b),
                      child: const Text(
                        '✦ LEVEL UP ✦',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'You reached Level ${widget.newLevel}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Animated badge ───────────────────────────
                    AnimatedBuilder(
                      animation: Listenable.merge([_scale, _glow]),
                      builder: (_, __) => Transform.scale(
                        scale: _scale.value,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer pulsing glow
                            Container(
                              width: badgeSize + 60,
                              height: badgeSize + 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: t.glowColor.withOpacity(
                                      0.25 + _glow.value * 0.2,
                                    ),
                                    blurRadius: t.glowRadius + _glow.value * 20,
                                    spreadRadius: t.glowSpread,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: badgeSize + 40,
                              height: badgeSize + 40,
                              child: Image.asset(
                                'assets/images/ranks/rank_${widget.tier}.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── New rank title ───────────────────────────
                    ShaderMask(
                      shaderCallback: (b) =>
                          LinearGradient(colors: t.gradient).createShader(b),
                      child: Text(
                        widget.newTitle.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Decorative line
                    Container(
                      height: 1.5,
                      width: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            t.primary,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Dismiss button ───────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style:
                            ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ).copyWith(
                              backgroundColor: WidgetStateProperty.all(
                                Colors.transparent,
                              ),
                            ),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: t.gradient),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: t.glowColor.withOpacity(0.4),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          alignment: Alignment.center,
                          child: const Text(
                            'Claim your glory!',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Floating particle burst for the level-up dialog
class _ParticlePainter extends CustomPainter {
  final double progress;
  final Color color;
  const _ParticlePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);
    final paint = Paint()..color = color.withOpacity(0.12);
    for (int i = 0; i < 24; i++) {
      final angle = rng.nextDouble() * math.pi * 2;
      final speed = 0.3 + rng.nextDouble() * 0.7;
      final dist = size.shortestSide * 0.6 * progress * speed;
      final x = size.width / 2 + math.cos(angle) * dist;
      final y = size.height / 2 + math.sin(angle) * dist;
      final r = (1.5 + rng.nextDouble() * 3) * (1 - progress * 0.6);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}

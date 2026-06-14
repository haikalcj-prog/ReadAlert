import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../rank_book_names.dart';
import '../services/xp_service.dart';

// ════════════════════════════════════════════════════════════
//  RANK PROGRESS SCREEN
//
//  Shows all 10 tiers in a vertical timeline.
//  • Past tiers  → glowing badge, fully unlocked, tappable
//  • Current tier → hero card with animated XP ring + pulse
//  • Future tiers → locked_rank.png, dim, shows XP required
//
//  Tap any card → _RankDetailSheet (bottom sheet) with
//  tier story, XP thresholds for each sub-level, and a
//  motivational progress arc.
// ════════════════════════════════════════════════════════════

// ── Re-use the same tier themes from home_screen.dart ──────
class _T {
  final String name;
  final Color primary;
  final Color secondary;
  final Color bgDark;
  final Color bgMid;
  final Color glowColor;
  final double glowRadius;
  final String lore; // flavour text shown in detail sheet

  const _T({
    required this.name,
    required this.primary,
    required this.secondary,
    required this.bgDark,
    required this.bgMid,
    required this.glowColor,
    required this.lore,
    this.glowRadius = 40,
  });

  List<Color> get gradient => [primary, secondary];
}

const List<_T> _tiers = [
  _T(
    name: 'Scribe',
    primary: Color(0xFFE2E8F0),
    secondary: Color(0xFF94A3B8),
    bgDark: Color(0xFF0D1117),
    bgMid: Color(0xFF161B26),
    glowColor: Color(0xFF94A3B8),
    glowRadius: 24,
    lore: 'Every legend begins with a single page. You have answered the call.',
  ),
  _T(
    name: 'Chronicler',
    primary: Color(0xFF86EFAC),
    secondary: Color(0xFF059669),
    bgDark: Color(0xFF051A10),
    bgMid: Color(0xFF0C2A1A),
    glowColor: Color(0xFF34D399),
    glowRadius: 32,
    lore:
        'Your words are becoming a record. The emerald light guides your quill.',
  ),
  _T(
    name: 'Keeper',
    primary: Color(0xFF7DD3FC),
    secondary: Color(0xFF0284C7),
    bgDark: Color(0xFF050F1A),
    bgMid: Color(0xFF0A1F35),
    glowColor: Color(0xFF38BDF8),
    glowRadius: 36,
    lore: 'You guard the archives of knowledge, a guardian of ancient texts.',
  ),
  _T(
    name: 'Elder',
    primary: Color(0xFFD8B4FE),
    secondary: Color(0xFF7C3AED),
    bgDark: Color(0xFF0D0520),
    bgMid: Color(0xFF160A38),
    glowColor: Color(0xFFA78BFA),
    glowRadius: 40,
    lore:
        'The violet flame of wisdom burns within you. Others seek your counsel.',
  ),
  _T(
    name: 'Seer',
    primary: Color(0xFFFCA5A5),
    secondary: Color(0xFFE11D48),
    bgDark: Color(0xFF1A0508),
    bgMid: Color(0xFF2D0A10),
    glowColor: Color(0xFFF87171),
    glowRadius: 40,
    lore: 'Beyond the veil of ordinary sight, you perceive what others cannot.',
  ),
  _T(
    name: 'Oracle',
    primary: Color(0xFFFFD700),
    secondary: Color(0xFFFF8C00),
    bgDark: Color(0xFF1A1200),
    bgMid: Color(0xFF2E1F00),
    glowColor: Color(0xFFFBBF24),
    glowRadius: 50,
    lore: 'The golden wings of prophecy carry you above mortal understanding.',
  ),
  _T(
    name: 'Ancient',
    primary: Color(0xFF67E8F9),
    secondary: Color(0xFF0F766E),
    bgDark: Color(0xFF02111A),
    bgMid: Color(0xFF041E2C),
    glowColor: Color(0xFF22D3EE),
    glowRadius: 52,
    lore:
        'You have endured through countless ages. The teal star marks your eternity.',
  ),
  _T(
    name: 'Legendary',
    primary: Color(0xFFFDA4AF),
    secondary: Color(0xFF9F1239),
    bgDark: Color(0xFF1A0510),
    bgMid: Color(0xFF2D0818),
    glowColor: Color(0xFFFB7185),
    glowRadius: 54,
    lore:
        'Songs are sung of your deeds. The ruby heart blazes with your story.',
  ),
  _T(
    name: 'Mythical',
    primary: Color(0xFFF9A8D4),
    secondary: Color(0xFFBE185D),
    bgDark: Color(0xFF1A0218),
    bgMid: Color(0xFF2D0428),
    glowColor: Color(0xFFF472B6),
    glowRadius: 58,
    lore:
        'The pink wings of myth carry stories that defy mortal comprehension.',
  ),
  _T(
    name: 'Primordial',
    primary: Color(0xFFFFD700),
    secondary: Color(0xFF7C3AED),
    bgDark: Color(0xFF04010F),
    bgMid: Color(0xFF0A0320),
    glowColor: Color(0xFFA855F7),
    glowRadius: 70,
    lore:
        'Before time, before words — you are the void from which all stories emerge.',
  ),
];

// XP required to unlock each tier (= tierStarts from XpService)
const List<int> _tierUnlockXp = [
  0,
  1200,
  3200,
  6700,
  12200,
  20200,
  32200,
  50200,
  76200,
  114200,
];
// Friendly XP labels
const List<String> _tierUnlockLabel = [
  'Start',
  '1,200 XP',
  '3,200 XP',
  '6,700 XP',
  '12,200 XP',
  '20,200 XP',
  '32,200 XP',
  '50,200 XP',
  '76,200 XP',
  '114,200 XP',
];
// Sub-level steps inside each tier
const List<int> _tierSteps = [
  120,
  200,
  350,
  550,
  800,
  1200,
  1800,
  2600,
  3800,
  5500,
];

// ════════════════════════════════════════════════════════════
class RankProgressScreen extends StatefulWidget {
  const RankProgressScreen({super.key});
  @override
  State<RankProgressScreen> createState() => _RankProgressScreenState();
}

class _RankProgressScreenState extends State<RankProgressScreen>
    with TickerProviderStateMixin {
  static const Color _bg = Color(0xFF04010F);

  late AnimationController _bgPulse;

  @override
  void initState() {
    super.initState();
    // PERF: single slow pulse instead of two forever-repeating controllers
    _bgPulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgPulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Scaffold(backgroundColor: _bg);

    return Scaffold(
      backgroundColor: _bg,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (ctx, snap) {
          final d = snap.data?.data() as Map<String, dynamic>?;
          final int totalXp = d?['totalXp'] ?? d?['points'] ?? 0;
          final levelData = XpService.calculateLevel(totalXp);
          final int currentTier = levelData['tierIndex'] as int;
          final double tierProg = levelData['progress'] as double;
          final int currentLevel = levelData['level'] as int;

          return Stack(
            children: [
              // ── Cosmic background ────────────────────────────
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _bgPulse,
                  builder: (_, __) => CustomPaint(
                    painter: _CosmicBgPainter(
                      pulse: _bgPulse.value,
                      tierColor: _tiers[currentTier].glowColor,
                    ),
                  ),
                ),
              ),

              SafeArea(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // ── App bar ──────────────────────────────────
                    SliverToBoxAdapter(
                      child: _buildAppBar(context, currentTier),
                    ),

                    // ── Hero XP summary ──────────────────────────
                    SliverToBoxAdapter(
                      child: _buildXpSummary(
                        totalXp,
                        currentLevel,
                        currentTier,
                        tierProg,
                        levelData,
                      ),
                    ),

                    // ── Section label ────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                        child: Row(
                          children: [
                            Container(
                              width: 3,
                              height: 16,
                              decoration: BoxDecoration(
                                color: _tiers[currentTier].primary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'RANK PROGRESSION',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.45),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Timeline ─────────────────────────────────
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _buildTierCard(
                          context: context,
                          tier: i,
                          currentTier: currentTier,
                          currentLevel: currentLevel,
                          totalXp: totalXp,
                          tierProgress: i == currentTier ? tierProg : 0,
                        ),
                        childCount: 10,
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 60)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── APP BAR ───────────────────────────────────────────────
  Widget _buildAppBar(BuildContext ctx, int currentTier) {
    final t = _tiers[currentTier];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 20, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(ctx),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rank Journey',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Track your path to glory',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Current rank mini badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  t.primary.withOpacity(0.2),
                  t.secondary.withOpacity(0.1),
                ],
              ),
              border: Border.all(color: t.primary.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  shaderCallback: (b) =>
                      LinearGradient(colors: t.gradient).createShader(b),
                  child: Text(
                    t.name.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── XP SUMMARY HERO ───────────────────────────────────────
  Widget _buildXpSummary(
    int totalXp,
    int level,
    int tier,
    double progress,
    Map<String, dynamic> levelData,
  ) {
    final t = _tiers[tier];
    final int xpLeft = levelData['xpNeeded'] as int;
    final int nextUnlock = tier < 9 ? _tierUnlockXp[tier + 1] : 0;
    final int xpToNextTier = tier < 9
        ? (nextUnlock - totalXp).clamp(0, nextUnlock)
        : 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            Color.lerp(const Color(0xFF0E0A20), t.bgMid, 0.6)!,
            Color.lerp(const Color(0xFF04010F), t.bgDark, 0.5)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: t.primary.withOpacity(0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: t.glowColor.withOpacity(0.18),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          // Circular XP ring
          _CircularXpRing(progress: progress, theme: t, level: level),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (b) =>
                      LinearGradient(colors: t.gradient).createShader(b),
                  child: Text(
                    t.name.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  kRankBookNames[tier],
                  style: TextStyle(
                    color: t.primary.withOpacity(0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalXp total XP',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                // To next level
                _xpRow(
                  'Next level',
                  '$xpLeft XP',
                  t.primary,
                  Icons.arrow_upward_rounded,
                ),
                if (tier < 9) ...[
                  const SizedBox(height: 6),
                  _xpRow(
                    'Next rank',
                    '$xpToNextTier XP',
                    _tiers[tier + 1].primary,
                    Icons.workspace_premium_rounded,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _xpRow(String label, String value, Color color, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // ── TIER CARD ─────────────────────────────────────────────
  Widget _buildTierCard({
    required BuildContext context,
    required int tier,
    required int currentTier,
    required int currentLevel,
    required int totalXp,
    required double tierProgress,
  }) {
    final bool isUnlocked = tier <= currentTier;
    final bool isCurrent = tier == currentTier;
    final bool isNext = tier == currentTier + 1;
    final t = _tiers[tier];

    return GestureDetector(
      onTap: () => _showDetailSheet(
        context: context,
        tier: tier,
        isUnlocked: isUnlocked,
        currentLevel: currentLevel,
        totalXp: totalXp,
        tierProgress: tierProgress,
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: isUnlocked
              ? LinearGradient(
                  colors: [
                    Color.lerp(const Color(0xFF0E0A20), t.bgMid, 0.5)!,
                    Color.lerp(const Color(0xFF0E0A20), t.bgDark, 0.3)!,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isUnlocked ? null : const Color(0xFF0A0818),
          border: Border.all(
            color: isCurrent
                ? t.primary.withOpacity(0.55)
                : isUnlocked
                ? t.primary.withOpacity(0.18)
                : Colors.white.withOpacity(0.06),
            width: isCurrent ? 1.5 : 1,
          ),
          boxShadow: isCurrent
              ? [
                  BoxShadow(
                    color: t.glowColor.withOpacity(0.22),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Starfield bg for unlocked
              if (isUnlocked)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CardStarsPainter(
                      color: t.primary.withOpacity(0.06),
                      tier: tier,
                    ),
                  ),
                ),

              // PERF: static shimmer instead of AnimationController per card
              if (isCurrent)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          t.glowColor.withOpacity(0.06),
                          Colors.transparent,
                          t.glowColor.withOpacity(0.03),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    // ── Badge ──────────────────────────────────────
                    _TierBadgeWidget(
                      tier: tier,
                      isUnlocked: isUnlocked,
                      isCurrent: isCurrent,
                      theme: t,
                    ),

                    const SizedBox(width: 16),

                    // ── Info ───────────────────────────────────────
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Flexible(
                                child: ShaderMask(
                                  shaderCallback: (b) => LinearGradient(
                                    colors: isUnlocked
                                        ? t.gradient
                                        : [Colors.white24, Colors.white12],
                                  ).createShader(b),
                                  child: Text(
                                    t.name.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                      letterSpacing: 0.8,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    softWrap: false,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Status badge
                              _StatusChip(
                                isUnlocked: isUnlocked,
                                isCurrent: isCurrent,
                                isNext: isNext,
                                theme: t,
                              ),
                            ],
                          ),

                          const SizedBox(height: 5),

                          Text(
                            kRankBookNames[tier],
                            style: TextStyle(
                              color: isUnlocked
                                  ? t.primary.withOpacity(0.78)
                                  : Colors.white.withOpacity(0.24),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 5),

                          // Levels range
                          Text(
                            'Levels ${tier * 10 + 1} – ${tier * 10 + 10}',
                            style: TextStyle(
                              color: isUnlocked
                                  ? Colors.white.withOpacity(0.45)
                                  : Colors.white.withOpacity(0.2),
                              fontSize: 12,
                            ),
                          ),

                          const SizedBox(height: 4),

                          // Unlock XP
                          Row(
                            children: [
                              Icon(
                                isUnlocked
                                    ? Icons.check_circle_rounded
                                    : Icons.lock_rounded,
                                size: 12,
                                color: isUnlocked
                                    ? t.primary.withOpacity(0.7)
                                    : Colors.white.withOpacity(0.25),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isUnlocked
                                    ? (tier == 0
                                          ? 'Starting rank'
                                          : 'Unlocked at ${_tierUnlockLabel[tier]}')
                                    : 'Requires ${_tierUnlockLabel[tier]}',
                                style: TextStyle(
                                  color: isUnlocked
                                      ? t.primary.withOpacity(0.6)
                                      : Colors.white.withOpacity(0.2),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),

                          // Current tier progress bar
                          if (isCurrent) ...[
                            const SizedBox(height: 12),
                            _TierProgressBar(progress: tierProgress, theme: t),
                          ],
                        ],
                      ),
                    ),

                    // Chevron
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: isUnlocked
                          ? t.primary.withOpacity(0.5)
                          : Colors.white.withOpacity(0.12),
                      size: 20,
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

  // ── DETAIL BOTTOM SHEET ───────────────────────────────────
  void _showDetailSheet({
    required BuildContext context,
    required int tier,
    required bool isUnlocked,
    required int currentLevel,
    required int totalXp,
    required double tierProgress,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RankDetailSheet(
        tier: tier,
        isUnlocked: isUnlocked,
        currentLevel: currentLevel,
        totalXp: totalXp,
        tierProgress: tierProgress,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  CIRCULAR XP RING
// ════════════════════════════════════════════════════════════
class _CircularXpRing extends StatefulWidget {
  final double progress;
  final _T theme;
  final int level;
  const _CircularXpRing({
    required this.progress,
    required this.theme,
    required this.level,
  });
  @override
  State<_CircularXpRing> createState() => _CircularXpRingState();
}

class _CircularXpRingState extends State<_CircularXpRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => SizedBox(
        width: 88,
        height: 88,
        child: CustomPaint(
          painter: _RingPainter(
            progress: widget.progress * _anim.value,
            color1: widget.theme.primary,
            color2: widget.theme.secondary,
            glowColor: widget.theme.glowColor,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${widget.level}',
                  style: TextStyle(
                    color: widget.theme.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                    height: 1,
                  ),
                ),
                Text(
                  'LVL',
                  style: TextStyle(
                    color: widget.theme.primary.withOpacity(0.5),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
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

// ════════════════════════════════════════════════════════════
//  TIER BADGE WIDGET
// ════════════════════════════════════════════════════════════
class _TierBadgeWidget extends StatelessWidget {
  final int tier;
  final bool isUnlocked, isCurrent;
  final _T theme;
  const _TierBadgeWidget({
    required this.tier,
    required this.isUnlocked,
    required this.isCurrent,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final double size = isCurrent ? 84 : 68;

    return SizedBox(
      width: size + 20,
      height: size + 20,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow
          if (isUnlocked)
            Container(
              width: size + 16,
              height: size + 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: theme.glowColor.withOpacity(isCurrent ? 0.45 : 0.22),
                    blurRadius: isCurrent
                        ? theme.glowRadius
                        : theme.glowRadius * 0.5,
                    spreadRadius: isCurrent ? 6 : 2,
                  ),
                ],
              ),
            ),
          // Badge image
          Image.asset(
            isUnlocked
                ? 'assets/images/ranks/rank_$tier.png'
                : 'assets/images/ranks/locked_rank.png',
            width: size + 20,
            height: size + 20,
            fit: BoxFit.contain,
            color: isUnlocked ? null : Colors.white.withOpacity(0.3),
            colorBlendMode: isUnlocked ? null : BlendMode.modulate,
          ),
          // Tier number on locked
          if (!isUnlocked)
            Positioned(
              bottom: 6,
              right: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'T${tier + 1}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  STATUS CHIP
// ════════════════════════════════════════════════════════════
class _StatusChip extends StatelessWidget {
  final bool isUnlocked, isCurrent, isNext;
  final _T theme;
  const _StatusChip({
    required this.isUnlocked,
    required this.isCurrent,
    required this.isNext,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    if (isCurrent) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: theme.gradient),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: theme.glowColor.withOpacity(0.4), blurRadius: 8),
          ],
        ),
        child: const Text(
          'CURRENT',
          style: TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
      );
    }
    if (isUnlocked) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.greenAccent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
        ),
        child: const Text(
          '✓ ACHIEVED',
          style: TextStyle(
            color: Colors.greenAccent,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      );
    }
    if (isNext) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.orangeAccent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
        ),
        child: const Text(
          'UP NEXT',
          style: TextStyle(
            color: Colors.orangeAccent,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_rounded,
            color: Colors.white.withOpacity(0.25),
            size: 9,
          ),
          const SizedBox(width: 4),
          Text(
            'LOCKED',
            style: TextStyle(
              color: Colors.white.withOpacity(0.25),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  TIER PROGRESS BAR
// ════════════════════════════════════════════════════════════
class _TierProgressBar extends StatelessWidget {
  final double progress;
  final _T theme;
  const _TierProgressBar({required this.progress, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tier progress',
              style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 10,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                color: theme.primary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Stack(
          children: [
            Container(
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                height: 5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: theme.gradient),
                  borderRadius: BorderRadius.circular(5),
                  boxShadow: [
                    BoxShadow(
                      color: theme.glowColor.withOpacity(0.6),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════
//  RANK DETAIL BOTTOM SHEET
// ════════════════════════════════════════════════════════════
class _RankDetailSheet extends StatefulWidget {
  final int tier;
  final bool isUnlocked;
  final int currentLevel, totalXp;
  final double tierProgress;

  const _RankDetailSheet({
    required this.tier,
    required this.isUnlocked,
    required this.currentLevel,
    required this.totalXp,
    required this.tierProgress,
  });

  @override
  State<_RankDetailSheet> createState() => _RankDetailSheetState();
}

class _RankDetailSheetState extends State<_RankDetailSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _enter;
  late Animation<double> _scale, _fade;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scale = CurvedAnimation(parent: _enter, curve: Curves.elasticOut);
    _fade = CurvedAnimation(parent: _enter, curve: Curves.easeOut);
    _enter.forward();
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _tiers[widget.tier];
    final int tierStartXp = _tierUnlockXp[widget.tier];
    final int step = _tierSteps[widget.tier];
    final int tierIndex = widget.tier;

    // Calculate which sub-level (0-9) the user is on within this tier
    final int subLevel = widget.tier < (widget.currentLevel - 1) ~/ 10
        ? 9
        : widget.tier == (widget.currentLevel - 1) ~/ 10
        ? (widget.currentLevel - 1) % 10
        : -1; // not reached

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        gradient: LinearGradient(
          colors: [
            Color.lerp(const Color(0xFF0E0A20), t.bgMid, 0.7)!,
            Color.lerp(const Color(0xFF04010F), t.bgDark, 0.6)!,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(
          top: BorderSide(color: t.primary.withOpacity(0.3), width: 1.5),
        ),
      ),
      child: Column(
        children: [
          // Handle + glow line
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 1,
            width: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  t.primary.withOpacity(0.6),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: FadeTransition(
                opacity: _fade,
                child: Column(
                  children: [
                    // ── Hero badge ───────────────────────────────
                    ScaleTransition(
                      scale: _scale,
                      child: _SheetHeroBadge(
                        tier: widget.tier,
                        isUnlocked: widget.isUnlocked,
                        theme: t,
                      ),
                    ),

                    const SizedBox(height: 14),

                    Text(
                      kRankBookNames[widget.tier],
                      style: TextStyle(
                        color: widget.isUnlocked
                            ? t.primary
                            : Colors.white.withOpacity(0.3),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 20),

                    // ── Lore text ────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: t.primary.withOpacity(0.15)),
                      ),
                      child: Text(
                        '"${t.lore}"',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.55),
                          fontSize: 13,
                          height: 1.6,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Sub-level grid (10 levels) ───────────────
                    _sectionLabel('LEVELS IN THIS RANK', t),
                    const SizedBox(height: 12),

                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 0.9,
                          ),
                      itemCount: 10,
                      itemBuilder: (_, i) {
                        final int lvl = tierIndex * 10 + 1 + i;
                        final bool reached = i <= subLevel;
                        final bool isCurr =
                            i == subLevel &&
                            widget.isUnlocked &&
                            tierIndex == (widget.currentLevel - 1) ~/ 10;

                        return _SubLevelCell(
                          level: lvl,
                          subIndex: i,
                          isReached: reached,
                          isCurrent: isCurr,
                          theme: t,
                          xpRequired: tierStartXp + i * step,
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // ── XP breakdown ─────────────────────────────
                    _sectionLabel('XP BREAKDOWN', t),
                    const SizedBox(height: 12),
                    _XpBreakdownCard(
                      tier: widget.tier,
                      theme: t,
                      totalXp: widget.totalXp,
                      isUnlocked: widget.isUnlocked,
                    ),

                    if (!widget.isUnlocked) ...[
                      const SizedBox(height: 20),
                      _MotivationCard(
                        tier: widget.tier,
                        totalXp: widget.totalXp,
                        theme: t,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, _T t) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: t.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────
class _SheetHeroBadge extends StatefulWidget {
  final int tier;
  final bool isUnlocked;
  final _T theme;
  const _SheetHeroBadge({
    required this.tier,
    required this.isUnlocked,
    required this.theme,
  });
  @override
  State<_SheetHeroBadge> createState() => _SheetHeroBadgeState();
}

class _SheetHeroBadgeState extends State<_SheetHeroBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulsing ring
          if (widget.isUnlocked)
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: t.glowColor.withOpacity(0.15 + _pulse.value * 0.15),
                    blurRadius: t.glowRadius + _pulse.value * 20,
                    spreadRadius: 4 + _pulse.value * 8,
                  ),
                ],
              ),
            ),
          SizedBox(
            width: 150,
            height: 150,
            child: Image.asset(
              widget.isUnlocked
                  ? 'assets/images/ranks/rank_${widget.tier}.png'
                  : 'assets/images/ranks/locked_rank.png',
              fit: BoxFit.contain,
              color: widget.isUnlocked ? null : Colors.white.withOpacity(0.25),
              colorBlendMode: widget.isUnlocked ? null : BlendMode.modulate,
            ),
          ),
          // Tier name below
          Positioned(
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: widget.isUnlocked
                      ? t.gradient
                      : [Colors.white12, Colors.white.withOpacity(0.08)],
                ),
                boxShadow: widget.isUnlocked
                    ? [
                        BoxShadow(
                          color: t.glowColor.withOpacity(0.5),
                          blurRadius: 12,
                        ),
                      ]
                    : null,
              ),
              child: Text(
                widget.isUnlocked ? t.name.toUpperCase() : 'LOCKED',
                style: TextStyle(
                  color: widget.isUnlocked ? Colors.white : Colors.white30,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
class _SubLevelCell extends StatelessWidget {
  final int level, subIndex;
  final bool isReached, isCurrent;
  final _T theme;
  final int xpRequired;

  const _SubLevelCell({
    required this.level,
    required this.subIndex,
    required this.isReached,
    required this.isCurrent,
    required this.theme,
    required this.xpRequired,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: isCurrent ? LinearGradient(colors: theme.gradient) : null,
        color: isCurrent
            ? null
            : isReached
            ? theme.primary.withOpacity(0.12)
            : Colors.white.withOpacity(0.04),
        border: Border.all(
          color: isCurrent
              ? theme.primary
              : isReached
              ? theme.primary.withOpacity(0.3)
              : Colors.white.withOpacity(0.06),
          width: isCurrent ? 1.5 : 1,
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: theme.glowColor.withOpacity(0.4),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isReached && !isCurrent)
            Icon(
              Icons.check_rounded,
              color: theme.primary.withOpacity(0.8),
              size: 16,
            )
          else
            Text(
              '$level',
              style: TextStyle(
                color: isCurrent
                    ? Colors.white
                    : isReached
                    ? theme.primary
                    : Colors.white.withOpacity(0.2),
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          const SizedBox(height: 2),
          Text(
            'Lv.$level',
            style: TextStyle(
              color: isCurrent
                  ? Colors.white.withOpacity(0.8)
                  : Colors.white.withOpacity(isReached ? 0.35 : 0.15),
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
class _XpBreakdownCard extends StatelessWidget {
  final int tier, totalXp;
  final bool isUnlocked;
  final _T theme;

  const _XpBreakdownCard({
    required this.tier,
    required this.totalXp,
    required this.isUnlocked,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final int unlockXp = _tierUnlockXp[tier];
    final int step = _tierSteps[tier];
    final int tierEnd = unlockXp + step * 10;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.primary.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          _xpRow2('Unlock XP', _fmt(unlockXp), theme.primary),
          const SizedBox(height: 10),
          _xpRow2('XP per sub-level', '+${_fmt(step)} XP', theme.secondary),
          const SizedBox(height: 10),
          _xpRow2(
            'Full tier range',
            '${_fmt(unlockXp)} → ${_fmt(tierEnd)}',
            Colors.white54,
          ),
          if (isUnlocked && tier < 9) ...[
            const SizedBox(height: 10),
            Divider(color: Colors.white.withOpacity(0.07)),
            const SizedBox(height: 10),
            _xpRow2(
              'XP to next rank',
              '+${_fmt((_tierUnlockXp[tier + 1] - totalXp).clamp(0, 999999))} XP',
              _tiers[tier + 1].primary,
            ),
          ],
        ],
      ),
    );
  }

  Widget _xpRow2(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _fmt(int n) {
    if (n >= 1000)
      return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}K';
    return '$n';
  }
}

// ────────────────────────────────────────────────────────────
class _MotivationCard extends StatelessWidget {
  final int tier, totalXp;
  final _T theme;
  const _MotivationCard({
    required this.tier,
    required this.totalXp,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final int needed = (_tierUnlockXp[tier] - totalXp).clamp(0, 999999);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            theme.primary.withOpacity(0.12),
            theme.secondary.withOpacity(0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: theme.primary.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Icon(Icons.emoji_events_rounded, color: theme.primary, size: 32),
          const SizedBox(height: 10),
          ShaderMask(
            shaderCallback: (b) =>
                LinearGradient(colors: theme.gradient).createShader(b),
            child: Text(
              '${_fmt(needed)} XP to unlock!',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Every page brings you closer to ${theme.name}.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 12,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          // Mini progress toward this tier
          _MiniTierProgress(tier: tier, totalXp: totalXp, theme: theme),
        ],
      ),
    );
  }

  String _fmt(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}K' : '$n';
}

class _MiniTierProgress extends StatelessWidget {
  final int tier, totalXp;
  final _T theme;
  const _MiniTierProgress({
    required this.tier,
    required this.totalXp,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final int prevXp = tier > 0 ? _tierUnlockXp[tier - 1] : 0;
    final int targXp = _tierUnlockXp[tier];
    final double pct = ((totalXp - prevXp) / (targXp - prevXp)).clamp(0.0, 1.0);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${(pct * 100).toInt()}% of the way there',
              style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 11,
              ),
            ),
            Text(
              '${totalXp ~/ 1000}K / ${targXp ~/ 1000}K XP',
              style: TextStyle(
                color: theme.primary.withOpacity(0.7),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            FractionallySizedBox(
              widthFactor: pct,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: theme.gradient),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: theme.glowColor.withOpacity(0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════
//  CUSTOM PAINTERS
// ════════════════════════════════════════════════════════════

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color1, color2, glowColor;
  const _RingPainter({
    required this.progress,
    required this.color1,
    required this.color2,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 6;

    // Track
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = Colors.white.withOpacity(0.07)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7,
    );

    // Progress arc
    final sweep = 2 * math.pi * progress;
    final rect = Rect.fromCircle(center: c, radius: r);
    final arcPaint = Paint()
      ..shader = SweepGradient(
        colors: [color1, color2],
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + (sweep > 0 ? sweep : 0.01),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -math.pi / 2, sweep, false, arcPaint);

    // Glow cap
    if (progress > 0.02) {
      final endAngle = -math.pi / 2 + sweep;
      final ex = c.dx + r * math.cos(endAngle);
      final ey = c.dy + r * math.sin(endAngle);
      canvas.drawCircle(
        Offset(ex, ey),
        5,
        Paint()
          ..color = glowColor.withOpacity(0.8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

class _CosmicBgPainter extends CustomPainter {
  final double pulse;
  final Color tierColor;
  const _CosmicBgPainter({required this.pulse, required this.tierColor});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(7);
    // Stars
    for (int i = 0; i < 80; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = 0.4 + rng.nextDouble() * 1.2;
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..color = Colors.white.withOpacity(0.06 + rng.nextDouble() * 0.1),
      );
    }
    // Two nebula blobs
    final p1 = Paint()
      ..shader =
          RadialGradient(
            colors: [
              tierColor.withOpacity(0.07 + pulse * 0.04),
              Colors.transparent,
            ],
            radius: 0.6,
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.2, size.height * 0.15),
              radius: size.width * 0.5,
            ),
          );
    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.15),
      size.width * 0.5,
      p1,
    );

    final p2 = Paint()
      ..shader =
          RadialGradient(
            colors: [
              tierColor.withOpacity(0.05 + pulse * 0.03),
              Colors.transparent,
            ],
            radius: 0.5,
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.8, size.height * 0.7),
              radius: size.width * 0.45,
            ),
          );
    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * 0.7),
      size.width * 0.45,
      p2,
    );
  }

  @override
  bool shouldRepaint(_CosmicBgPainter old) =>
      old.pulse != pulse || old.tierColor != tierColor;
}

class _CardStarsPainter extends CustomPainter {
  final Color color;
  final int tier;
  const _CardStarsPainter({required this.color, required this.tier});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(tier * 13 + 3);
    final count = 12 + tier * 3;
    for (int i = 0; i < count; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      canvas.drawCircle(
        Offset(x, y),
        0.8 + rng.nextDouble(),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_CardStarsPainter old) => old.tier != tier;
}

/// Subtle sweep gradient that rotates on the current card
// _GlowSweep removed — replaced with static gradient for performance

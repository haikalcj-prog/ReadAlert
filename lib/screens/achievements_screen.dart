import 'package:flutter/material.dart';
import '../services/stats_service.dart';
import '../services/level_up_service.dart';
import '../services/audio_service.dart';

class AchievementsScreen extends StatefulWidget {
  final Map<String, dynamic> stats;

  const AchievementsScreen({super.key, required this.stats});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen>
    with SingleTickerProviderStateMixin {
  List<String> _claimed = [];
  late Map<String, dynamic> _stats;
  bool _isLoading = true;
  late TabController _tabCtrl;

  static const Color bgColor = Color(0xFF0F172A);
  static const Color cardColor = Color(0xFF1E293B);
  static const Color accent = Color(0xFF8B5CF6);
  static const Color pink = Color(0xFFD134B6);
  static const Color gold = Color(0xFFFFBB33);
  static const Color cyan = Color(0xFF06B6D4);
  static const Color green = Color(0xFF10B981);
  static const Color fire = Color(0xFFFF6B35);

  @override
  void initState() {
    super.initState();
    _stats = Map<String, dynamic>.from(widget.stats);
    _tabCtrl = TabController(length: 3, vsync: this);
    _load(showLoading: false);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool showLoading = false}) async {
    if (showLoading && mounted) {
      setState(() => _isLoading = true);
    }

    final results = await Future.wait<dynamic>([
      StatsService.getClaimedAchievements(),
      StatsService.fetchAllStats(),
    ]);

    if (mounted) {
      setState(() {
        _claimed = List<String>.from(results[0] as List);
        _stats = Map<String, dynamic>.from(results[1] as Map);
        _isLoading = false;
      });
    }
  }

  Map<String, int> _buildStatsForCheck() => {
    'completedBooks': _stats['completedBooks'] ?? 0,
    'totalPages': _stats['totalPages'] ?? 0,
    'longestStreak': _stats['longestStreak'] ?? 0,
    'level': _stats['level'] ?? 1,
    'libraryCount': _stats['libraryCount'] ?? 0,
    'uniqueGenres': _stats['uniqueGenres'] ?? 0,
    'uniqueAuthors': _stats['uniqueAuthors'] ?? 0,
    'topAuthorCount': _stats['topAuthorCount'] ?? 0,
  };

  bool _isUnlocked(Map<String, dynamic> a) =>
      StatsService.checkCondition(a, _buildStatsForCheck());

  int _currentValue(Map<String, dynamic> a) {
    final field = a['field'] as String? ?? '';
    final raw = _buildStatsForCheck()[field] ?? 0;
    return raw;
  }

  double _progress(Map<String, dynamic> a) {
    final threshold = a['threshold'] as int? ?? 1;
    if (threshold <= 0) return 1;
    return (_currentValue(a) / threshold).clamp(0.0, 1.0);
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Library':
        return cyan;
      case 'Finished':
        return gold;
      case 'Pages':
        return accent;
      case 'Streak':
        return fire;
      case 'Rank':
        return pink;
      case 'Discovery':
        return green;
      default:
        return accent;
    }
  }

  Future<void> _claim(Map<String, dynamic> a) async {
    AudioService.playAchievement();
    final int rewardXp = (a['xp'] as num?)?.toInt() ?? 0;
    final String title = a['title']?.toString() ?? 'Achievement';

    final result = await StatsService.claimAchievement(a['id'], rewardXp);

    if (!mounted) return;

    final String message = rewardXp > 0
        ? '🎉 Claimed "$title"! +$rewardXp XP'
        : '🎉 Claimed "$title" badge!';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    if (result['leveledUp'] == true) {
      LevelUpService.showLevelUp(
        result['newLevel'] as int,
        result['newTitle'] as String,
      );
    }

    // Refresh both the claimed badges and the latest XP/level stats immediately.
    // This prevents a delay where level-based achievements only appear after
    // leaving and reopening the profile/achievement pages.
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final all = StatsService.getAllAchievements();
    final unlocked = all.where(_isUnlocked).toList();
    final ready = unlocked.where((a) => !_claimed.contains(a['id'])).toList();
    final claimed = all.where((a) => _claimed.contains(a['id'])).toList();
    final locked = all.where((a) => !_isUnlocked(a)).toList();
    final pct = all.isEmpty ? 0.0 : _claimed.length / all.length;

    return Scaffold(
      backgroundColor: bgColor,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: accent, strokeWidth: 2),
            )
          : NestedScrollView(
              headerSliverBuilder: (_, __) => [
                SliverAppBar(
                  backgroundColor: bgColor,
                  elevation: 0,
                  pinned: true,
                  expandedHeight: 310,
                  leading: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  title: const Text(
                    'Achievements',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: _buildHero(pct, all.length, ready.length),
                  ),
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(54),
                    child: Container(
                      color: bgColor,
                      child: TabBar(
                        controller: _tabCtrl,
                        indicatorColor: gold,
                        indicatorWeight: 3,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white38,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                        tabs: [
                          Tab(text: 'Ready (${ready.length})'),
                          Tab(text: 'Claimed (${claimed.length})'),
                          Tab(text: 'Locked (${locked.length})'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildGrid(ready, AchievementListType.ready),
                  _buildGrid(claimed, AchievementListType.claimed),
                  _buildGrid(locked, AchievementListType.locked),
                ],
              ),
            ),
    );
  }

  Widget _buildHero(double pct, int total, int readyCount) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF23104F), bgColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(top: 38, right: -35, child: _glowOrb(pink, 130)),
          Positioned(bottom: 26, left: -45, child: _glowOrb(cyan, 150)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 64, 20, 72),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [gold, pink, accent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: gold.withOpacity(0.28),
                              blurRadius: 28,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text('🏆', style: TextStyle(fontSize: 36)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Badge Vault',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              readyCount > 0
                                  ? '$readyCount badge${readyCount == 1 ? '' : 's'} ready to claim'
                                  : 'Keep reading to unlock more rewards',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.50),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _buildProgressBanner(pct, total),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glowOrb(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withOpacity(0.22), Colors.transparent],
        ),
      ),
    );
  }

  Widget _buildProgressBanner(double pct, int total) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            height: 58,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: pct,
                  backgroundColor: Colors.white.withOpacity(0.10),
                  valueColor: const AlwaysStoppedAnimation<Color>(gold),
                  strokeWidth: 6,
                ),
                Text(
                  '${(pct * 100).toInt()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_claimed.length} / $total badges claimed',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 8,
                    backgroundColor: Colors.white.withOpacity(0.10),
                    valueColor: const AlwaysStoppedAnimation<Color>(gold),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${total - _claimed.length} remaining to collect',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.42),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(
    List<Map<String, dynamic>> items,
    AchievementListType type,
  ) {
    if (items.isEmpty) {
      final empty = _emptyState(type);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(empty.$1, style: const TextStyle(fontSize: 54)),
              const SizedBox(height: 14),
              Text(
                empty.$2,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                empty.$3,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.38),
                  fontSize: 13,
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 520 ? 3 : 2;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          physics: const BouncingScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.56,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) => _buildBadgeCard(items[i], type),
        );
      },
    );
  }

  (String, String, String) _emptyState(AchievementListType type) {
    switch (type) {
      case AchievementListType.ready:
        return (
          '✨',
          'No badges ready yet',
          'Reach a milestone, then come back to claim your XP reward.',
        );
      case AchievementListType.claimed:
        return (
          '🏅',
          'No claimed badges yet',
          'Unlocked badges will appear here after you claim them.',
        );
      case AchievementListType.locked:
        return (
          '🎉',
          'All badges unlocked',
          'You have completed every achievement in the vault.',
        );
    }
  }

  Widget _buildBadgeCard(Map<String, dynamic> a, AchievementListType type) {
    final isUnlocked = _isUnlocked(a);
    final isClaimed = _claimed.contains(a['id']);
    final category = a['category'] as String? ?? 'General';
    final categoryColor = _categoryColor(category);
    final progress = _progress(a);
    final current = _currentValue(a);
    final threshold = a['threshold'] as int? ?? 0;

    final Color borderColor = isClaimed
        ? categoryColor.withOpacity(0.45)
        : isUnlocked
        ? gold.withOpacity(0.55)
        : Colors.white.withOpacity(0.07);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      padding: const EdgeInsets.all(1.2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: isUnlocked || isClaimed
            ? LinearGradient(
                colors: [borderColor, categoryColor.withOpacity(0.20)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isUnlocked || isClaimed ? null : cardColor,
        boxShadow: isUnlocked || isClaimed
            ? [
                BoxShadow(
                  color: categoryColor.withOpacity(0.14),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(23),
          border: Border.all(color: borderColor, width: 0.7),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _categoryPill(category, categoryColor, isUnlocked),
                if (isClaimed)
                  Icon(
                    Icons.check_circle_rounded,
                    color: categoryColor,
                    size: 18,
                  )
                else if (!isUnlocked)
                  Icon(
                    Icons.lock_rounded,
                    color: Colors.white.withOpacity(0.22),
                    size: 17,
                  ),
              ],
            ),
            const Spacer(),
            _buildBadgeIcon(a, isUnlocked, isClaimed, categoryColor),
            const SizedBox(height: 12),
            Text(
              a['title'],
              style: TextStyle(
                color: isUnlocked || isClaimed ? Colors.white : Colors.white38,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 5),
            Text(
              a['description'],
              style: TextStyle(
                color: Colors.white.withOpacity(
                  isUnlocked || isClaimed ? 0.42 : 0.26,
                ),
                fontSize: 11,
                height: 1.25,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            if (!isUnlocked) ...[
              _miniProgress(progress, current, threshold, categoryColor),
              const SizedBox(height: 10),
            ],
            _buildActionButton(a, isUnlocked, isClaimed),
          ],
        ),
      ),
    );
  }

  Widget _categoryPill(String category, Color color, bool isUnlocked) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(isUnlocked ? 0.14 : 0.07),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(isUnlocked ? 0.25 : 0.10)),
      ),
      child: Text(
        category,
        style: TextStyle(
          color: isUnlocked ? color : Colors.white.withOpacity(0.26),
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _achievementAsset(
    Map<String, dynamic> achievement, {
    double size = 42,
    double fallbackSize = 28,
  }) {
    final asset = achievement['asset']?.toString();
    final icon = achievement['icon']?.toString() ?? '🏅';

    if (asset == null || asset.isEmpty) {
      return Text(icon, style: TextStyle(fontSize: fallbackSize));
    }

    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) =>
          Text(icon, style: TextStyle(fontSize: fallbackSize)),
    );
  }

  Widget _buildBadgeIcon(
    Map<String, dynamic> a,
    bool unlocked,
    bool isClaimed,
    Color color,
  ) {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (unlocked || isClaimed)
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [color.withOpacity(0.26), Colors.transparent],
              ),
            ),
          ),
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: unlocked || isClaimed
                ? LinearGradient(
                    colors: [color.withOpacity(0.28), color.withOpacity(0.08)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: unlocked || isClaimed
                ? null
                : Colors.white.withOpacity(0.04),
            border: Border.all(
              color: unlocked || isClaimed
                  ? color.withOpacity(0.40)
                  : Colors.white.withOpacity(0.08),
              width: 2,
            ),
          ),
          child: Center(
            child: unlocked || isClaimed
                ? _achievementAsset(a, size: 46, fallbackSize: 30)
                : Text(
                    '🔒',
                    style: TextStyle(fontSize: 30, color: Colors.white12),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _miniProgress(
    double progress,
    int current,
    int threshold,
    Color color,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progress',
              style: TextStyle(
                color: Colors.white.withOpacity(0.28),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '$current / $threshold',
              style: TextStyle(
                color: Colors.white.withOpacity(0.38),
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: Colors.white.withOpacity(0.06),
            valueColor: AlwaysStoppedAnimation<Color>(color.withOpacity(0.8)),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    Map<String, dynamic> a,
    bool unlocked,
    bool isClaimed,
  ) {
    if (!unlocked) {
      return _pill(
        a['xp'] > 0 ? '+${a['xp']} XP' : 'Badge reward',
        Colors.white.withOpacity(0.07),
        Colors.white.withOpacity(0.08),
        Colors.white.withOpacity(0.25),
        null,
      );
    }
    if (isClaimed) {
      return _pill(
        '✓ Claimed',
        accent.withOpacity(0.14),
        accent.withOpacity(0.34),
        accent,
        null,
      );
    }
    return _pill(
      a['xp'] > 0 ? 'Claim +${a['xp']} XP' : 'Claim Badge',
      gold.withOpacity(0.16),
      gold.withOpacity(0.48),
      gold,
      () => _claim(a),
    );
  }

  Widget _pill(
    String label,
    Color bg,
    Color border,
    Color text,
    VoidCallback? onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: text,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

enum AchievementListType { ready, claimed, locked }

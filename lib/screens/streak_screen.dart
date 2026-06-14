import 'package:flutter/material.dart';
import '../services/stats_service.dart';
import '../services/xp_service.dart';

class StreakScreen extends StatefulWidget {
  final int currentStreak;
  final int longestStreak;

  const StreakScreen({
    super.key,
    required this.currentStreak,
    required this.longestStreak,
  });

  @override
  State<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends State<StreakScreen>
    with SingleTickerProviderStateMixin {
  Set<String> _readingDays = {};
  bool _isLoading = true;
  DateTime _displayMonth = DateTime.now();

  // Display-only current streak. This prevents StreakScreen from showing an
  // old Firestore value after the user misses more than one day.
  late int _displayCurrentStreak;
  late int _displayLongestStreak;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  static const Color bgColor = Color(0xFF0F172A);
  static const Color cardColor = Color(0xFF1E293B);
  static const Color accent = Color(0xFF8B5CF6);
  static const Color fire = Color(0xFFFF6B35);
  static const Color gold = Color(0xFFFFBB33);

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.88,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _displayCurrentStreak = widget.currentStreak;
    _displayLongestStreak = widget.longestStreak;

    _load();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final days = await StatsService.getReadingDays();

    // fetchAllStats() returns the corrected display streak, not the stale
    // Firestore currentStreak value.
    Map<String, dynamic> stats = {};
    try {
      stats = await StatsService.fetchAllStats();
    } catch (_) {}

    if (mounted) {
      setState(() {
        _readingDays = days;
        _displayCurrentStreak = stats['currentStreak'] ?? widget.currentStreak;
        _displayLongestStreak = stats['longestStreak'] ?? widget.longestStreak;
        _isLoading = false;
      });
    }
  }

  bool _wasReadOn(DateTime date) =>
      _readingDays.contains(XpService.dateKey(date));

  int _readDaysInMonth() {
    final daysInMonth = DateTime(
      _displayMonth.year,
      _displayMonth.month + 1,
      0,
    ).day;
    int count = 0;
    for (int d = 1; d <= daysInMonth; d++) {
      if (_wasReadOn(DateTime(_displayMonth.year, _displayMonth.month, d))) {
        count++;
      }
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: accent, strokeWidth: 2),
            )
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  backgroundColor: bgColor,
                  elevation: 0,
                  pinned: true,
                  leading: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  title: const Text(
                    'Streak Calendar',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    child: Column(
                      children: [
                        _buildHeroCard(),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                '🔥',
                                '$_displayCurrentStreak',
                                'Current',
                                fire,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                '🏆',
                                '$_displayLongestStreak',
                                'Best',
                                gold,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                '📅',
                                '${_readDaysInMonth()}',
                                'This Month',
                                accent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildXpRewardCard(),
                        const SizedBox(height: 24),
                        _buildCalendarCard(),
                        const SizedBox(height: 20),
                        _buildLegend(),
                        const SizedBox(height: 20),
                        _buildMotivationCard(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeroCard() {
    final streak = _displayCurrentStreak;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1040), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: fire.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: fire.withOpacity(0.10),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, child) => Transform.scale(
              scale: streak > 0 ? _pulseAnim.value : 1.0,
              child: child,
            ),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fire.withOpacity(0.12),
                border: Border.all(color: fire.withOpacity(0.3), width: 2),
                boxShadow: streak > 0
                    ? [BoxShadow(color: fire.withOpacity(0.3), blurRadius: 20)]
                    : null,
              ),
              child: const Center(
                child: Text('🔥', style: TextStyle(fontSize: 38)),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$streak',
                      style: TextStyle(
                        color: fire,
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 6),
                      child: Text(
                        'day${streak == 1 ? '' : 's'}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _getMotivationalMessage(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String emoji, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.35),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _navBtn(
                Icons.chevron_left_rounded,
                () => setState(
                  () => _displayMonth = DateTime(
                    _displayMonth.year,
                    _displayMonth.month - 1,
                  ),
                ),
              ),
              Column(
                children: [
                  Text(
                    _monthName(_displayMonth),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  Text(
                    '${_readDaysInMonth()} reading days',
                    style: TextStyle(
                      color: accent.withOpacity(0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              _navBtn(
                Icons.chevron_right_rounded,
                () => setState(
                  () => _displayMonth = DateTime(
                    _displayMonth.year,
                    _displayMonth.month + 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.25),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          _buildCalendarGrid(),
        ],
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white.withOpacity(0.5), size: 20),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDay = DateTime(_displayMonth.year, _displayMonth.month, 1);
    final daysInMonth = DateTime(
      _displayMonth.year,
      _displayMonth.month + 1,
      0,
    ).day;
    final startOffset = firstDay.weekday - 1;
    final today = DateTime.now();
    final List<Widget> cells = [];

    for (int i = 0; i < startOffset; i++) cells.add(const SizedBox());

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_displayMonth.year, _displayMonth.month, day);
      final isToday =
          date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
      final wasRead = _wasReadOn(date);
      final isFuture = date.isAfter(today);

      BoxDecoration deco;
      Color textCol;

      if (isToday) {
        deco = BoxDecoration(
          shape: BoxShape.circle,
          color: fire,
          boxShadow: [BoxShadow(color: fire.withOpacity(0.5), blurRadius: 8)],
        );
        textCol = Colors.white;
      } else if (wasRead) {
        deco = BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFFD134B6)],
          ),
          boxShadow: [BoxShadow(color: accent.withOpacity(0.3), blurRadius: 6)],
        );
        textCol = Colors.white;
      } else {
        deco = BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.04),
        );
        textCol = isFuture
            ? Colors.white.withOpacity(0.1)
            : Colors.white.withOpacity(0.3);
      }

      cells.add(
        Container(
          margin: const EdgeInsets.all(2),
          decoration: deco,
          child: Center(
            child: Text(
              '$day',
              style: TextStyle(
                color: textCol,
                fontSize: 12,
                fontWeight: isToday || wasRead
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
        ),
      );
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 7,
      childAspectRatio: 1,
      children: cells,
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendDot(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFFD134B6)],
          ),
          label: 'Read',
        ),
        const SizedBox(width: 20),
        _legendDot(solid: Colors.white12, label: 'No reading'),
        const SizedBox(width: 20),
        _legendDot(solid: fire, label: 'Today'),
      ],
    );
  }

  Widget _legendDot({Gradient? gradient, Color? solid, required String label}) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: gradient,
            color: solid,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12),
        ),
      ],
    );
  }

  int _dailyStreakXp(int streak) {
    if (streak >= 100) return 50;
    if (streak >= 30) return 30;
    if (streak >= 7) return 25;
    if (streak >= 3) return 20;
    return 15;
  }

  int? _nextXpMilestone(int streak) {
    const milestones = [3, 7, 30, 100];
    for (final milestone in milestones) {
      if (streak < milestone) return milestone;
    }
    return null;
  }

  Widget _buildXpRewardCard() {
    final streak = _displayCurrentStreak;
    final currentXp = _dailyStreakXp(streak);
    final nextMilestone = _nextXpMilestone(streak);
    final nextXp = nextMilestone == null ? null : _dailyStreakXp(nextMilestone);
    final daysLeft = nextMilestone == null ? 0 : nextMilestone - streak;

    String subtitle;
    if (streak == 0) {
      subtitle = 'Read today to earn your first +15 XP streak bonus.';
    } else if (nextMilestone == null) {
      subtitle =
          'Maximum streak reward unlocked. Keep reading daily to keep earning +50 XP.';
    } else {
      subtitle =
          '$daysLeft more day${daysLeft == 1 ? '' : 's'} to unlock +$nextXp XP/day at $nextMilestone days.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: gold.withOpacity(0.20)),
        gradient: LinearGradient(
          colors: [gold.withOpacity(0.08), cardColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: gold.withOpacity(0.14),
                  border: Border.all(color: gold.withOpacity(0.30)),
                ),
                child: const Center(
                  child: Text('⚡', style: TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '+$currentXp XP/day',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Current daily streak reward',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.42),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 12.5,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildRewardTier('1–2', '15 XP', streak < 3)),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRewardTier(
                  '3+',
                  '20 XP',
                  streak >= 3 && streak < 7,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRewardTier(
                  '7+',
                  '25 XP',
                  streak >= 7 && streak < 30,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRewardTier(
                  '30+',
                  '30 XP',
                  streak >= 30 && streak < 100,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: _buildRewardTier('100+', '50 XP', streak >= 100)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRewardTier(String dayLabel, String xpLabel, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: isActive
            ? gold.withOpacity(0.16)
            : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? gold.withOpacity(0.45)
              : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Column(
        children: [
          Text(
            dayLabel,
            style: TextStyle(
              color: isActive ? gold : Colors.white.withOpacity(0.35),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            xpLabel,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white.withOpacity(0.32),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMotivationCard() {
    final streak = _displayCurrentStreak;
    const milestones = [3, 7, 30, 100];
    final next = milestones.firstWhere((m) => m > streak, orElse: () => 365);
    final prev = milestones.lastWhere((m) => m <= streak, orElse: () => 0);
    final progress = (prev == next)
        ? 1.0
        : (streak - prev) / (next - prev).toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.2)),
        gradient: LinearGradient(
          colors: [accent.withOpacity(0.07), cardColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Text(
            _getMotivationalMessage(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            streak == 0
                ? 'Log your first reading session to begin.'
                : 'Keep reading every day to maintain your streak!',
            style: TextStyle(
              color: Colors.white.withOpacity(0.35),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          if (streak > 0) ...[
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$streak days',
                  style: TextStyle(
                    color: fire,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  next >= 100 && streak >= 100
                      ? 'Max reward unlocked'
                      : 'Next: $next days',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Stack(
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [fire, gold]),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _monthName(DateTime d) {
    const m = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${m[d.month - 1]} ${d.year}';
  }

  String _getMotivationalMessage() {
    final s = _displayCurrentStreak;
    if (s == 0) return ' Start your streak today!';
    if (s < 3) return '📚 Great start! Keep it up!';
    if (s < 7) return '🔥 You\'re on fire! $s days!';
    if (s < 30) return '⚡ Incredible! $s day streak!';
    if (s < 100) return '🌋 Legendary! $s day streak!';
    return '👁️ Mythic reader! $s days!';
  }
}

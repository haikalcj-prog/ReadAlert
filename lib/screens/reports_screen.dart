import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/stats_service.dart';

class ReportsScreen extends StatefulWidget {
  final Map<String, dynamic> stats;
  final int initialTabIndex;

  const ReportsScreen({
    super.key,
    required this.stats,
    this.initialTabIndex = 0,
  });

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with TickerProviderStateMixin {
  late TabController _tabCtrl;
  int _touchedIndex = -1;

  int _weekOffset = 0;
  int _monthOffset = 0;
  int _yearOffset = 0;

  Map<String, dynamic> _weeklyReportStats = {};
  Map<String, dynamic> _monthlyReportStats = {};
  Map<String, dynamic> _yearlyReportStats = {};

  bool _loadingWeekly = false;
  bool _loadingMonthly = false;
  bool _loadingYearly = false;

  static const Color bgColor = Color(0xFF0F172A);
  static const Color cardColor = Color(0xFF1E293B);
  static const Color card2 = Color(0xFF243044);
  static const Color accent = Color(0xFF8B5CF6);
  static const Color pink = Color(0xFFD134B6);
  static const Color teal = Color(0xFF06B6D4);
  static const Color green = Color(0xFF10B981);
  static const Color gold = Color(0xFFFFBB33);
  static const Color fire = Color(0xFFFF6B35);

  static const List<String> _monthNamesFull = [
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

  @override
  void initState() {
    super.initState();
    final safeInitialIndex = widget.initialTabIndex.clamp(0, 2).toInt();
    _tabCtrl = TabController(
      length: 3,
      vsync: this,
      initialIndex: safeInitialIndex,
    );
    _tabCtrl.addListener(() {
      if (mounted) setState(() => _touchedIndex = -1);
    });

    _weeklyReportStats = Map<String, dynamic>.from(widget.stats);
    _monthlyReportStats = Map<String, dynamic>.from(widget.stats);
    _yearlyReportStats = Map<String, dynamic>.from(widget.stats);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPeriodStats('weekly');
      _loadPeriodStats('monthly');
      _loadPeriodStats('yearly');
    });
  }

  Future<void> _loadPeriodStats(String period) async {
    if (!mounted) return;

    final int offset = period == 'monthly'
        ? _monthOffset
        : period == 'yearly'
        ? _yearOffset
        : _weekOffset;

    setState(() {
      if (period == 'monthly') {
        _loadingMonthly = true;
      } else if (period == 'yearly') {
        _loadingYearly = true;
      } else {
        _loadingWeekly = true;
      }
    });

    try {
      final data = await StatsService.fetchReportStatsForPeriod(
        period: period,
        offset: offset,
      );
      if (!mounted) return;
      setState(() {
        if (period == 'monthly') {
          _monthlyReportStats = data;
        } else if (period == 'yearly') {
          _yearlyReportStats = data;
        } else {
          _weeklyReportStats = data;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load $period report: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        if (period == 'monthly') {
          _loadingMonthly = false;
        } else if (period == 'yearly') {
          _loadingYearly = false;
        } else {
          _loadingWeekly = false;
        }
      });
    }
  }

  void _movePeriod(String period, int direction) {
    setState(() {
      _touchedIndex = -1;
      if (period == 'monthly') {
        _monthOffset += direction;
        if (_monthOffset > 0) _monthOffset = 0;
      } else if (period == 'yearly') {
        _yearOffset += direction;
        if (_yearOffset > 0) _yearOffset = 0;
      } else {
        _weekOffset += direction;
        if (_weekOffset > 0) _weekOffset = 0;
      }
    });
    _loadPeriodStats(period);
  }

  bool _canGoNext(String period) {
    if (period == 'monthly') return _monthOffset < 0;
    if (period == 'yearly') return _yearOffset < 0;
    return _weekOffset < 0;
  }

  DateTime _weekStartFromOffset(int offset) {
    final target = DateTime.now().add(Duration(days: offset * 7));
    final targetDay = DateTime(target.year, target.month, target.day);
    return targetDay.subtract(Duration(days: targetDay.weekday - 1));
  }

  String _shortDate(DateTime date) {
    return '${date.day} ${_monthNamesFull[date.month - 1].substring(0, 3)}';
  }

  String get _selectedWeekLabel {
    final start = _weekStartFromOffset(_weekOffset);
    final end = start.add(const Duration(days: 6));
    if (_weekOffset == 0) return 'This Week';
    return '${_shortDate(start)} - ${_shortDate(end)} ${end.year}';
  }

  String get _selectedMonthYear {
    final now = DateTime.now();
    final target = DateTime(now.year, now.month + _monthOffset, 1);
    return '${_monthNamesFull[target.month - 1]} ${target.year}';
  }

  String get _selectedYearLabel {
    return (DateTime.now().year + _yearOffset).toString();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            backgroundColor: bgColor,
            elevation: 0,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Reading Reports',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            bottom: TabBar(
              controller: _tabCtrl,
              indicatorColor: accent,
              indicatorWeight: 3,
              labelColor: accent,
              unselectedLabelColor: Colors.white38,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: 'Weekly'),
                Tab(text: 'Monthly'),
                Tab(text: 'Yearly'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [_buildWeekly(), _buildMonthly(), _buildYearly()],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  //  WEEKLY TAB
  // ════════════════════════════════════════════════════════
  Widget _buildWeekly() {
    final Map<int, int> raw = Map<int, int>.from(
      _weeklyReportStats['weeklyPages'] ?? widget.stats['weeklyPages'] ?? {},
    );
    final data = [for (int i = 0; i < 7; i++) raw[i] ?? 0];
    final total = data.fold(0, (a, b) => a + b);
    final avg = total ~/ 7;
    final today = _weekOffset == 0 ? DateTime.now().weekday - 1 : -1;
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final bestIdx = _bestIndex(data);
    final activeDays = data.where((v) => v > 0).length;

    return _tabScroll(
      children: [
        _periodNavigator(
          emoji: '📆',
          title: _selectedWeekLabel,
          subtitle: _weekOffset == 0
              ? 'Current weekly report'
              : 'Previous weekly report',
          color: accent,
          period: 'weekly',
          isLoading: _loadingWeekly,
        ),
        const SizedBox(height: 20),

        // Heatmap-style day cards
        _sectionLabel('DAILY ACTIVITY'),
        const SizedBox(height: 12),
        _buildDayHeatmap(data, labels, today, [accent, pink]),

        const SizedBox(height: 20),

        // Bar chart
        _sectionLabel('PAGES PER DAY'),
        const SizedBox(height: 12),
        _chartCard(
          child: _barChart(
            data: data,
            labels: labels,
            highlightIdx: today,
            touchedIdx: _touchedIndex,
            onTouch: (i) => setState(() => _touchedIndex = i),
            color1: accent,
            color2: pink,
          ),
        ),

        const SizedBox(height: 20),

        // KPI row
        _sectionLabel(_weekOffset == 0 ? 'THIS WEEK' : 'SELECTED WEEK'),
        const SizedBox(height: 12),
        _kpiGrid([
          _Kpi('📖', '$total', 'Total Pages', accent),
          _Kpi('📊', '$avg', 'Daily Avg', green),
          _Kpi('🔥', '$activeDays / 7', 'Active Days', fire),
          _Kpi('🏆', labels[bestIdx], 'Best Day', gold),
        ]),

        const SizedBox(height: 20),

        // Insight cards
        _sectionLabel('INSIGHTS'),
        const SizedBox(height: 12),
        _insightCard(
          '🔥',
          'Best day',
          '${labels[bestIdx]} with ${data[bestIdx]} pages',
          gold,
        ),
        _insightCard('📅', 'Active days', '$activeDays out of 7 days', accent),
        if (avg > 0)
          _insightCard(
            '📈',
            'Monthly projection',
            '${avg * 30} pages at this rate',
            green,
          ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════
  //  MONTHLY TAB
  // ════════════════════════════════════════════════════════
  Widget _buildMonthly() {
    final Map<int, int> raw = Map<int, int>.from(
      _monthlyReportStats['monthlyPages'] ?? widget.stats['monthlyPages'] ?? {},
    );
    final data = [for (int i = 1; i <= 6; i++) raw[i] ?? 0];
    final total = data.fold(0, (a, b) => a + b);
    final avg = data.isEmpty ? 0 : total ~/ data.length;
    final nowW = _monthOffset == 0
        ? _calendarWeekIndexInMonth(DateTime.now()) - 1
        : -1;
    const labels = ['W1', 'W2', 'W3', 'W4', 'W5', 'W6'];
    final bestIdx = _bestIndex(data);

    return _tabScroll(
      children: [
        _periodNavigator(
          emoji: '📅',
          title: _selectedMonthYear,
          subtitle: _monthOffset == 0
              ? 'Current monthly report'
              : 'Previous monthly report',
          color: teal,
          period: 'monthly',
          isLoading: _loadingMonthly,
        ),
        const SizedBox(height: 20),

        _sectionLabel('PAGES PER WEEK'),
        const SizedBox(height: 12),
        _chartCard(
          child: _barChart(
            data: data,
            labels: labels,
            highlightIdx: nowW,
            touchedIdx: _touchedIndex,
            onTouch: (i) => setState(() => _touchedIndex = i),
            color1: teal,
            color2: accent,
            showValues: true,
          ),
        ),

        const SizedBox(height: 20),

        // Progress toward month goal (simple fill card)
        _sectionLabel('MONTHLY PROGRESS'),
        const SizedBox(height: 12),
        _progressCard(
          current: total,
          label: 'pages read in $_selectedMonthYear',
          color: teal,
          subLabel: 'Best week: ${labels[bestIdx]} with ${data[bestIdx]} pages',
        ),

        const SizedBox(height: 20),

        _sectionLabel(
          '${_monthOffset == 0 ? 'THIS MONTH' : 'SELECTED MONTH'} • $_selectedMonthYear',
        ),
        const SizedBox(height: 12),
        _kpiGrid([
          _Kpi('📖', '$total', 'Total Pages', teal),
          _Kpi('📊', '$avg', 'Weekly Avg', green),
          _Kpi('🏆', labels[bestIdx], 'Best Week', gold),
          _Kpi(
            '📅',
            '${data.where((v) => v > 0).length} / ${data.length}',
            'Active Weeks',
            accent,
          ),
        ]),

        const SizedBox(height: 20),

        _sectionLabel('INSIGHTS'),
        const SizedBox(height: 12),
        _insightCard(
          '🏆',
          'Best week',
          '${labels[bestIdx]} — ${data[bestIdx]} pages',
          gold,
        ),
        _insightCard('📊', 'Weekly average', '$avg pages per week', teal),
        if (avg > 0)
          _insightCard(
            '📈',
            'Yearly projection',
            '${avg * 48} pages at this rate',
            green,
          ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════
  //  YEARLY TAB
  // ════════════════════════════════════════════════════════
  Widget _buildYearly() {
    final Map<int, int> raw = Map<int, int>.from(
      _yearlyReportStats['yearlyPages'] ?? widget.stats['yearlyPages'] ?? {},
    );
    final data = [for (int i = 1; i <= 12; i++) raw[i] ?? 0];
    final total = data.fold(0, (a, b) => a + b);
    final avg = total ~/ 12;
    final nowMonth = _yearOffset == 0 ? DateTime.now().month - 1 : -1;
    const labels = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final bestIdx = _bestIndex(data);
    final activeM = data.where((v) => v > 0).length;

    return _tabScroll(
      children: [
        _periodNavigator(
          emoji: '📚',
          title: '$_selectedYearLabel Reading Summary',
          subtitle: _yearOffset == 0
              ? 'Current yearly report'
              : 'Previous yearly report',
          color: pink,
          period: 'yearly',
          isLoading: _loadingYearly,
        ),
        const SizedBox(height: 20),

        // Line chart for the full year
        _sectionLabel('PAGES PER MONTH'),
        const SizedBox(height: 12),
        _chartCard(
          height: 220,
          child: _lineChart(
            data: data,
            labels: labels,
            highlightIdx: nowMonth,
            onTouch: (i) => setState(() => _touchedIndex = i),
          ),
        ),

        const SizedBox(height: 20),

        // Monthly breakdown mini bars
        _sectionLabel('MONTH BREAKDOWN'),
        const SizedBox(height: 12),
        _buildMonthGrid(data, labels, nowMonth),

        const SizedBox(height: 20),

        _sectionLabel(
          '${_yearOffset == 0 ? 'THIS YEAR' : 'SELECTED YEAR'} • $_selectedYearLabel',
        ),
        const SizedBox(height: 12),
        _kpiGrid([
          _Kpi('📖', '$total', 'Total Pages', pink),
          _Kpi('📊', '$avg', 'Monthly Avg', green),
          _Kpi('🏆', labels[bestIdx], 'Best Month', gold),
          _Kpi('📅', '$activeM / 12', 'Active Months', accent),
        ]),

        const SizedBox(height: 20),

        _sectionLabel('INSIGHTS'),
        const SizedBox(height: 12),
        _insightCard(
          '🏆',
          'Best month',
          '${labels[bestIdx]} — ${data[bestIdx]} pages',
          gold,
        ),
        _insightCard('📊', 'Monthly average', '$avg pages per month', pink),
        _insightCard('📅', 'Active months', '$activeM out of 12', accent),
        _insightCard(
          '📚',
          'Books completed',
          '${_yearlyReportStats['booksCompleted'] ?? widget.stats['completedBooks'] ?? 0} books',
          green,
        ),
        _insightCard(
          '🔥',
          'Longest streak',
          '${widget.stats['longestStreak'] ?? 0} days',
          fire,
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════
  //  CHART WIDGETS
  // ════════════════════════════════════════════════════════

  /// Day heatmap — coloured squares like GitHub contributions
  Widget _buildDayHeatmap(
    List<int> data,
    List<String> labels,
    int today,
    List<Color> colors,
  ) {
    final maxVal = data.isEmpty ? 1 : data.reduce((a, b) => a > b ? a : b);
    return Row(
      children: List.generate(7, (i) {
        final val = data[i];
        final intensity = maxVal == 0 ? 0.0 : val / maxVal;
        final isToday = i == today;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: Duration(milliseconds: 300 + i * 50),
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: isToday
                        ? LinearGradient(
                            colors: [pink, accent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isToday
                        ? null
                        : val == 0
                        ? Colors.white.withOpacity(0.05)
                        : Color.lerp(
                            colors[0].withOpacity(0.15),
                            colors[0],
                            intensity,
                          ),
                    border: Border.all(
                      color: isToday
                          ? pink.withOpacity(0.5)
                          : Colors.white.withOpacity(0.06),
                    ),
                    boxShadow: val > 0 && !isToday
                        ? [
                            BoxShadow(
                              color: colors[0].withOpacity(intensity * 0.4),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: val > 0
                        ? Text(
                            '$val',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  labels[i].substring(0, 1),
                  style: TextStyle(
                    color: isToday ? accent : Colors.white.withOpacity(0.3),
                    fontSize: 10,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  /// Monthly grid — 3-column blocks with fill bars
  Widget _buildMonthGrid(List<int> data, List<String> labels, int nowMonth) {
    final maxVal = data.isEmpty ? 1 : data.reduce((a, b) => a > b ? a : b);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.1,
      ),
      itemCount: 12,
      itemBuilder: (_, i) {
        final val = data[i];
        final pct = maxVal == 0 ? 0.0 : val / maxVal;
        final isNow = i == nowMonth;
        final hasPassed = i < nowMonth;
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isNow ? accent.withOpacity(0.15) : cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isNow
                  ? accent.withOpacity(0.5)
                  : Colors.white.withOpacity(0.05),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                labels[i],
                style: TextStyle(
                  color: isNow ? accent : Colors.white.withOpacity(0.5),
                  fontSize: 10,
                  fontWeight: isNow ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              Text(
                '$val',
                style: TextStyle(
                  color: isNow
                      ? Colors.white
                      : hasPassed && val > 0
                      ? Colors.white.withOpacity(0.8)
                      : Colors.white.withOpacity(0.3),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 3,
                  backgroundColor: Colors.white.withOpacity(0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isNow ? accent : pink.withOpacity(0.6),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _barChart({
    required List<int> data,
    required List<String> labels,
    required int highlightIdx,
    required int touchedIdx,
    required ValueChanged<int> onTouch,
    required Color color1,
    required Color color2,
    bool showValues = false,
  }) {
    final maxY = data.isEmpty
        ? 10.0
        : data.reduce((a, b) => a > b ? a : b).toDouble();
    final chartMax = maxY <= 0 ? 10.0 : maxY * 1.4;

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          maxY: chartMax,
          barTouchData: BarTouchData(
            enabled: true,
            touchCallback: (event, resp) {
              onTouch(resp?.spot?.touchedBarGroupIndex ?? -1);
            },
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: card2,
              tooltipRoundedRadius: 10,
              tooltipPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                '${rod.toY.toInt()} pages',
                TextStyle(
                  color: color1,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, _) {
                  final i = value.toInt();
                  if (i < 0 || i >= labels.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        color: i == highlightIdx
                            ? color1
                            : Colors.white.withOpacity(0.3),
                        fontSize: 10,
                        fontWeight: i == highlightIdx
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(data.length, (i) {
            final isTouched = touchedIdx == i;
            final isHighlight = i == highlightIdx;
            final val = data[i].toDouble();
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: val,
                  width: isTouched ? 24 : 18,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                  gradient: val > 0
                      ? LinearGradient(
                          colors: isHighlight || isTouched
                              ? [color2, color1]
                              : [color1.withOpacity(0.6), color1],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        )
                      : LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.06),
                            Colors.white.withOpacity(0.03),
                          ],
                        ),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: chartMax,
                    color: Colors.white.withOpacity(0.025),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _lineChart({
    required List<int> data,
    required List<String> labels,
    required int highlightIdx,
    required ValueChanged<int> onTouch,
  }) {
    final maxY = data.isEmpty
        ? 10.0
        : data.reduce((a, b) => a > b ? a : b).toDouble();
    final chartMax = maxY <= 0 ? 10.0 : maxY * 1.3;

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          maxY: chartMax,
          minY: 0,
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: card2,
              tooltipRoundedRadius: 10,
              getTooltipItems: (spots) => spots
                  .map(
                    (s) => LineTooltipItem(
                      '${s.y.toInt()} pages',
                      TextStyle(
                        color: pink,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 2,
                getTitlesWidget: (value, _) {
                  final i = value.toInt();
                  if (i < 0 || i >= labels.length || i % 2 != 0) {
                    return const SizedBox();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        color: i == highlightIdx
                            ? pink
                            : Colors.white.withOpacity(0.3),
                        fontSize: 10,
                        fontWeight: i == highlightIdx
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(
                data.length,
                (i) => FlSpot(i.toDouble(), data[i].toDouble()),
              ),
              isCurved: true,
              gradient: const LinearGradient(
                colors: [accent, pink],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, _, __, i) => FlDotCirclePainter(
                  radius: i == highlightIdx ? 7 : (spot.y > 0 ? 4 : 2),
                  color: i == highlightIdx
                      ? pink
                      : (spot.y > 0 ? accent : Colors.white24),
                  strokeWidth: i == highlightIdx ? 2 : 0,
                  strokeColor: Colors.white.withOpacity(0.6),
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [accent.withOpacity(0.3), Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  //  REUSABLE LAYOUT HELPERS
  // ════════════════════════════════════════════════════════

  Widget _periodNavigator({
    required String emoji,
    required String title,
    required String subtitle,
    required Color color,
    required String period,
    required bool isLoading,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.18)),
        gradient: LinearGradient(
          colors: [color.withOpacity(0.14), cardColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _periodArrow(
                icon: Icons.chevron_left_rounded,
                color: color,
                onTap: () => _movePeriod(period, -1),
              ),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 21)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.42),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _periodArrow(
                icon: Icons.chevron_right_rounded,
                color: color,
                isEnabled: _canGoNext(period),
                onTap: () => _movePeriod(period, 1),
              ),
            ],
          ),
          if (isLoading) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 3,
                backgroundColor: Colors.white.withOpacity(0.06),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _periodArrow({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isEnabled = true,
  }) {
    return Opacity(
      opacity: isEnabled ? 1 : 0.35,
      child: GestureDetector(
        onTap: isEnabled ? onTap : null,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Icon(icon, color: color, size: 26),
        ),
      ),
    );
  }

  Widget _tabScroll({required List<Widget> children}) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _chartCard({required Widget child, double height = 240}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: child,
    );
  }

  Widget _progressCard({
    required int current,
    required String label,
    required Color color,
    String? subLabel,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$current',
                style: TextStyle(
                  color: color,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (subLabel != null) ...[
            const SizedBox(height: 8),
            Text(
              subLabel,
              style: TextStyle(
                color: Colors.white.withOpacity(0.25),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kpiGrid(List<_Kpi> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.9,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final kpi = items[i];
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: kpi.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(kpi.emoji, style: const TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      kpi.label,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.35),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      kpi.value,
                      style: TextStyle(
                        color: kpi.color,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _insightCard(String emoji, String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 13,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 0),
    child: Text(
      text,
      style: TextStyle(
        color: Colors.white.withOpacity(0.4),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    ),
  );

  // ── HELPERS ───────────────────────────────────────────────
  int _calendarWeekIndexInMonth(DateTime date) {
    final firstDayOfMonth = DateTime(date.year, date.month, 1);
    final firstWeekStart = firstDayOfMonth.subtract(
      Duration(days: firstDayOfMonth.weekday - 1),
    );
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return (normalizedDate.difference(firstWeekStart).inDays ~/ 7) + 1;
  }

  int _bestIndex(List<int> data) {
    if (data.isEmpty) return 0;
    int best = 0;
    for (int i = 1; i < data.length; i++) {
      if (data[i] > data[best]) best = i;
    }
    return best;
  }
}

// ── DATA CLASS ────────────────────────────────────────────
class _Kpi {
  final String emoji;
  final String value;
  final String label;
  final Color color;
  const _Kpi(this.emoji, this.value, this.label, this.color);
}

import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'rank_progress.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../rank_book_names.dart';
import '../services/xp_service.dart';
import '../services/quest_service.dart';
import '../services/level_up_service.dart';
import '../services/audio_service.dart';
import '../widgets/level_up_dialog.dart';
import '../widgets/xp_toast.dart';
import 'book_detail_screen.dart';

// TierTheme and kTierThemes are now imported from
// '../widgets/level_up_dialog.dart'

// ════════════════════════════════════════════════════════════
//  HOME SCREEN
// ════════════════════════════════════════════════════════════
class HomeScreen extends StatefulWidget {
  final VoidCallback? onGoToSearch;

  const HomeScreen({super.key, this.onGoToSearch});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // ── Tier-independent colours ─────────────────────────────
  static const Color _surface = Color(0xFF162032);
  static const Color _indigo = Color(0xFF6366F1);

  // ── Animation controllers ────────────────────────────────
  late AnimationController _bgCtrl; // smooth bg colour transition
  late AnimationController _badgeCtrl; // idle badge pulse
  int _currentTier = 0;

  // Tween that transitions between old and new bg colours
  Color _bgFrom = kTierThemes[0].bgDark;
  Color _bgTo = kTierThemes[0].bgDark;
  Color _midFrom = kTierThemes[0].bgMid;
  Color _midTo = kTierThemes[0].bgMid;

  // ── Search and sort state ────────────────────────────────
  late TextEditingController _searchController;
  String _searchQuery = '';
  String _sortOption =
      'Recent'; // 'Recent', 'TitleAZ', 'AuthorAZ', 'ProgressHL', 'PagesHL'

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _badgeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _bgCtrl.dispose();
    _badgeCtrl.dispose();
    super.dispose();
  }

  void _updateTier(int tier) {
    if (tier == _currentTier) return;
    _bgFrom = Color.lerp(
      _bgFrom,
      kTierThemes[_currentTier].bgDark,
      _bgCtrl.value,
    )!;
    _midFrom = Color.lerp(
      _midFrom,
      kTierThemes[_currentTier].bgMid,
      _bgCtrl.value,
    )!;
    _bgTo = kTierThemes[tier].bgDark;
    _midTo = kTierThemes[tier].bgMid;
    _currentTier = tier;
    _bgCtrl.forward(from: 0);
  }

  // ── Filter books by search query ─────────────────────────
  List<QueryDocumentSnapshot> _filterBooks(List<QueryDocumentSnapshot> books) {
    if (_searchQuery.isEmpty) return books;
    final query = _searchQuery.toLowerCase();
    return books.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final title = (data['title'] ?? '').toString().toLowerCase();
      final authors = data['authors'] is List
          ? (data['authors'] as List).join(', ').toLowerCase()
          : (data['authors'] ?? '').toString().toLowerCase();
      final category = (data['category'] ?? '').toString().toLowerCase();
      final categories = data['categories'] is List
          ? (data['categories'] as List).join(', ').toLowerCase()
          : (data['categories'] ?? '').toString().toLowerCase();
      final genre = (data['genre'] ?? '').toString().toLowerCase();
      final isbn = (data['isbn'] ?? '').toString().toLowerCase();
      final isbn10 = (data['isbn10'] ?? '').toString().toLowerCase();
      final isbn13 = (data['isbn13'] ?? '').toString().toLowerCase();
      return title.contains(query) ||
          authors.contains(query) ||
          category.contains(query) ||
          categories.contains(query) ||
          genre.contains(query) ||
          isbn.contains(query) ||
          isbn10.contains(query) ||
          isbn13.contains(query);
    }).toList();
  }

  // ── Sort books by the selected option ────────────────────
  void _sortBooks(List<QueryDocumentSnapshot> books) {
    switch (_sortOption) {
      case 'TitleAZ':
        books.sort((a, b) {
          final titleA = (a.data() as Map)['title']?.toString() ?? '';
          final titleB = (b.data() as Map)['title']?.toString() ?? '';
          return titleA.toLowerCase().compareTo(titleB.toLowerCase());
        });
        break;
      case 'AuthorAZ':
        books.sort((a, b) {
          final authorsA = _getFirstAuthor(a).toLowerCase();
          final authorsB = _getFirstAuthor(b).toLowerCase();
          return authorsA.compareTo(authorsB);
        });
        break;
      case 'ProgressHL':
        books.sort((a, b) {
          final curA = (a.data() as Map)['currentPage'] as int? ?? 0;
          final totalA = (a.data() as Map)['pageCount'] as int? ?? 1;
          final curB = (b.data() as Map)['currentPage'] as int? ?? 0;
          final totalB = (b.data() as Map)['pageCount'] as int? ?? 1;
          final progressA = totalA > 0 ? curA / totalA : 0.0;
          final progressB = totalB > 0 ? curB / totalB : 0.0;
          return progressB.compareTo(progressA);
        });
        break;
      case 'PagesHL':
        books.sort((a, b) {
          final curA = (a.data() as Map)['currentPage'] as int? ?? 0;
          final curB = (b.data() as Map)['currentPage'] as int? ?? 0;
          return curB.compareTo(curA);
        });
        break;
      case 'Recent':
      default:
        books.sort((a, b) {
          // Try updatedAt first
          final updatedA = (a.data() as Map)['updatedAt'] as Timestamp?;
          final updatedB = (b.data() as Map)['updatedAt'] as Timestamp?;
          if (updatedA != null && updatedB != null) {
            return updatedB.compareTo(updatedA);
          }
          // Fall back to addedAt
          final addedA = (a.data() as Map)['addedAt'] as Timestamp?;
          final addedB = (b.data() as Map)['addedAt'] as Timestamp?;
          if (addedA != null && addedB != null) {
            return addedB.compareTo(addedA);
          }
          // Fall back to createdAt
          final createdA = (a.data() as Map)['createdAt'] as Timestamp?;
          final createdB = (b.data() as Map)['createdAt'] as Timestamp?;
          if (createdA != null && createdB != null) {
            return createdB.compareTo(createdA);
          }
          return 0;
        });
        break;
    }
  }

  String _getFirstAuthor(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    if (data['authors'] is List) {
      final list = data['authors'] as List;
      return list.isNotEmpty ? list[0].toString() : '';
    }
    return (data['authors'] ?? '').toString();
  }

  // ── UPDATE PROGRESS ──────────────────────────────────────
  Future<void> _updateProgress(
    String bookId,
    int newPage,
    int totalPages,
    int bestProgress,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final bookRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('library')
        .doc(bookId);

    final bookSnap = await bookRef.get();
    final oldData = bookSnap.data() ?? {};
    final String oldStatus = oldData['status']?.toString() ?? 'Reading';

    final int pagesRead = (newPage - bestProgress).clamp(0, totalPages);
    final bool finished = newPage >= totalPages;
    final bool justFinished = oldStatus != 'Finished' && finished;
    final String todayDate = XpService.dateKey(DateTime.now());

    if (pagesRead > 0) {
      await XpService.logProgressHistory(bookId, pagesRead);
    }

    final Map<String, dynamic> updateData = {
      'currentPage': newPage,
      'bestProgress': newPage > bestProgress ? newPage : bestProgress,
      'status': finished ? 'Finished' : 'Reading',
    };

    if (justFinished) {
      updateData['finishedReading'] = todayDate;
    } else if (!finished && oldStatus == 'Finished') {
      updateData['finishedReading'] = FieldValue.delete();
    }

    await bookRef.update(updateData);

    // Streak only counts if the user really read new pages
    // or finished the book for the first time.
    final bool shouldCountStreak = pagesRead > 0 || justFinished;
    final bool isNewDay = shouldCountStreak
        ? await XpService.updateStreak()
        : false;

    final result = await XpService.awardXp(
      pagesRead: pagesRead,
      isNewDay: isNewDay,
      justFinished: justFinished,
    );

    if (mounted && result['xpGained'] > 0) _showXpToast(result);
    if (mounted && result['leveledUp'] == true) {
      LevelUpService.showLevelUp(result['newLevel'], result['newTitle']);
    }
  }

  // ── XP TOAST ─────────────────────────────────────────────
  void _showXpToast(Map<String, dynamic> result) {
    AudioService.playXpGain();
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (ctx) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        child: XpToastWidget(result: result, accentColor: _indigo),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3), () => entry.remove());
  }

  // Level-up popup is now handled globally by LevelUpService.

  // ── QUEST POPUP ─────────────────────────────────────────
  void _showQuestDialog() {
    final th = kTierThemes[_currentTier];
    List<QuestStatus>? cachedQuests;
    Future<List<QuestStatus>> questFuture = QuestService.fetchQuestStatuses()
        .then((quests) {
          cachedQuests = quests;
          return quests;
        });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          Future<void> refresh() async {
            setLocal(() {
              questFuture = QuestService.fetchQuestStatuses().then((quests) {
                cachedQuests = quests;
                return quests;
              });
            });
            await questFuture;
          }

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.82,
            ),
            decoration: BoxDecoration(
              color: Color.lerp(const Color(0xFF1A1F35), th.bgMid, 0.6),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border(
                top: BorderSide(color: th.primary.withOpacity(0.5), width: 1.5),
              ),
            ),
            child: SafeArea(
              top: false,
              child: FutureBuilder<List<QuestStatus>>(
                future: questFuture,
                initialData: cachedQuests,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting &&
                      cachedQuests == null) {
                    return SizedBox(
                      height: 260,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: th.primary,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  }

                  if (snap.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Unable to load quests. ${snap.error}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    );
                  }

                  final quests = snap.data ?? cachedQuests ?? [];
                  final daily = quests
                      .where((q) => q.type == QuestType.daily)
                      .toList();
                  final weekly = quests
                      .where((q) => q.type == QuestType.weekly)
                      .toList();

                  Widget sectionTitle(String text, IconData icon) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(22, 18, 22, 10),
                      child: Row(
                        children: [
                          Icon(icon, color: th.primary, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 12),
                        Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(22, 18, 22, 4),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(colors: th.gradient),
                                  boxShadow: [
                                    BoxShadow(
                                      color: th.glowColor.withOpacity(0.35),
                                      blurRadius: 16,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.emoji_events_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Reading Quests',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Text(
                                      'Complete quests and claim bonus XP.',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.45),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        sectionTitle('Daily Quests', Icons.today_rounded),
                        ...daily.map(
                          (quest) => _QuestTile(
                            quest: quest,
                            theme: th,
                            onClaim: () async {
                              final result = await QuestService.claimQuest(
                                quest,
                              );
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      result['xpGained'] > 0
                                          ? 'Claimed +${result['xpGained']} XP!'
                                          : 'Quest already claimed.',
                                    ),
                                  ),
                                );
                              }
                              if (mounted && result['xpGained'] > 0) {
                                _showXpToast(result);
                              }
                              if (mounted && result['leveledUp'] == true) {
                                LevelUpService.showLevelUp(
                                  result['newLevel'],
                                  result['newTitle'],
                                );
                              }
                              await refresh();
                            },
                          ),
                        ),
                        sectionTitle(
                          'Weekly Quests',
                          Icons.calendar_month_rounded,
                        ),
                        ...weekly.map(
                          (quest) => _QuestTile(
                            quest: quest,
                            theme: th,
                            onClaim: () async {
                              final result = await QuestService.claimQuest(
                                quest,
                              );
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      result['xpGained'] > 0
                                          ? 'Claimed +${result['xpGained']} XP!'
                                          : 'Quest already claimed.',
                                    ),
                                  ),
                                );
                              }
                              if (mounted && result['xpGained'] > 0) {
                                _showXpToast(result);
                              }
                              if (mounted && result['leveledUp'] == true) {
                                LevelUpService.showLevelUp(
                                  result['newLevel'],
                                  result['newTitle'],
                                );
                              }
                              await refresh();
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  // ── UPDATE PROGRESS BOTTOM SHEET (tier-aware) ────────────
  void _showUpdateDialog(
    String bookId,
    String title,
    int currentPage,
    int totalPages,
    int bestProgress,
  ) {
    final th = kTierThemes[_currentTier];
    final ctrl = TextEditingController(text: '$currentPage');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          int curVal() =>
              (int.tryParse(ctrl.text) ?? currentPage).clamp(0, totalPages);
          double pct() => totalPages > 0 ? curVal() / totalPages : 0.0;
          int newPages() => (curVal() - bestProgress).clamp(0, totalPages);
          int xpPrev() => newPages() + (curVal() >= totalPages ? 50 : 0);
          bool finish() => curVal() >= totalPages;

          void add(int n) {
            ctrl.text = '${(curVal() + n).clamp(0, totalPages)}';
            setLocal(() {});
          }

          void setP(double p) {
            ctrl.text = '${(p * totalPages).round().clamp(0, totalPages)}';
            setLocal(() {});
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                color: Color.lerp(const Color(0xFF1A1F35), th.bgMid, 0.6),
                border: Border(
                  top: BorderSide(
                    color: th.primary.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Header
                      Row(
                        children: [
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: Image.asset(
                              'assets/images/ranks/rank_$_currentTier.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Update Progress',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  title,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.4),
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (finish())
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: th.gradient),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                '🏆 FINISH!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 22),

                      // Page input
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: th.primary.withOpacity(0.4),
                            width: 1.5,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => add(-1),
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: th.primary.withOpacity(0.15),
                                  border: Border.all(
                                    color: th.primary.withOpacity(0.4),
                                  ),
                                ),
                                child: Icon(
                                  Icons.remove_rounded,
                                  color: th.primary,
                                  size: 18,
                                ),
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: ctrl,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                onChanged: (_) => setLocal(() {}),
                                style: TextStyle(
                                  color: th.primary,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                ),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: '$currentPage',
                                  hintStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.2),
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  suffixText: '/ $totalPages',
                                  suffixStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.3),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => add(1),
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: th.primary.withOpacity(0.15),
                                  border: Border.all(
                                    color: th.primary.withOpacity(0.4),
                                  ),
                                ),
                                child: Icon(
                                  Icons.add_rounded,
                                  color: th.primary,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Quick-add
                      Row(
                        children: [5, 10, 20, 50]
                            .map(
                              (n) => Expanded(
                                child: GestureDetector(
                                  onTap: () => add(n),
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: th.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: th.primary.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '+$n',
                                        style: TextStyle(
                                          color: th.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),

                      const SizedBox(height: 10),

                      // % shortcuts
                      Row(
                        children: [25, 50, 75, 100]
                            .map(
                              (p) => Expanded(
                                child: GestureDetector(
                                  onTap: () => setP(p / 100),
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: (pct() * 100).round() == p
                                          ? th.primary.withOpacity(0.2)
                                          : Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: (pct() * 100).round() == p
                                            ? th.primary.withOpacity(0.5)
                                            : Colors.white.withOpacity(0.08),
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '$p%',
                                        style: TextStyle(
                                          color: (pct() * 100).round() == p
                                              ? th.primary
                                              : Colors.white.withOpacity(0.3),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),

                      const SizedBox(height: 16),

                      // Progress bar preview
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Preview',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.35),
                              fontSize: 11,
                            ),
                          ),
                          Row(
                            children: [
                              ShaderMask(
                                shaderCallback: (b) => LinearGradient(
                                  colors: th.gradient,
                                ).createShader(b),
                                child: Text(
                                  '${(pct() * 100).toInt()}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              if (xpPrev() > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amberAccent.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.amberAccent.withOpacity(
                                        0.3,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    '+${xpPrev()} XP',
                                    style: const TextStyle(
                                      color: Colors.amberAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Stack(
                        children: [
                          Container(
                            height: 7,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: pct().clamp(0.0, 1.0),
                            child: Container(
                              height: 7,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: th.gradient),
                                borderRadius: BorderRadius.circular(7),
                                boxShadow: [
                                  BoxShadow(
                                    color: th.glowColor.withOpacity(0.6),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 22),

                      // Save button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: () async {
                            final newPage = curVal();
                            Navigator.pop(ctx);
                            await _updateProgress(
                              bookId,
                              newPage,
                              totalPages,
                              bestProgress,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                          ),
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: th.gradient),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: th.glowColor.withOpacity(0.4),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle_outline_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Save Progress',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
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
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── SMART IMAGE ───────────────────────────────────────────
  Widget _buildSmartImage(String? url, double w, double h) {
    final ph = Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.book_rounded,
        color: Colors.white.withOpacity(0.1),
        size: 24,
      ),
    );
    if (url == null || url.isEmpty || url == 'null') return ph;
    if (url.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: url,
        width: w,
        height: h,
        fit: BoxFit.cover,
        placeholder: (_, __) => ph,
        errorWidget: (_, __, ___) => ph,
      );
    }
    return Image.file(
      File(url),
      width: w,
      height: h,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => ph,
    );
  }

  Map<String, dynamic> _formatBookData(QueryDocumentSnapshot doc) {
    final data = Map<String, dynamic>.from(doc.data() as Map);
    data['id'] = doc.id;
    if (data['authors'] is String) data['authors'] = [data['authors']];
    if (data['thumbnail'] != null)
      data['imageLinks'] = {'thumbnail': data['thumbnail']};
    if (data['categories'] is String) data['categories'] = [data['categories']];
    return data;
  }

  // ════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Scaffold(backgroundColor: Color(0xFF0F172A));

    return AnimatedBuilder(
      animation: _bgCtrl,
      builder: (_, __) {
        final t = _bgCtrl.value;
        final bg = Color.lerp(_bgFrom, _bgTo, t)!;
        final mid = Color.lerp(_midFrom, _midTo, t)!;
        final theme = kTierThemes[_currentTier];

        return Scaffold(
          backgroundColor: bg,
          body: Stack(
            children: [
              // ── Atmospheric background — RepaintBoundary prevents
              //    propagation to child widgets on every frame
              Positioned.fill(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _bgCtrl,
                    builder: (_, __) => CustomPaint(
                      painter: _NebulaPainter(
                        color1: theme.primary.withOpacity(0.055),
                        color2: theme.secondary.withOpacity(0.035),
                        mid: mid,
                        bg: bg,
                      ),
                    ),
                  ),
                ),
              ),

              SafeArea(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // ── HEADER ────────────────────────────────
                    SliverToBoxAdapter(
                      child: StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .snapshots(),
                        builder: (ctx, snap) {
                          final d = snap.data?.data() as Map<String, dynamic>?;
                          final int totalXp =
                              d?['totalXp'] ?? d?['points'] ?? 0;
                          final int streak =
                              XpService.displayCurrentStreakFromData(d);
                          final String name =
                              d?['name'] ?? d?['displayName'] ?? 'Reader';
                          final String? photoURL = d?['photoURL'];
                          final levelData = XpService.calculateLevel(totalXp);
                          final tier = levelData['tierIndex'] as int;
                          final rankBookTier =
                              XpService.resolveEquippedRankBookIndex(
                                d?['equippedRankBookIndex'],
                                tier,
                              );
                          _updateTier(rankBookTier);
                          final th = kTierThemes[rankBookTier];

                          return _HeaderCard(
                            name: name,
                            photoURL: photoURL,
                            totalXp: totalXp,
                            streak: streak,
                            levelData: levelData,
                            rankBookTier: rankBookTier,
                            theme: th,
                            badgeAnim: _badgeCtrl,
                            greeting: _greeting(),
                            onQuestTap: _showQuestDialog,
                          );
                        },
                      ),
                    ),

                    // ── Currently Reading label ───────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 3,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: theme.primary,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Currently Reading',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: widget.onGoToSearch,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.primary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: theme.primary.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.add_rounded,
                                      color: theme.primary,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Add Book',
                                      style: TextStyle(
                                        color: theme.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Search and Sort controls ──────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            // Search field
                            TextField(
                              controller: _searchController,
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value;
                                });
                              },
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search by title, author, genre...',
                                hintStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 14,
                                ),
                                prefixIcon: Icon(
                                  Icons.search_rounded,
                                  color: theme.primary.withOpacity(0.6),
                                ),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _searchQuery = '';
                                            _searchController.clear();
                                          });
                                        },
                                        child: Icon(
                                          Icons.clear_rounded,
                                          color: theme.primary.withOpacity(0.6),
                                        ),
                                      )
                                    : null,
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.05),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: theme.primary.withOpacity(0.2),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: theme.primary.withOpacity(0.2),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: theme.primary.withOpacity(0.5),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Sort dropdown
                            DropdownButtonFormField<String>(
                              value: _sortOption,
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _sortOption = value;
                                  });
                                }
                              },
                              items: [
                                DropdownMenuItem(
                                  value: 'Recent',
                                  child: Text(
                                    'Recently Added',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'TitleAZ',
                                  child: Text(
                                    'Title A-Z',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'AuthorAZ',
                                  child: Text(
                                    'Author A-Z',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'ProgressHL',
                                  child: Text(
                                    'Progress High-Low',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'PagesHL',
                                  child: Text(
                                    'Pages Read High-Low',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                              decoration: InputDecoration(
                                hintText: 'Sort by...',
                                hintStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                ),
                                prefixIcon: Icon(
                                  Icons.sort_rounded,
                                  color: theme.primary.withOpacity(0.6),
                                ),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.05),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: theme.primary.withOpacity(0.2),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: theme.primary.withOpacity(0.2),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: theme.primary.withOpacity(0.5),
                                  ),
                                ),
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              dropdownColor: Color.lerp(
                                const Color(0xFF1A1F35),
                                theme.bgMid,
                                0.6,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),

                    // ── BOOK LIST ─────────────────────────────
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .collection('library')
                          .where('status', isEqualTo: 'Reading')
                          .snapshots(),
                      builder: (ctx, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return SliverToBoxAdapter(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(40),
                                child: CircularProgressIndicator(
                                  color: theme.primary,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          );
                        }
                        if (!snap.hasData || snap.data!.docs.isEmpty) {
                          return SliverToBoxAdapter(
                            child: _buildEmptyState(theme),
                          );
                        }
                        var books = snap.data!.docs;
                        // Apply search filter
                        books = _filterBooks(books);
                        // Apply sort
                        _sortBooks(books);
                        // Show no results message if search returns empty
                        if (books.isEmpty && _searchQuery.isNotEmpty) {
                          return SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(40),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(28),
                                    decoration: BoxDecoration(
                                      color: theme.primary.withOpacity(0.08),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: theme.primary.withOpacity(0.2),
                                      ),
                                    ),
                                    child: const Text(
                                      '🔍',
                                      style: TextStyle(fontSize: 48),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  const Text(
                                    'No matching books found',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Try adjusting your search criteria.',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.35),
                                      fontSize: 14,
                                      height: 1.5,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return SliverList(
                          delegate: SliverChildBuilderDelegate((ctx, i) {
                            final doc = books[i];
                            final data = doc.data() as Map<String, dynamic>;
                            final String title = data['title'] ?? 'Unknown';
                            final String authors = data['authors'] is List
                                ? (data['authors'] as List).join(', ')
                                : (data['authors'] ?? 'Unknown');
                            final String? thumb = data['thumbnail']?.toString();
                            final int total = (data['pageCount'] as int? ?? 1)
                                .clamp(1, 999999);
                            final int cur = data['currentPage'] as int? ?? 0;
                            final int best =
                                data['bestProgress'] as int? ?? cur;
                            return _BookCard(
                              doc: doc,
                              title: title,
                              authors: authors,
                              thumb: thumb,
                              totalPages: total,
                              currentPage: cur,
                              bestProgress: best,
                              pct: cur / total,
                              isBehind: cur < best,
                              tierTheme: theme,
                              onUpdate: () => _showUpdateDialog(
                                doc.id,
                                title,
                                cur,
                                total,
                                best,
                              ),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BookDetailScreen(
                                    bookData: _formatBookData(doc),
                                  ),
                                ),
                              ),
                              buildImage: _buildSmartImage,
                            );
                          }, childCount: books.length),
                        );
                      },
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(TierTheme th) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: th.primary.withOpacity(0.08),
              shape: BoxShape.circle,
              border: Border.all(color: th.primary.withOpacity(0.2)),
            ),
            child: const Text('📚', style: TextStyle(fontSize: 48)),
          ),
          const SizedBox(height: 20),
          const Text(
            'No books in progress',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Search for a book and set it to "Reading" to start tracking.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.35),
              fontSize: 14,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: widget.onGoToSearch,
            icon: const Icon(
              Icons.search_rounded,
              color: Colors.white,
              size: 18,
            ),
            label: const Text(
              'Find a Book',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: th.primary.withOpacity(0.85),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h >= 21 || h < 5) return 'Good night,';
    if (h < 12) return 'Good morning,';
    if (h < 17) return 'Good afternoon,';
    return 'Good evening,';
  }
}

// ════════════════════════════════════════════════════════════
//  HEADER CARD WIDGET
// ════════════════════════════════════════════════════════════
class _HeaderCard extends StatelessWidget {
  final String name;
  final String? photoURL;
  final int totalXp;
  final int streak;
  final Map<String, dynamic> levelData;
  final int rankBookTier;
  final TierTheme theme;
  final AnimationController badgeAnim;
  final String greeting;
  final VoidCallback onQuestTap;

  const _HeaderCard({
    required this.name,
    required this.photoURL,
    required this.totalXp,
    required this.streak,
    required this.levelData,
    required this.rankBookTier,
    required this.theme,
    required this.badgeAnim,
    required this.greeting,
    required this.onQuestTap,
  });

  @override
  Widget build(BuildContext context) {
    final int level = levelData['level'] as int;
    final double prog = levelData['progress'] as double;
    final int xpLeft = levelData['xpNeeded'] as int;
    final String title = levelData['title'] as String;
    final rankBookTheme = kTierThemes[rankBookTier];

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        // Subtle card bg with a slight tier tint
        gradient: LinearGradient(
          colors: [
            Color.lerp(const Color(0xFF1E293B), theme.bgMid, 0.45)!,
            Color.lerp(const Color(0xFF1E293B), theme.bgMid, 0.15)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: theme.primary.withOpacity(0.22), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: theme.glowColor.withOpacity(0.12),
            blurRadius: 28,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            // Background shimmer particles
            Positioned.fill(
              child: CustomPaint(
                painter: _StarfieldPainter(
                  color: theme.primary.withOpacity(0.08),
                  tier: rankBookTier,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
              child: Column(
                children: [
                  // ── Row 1: avatar + name + streak ──────────
                  Row(
                    children: [
                      // Avatar
                      _buildAvatar(),
                      const SizedBox(width: 14),
                      // Name + greeting
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              greeting,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            // Tier title pill
                            _TierPill(title: title, theme: theme),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Quest button + streak badge
                      _QuestButton(theme: theme, onTap: onQuestTap),
                      const SizedBox(width: 8),
                      _StreakBadge(streak: streak),
                    ],
                  ),

                  const SizedBox(height: 26),

                  // ── Rank badge (centred, glowing) — tap → rank journey ──
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, a, __) => const RankProgressScreen(),
                        transitionsBuilder: (_, anim, __, child) =>
                            FadeTransition(
                              opacity: anim,
                              child: SlideTransition(
                                position:
                                    Tween<Offset>(
                                      begin: const Offset(0, 0.08),
                                      end: Offset.zero,
                                    ).animate(
                                      CurvedAnimation(
                                        parent: anim,
                                        curve: Curves.easeOutCubic,
                                      ),
                                    ),
                                child: child,
                              ),
                            ),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            _AnimatedRankBadge(
                              tier: rankBookTier,
                              theme: rankBookTheme,
                              animation: badgeAnim,
                            ),
                            // Subtle "tap" hint
                            Positioned(
                              bottom: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: theme.primary.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.military_tech_rounded,
                                      color: theme.primary,
                                      size: 10,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'View rank journey',
                                      style: TextStyle(
                                        color: theme.primary,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: theme.gradient,
                          ).createShader(bounds),
                          child: Text(
                            kRankBookNames[rankBookTier],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ── XP bar ──────────────────────────────────
                  _XpBar(
                    level: level,
                    progress: prog,
                    xpLeft: xpLeft,
                    totalXp: totalXp,
                    theme: theme,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    Widget inner;
    if (photoURL != null && photoURL!.isNotEmpty && photoURL != 'null') {
      if (photoURL!.startsWith('http')) {
        inner = CachedNetworkImage(
          imageUrl: photoURL!,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _initials(),
        );
      } else {
        final f = File(photoURL!);
        inner = f.existsSync()
            ? Image.file(f, width: 52, height: 52, fit: BoxFit.cover)
            : _initials();
      }
    } else {
      inner = _initials();
    }

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: theme.gradient),
        boxShadow: [
          BoxShadow(
            color: theme.glowColor.withOpacity(0.4),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(2.5),
        child: ClipOval(
          child: Container(
            color: const Color(0xFF1E293B),
            child: ClipOval(child: inner),
          ),
        ),
      ),
    );
  }

  Widget _initials() {
    return Container(
      width: 52,
      height: 52,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF0F172A),
      ),
      child: Center(
        child: ShaderMask(
          shaderCallback: (b) =>
              LinearGradient(colors: theme.gradient).createShader(b),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'R',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Tier pill ─────────────────────────────────────────────
class _TierPill extends StatelessWidget {
  final String title;
  final TierTheme theme;
  const _TierPill({required this.title, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            theme.primary.withOpacity(0.18),
            theme.secondary.withOpacity(0.08),
          ],
        ),
        border: Border.all(color: theme.primary.withOpacity(0.45), width: 1.2),
        boxShadow: [
          BoxShadow(color: theme.glowColor.withOpacity(0.2), blurRadius: 8),
        ],
      ),
      child: ShaderMask(
        shaderCallback: (b) =>
            LinearGradient(colors: theme.gradient).createShader(b),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: 1.4,
          ),
        ),
      ),
    );
  }
}

// ── Streak badge ─────────────────────────────────────────
class _StreakBadge extends StatelessWidget {
  final int streak;
  const _StreakBadge({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orangeAccent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orangeAccent.withOpacity(0.35)),
            boxShadow: [
              BoxShadow(
                color: Colors.orangeAccent.withOpacity(0.15),
                blurRadius: 12,
              ),
            ],
          ),
          child: Column(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 20)),
              const SizedBox(height: 4),
              Text(
                '$streak',
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  height: 1,
                ),
              ),
              Text(
                'day${streak == 1 ? '' : 's'}',
                style: TextStyle(
                  color: Colors.orangeAccent.withOpacity(0.6),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Quest button with red notification dot ───────────────
class _QuestButton extends StatelessWidget {
  final TierTheme theme;
  final VoidCallback onTap;

  const _QuestButton({required this.theme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    Widget button(bool hasClaimableQuest) {
      return GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: theme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.primary.withOpacity(0.35)),
                boxShadow: [
                  BoxShadow(
                    color: theme.glowColor.withOpacity(0.14),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.emoji_events_rounded,
                    color: theme.primary,
                    size: 21,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Quest',
                    style: TextStyle(
                      color: theme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            if (hasClaimableQuest)
              Positioned(
                top: -3,
                right: -3,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF162032),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent.withOpacity(0.55),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }

    if (user == null) return button(false);

    final libraryStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('library')
        .snapshots();

    final claimStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('questClaims')
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: libraryStream,
      builder: (context, librarySnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: claimStream,
          builder: (context, claimSnap) {
            final hasClaimableQuest = QuestService.hasClaimableQuestFromDocs(
              libraryDocs: librarySnap.data?.docs ?? const [],
              claimDocs: claimSnap.data?.docs ?? const [],
            );
            return button(hasClaimableQuest);
          },
        );
      },
    );
  }
}

// ── Quest tile for the popup ──────────────────────────────
class _QuestTile extends StatelessWidget {
  final QuestStatus quest;
  final TierTheme theme;
  final Future<void> Function() onClaim;

  const _QuestTile({
    required this.quest,
    required this.theme,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final bool canClaim = quest.completed && !quest.claimed;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (quest.claimed) {
      statusColor = Colors.greenAccent;
      statusText = 'Claimed';
      statusIcon = Icons.check_circle_rounded;
    } else if (quest.completed) {
      statusColor = Colors.amberAccent;
      statusText = 'Ready';
      statusIcon = Icons.card_giftcard_rounded;
    } else {
      statusColor = Colors.white38;
      statusText = 'Not completed';
      statusIcon = Icons.lock_outline_rounded;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(22, 6, 22, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: canClaim
              ? Colors.amberAccent.withOpacity(0.42)
              : Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor.withOpacity(0.12),
              border: Border.all(color: statusColor.withOpacity(0.45)),
            ),
            child: Icon(statusIcon, color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quest.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  quest.description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 11,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          canClaim
              ? ElevatedButton(
                  onPressed: onClaim,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    '+${quest.rewardXp} XP',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Text(
                    '+${quest.rewardXp} XP',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.36),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

// ── Animated rank badge ───────────────────────────────────
class _AnimatedRankBadge extends StatelessWidget {
  final int tier;
  final TierTheme theme;
  final AnimationController animation;

  const _AnimatedRankBadge({
    required this.tier,
    required this.theme,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    // Higher tiers get larger badges to show off the wings
    final double badgeSize = 90.0 + tier * 8.0; // 90 → 162
    final double glowMulti = 0.5 + tier * 0.06;

    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        final pulse = 0.92 + animation.value * 0.08;
        return Transform.scale(
          scale: pulse,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow ring (blurred)
              Container(
                width: badgeSize + 40,
                height: badgeSize + 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.glowColor.withOpacity(0.22 * glowMulti),
                      blurRadius: theme.glowRadius,
                      spreadRadius: theme.glowSpread * 0.5,
                    ),
                  ],
                ),
              ),
              // Inner glow
              Container(
                width: badgeSize,
                height: badgeSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.glowColor.withOpacity(0.35 * glowMulti),
                      blurRadius: theme.glowRadius * 0.5,
                      spreadRadius: theme.glowSpread * 0.3,
                    ),
                  ],
                ),
              ),
              // Badge image — no BoxShape.circle clip so wings show fully
              SizedBox(
                width: badgeSize + 36,
                height: badgeSize + 36,
                child: Image.asset(
                  'assets/images/ranks/rank_$tier.png',
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── XP bar ───────────────────────────────────────────────
class _XpBar extends StatelessWidget {
  final int level;
  final double progress;
  final int xpLeft;
  final int totalXp;
  final TierTheme theme;

  const _XpBar({
    required this.level,
    required this.progress,
    required this.xpLeft,
    required this.totalXp,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            // Info button
            GestureDetector(
              onTap: () => _showXpInfoSheet(context),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.primary.withOpacity(0.12),
                  border: Border.all(color: theme.primary.withOpacity(0.3)),
                ),
                child: Icon(
                  Icons.info_outline_rounded,
                  color: theme.primary.withOpacity(0.7),
                  size: 15,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Level chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  colors: [
                    theme.primary.withOpacity(0.25),
                    theme.secondary.withOpacity(0.12),
                  ],
                ),
                border: Border.all(color: theme.primary.withOpacity(0.4)),
              ),
              child: Text(
                'Lv.$level',
                style: TextStyle(
                  color: theme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Progress bar
            Expanded(
              child: Stack(
                children: [
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: theme.gradient),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: theme.glowColor.withOpacity(0.6),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${xpLeft} XP',
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '$totalXp XP total',
            style: TextStyle(
              color: Colors.white.withOpacity(0.2),
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  void _showXpInfoSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Color.lerp(const Color(0xFF1A1F35), theme.bgMid, 0.6),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: theme.primary.withOpacity(0.5), width: 1.5),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: theme.gradient),
                        boxShadow: [
                          BoxShadow(
                            color: theme.glowColor.withOpacity(0.35),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'How to Earn XP',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Level up and unlock new ranks!',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.45),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // XP Sources
                _xpInfoTile(
                  '📖',
                  'Read Pages',
                  '+1 XP per page read',
                  'Every page you read earns you experience points.',
                  theme,
                ),
                _xpInfoTile(
                  '🔥',
                  'Daily Streak',
                  '+15–50 XP',
                  '1–2 days: 15 XP · 3+ days: 20 XP · 7+ days: 25 XP · 30+ days: 30 XP · 100+ days: 50 XP.',
                  theme,
                ),
                _xpInfoTile(
                  '🏆',
                  'Finish a Book',
                  '+50 XP per book',
                  'Complete a book to earn a big XP bonus.',
                  theme,
                ),
                _xpInfoTile(
                  '📚',
                  'Add a Book',
                  '+5 XP per book',
                  'Add new books to your library to earn XP.',
                  theme,
                ),
                _xpInfoTile(
                  '⭐',
                  'Complete Quests',
                  'Varies',
                  'Daily and weekly quests give bonus XP when claimed.',
                  theme,
                ),
                _xpInfoTile(
                  '🏅',
                  'Unlock Achievements',
                  'Varies',
                  'Earn XP rewards when you unlock new achievements.',
                  theme,
                ),

                const SizedBox(height: 16),

                // Ranks info
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        theme.primary.withOpacity(0.12),
                        theme.secondary.withOpacity(0.06),
                      ],
                    ),
                    border: Border.all(color: theme.primary.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.military_tech_rounded,
                        color: theme.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '10 Ranks to Master',
                              style: TextStyle(
                                color: theme.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Scribe → Chronicler → Keeper → Elder → Seer → Oracle → Ancient → Legendary → Mythical → Primordial',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _xpInfoTile(
    String emoji,
    String title,
    String xpAmount,
    String description,
    TierTheme theme,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: theme.primary.withOpacity(0.15),
                border: Border.all(color: theme.primary.withOpacity(0.3)),
              ),
              child: Text(
                xpAmount,
                style: TextStyle(
                  color: theme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  BOOK CARD WIDGET
// ════════════════════════════════════════════════════════════
class _BookCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final String title, authors;
  final String? thumb;
  final int totalPages, currentPage, bestProgress;
  final double pct;
  final bool isBehind;
  final TierTheme tierTheme;
  final VoidCallback onUpdate;
  final VoidCallback onTap;
  final Widget Function(String?, double, double) buildImage;

  const _BookCard({
    required this.doc,
    required this.title,
    required this.authors,
    required this.thumb,
    required this.totalPages,
    required this.currentPage,
    required this.bestProgress,
    required this.pct,
    required this.isBehind,
    required this.tierTheme,
    required this.onUpdate,
    required this.onTap,
    required this.buildImage,
  });

  @override
  Widget build(BuildContext context) {
    final Color accent = tierTheme.primary;
    final Color accent2 = tierTheme.secondary;
    final Color glow = tierTheme.glowColor;
    final int pctInt = (pct * 100).toInt();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            Color.lerp(const Color(0xFF1E293B), tierTheme.bgMid, 0.3)!,
            Color.lerp(const Color(0xFF1A2035), tierTheme.bgDark, 0.2)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: accent.withOpacity(0.2), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: glow.withOpacity(0.10),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // ── Top section: cover + info ──────────────────────
            GestureDetector(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cover with glow shadow
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: glow.withOpacity(0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Hero(
                        tag: 'book_${doc.id}',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: buildImage(thumb, 76, 114),
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            authors,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 14),

                          // Pages chip
                          _chip(
                            '$currentPage / $totalPages pages',
                            Icons.menu_book_rounded,
                            accent.withOpacity(0.8),
                          ),

                          if (bestProgress > 0 && !isBehind) ...[
                            const SizedBox(height: 6),
                            _chip(
                              'Best: $bestProgress pages',
                              Icons.emoji_events_rounded,
                              Colors.amberAccent,
                            ),
                          ],

                          const SizedBox(height: 14),

                          // Inline % indicator
                          Row(
                            children: [
                              ShaderMask(
                                shaderCallback: (b) => LinearGradient(
                                  colors: [accent, accent2],
                                ).createShader(b),
                                child: Text(
                                  '$pctInt%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 22,
                                    height: 1,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'complete',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.3),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Behind warning ─────────────────────────────────
            if (isBehind)
              Container(
                margin: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orangeAccent.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Text('⚠️', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Reach past page $bestProgress to earn XP again.',
                        style: TextStyle(
                          color: Colors.orangeAccent.withOpacity(0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Tier-coloured progress bar ─────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(18, isBehind ? 12 : 0, 18, 0),
              child: Stack(
                children: [
                  Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: pct.clamp(0.0, 1.0),
                    child: Container(
                      height: 5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [accent2, accent]),
                        borderRadius: BorderRadius.circular(5),
                        boxShadow: [
                          BoxShadow(
                            color: glow.withOpacity(0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Update button — tier-gradient ──────────────────
            Padding(
              padding: const EdgeInsets.all(18),
              child: GestureDetector(
                onTap: onUpdate,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent.withOpacity(0.9),
                        accent2.withOpacity(0.8),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: glow.withOpacity(0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.edit_rounded,
                        color: Colors.white,
                        size: 17,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Update Progress',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// LevelUpDialog and ParticlePainter are now in widgets/level_up_dialog.dart

/// Soft two-blob nebula painted behind the main scaffold
// ════════════════════════════════════════════════════════════
//  CUSTOM PAINTERS
// ════════════════════════════════════════════════════════════
class _NebulaPainter extends CustomPainter {
  final Color color1, color2, mid, bg;
  const _NebulaPainter({
    required this.color1,
    required this.color2,
    required this.mid,
    required this.bg,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Top-left blob
    final p1 = Paint()
      ..shader =
          RadialGradient(
            colors: [color1, Colors.transparent],
            radius: 0.7,
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.15, size.height * 0.12),
              radius: size.width * 0.55,
            ),
          );
    canvas.drawCircle(
      Offset(size.width * 0.15, size.height * 0.12),
      size.width * 0.55,
      p1,
    );

    // Bottom-right blob
    final p2 = Paint()
      ..shader =
          RadialGradient(
            colors: [color2, Colors.transparent],
            radius: 0.6,
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.85, size.height * 0.75),
              radius: size.width * 0.5,
            ),
          );
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.75),
      size.width * 0.5,
      p2,
    );
  }

  @override
  bool shouldRepaint(_NebulaPainter old) =>
      old.color1 != color1 || old.color2 != color2;
}

/// Tiny star dots scattered on the card header
class _StarfieldPainter extends CustomPainter {
  final Color color;
  final int tier;
  const _StarfieldPainter({required this.color, required this.tier});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(tier * 42 + 7);
    final paint = Paint()..color = color;
    final count = 18 + tier * 4;
    for (int i = 0; i < count; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = 0.6 + rng.nextDouble() * 1.4;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(_StarfieldPainter old) => old.tier != tier;
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'xp_service.dart';

class StatsService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw Exception('StatsService: no authenticated user.');
    return user.uid;
  }

  // ── MAIN STATS ──────────────────────────────────────────
  static Future<Map<String, dynamic>> fetchAllStats() async {
    final userDoc = await _firestore.collection('users').doc(_uid).get();
    final librarySnap = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('library')
        .get();

    final userData = userDoc.data() ?? {};

    final int libraryCount = librarySnap.docs.length;
    int totalPages = 0;
    int completedBooks = 0;

    final Map<String, int> authorCounts = {};
    final Map<String, int> genreCounts = {};

    // Weekly: day index 0=Mon..6=Sun → pages
    final Map<int, int> weeklyPages = {for (var i = 0; i < 7; i++) i: 0};

    // Monthly: week index 1..5 → pages
    final Map<int, int> monthlyPages = {for (var i = 1; i <= 6; i++) i: 0};

    // Yearly: month 1..12 → pages
    final Map<int, int> yearlyPages = {for (var i = 1; i <= 12; i++) i: 0};

    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

    void addAuthor(dynamic rawAuthor) {
      if (rawAuthor == null) return;
      final parts = rawAuthor is List
          ? rawAuthor.map((e) => e.toString())
          : rawAuthor.toString().split(',');

      for (final part in parts) {
        final author = part.trim();
        if (author.isEmpty) continue;
        final lower = author.toLowerCase();
        if (lower == 'unknown' || lower == 'unknown author') continue;
        authorCounts[author] = (authorCounts[author] ?? 0) + 1;
      }
    }

    void addGenre(dynamic rawGenre) {
      if (rawGenre == null) return;
      final parts = rawGenre is List
          ? rawGenre.map((e) => e.toString())
          : rawGenre.toString().split(',');

      for (final part in parts) {
        final genre = part.trim();
        if (genre.isEmpty) continue;
        final lower = genre.toLowerCase();
        if (lower == 'uncategorized' || lower == 'unknown') continue;
        genreCounts[genre] = (genreCounts[genre] ?? 0) + 1;
      }
    }

    int parseInt(dynamic value, [int fallback = 0]) {
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? fallback;
      return fallback;
    }

    for (final doc in librarySnap.docs) {
      final data = doc.data();
      final int currentPage = parseInt(data['currentPage']);
      final String status = data['status'] ?? 'Want to read';

      totalPages += currentPage;

      if (status == 'Finished') completedBooks++;

      addAuthor(data['authors']);
      addGenre(data['categories']);

      // Progress history for charts
      final history = data['progressHistory'];
      if (history is List) {
        for (final entry in history) {
          if (entry is Map) {
            final ts = entry['timestamp'];
            final int pages = parseInt(entry['pagesRead']);
            if (ts is Timestamp) {
              final date = ts.toDate();

              // Weekly
              final weekStart = DateTime(
                startOfWeek.year,
                startOfWeek.month,
                startOfWeek.day,
              );
              final weekEnd = weekStart.add(const Duration(days: 7));
              if (!date.isBefore(weekStart) && date.isBefore(weekEnd)) {
                final dayIndex = date.weekday - 1;
                weeklyPages[dayIndex] = (weeklyPages[dayIndex] ?? 0) + pages;
              }

              // Monthly calendar-week bucket (Mon-Sun).
              // Example for May 2026:
              // W1 = May 1-3, W2 = May 4-10, W3 = May 11-17.
              if (date.month == now.month && date.year == now.year) {
                final firstDayOfMonth = DateTime(now.year, now.month, 1);
                final firstWeekStart = firstDayOfMonth.subtract(
                  Duration(days: firstDayOfMonth.weekday - 1),
                );
                final normalizedDate = DateTime(
                  date.year,
                  date.month,
                  date.day,
                );
                final weekOfMonth =
                    (normalizedDate.difference(firstWeekStart).inDays ~/ 7) + 1;
                if (weekOfMonth >= 1 && weekOfMonth <= 6) {
                  monthlyPages[weekOfMonth] =
                      (monthlyPages[weekOfMonth] ?? 0) + pages;
                }
              }

              // Yearly
              if (date.year == now.year) {
                yearlyPages[date.month] =
                    (yearlyPages[date.month] ?? 0) + pages;
              }
            }
          }
        }
      }
    }

    String favoriteAuthor = 'N/A';
    if (authorCounts.isNotEmpty) {
      favoriteAuthor = authorCounts.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
    }

    String favoriteGenre = 'N/A';
    if (genreCounts.isNotEmpty) {
      favoriteGenre = genreCounts.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
    }

    final int uniqueGenres = genreCounts.length;
    final int uniqueAuthors = authorCounts.length;
    final int topAuthorCount = authorCounts.isEmpty
        ? 0
        : authorCounts.values.reduce((a, b) => a > b ? a : b);

    // IMPORTANT:
    // Do NOT auto-heal XP here from the remaining library.
    // XP is awarded/deducted by LibraryService and XpService.
    // However, claimed achievements are dynamic in ReadAlert. If the user
    // deletes books or reduces progress and no longer meets an achievement
    // requirement, the claimed badge should be removed and its achievement XP
    // reward should be deducted once.
    final int storedXp = parseInt(userData['totalXp'] ?? userData['points']);
    final int longestStreak = parseInt(userData['longestStreak']);

    final Map<String, dynamic> statsForAchievementCheck = {
      'totalPages': totalPages,
      'completedBooks': completedBooks,
      'libraryCount': libraryCount,
      'longestStreak': longestStreak,
      'level': XpService.calculateLevel(storedXp)['level'],
      'uniqueGenres': uniqueGenres,
      'uniqueAuthors': uniqueAuthors,
      'topAuthorCount': topAuthorCount,
    };

    final achievementSync = await reconcileClaimedAchievements(
      statsForAchievementCheck,
    );

    final int totalXp = achievementSync['totalXp'] as int;
    final int level = XpService.calculateLevel(totalXp)['level'] as int;

    return {
      'totalXp': totalXp,
      'points': totalXp,
      'totalPages': totalPages,
      'completedBooks': completedBooks,
      'libraryCount': libraryCount,
      'currentStreak': XpService.displayCurrentStreakFromData(userData),
      'longestStreak': longestStreak,
      'level': level,
      'favoriteAuthor': favoriteAuthor,
      'favoriteGenre': favoriteGenre,
      'genreCounts': genreCounts,
      'authorCounts': authorCounts,
      'uniqueGenres': uniqueGenres,
      'uniqueAuthors': uniqueAuthors,
      'topAuthorCount': topAuthorCount,
      'weeklyPages': weeklyPages,
      'monthlyPages': monthlyPages,
      'yearlyPages': yearlyPages,
      'claimedAchievements': List<String>.from(
        achievementSync['claimedAchievements'] ?? [],
      ),
      'equippedBadge': achievementSync['equippedBadge'] ?? '',
    };
  }

  // ── PERIOD REPORT STATS ─────────────────────────────────
  // Used by ReportsScreen to show current/previous week, month, and year.
  // It reads the same progressHistory stored by LibraryService, so no Firestore
  // schema changes are needed.
  static Future<Map<String, dynamic>> fetchReportStatsForPeriod({
    required String period,
    int offset = 0,
  }) async {
    final librarySnap = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('library')
        .get();

    final now = DateTime.now();

    DateTime start;
    DateTime end;

    if (period == 'monthly') {
      final target = DateTime(now.year, now.month + offset, 1);
      start = DateTime(target.year, target.month, 1);
      end = DateTime(target.year, target.month + 1, 1);
    } else if (period == 'yearly') {
      final target = DateTime(now.year + offset, 1, 1);
      start = DateTime(target.year, 1, 1);
      end = DateTime(target.year + 1, 1, 1);
    } else {
      final target = now.add(Duration(days: offset * 7));
      final targetDay = DateTime(target.year, target.month, target.day);
      start = targetDay.subtract(Duration(days: targetDay.weekday - 1));
      end = start.add(const Duration(days: 7));
    }

    final Map<int, int> weeklyPages = {for (var i = 0; i < 7; i++) i: 0};
    final Map<int, int> monthlyPages = {for (var i = 1; i <= 6; i++) i: 0};
    final Map<int, int> yearlyPages = {for (var i = 1; i <= 12; i++) i: 0};

    int pagesRead = 0;
    int booksAdded = 0;
    int booksCompleted = 0;
    final Set<String> activeDateKeys = {};

    int parseInt(dynamic value, [int fallback = 0]) {
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? fallback;
      return fallback;
    }

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) {
        final text = value.trim();
        if (text.isEmpty) return null;
        return DateTime.tryParse(text);
      }
      return null;
    }

    bool isInRange(DateTime date) {
      final normalized = DateTime(date.year, date.month, date.day);
      return !normalized.isBefore(start) && normalized.isBefore(end);
    }

    void addPagesToBuckets(DateTime date, int pages) {
      if (pages <= 0) return;
      pagesRead += pages;
      activeDateKeys.add(XpService.dateKey(date));

      if (period == 'monthly') {
        final firstDayOfMonth = DateTime(start.year, start.month, 1);
        final firstWeekStart = firstDayOfMonth.subtract(
          Duration(days: firstDayOfMonth.weekday - 1),
        );
        final normalizedDate = DateTime(date.year, date.month, date.day);
        final weekOfMonth =
            (normalizedDate.difference(firstWeekStart).inDays ~/ 7) + 1;
        if (weekOfMonth >= 1 && weekOfMonth <= 6) {
          monthlyPages[weekOfMonth] = (monthlyPages[weekOfMonth] ?? 0) + pages;
        }
      } else if (period == 'yearly') {
        yearlyPages[date.month] = (yearlyPages[date.month] ?? 0) + pages;
      } else {
        final dayIndex = date.weekday - 1;
        weeklyPages[dayIndex] = (weeklyPages[dayIndex] ?? 0) + pages;
      }
    }

    for (final doc in librarySnap.docs) {
      final data = doc.data();

      final addedAt = parseDate(data['addedAt']);
      if (addedAt != null && isInRange(addedAt)) booksAdded++;

      final finishedAt = parseDate(data['finishedReading']);
      if (finishedAt != null && isInRange(finishedAt)) booksCompleted++;

      final history = data['progressHistory'];
      if (history is List) {
        for (final entry in history) {
          if (entry is Map) {
            final date = parseDate(entry['timestamp']);
            final int pages = parseInt(entry['pagesRead']);

            // Keep the actual pagesRead value.
            // This allows large manual-entry books to appear in reports,
            // which is useful when testing XP, levels, and rank images.
            if (date != null && isInRange(date)) {
              addPagesToBuckets(date, pages);
            }
          }
        }
      }
    }

    return {
      'period': period,
      'offset': offset,
      'startDate': start,
      'endDate': end,
      'weeklyPages': weeklyPages,
      'monthlyPages': monthlyPages,
      'yearlyPages': yearlyPages,
      'pagesRead': pagesRead,
      'booksAdded': booksAdded,
      'booksCompleted': booksCompleted,
      'activeDays': activeDateKeys.length,
    };
  }

  // ── ACHIEVEMENTS ────────────────────────────────────────
  static List<Map<String, dynamic>> getAllAchievements() {
    return [
      // Library Collection — 4
      {
        'id': 'first_shelf',
        'title': 'First Shelf',
        'description': 'Add your first book to the library',
        'icon': '📚',
        'asset': 'assets/images/achievements/first_shelf.png',
        'xp': 10,
        'field': 'libraryCount',
        'op': '>=',
        'threshold': 1,
        'category': 'Library',
      },
      {
        'id': 'night_owl',
        'title': 'Night Owl',
        'description': 'Add 5 books to the library',
        'icon': '🦉',
        'asset': 'assets/images/achievements/night_owl.png',
        'xp': 20,
        'field': 'libraryCount',
        'op': '>=',
        'threshold': 5,
        'category': 'Library',
      },
      {
        'id': 'library_builder',
        'title': 'Library Builder',
        'description': 'Add 15 books to the library',
        'icon': '🏗️',
        'asset': 'assets/images/achievements/library_builder.png',
        'xp': 45,
        'field': 'libraryCount',
        'op': '>=',
        'threshold': 15,
        'category': 'Library',
      },
      {
        'id': 'archive_keeper',
        'title': 'Archive Keeper',
        'description': 'Add 30 books to the library',
        'icon': '🗄️',
        'asset': 'assets/images/achievements/archive_keeper.png',
        'xp': 90,
        'field': 'libraryCount',
        'op': '>=',
        'threshold': 30,
        'category': 'Library',
      },

      // Finished Books — 4
      {
        'id': 'literary_explorer',
        'title': 'Literary Explorer',
        'description': 'Finish your first book',
        'icon': '📖',
        'asset': 'assets/images/achievements/literary_explorer.png',
        'xp': 20,
        'field': 'completedBooks',
        'op': '>=',
        'threshold': 1,
        'category': 'Finished',
      },
      {
        'id': 'bookworm',
        'title': 'Bookworm',
        'description': 'Finish 10 books',
        'icon': '🐛',
        'asset': 'assets/images/achievements/bookworm.png',
        'xp': 60,
        'field': 'completedBooks',
        'op': '>=',
        'threshold': 10,
        'category': 'Finished',
      },
      {
        'id': 'bibliophile',
        'title': 'Bibliophile',
        'description': 'Finish 25 books',
        'icon': '🏛️',
        'asset': 'assets/images/achievements/bibliophile.png',
        'xp': 120,
        'field': 'completedBooks',
        'op': '>=',
        'threshold': 25,
        'category': 'Finished',
      },
      {
        'id': 'master_reader',
        'title': 'Master Reader',
        'description': 'Finish 50 books',
        'icon': '👑',
        'asset': 'assets/images/achievements/master_reader.png',
        'xp': 200,
        'field': 'completedBooks',
        'op': '>=',
        'threshold': 50,
        'category': 'Finished',
      },

      // Pages Read — 4
      {
        'id': 'page_turner',
        'title': 'Page Turner',
        'description': 'Read 1,000 pages',
        'icon': '📃',
        'asset': 'assets/images/achievements/page_turner.png',
        'xp': 25,
        'field': 'totalPages',
        'op': '>=',
        'threshold': 1000,
        'category': 'Pages',
      },
      {
        'id': 'chapter_chaser',
        'title': 'Chapter Chaser',
        'description': 'Read 3,000 pages',
        'icon': '🍃',
        'asset': 'assets/images/achievements/chapter_chaser.png',
        'xp': 50,
        'field': 'totalPages',
        'op': '>=',
        'threshold': 3000,
        'category': 'Pages',
      },
      {
        'id': 'marathon_reader',
        'title': 'Marathon Reader',
        'description': 'Read 10,000 pages',
        'icon': '🏃',
        'asset': 'assets/images/achievements/marathon_reader.png',
        'xp': 110,
        'field': 'totalPages',
        'op': '>=',
        'threshold': 10000,
        'category': 'Pages',
      },
      {
        'id': 'tome_conqueror',
        'title': 'Tome Conqueror',
        'description': 'Read 25,000 pages',
        'icon': '📕',
        'asset': 'assets/images/achievements/tome_conqueror.png',
        'xp': 240,
        'field': 'totalPages',
        'op': '>=',
        'threshold': 25000,
        'category': 'Pages',
      },

      // Reading Streak — 4
      {
        'id': 'fire_starter',
        'title': 'Fire Starter',
        'description': 'Reach a 3-day streak',
        'icon': '🔥',
        'asset': 'assets/images/achievements/fire_starter.png',
        'xp': 15,
        'field': 'longestStreak',
        'op': '>=',
        'threshold': 3,
        'category': 'Streak',
      },
      {
        'id': 'flame_keeper',
        'title': 'Flame Keeper',
        'description': 'Reach a 7-day streak',
        'icon': '🕯️',
        'asset': 'assets/images/achievements/flame_keeper.png',
        'xp': 35,
        'field': 'longestStreak',
        'op': '>=',
        'threshold': 7,
        'category': 'Streak',
      },
      {
        'id': 'inferno',
        'title': 'Inferno',
        'description': 'Reach a 30-day streak',
        'icon': '🌋',
        'asset': 'assets/images/achievements/inferno.png',
        'xp': 120,
        'field': 'longestStreak',
        'op': '>=',
        'threshold': 30,
        'category': 'Streak',
      },
      {
        'id': 'eternal_flame',
        'title': 'Eternal Flame',
        'description': 'Reach a 100-day streak',
        'icon': '🔵',
        'asset': 'assets/images/achievements/eternal_flame.png',
        'xp': 300,
        'field': 'longestStreak',
        'op': '>=',
        'threshold': 100,
        'category': 'Streak',
      },

      // Level / Rank — 4
      {
        'id': 'scribe',
        'title': 'Scribe',
        'description': 'Reach Level 5',
        'icon': '✍️',
        'asset': 'assets/images/achievements/scribe.png',
        'xp': 0,
        'field': 'level',
        'op': '>=',
        'threshold': 5,
        'category': 'Rank',
      },
      {
        'id': 'keepers_mark',
        'title': "Keeper's Mark",
        'description': 'Reach Level 20',
        'icon': '🛡️',
        'asset': 'assets/images/achievements/keepers_mark.png',
        'xp': 0,
        'field': 'level',
        'op': '>=',
        'threshold': 20,
        'category': 'Rank',
      },
      {
        'id': 'ancient',
        'title': 'Ancient',
        'description': 'Reach Level 30',
        'icon': '🗿',
        'asset': 'assets/images/achievements/ancient.png',
        'xp': 0,
        'field': 'level',
        'op': '>=',
        'threshold': 30,
        'category': 'Rank',
      },
      {
        'id': 'mythic_reader',
        'title': 'Mythic Reader',
        'description': 'Reach Level 100',
        'icon': '👁️',
        'asset': 'assets/images/achievements/mythic_reader.png',
        'xp': 0,
        'field': 'level',
        'op': '>=',
        'threshold': 100,
        'category': 'Rank',
      },

      // Genre / Author — 4
      {
        'id': 'genre_explorer',
        'title': 'Genre Explorer',
        'description': 'Add books from 3 genres',
        'icon': '🧭',
        'asset': 'assets/images/achievements/genre_explorer.png',
        'xp': 25,
        'field': 'uniqueGenres',
        'op': '>=',
        'threshold': 3,
        'category': 'Discovery',
      },
      {
        'id': 'genre_collector',
        'title': 'Genre Collector',
        'description': 'Add books from 5 genres',
        'icon': '🎭',
        'asset': 'assets/images/achievements/genre_collector.png',
        'xp': 55,
        'field': 'uniqueGenres',
        'op': '>=',
        'threshold': 5,
        'category': 'Discovery',
      },
      {
        'id': 'author_seeker',
        'title': 'Author Seeker',
        'description': 'Add books from 3 authors',
        'icon': '🖋️',
        'asset': 'assets/images/achievements/author_seeker.png',
        'xp': 25,
        'field': 'uniqueAuthors',
        'op': '>=',
        'threshold': 3,
        'category': 'Discovery',
      },
      {
        'id': 'author_loyalist',
        'title': 'Author Loyalist',
        'description': 'Add 5 books by the same author',
        'icon': '🏅',
        'asset': 'assets/images/achievements/author_loyalist.png',
        'xp': 70,
        'field': 'topAuthorCount',
        'op': '>=',
        'threshold': 5,
        'category': 'Discovery',
      },
    ];
  }

  static bool checkCondition(
    Map<String, dynamic> achievement,
    Map<String, dynamic> stats,
  ) {
    final String field = achievement['field'] as String;
    final String op = achievement['op'] as String;
    final int threshold = achievement['threshold'] as int;
    final dynamic rawValue = stats[field] ?? 0;
    final int value = rawValue is int
        ? rawValue
        : rawValue is double
        ? rawValue.toInt()
        : int.tryParse(rawValue.toString()) ?? 0;

    switch (op) {
      case '>=':
        return value >= threshold;
      case '>':
        return value > threshold;
      case '==':
        return value == threshold;
      default:
        return false;
    }
  }

  static int _parseInt(dynamic value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static List<String> _validClaimedAchievementIds(
    List<String> claimed,
    Map<String, dynamic> stats,
  ) {
    final allById = {
      for (final achievement in getAllAchievements())
        achievement['id'] as String: achievement,
    };

    final valid = <String>[];
    for (final id in claimed) {
      final achievement = allById[id];
      if (achievement == null) continue;
      if (checkCondition(achievement, stats)) valid.add(id);
    }
    return valid;
  }

  static int _xpRewardForAchievement(String achievementId) {
    for (final achievement in getAllAchievements()) {
      if (achievement['id'] == achievementId) {
        return _parseInt(achievement['xp']);
      }
    }
    return 0;
  }

  // Recalculate claimed achievements against the current stats.
  // This keeps the badge collection dynamic after deleted books or reduced
  // progress. Invalid claimed badges are removed and their XP reward is
  // deducted once. If the equipped badge becomes invalid, it is unequipped.
  static Future<Map<String, dynamic>> reconcileClaimedAchievements(
    Map<String, dynamic> currentStats,
  ) async {
    final ref = _firestore.collection('users').doc(_uid);
    Map<String, dynamic> result = {
      'claimedAchievements': <String>[],
      'totalXp': 0,
      'equippedBadge': '',
    };

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? {};

      final originalClaimed = List<String>.from(
        data['claimedAchievements'] ?? [],
      );
      final int currentXp = _parseInt(data['totalXp'] ?? data['points']);

      // First pass: validate achievements using current stats and current level.
      var statsForCheck = Map<String, dynamic>.from(currentStats);
      statsForCheck['level'] = XpService.calculateLevel(currentXp)['level'];
      var validClaimed = _validClaimedAchievementIds(
        originalClaimed,
        statsForCheck,
      );

      // Deduct XP for invalid achievements. Then run a second pass because
      // deducted XP may lower level and invalidate rank-based achievements.
      int xpToDeduct = originalClaimed
          .where((id) => !validClaimed.contains(id))
          .fold<int>(0, (sum, id) => sum + _xpRewardForAchievement(id));
      int newXp = (currentXp - xpToDeduct).clamp(0, 99999999).toInt();

      statsForCheck = Map<String, dynamic>.from(currentStats);
      statsForCheck['level'] = XpService.calculateLevel(newXp)['level'];
      final secondPassValid = _validClaimedAchievementIds(
        originalClaimed,
        statsForCheck,
      );

      if (secondPassValid.length != validClaimed.length ||
          !secondPassValid.every(validClaimed.contains)) {
        validClaimed = secondPassValid;
        xpToDeduct = originalClaimed
            .where((id) => !validClaimed.contains(id))
            .fold<int>(0, (sum, id) => sum + _xpRewardForAchievement(id));
        newXp = (currentXp - xpToDeduct).clamp(0, 99999999).toInt();
      }

      String equippedBadge = (data['equippedBadge'] ?? '').toString();
      if (equippedBadge.isNotEmpty && !validClaimed.contains(equippedBadge)) {
        equippedBadge = '';
      }

      final levelData = XpService.calculateLevel(newXp);

      final claimedChanged =
          originalClaimed.length != validClaimed.length ||
          !originalClaimed.every(validClaimed.contains);
      final xpChanged = newXp != currentXp;
      final equippedChanged = equippedBadge != (data['equippedBadge'] ?? '');

      if (claimedChanged || xpChanged || equippedChanged) {
        tx.set(ref, {
          'claimedAchievements': validClaimed,
          'equippedBadge': equippedBadge,
          'totalXp': newXp,
          'points': newXp,
          'level': levelData['level'],
        }, SetOptions(merge: true));
      }

      result = {
        'claimedAchievements': validClaimed,
        'totalXp': newXp,
        'equippedBadge': equippedBadge,
      };
    });

    return result;
  }

  static Future<List<String>> getClaimedAchievements() async {
    final stats = await fetchAllStats();
    return List<String>.from(stats['claimedAchievements'] ?? []);
  }

  static Future<Map<String, dynamic>> claimAchievement(
    String achievementId,
    int xpReward,
  ) async {
    final ref = _firestore.collection('users').doc(_uid);
    bool leveledUp = false;
    int newLevel = 1;
    String newTitle = '';

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? {};
      final claimed = List<String>.from(data['claimedAchievements'] ?? []);
      if (claimed.contains(achievementId)) return;
      claimed.add(achievementId);

      final int currentXp = data['totalXp'] ?? data['points'] ?? 0;
      final int newXp = currentXp + xpReward;
      final oldLevelData = XpService.calculateLevel(currentXp);
      final levelData = XpService.calculateLevel(newXp);

      if ((levelData['level'] as int) > (oldLevelData['level'] as int)) {
        leveledUp = true;
        newLevel = levelData['level'] as int;
        newTitle = levelData['title'] as String;
      }

      tx.set(ref, {
        'claimedAchievements': claimed,
        'totalXp': newXp,
        'points': newXp,
        'level': levelData['level'],
      }, SetOptions(merge: true));
    });

    return {
      'leveledUp': leveledUp,
      'newLevel': newLevel,
      'newTitle': newTitle,
    };
  }

  static Future<void> equipBadge(String badgeId) async {
    await _firestore.collection('users').doc(_uid).update({
      'equippedBadge': badgeId,
    });
  }

  // ── STREAK CALENDAR ──────────────────────────────────────
  static Future<Set<String>> getReadingDays() async {
    final librarySnap = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('library')
        .get();

    final Set<String> days = {};
    for (final doc in librarySnap.docs) {
      final history = doc.data()['progressHistory'];
      if (history is List) {
        for (final entry in history) {
          if (entry is Map) {
            final String? storedKey = entry['dateKey'] as String?;
            if (storedKey != null && storedKey.isNotEmpty) {
              days.add(storedKey);
            } else if (entry['timestamp'] is Timestamp) {
              final date = (entry['timestamp'] as Timestamp).toDate();
              days.add(XpService.dateKey(date));
            }
          }
        }
      }
    }
    return days;
  }
}

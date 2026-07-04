import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class XpService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static const int manualBookPageXpCap = 1000;
  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw Exception('XpService: no authenticated user.');
    return user.uid;
  }

  // ── SHARED DATE KEY ──────────────────────────────────────
  static String dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── LEVELING SYSTEM (100 levels, 10 tiers) ──────────────
  static const List<int> tierStarts = [
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

  static const List<int> tierSteps = [
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

  // NEW: Updated Rank Titles
  static const List<String> tierNames = [
    'Scribe',
    'Chronicler',
    'Keeper',
    'Elder',
    'Seer',
    'Oracle',
    'Ancient',
    'Legendary',
    'Mythical',
    'Primordial',
  ];

  static Map<String, dynamic> calculateLevel(int totalXp) {
    int tierIndex = 0;
    for (int i = 0; i < tierStarts.length; i++) {
      if (totalXp >= tierStarts[i]) {
        tierIndex = i;
      } else {
        break;
      }
    }

    final int xpIntoTier = totalXp - tierStarts[tierIndex];
    final int step = tierSteps[tierIndex];

    int levelsGained = xpIntoTier ~/ step;
    if (tierIndex < tierStarts.length - 1) {
      levelsGained = levelsGained.clamp(0, 9);
    }

    int currentLevel = (tierIndex * 10) + 1 + levelsGained;

    final int currentLevelBaseXp =
        tierStarts[tierIndex] + (levelsGained * step);
    final int nextLevelXp = currentLevelBaseXp + step;

    final double progress = (totalXp - currentLevelBaseXp) / step.toDouble();

    return {
      'level': currentLevel,
      // NEW: Removed Roman numerals. It just shows the grand title now.
      'title': tierNames[tierIndex],
      'tierName': tierNames[tierIndex],
      'progress': progress.clamp(0.0, 1.0),
      'xpNeeded': (nextLevelXp - totalXp).clamp(0, nextLevelXp),
      'nextLevelXp': nextLevelXp,
      'tierIndex': tierIndex,
      'totalXp': totalXp,
    };
  }

  static String getTitleFromLevel(int level) {
    final int tierIndex = ((level - 1) ~/ 10).clamp(0, 9);
    return tierNames[tierIndex];
  }

  static int? _tryParseInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static bool isManualBookData(
    Map<String, dynamic> bookData, {
    String? bookId,
  }) {
    if (bookData.containsKey('isManual')) return bookData['isManual'] == true;
    if (bookData['manualEntry'] == true) return true;

    // Older manual books were saved with generated UUID document IDs before
    // the explicit isManual flag existed.
    return bookId != null && _uuidPattern.hasMatch(bookId);
  }

  static int capManualPageXp(int pages) {
    if (pages <= 0) return 0;
    return pages.clamp(0, manualBookPageXpCap).toInt();
  }

  static int pageXpProgressForBook({
    required int progress,
    required Map<String, dynamic> bookData,
    String? bookId,
  }) {
    if (progress <= 0) return 0;
    if (isManualBookData(bookData, bookId: bookId)) {
      return capManualPageXp(progress);
    }

    final verifiedPageCount = _tryParseInt(bookData['verifiedPageCount']);
    if (verifiedPageCount == null || verifiedPageCount <= 0) return 0;
    return progress.clamp(0, verifiedPageCount).toInt();
  }

  static int _clampTierIndex(int tierIndex) {
    return tierIndex.clamp(0, tierStarts.length - 1).toInt();
  }

  /// Display-only rank book choice.
  ///
  /// If no book has been explicitly equipped, or the saved book is no longer
  /// unlocked, the UI falls back to the highest rank unlocked by XP.
  static int resolveEquippedRankBookIndex(
    dynamic equippedRankBookIndex,
    int highestUnlockedTier,
  ) {
    final fallbackTier = _clampTierIndex(highestUnlockedTier);
    final selectedTier = _tryParseInt(equippedRankBookIndex);

    if (selectedTier == null ||
        selectedTier < 0 ||
        selectedTier >= tierStarts.length ||
        selectedTier > fallbackTier) {
      return fallbackTier;
    }

    return selectedTier;
  }

  static Future<bool> equipRankBook(int tierIndex) async {
    if (tierIndex < 0 || tierIndex >= tierStarts.length) return false;

    final ref = _firestore.collection('users').doc(_uid);
    bool equipped = false;

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? {};
      final totalXp =
          _tryParseInt(data['totalXp']) ?? _tryParseInt(data['points']) ?? 0;
      final currentTier = calculateLevel(totalXp)['tierIndex'] as int;

      if (tierIndex > currentTier) return;

      tx.set(ref, {
        'equippedRankBookIndex': tierIndex,
      }, SetOptions(merge: true));
      equipped = true;
    });

    return equipped;
  }

  static double getLevelProgress(int totalXp) =>
      calculateLevel(totalXp)['progress'] as double;

  static int getXpToNextLevel(int totalXp) =>
      calculateLevel(totalXp)['xpNeeded'] as int;

  // ── XP AWARD ─────────────────────────────────────────────
  static Future<Map<String, dynamic>> awardXp({
    required int pagesRead,
    required bool isNewDay,
    required bool justFinished,
    bool addedToLibrary = false,
  }) async {
    int xp = 0;
    final List<String> reasons = [];

    if (pagesRead > 0) {
      xp += pagesRead;
      reasons.add('+$pagesRead XP (pages)');
    }
    if (isNewDay) {
      xp += 15;
      reasons.add('+15 XP (daily streak)');
    }
    if (justFinished) {
      xp += 50;
      reasons.add('+50 XP (finished!)');
    }
    if (addedToLibrary) {
      xp += 5;
      reasons.add('+5 XP (added book)');
    }

    if (xp <= 0) {
      return {'xpGained': 0, 'reasons': <String>[], 'leveledUp': false};
    }

    final ref = _firestore.collection('users').doc(_uid);
    bool leveledUp = false;
    int newLevel = 1;
    String newTitle = '';

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? {};
      final int oldXp = data['totalXp'] ?? 0;
      final int newXp = oldXp + xp;

      final oldLevelData = calculateLevel(oldXp);
      final newLevelData = calculateLevel(newXp);

      if ((newLevelData['level'] as int) > (oldLevelData['level'] as int)) {
        leveledUp = true;
        newLevel = newLevelData['level'] as int;
        newTitle = newLevelData['title'] as String;
      }

      tx.set(ref, {
        'totalXp': newXp,
        'points': newXp,
        'level': newLevelData['level'],
      }, SetOptions(merge: true));
    });

    return {
      'xpGained': xp,
      'reasons': reasons,
      'leveledUp': leveledUp,
      'newLevel': newLevel,
      'newTitle': newTitle,
    };
  }

  // ── STREAK ───────────────────────────────────────────────
  // Call this ONLY when the user really reads pages.
  // Examples: progress increased, manual book has currentPage > 0,
  // or a book is added/updated as Finished.
  static Future<bool> updateStreak() async {
    final ref = _firestore.collection('users').doc(_uid);
    bool isNewDay = false;

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? {};
      final String lastDate = data['lastReadDate'] ?? '';
      final today = dateKey(DateTime.now());
      final yesterday = dateKey(
        DateTime.now().subtract(const Duration(days: 1)),
      );

      // Already counted today. Do not add another streak day or daily XP.
      if (lastDate == today) return;
      isNewDay = true;

      int currentStreak = data['currentStreak'] ?? 0;
      int longestStreak = data['longestStreak'] ?? 0;

      if (lastDate == yesterday) {
        currentStreak++;
      } else {
        currentStreak = 1;
      }

      if (currentStreak > longestStreak) longestStreak = currentStreak;

      tx.set(ref, {
        'lastReadDate': today,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
      }, SetOptions(merge: true));
    });

    return isNewDay;
  }

  // Use this for DISPLAY only.
  // It fixes the UI bug where Firestore still stores an old streak
  // after the user missed more than one day.
  static int displayCurrentStreakFromData(Map<String, dynamic>? data) {
    if (data == null) return 0;

    final String lastDate = data['lastReadDate'] ?? '';
    final String today = dateKey(DateTime.now());
    final String yesterday = dateKey(
      DateTime.now().subtract(const Duration(days: 1)),
    );

    if (lastDate == today || lastDate == yesterday) {
      return data['currentStreak'] ?? 0;
    }

    return 0;
  }

  // ── PROGRESS HISTORY ─────────────────────────────────────
  static Future<void> logProgressHistory(String bookId, int pagesRead) async {
    if (pagesRead <= 0) return;
    final bookRef = _firestore
        .collection('users')
        .doc(_uid)
        .collection('library')
        .doc(bookId);

    await bookRef.update({
      'progressHistory': FieldValue.arrayUnion([
        {
          'timestamp': Timestamp.now(),
          'pagesRead': pagesRead,
          'dateKey': dateKey(DateTime.now()),
        },
      ]),
    });
  }
}

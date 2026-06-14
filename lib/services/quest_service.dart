import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'xp_service.dart';

enum QuestType { daily, weekly }

class QuestStatus {
  final String id;
  final QuestType type;
  final String title;
  final String description;
  final int rewardXp;
  final bool completed;
  final bool claimed;
  final String claimKey;

  const QuestStatus({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.rewardXp,
    required this.completed,
    required this.claimed,
    required this.claimKey,
  });

  bool get canClaim => completed && !claimed;
}

class QuestService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw Exception('QuestService: no authenticated user.');
    return user.uid;
  }

  static String _todayKey() => XpService.dateKey(DateTime.now());

  static DateTime _startOfWeek(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  static String _weekKey(DateTime date) {
    final start = _startOfWeek(date);
    return '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
  }

  static int _parseInt(dynamic value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;

      final parts = value.split('-');
      if (parts.length == 3) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final d = int.tryParse(parts[2]);
        if (y != null && m != null && d != null) {
          return DateTime(y, m, d);
        }
      }
    }
    return null;
  }

  static bool _sameDay(DateTime date, DateTime target) {
    return date.year == target.year &&
        date.month == target.month &&
        date.day == target.day;
  }

  static bool _isInThisWeek(DateTime date, DateTime now) {
    final start = _startOfWeek(now);
    final end = start.add(const Duration(days: 7));
    final normalized = DateTime(date.year, date.month, date.day);
    return !normalized.isBefore(start) && normalized.isBefore(end);
  }

  static Set<String> _claimedKeysFromDocs(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.map((doc) => doc.id).toSet();
  }

  static Map<String, dynamic> _calculateMetricsFromDocs(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> libraryDocs, {
    Map<String, dynamic>? userData,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayKey = _todayKey();

    int todayPages = 0;
    int weekPages = 0;
    bool addedToday = false;
    bool finishedThisWeek = false;
    final Set<String> readingDaysThisWeek = {};

    final String lastReadDate = userData?['lastReadDate']?.toString() ?? '';
    if (lastReadDate == todayKey) {
      readingDaysThisWeek.add(todayKey);
    }

    for (final doc in libraryDocs) {
      final data = doc.data();

      final addedAtDate = _toDate(data['addedAt']);
      if (addedAtDate != null && _sameDay(addedAtDate, today)) {
        addedToday = true;
      }

      final finishedDate = _toDate(data['finishedReading']);
      if (finishedDate != null && _isInThisWeek(finishedDate, now)) {
        finishedThisWeek = true;
      }

      final progressHistory = data['progressHistory'];
      if (progressHistory is List) {
        for (final entry in progressHistory) {
          if (entry is! Map) continue;

          final int pagesRead = _parseInt(entry['pagesRead']);
          if (pagesRead <= 0) continue;

          DateTime? entryDate = _toDate(entry['timestamp']);
          final String? entryDateKey = entry['dateKey']?.toString();

          if (entryDate == null && entryDateKey != null) {
            entryDate = _toDate(entryDateKey);
          }

          if (entryDate == null) continue;

          final normalizedDate = DateTime(
            entryDate.year,
            entryDate.month,
            entryDate.day,
          );

          if (_sameDay(normalizedDate, today) || entryDateKey == todayKey) {
            todayPages += pagesRead;
          }

          if (_isInThisWeek(normalizedDate, now)) {
            weekPages += pagesRead;
            readingDaysThisWeek.add(XpService.dateKey(normalizedDate));
          }
        }
      }
    }

    return {
      'todayPages': todayPages,
      'weekPages': weekPages,
      'addedToday': addedToday,
      'finishedThisWeek': finishedThisWeek,
      'readingDaysThisWeek': readingDaysThisWeek.length,
      'readToday': todayPages > 0 || lastReadDate == todayKey,
    };
  }

  static List<QuestStatus> _buildQuestStatuses({
    required Map<String, dynamic> metrics,
    required Set<String> claimedKeys,
  }) {
    final todayKey = _todayKey();
    final weekKey = _weekKey(DateTime.now());

    QuestStatus daily({
      required String id,
      required String title,
      required String description,
      required int rewardXp,
      required bool completed,
    }) {
      final claimKey = 'daily_${todayKey}_$id';
      return QuestStatus(
        id: id,
        type: QuestType.daily,
        title: title,
        description: description,
        rewardXp: rewardXp,
        completed: completed,
        claimed: claimedKeys.contains(claimKey),
        claimKey: claimKey,
      );
    }

    QuestStatus weekly({
      required String id,
      required String title,
      required String description,
      required int rewardXp,
      required bool completed,
    }) {
      final claimKey = 'weekly_${weekKey}_$id';
      return QuestStatus(
        id: id,
        type: QuestType.weekly,
        title: title,
        description: description,
        rewardXp: rewardXp,
        completed: completed,
        claimed: claimedKeys.contains(claimKey),
        claimKey: claimKey,
      );
    }

    final int todayPages = _parseInt(metrics['todayPages']);
    final int weekPages = _parseInt(metrics['weekPages']);
    final int readingDaysThisWeek = _parseInt(metrics['readingDaysThisWeek']);
    final bool readToday = metrics['readToday'] == true;
    final bool addedToday = metrics['addedToday'] == true;
    final bool finishedThisWeek = metrics['finishedThisWeek'] == true;

    return [
      daily(
        id: 'read_today',
        title: 'Read Today',
        description: 'Read at least one page today.',
        rewardXp: 10,
        completed: readToday,
      ),
      daily(
        id: 'read_10_pages',
        title: 'Read 10 Pages',
        description: 'Read 10 or more pages today.',
        rewardXp: 15,
        completed: todayPages >= 10,
      ),
      daily(
        id: 'add_book',
        title: 'Add a Book',
        description: 'Add one book to your library today.',
        rewardXp: 10,
        completed: addedToday,
      ),
      weekly(
        id: 'read_50_pages',
        title: 'Weekly Reader',
        description: 'Read 50 or more pages this week.',
        rewardXp: 50,
        completed: weekPages >= 50,
      ),
      weekly(
        id: 'read_3_days',
        title: 'Consistent Reader',
        description: 'Read on 3 different days this week.',
        rewardXp: 40,
        completed: readingDaysThisWeek >= 3,
      ),
      weekly(
        id: 'finish_book',
        title: 'Finish a Book',
        description: 'Finish at least one book this week.',
        rewardXp: 75,
        completed: finishedThisWeek,
      ),
    ];
  }

  static Future<List<QuestStatus>> fetchQuestStatuses() async {
    final userRef = _firestore.collection('users').doc(_uid);

    final userSnap = await userRef.get();
    final librarySnap = await userRef.collection('library').get();
    final claimSnap = await userRef.collection('questClaims').get();

    final metrics = _calculateMetricsFromDocs(
      librarySnap.docs,
      userData: userSnap.data() ?? {},
    );

    return _buildQuestStatuses(
      metrics: metrics,
      claimedKeys: _claimedKeysFromDocs(claimSnap.docs),
    );
  }

  static bool hasClaimableQuestFromDocs({
    required Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> libraryDocs,
    required Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> claimDocs,
  }) {
    final metrics = _calculateMetricsFromDocs(libraryDocs);
    final quests = _buildQuestStatuses(
      metrics: metrics,
      claimedKeys: _claimedKeysFromDocs(claimDocs),
    );
    return quests.any((quest) => quest.canClaim);
  }

  static Future<Map<String, dynamic>> claimQuest(QuestStatus quest) async {
    if (!quest.completed || quest.claimed) {
      return {'xpGained': 0, 'reasons': <String>[], 'leveledUp': false};
    }

    final userRef = _firestore.collection('users').doc(_uid);
    final claimRef = userRef.collection('questClaims').doc(quest.claimKey);

    bool alreadyClaimed = false;
    bool leveledUp = false;
    int newLevel = 1;
    String newTitle = '';

    await _firestore.runTransaction((tx) async {
      final claimSnap = await tx.get(claimRef);
      if (claimSnap.exists) {
        alreadyClaimed = true;
        return;
      }

      final userSnap = await tx.get(userRef);
      final userData = userSnap.data() ?? {};
      final int oldXp = _parseInt(userData['totalXp']);
      final int newXp = oldXp + quest.rewardXp;

      final oldLevelData = XpService.calculateLevel(oldXp);
      final newLevelData = XpService.calculateLevel(newXp);

      if ((newLevelData['level'] as int) > (oldLevelData['level'] as int)) {
        leveledUp = true;
        newLevel = newLevelData['level'] as int;
        newTitle = newLevelData['title'] as String;
      }

      tx.set(claimRef, {
        'questId': quest.id,
        'type': quest.type == QuestType.daily ? 'daily' : 'weekly',
        'title': quest.title,
        'rewardXp': quest.rewardXp,
        'claimedAt': FieldValue.serverTimestamp(),
      });

      tx.set(userRef, {
        'totalXp': newXp,
        'points': newXp,
        'level': newLevelData['level'],
      }, SetOptions(merge: true));
    });

    if (alreadyClaimed) {
      return {'xpGained': 0, 'reasons': <String>[], 'leveledUp': false};
    }

    return {
      'xpGained': quest.rewardXp,
      'reasons': ['+${quest.rewardXp} XP (${quest.title})'],
      'leveledUp': leveledUp,
      'newLevel': newLevel,
      'newTitle': newTitle,
    };
  }
}

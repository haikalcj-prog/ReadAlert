import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'xp_service.dart';

class LibraryService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw Exception('LibraryService: no authenticated user.');
    return user.uid;
  }

  // ==========================================
  // 1. MAIN LIBRARY METHODS
  // ==========================================

  static Stream<QuerySnapshot> getLibraryStream() {
    return _firestore
        .collection('users')
        .doc(_uid)
        .collection('library')
        .orderBy('addedAt', descending: true)
        .snapshots();
  }

  static Stream<DocumentSnapshot> getBookStream(String bookId) {
    return _firestore
        .collection('users')
        .doc(_uid)
        .collection('library')
        .doc(bookId)
        .snapshots();
  }

  static Future<void> addBook({
    required String bookId,
    required String title,
    required String authors,
    required String status,
    String? thumbnail,
    int? pageCount,
    String? description,
    String? publisher,
    String? publishedDate,
    String? categories,
    List<dynamic>? industryIdentifiers,
    String? bookUrl,
  }) async {
    final userRef = _firestore.collection('users').doc(_uid);
    final bookRef = userRef.collection('library').doc(bookId);

    final int totalPages = pageCount ?? 0;
    final int initialProgress = status == 'Finished' ? totalPages : 0;

    final String todayDate = XpService.dateKey(DateTime.now());
    String? startedReading;
    String? finishedReading;

    if (status == 'Reading') {
      startedReading = todayDate;
    } else if (status == 'Finished') {
      startedReading = todayDate;
      finishedReading = todayDate;
    }

    await bookRef.set({
      'title': title,
      'authors': authors,
      'status': status,
      'thumbnail': thumbnail,
      'pageCount': totalPages,
      'description': description,
      'publisher': publisher,
      'publishedDate': publishedDate,
      'categories': categories,
      'industryIdentifiers': industryIdentifiers,
      'bookUrl': bookUrl,
      'currentPage': initialProgress,
      'bestProgress': initialProgress,
      'startedReading': startedReading,
      'finishedReading': finishedReading,
      'progressHistory': initialProgress > 0
          ? [
              {
                'timestamp': Timestamp.now(),
                'pagesRead': initialProgress,
                'dateKey': todayDate,
              },
            ]
          : [],
      'addedAt': Timestamp.now(),
      'onShelves': [],
      'shelfAddedAt': {},
    });

    // Streak only counts when the user actually has reading progress.
    // Adding a book to Want to read / Reading with 0 pages will not count.
    final bool shouldCountStreak = initialProgress > 0;
    final bool isNewDay = shouldCountStreak
        ? await XpService.updateStreak()
        : false;

    await XpService.awardXp(
      pagesRead: initialProgress,
      isNewDay: isNewDay,
      justFinished: status == 'Finished',
      addedToLibrary: true,
    );
  }

  static Future<void> addManualBook({
    required String title,
    required String authors,
    required int pageCount,
    required int currentPage,
    required String status,
    required String bookFormat,
    String? genres,
    String? publisher,
    String? publishedDate,
    String? isbn13,
    String? isbn10,
    String? description,
    String? location,
    String? bookUrl,
    String? startedReading,
    String? finishedReading,
    File? coverImage,
  }) async {
    final bookId = const Uuid().v4();
    final bookRef = _firestore
        .collection('users')
        .doc(_uid)
        .collection('library')
        .doc(bookId);

    String? thumbnailUrl;
    if (coverImage != null) thumbnailUrl = coverImage.path;

    final List<Map<String, String>> identifiers = [];
    if (isbn13 != null && isbn13.isNotEmpty) {
      identifiers.add({'type': 'ISBN_13', 'identifier': isbn13});
    }
    if (isbn10 != null && isbn10.isNotEmpty) {
      identifiers.add({'type': 'ISBN_10', 'identifier': isbn10});
    }

    final int initialProgress = status == 'Finished' ? pageCount : currentPage;

    await bookRef.set({
      'title': title,
      'authors': authors,
      'categories': genres,
      'publisher': publisher,
      'publishedDate': publishedDate,
      'industryIdentifiers': identifiers,
      'description': description,
      'pageCount': pageCount,
      'location': location,
      'bookUrl': bookUrl,
      'status': status,
      'bookFormat': bookFormat,
      'thumbnail': thumbnailUrl,
      'addedAt': Timestamp.now(),
      'currentPage': initialProgress,
      'bestProgress': initialProgress,
      'startedReading': startedReading,
      'finishedReading': finishedReading,
      'progressHistory': initialProgress > 0
          ? [
              {
                'timestamp': Timestamp.now(),
                'pagesRead': initialProgress,
                'dateKey': XpService.dateKey(DateTime.now()),
              },
            ]
          : [],
      'onShelves': [],
      'shelfAddedAt': {},
    });

    // Streak only counts when the manual book already has reading progress.
    // Example: currentPage > 0 or status == Finished.
    final bool shouldCountStreak = initialProgress > 0;
    final bool isNewDay = shouldCountStreak
        ? await XpService.updateStreak()
        : false;

    await XpService.awardXp(
      pagesRead: initialProgress,
      isNewDay: isNewDay,
      justFinished: status == 'Finished',
      addedToLibrary: true,
    );
  }

  static Future<void> removeBook(String bookId) async {
    final userRef = _firestore.collection('users').doc(_uid);
    final bookRef = userRef.collection('library').doc(bookId);

    try {
      await _firestore.runTransaction((transaction) async {
        final bookSnap = await transaction.get(bookRef);
        if (!bookSnap.exists) return;

        final bookData = bookSnap.data() as Map<String, dynamic>;
        final int bestProgress =
            bookData['bestProgress'] ?? bookData['currentPage'] ?? 0;
        final String status = bookData['status'] ?? 'Want to read';
        final List<dynamic> onShelvesIds = bookData['onShelves'] ?? [];

        // 1. DEDUCT XP
        int xpToDeduct = 5 + bestProgress;
        if (status == 'Finished') xpToDeduct += 50;

        final userSnap = await transaction.get(userRef);
        final int currentXp = (userSnap.data() ?? {})['totalXp'] ?? 0;
        final int newXp = (currentXp - xpToDeduct).clamp(0, 99999999);

        transaction.update(userRef, {
          'totalXp': newXp,
          'points': newXp,
          'level': XpService.calculateLevel(newXp)['level'],
        });

        // 2. Clear Book Shadow Data & Remove main book
        transaction.delete(bookRef);

        // 3. Find and decrement book counts for any shelves this book was on
        final shelvesRef = userRef.collection('shelves');
        for (String shelfId in onShelvesIds) {
          transaction.update(shelvesRef.doc(shelfId), {
            'bookCount': FieldValue.increment(-1),
          });
        }
      });
    } catch (e) {
      debugPrint('Error removing book and updating shelves: $e');
      throw Exception('Failed to fully remove book from library and shelves.');
    }
  }

  static Future<void> updateProgress(String bookId, int currentPage) async {
    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('library')
        .doc(bookId)
        .update({'currentPage': currentPage});
  }

  static Future<Map<String, dynamic>> updateBookDetailsWithXp({
    required String bookId,
    required Map<String, dynamic> updates,
  }) async {
    final userRef = _firestore.collection('users').doc(_uid);
    final bookRef = userRef.collection('library').doc(bookId);

    int xpDifference = 0;
    bool leveledUp = false;
    int newLevel = 1;
    String newTitle = '';
    bool shouldCountStreak = false;

    try {
      await _firestore.runTransaction((transaction) async {
        final bookSnap = await transaction.get(bookRef);
        if (!bookSnap.exists) return;

        final oldData = bookSnap.data() as Map<String, dynamic>;

        int parseInt(dynamic val, [int def = 0]) {
          if (val is int) return val;
          if (val is double) return val.toInt();
          if (val is String) return int.tryParse(val) ?? def;
          return def;
        }

        final int oldBestProgress = parseInt(
          oldData['bestProgress'],
          parseInt(oldData['currentPage']),
        );
        final String oldStatus = oldData['status'] ?? 'Want to read';

        int oldXpYield = oldBestProgress;
        if (oldStatus == 'Finished') oldXpYield += 50;

        final Map<String, dynamic> safeUpdates = Map<String, dynamic>.from(
          updates,
        );

        int requestedProgress = safeUpdates.containsKey('currentPage')
            ? parseInt(safeUpdates['currentPage'])
            : parseInt(oldData['currentPage']);

        int newTotalPages = safeUpdates.containsKey('pageCount')
            ? parseInt(safeUpdates['pageCount'])
            : parseInt(oldData['pageCount'], 1);

        if (newTotalPages <= 0) newTotalPages = 1;

        String requestedStatus = safeUpdates['status'] ?? oldStatus;

        int newProgress = requestedProgress;
        String newStatus = requestedStatus;
        int newBestProgress = oldBestProgress;

        final String todayDate = XpService.dateKey(DateTime.now());

        bool isExplicitDemotion =
            oldStatus == 'Finished' &&
            (requestedStatus == 'Reading' || requestedStatus == 'Want to read');

        if (isExplicitDemotion) {
          newProgress = 0;
          newBestProgress = 0;
          newStatus = requestedStatus;
          safeUpdates['finishedReading'] = FieldValue.delete();
        } else if (requestedStatus == 'Finished' && oldStatus != 'Finished') {
          newProgress = newTotalPages;
          newStatus = 'Finished';
          safeUpdates['finishedReading'] = todayDate;
        } else if (newProgress >= newTotalPages) {
          newStatus = 'Finished';
          newProgress = newTotalPages;
          if (oldStatus != 'Finished') {
            safeUpdates['finishedReading'] = todayDate;
          }
        } else if (newProgress > 0 && requestedStatus == 'Want to read') {
          newStatus = 'Reading';
        } else if (newProgress < newTotalPages && oldStatus == 'Finished') {
          newStatus = 'Reading';
          safeUpdates['finishedReading'] = FieldValue.delete();
        }

        if (oldStatus == 'Want to read' && newStatus == 'Reading') {
          if (oldData['startedReading'] == null) {
            safeUpdates['startedReading'] = todayDate;
          }
        }

        if (!isExplicitDemotion) {
          newBestProgress = newProgress > oldBestProgress
              ? newProgress
              : oldBestProgress;
        }

        safeUpdates['status'] = newStatus;
        safeUpdates['currentPage'] = newProgress;
        safeUpdates['bestProgress'] = newBestProgress;

        final int pagesReadThisSession = newProgress > oldBestProgress
            ? newProgress - oldBestProgress
            : 0;
        if (pagesReadThisSession > 0 && !isExplicitDemotion) {
          safeUpdates['progressHistory'] = FieldValue.arrayUnion([
            {
              'timestamp': Timestamp.now(),
              'pagesRead': pagesReadThisSession,
              'dateKey': todayDate,
            },
          ]);
        }

        int newXpYield = newBestProgress;
        if (newStatus == 'Finished') newXpYield += 50;

        xpDifference = newXpYield - oldXpYield;

        // Count streak only when this edit represents real reading activity.
        // This covers increasing page progress and marking a book as Finished.
        shouldCountStreak =
            pagesReadThisSession > 0 ||
            (oldStatus != 'Finished' && newStatus == 'Finished');

        final userSnap = await transaction.get(userRef);
        final int currentXp = parseInt((userSnap.data() ?? {})['totalXp']);
        final int newTotalXp = (currentXp + xpDifference).clamp(0, 99999999);
        final newLevelData = XpService.calculateLevel(newTotalXp);

        transaction.update(bookRef, safeUpdates);
        transaction.set(userRef, {
          'totalXp': newTotalXp,
          'points': newTotalXp,
          'level': newLevelData['level'],
        }, SetOptions(merge: true));
      });
      // Add the daily streak bonus after the transaction, so it only happens
      // when the edit really counts as reading activity.
      if (shouldCountStreak) {
        final bool isNewDay = await XpService.updateStreak();
        if (isNewDay) {
          await XpService.awardXp(
            pagesRead: 0,
            isNewDay: true,
            justFinished: false,
          );
        }
      }
    } catch (e) {
      debugPrint('CRITICAL ERROR in updateBookDetailsWithXp: $e');
      rethrow;
    }

    return {
      'xpGained': xpDifference,
      'leveledUp': leveledUp,
      'newLevel': newLevel,
      'newTitle': newTitle,
    };
  }

  // ==========================================
  // 2. SHELF METHODS
  // ==========================================

  static Stream<QuerySnapshot> getShelvesStream() {
    return _firestore
        .collection('users')
        .doc(_uid)
        .collection('shelves')
        .snapshots();
  }

  static Future<void> createShelf(String name) async {
    final normalized = name.trim();
    if (normalized.isEmpty) {
      throw Exception('Shelf name cannot be empty.');
    }

    final shelvesRef = _firestore
        .collection('users')
        .doc(_uid)
        .collection('shelves');
    final existing = await shelvesRef.get();
    final exists = existing.docs.any(
      (doc) =>
          (doc['name'] ?? '').toString().trim().toLowerCase() ==
          normalized.toLowerCase(),
    );

    if (exists) {
      throw Exception('A shelf with that name already exists.');
    }

    await shelvesRef.add({
      'name': normalized,
      'bookCount': 0,
      'createdAt': Timestamp.now(),
    });
  }

  static Future<void> renameShelf(String shelfId, String newName) async {
    final normalized = newName.trim();
    if (normalized.isEmpty) {
      throw Exception('Shelf name cannot be empty.');
    }

    final shelvesRef = _firestore
        .collection('users')
        .doc(_uid)
        .collection('shelves');
    final existing = await shelvesRef.get();
    final exists = existing.docs.any(
      (doc) =>
          doc.id != shelfId &&
          (doc['name'] ?? '').toString().trim().toLowerCase() ==
              normalized.toLowerCase(),
    );

    if (exists) {
      throw Exception('A shelf with that name already exists.');
    }

    await shelvesRef.doc(shelfId).update({'name': normalized});
  }

  static Stream<QuerySnapshot> getBooksInShelfStream(String shelfId) {
    return _firestore
        .collection('users')
        .doc(_uid)
        .collection('library')
        .where('onShelves', arrayContains: shelfId)
        .snapshots();
  }

  static Future<void> deleteShelf(String shelfId) async {
    final userRef = _firestore.collection('users').doc(_uid);
    final shelfRef = userRef.collection('shelves').doc(shelfId);

    // Scan all library books to unlink them from this shelf
    final booksOnThisShelfQuery = await userRef
        .collection('library')
        .where('onShelves', arrayContains: shelfId)
        .get();

    WriteBatch batch = _firestore.batch();

    // Unlink books using shadow data
    for (var doc in booksOnThisShelfQuery.docs) {
      batch.update(doc.reference, {
        'onShelves': FieldValue.arrayRemove([shelfId]),
        'shelfAddedAt.$shelfId': FieldValue.delete(),
      });
    }

    // Delete the shelf document itself
    batch.delete(shelfRef);

    await batch.commit();
  }

  static Future<void> unlinkBookFromShelf(String bookId, String shelfId) async {
    final userRef = _firestore.collection('users').doc(_uid);

    await _firestore.runTransaction((transaction) async {
      final shelfRef = userRef.collection('shelves').doc(shelfId);
      final bookRef = userRef.collection('library').doc(bookId);
      final bookSnap = await transaction.get(bookRef);

      if (!bookSnap.exists) return;

      final bookData = bookSnap.data() as Map<String, dynamic>;
      final onShelves = List<String>.from(bookData['onShelves'] ?? []);
      if (!onShelves.contains(shelfId)) return;

      transaction.update(bookRef, {
        'onShelves': FieldValue.arrayRemove([shelfId]),
        'shelfAddedAt.$shelfId': FieldValue.delete(),
      });

      transaction.update(shelfRef, {'bookCount': FieldValue.increment(-1)});
    });
  }

  static Future<void> linkBooksToShelf(
    String shelfId,
    List<String> bookIds,
  ) async {
    if (bookIds.isEmpty) return;
    final userRef = _firestore.collection('users').doc(_uid);
    final shelfRef = userRef.collection('shelves').doc(shelfId);

    await _firestore.runTransaction((transaction) async {
      final bookRefs = bookIds.toSet().map(
        (bookId) => userRef.collection('library').doc(bookId),
      );
      final bookSnaps = <DocumentSnapshot>[];

      for (final bookRef in bookRefs) {
        bookSnaps.add(await transaction.get(bookRef));
      }

      int linkedCount = 0;

      for (final bookSnap in bookSnaps) {
        if (!bookSnap.exists) {
          continue;
        }

        final bookData = bookSnap.data() as Map<String, dynamic>;
        final onShelves = List<String>.from(bookData['onShelves'] ?? []);
        if (onShelves.contains(shelfId)) {
          continue;
        }

        transaction.update(bookSnap.reference, {
          'onShelves': FieldValue.arrayUnion([shelfId]),
          'shelfAddedAt.$shelfId': Timestamp.now(),
        });
        linkedCount++;
      }

      if (linkedCount > 0) {
        transaction.update(shelfRef, {
          'bookCount': FieldValue.increment(linkedCount),
        });
      }
    });
  }

  static Future<void> saveBookShelves({
    required String bookId,
    required Set<String> selectedShelfIds,
  }) async {
    final userRef = _firestore.collection('users').doc(_uid);
    final bookRef = userRef.collection('library').doc(bookId);

    await _firestore.runTransaction((transaction) async {
      final bookSnap = await transaction.get(bookRef);
      if (!bookSnap.exists) {
        throw Exception('Book not found in library.');
      }

      final bookData = bookSnap.data() as Map<String, dynamic>;
      final currentShelfIds = Set<String>.from(bookData['onShelves'] ?? []);
      final shelvesToAdd = selectedShelfIds.difference(currentShelfIds);
      final shelvesToRemove = currentShelfIds.difference(selectedShelfIds);

      if (shelvesToAdd.isEmpty && shelvesToRemove.isEmpty) {
        return;
      }

      final updates = <String, dynamic>{'onShelves': selectedShelfIds.toList()};

      for (final shelfId in shelvesToAdd) {
        updates['shelfAddedAt.$shelfId'] = Timestamp.now();
      }

      for (final shelfId in shelvesToRemove) {
        updates['shelfAddedAt.$shelfId'] = FieldValue.delete();
      }

      transaction.update(bookRef, updates);

      for (final shelfId in shelvesToAdd) {
        final shelfRef = userRef.collection('shelves').doc(shelfId);
        transaction.update(shelfRef, {'bookCount': FieldValue.increment(1)});
      }

      for (final shelfId in shelvesToRemove) {
        final shelfRef = userRef.collection('shelves').doc(shelfId);
        transaction.update(shelfRef, {'bookCount': FieldValue.increment(-1)});
      }
    });
  }
}

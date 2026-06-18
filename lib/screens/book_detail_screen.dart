import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../services/library_service.dart';
import '../services/level_up_service.dart';
import 'full_book_info_screen.dart';

class BookDetailScreen extends StatefulWidget {
  final Map<String, dynamic> bookData;

  const BookDetailScreen({super.key, required this.bookData});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  bool _isAdding = false;
  bool _isRemoving = false;

  final Color bgColor = const Color(0xFF111118);
  final Color cardColor = const Color(0xFF1A1A26);
  final Color accentColor = const Color(0xFFE91E63);

  Map<String, dynamic> get _volumeInfo {
    if (widget.bookData.containsKey('volumeInfo')) {
      return widget.bookData['volumeInfo'] as Map<String, dynamic>;
    }
    return widget.bookData;
  }

  String get _bookId => widget.bookData['id'] ?? '';

  String? get _bookUrl {
    final candidates = [
      widget.bookData['bookUrl'],
      _volumeInfo['bookUrl'],
      _volumeInfo['infoLink'],
      _volumeInfo['canonicalVolumeLink'],
      _volumeInfo['previewLink'],
    ];

    for (final value in candidates) {
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return null;
  }

  Widget _buildCoverImage(
    String? url,
    double width,
    double height, {
    bool isBlurred = false,
  }) {
    if (url == null || url.isEmpty || url == 'null') {
      return isBlurred
          ? Container(color: bgColor.withOpacity(0.6))
          : Container(
              width: width,
              height: height,
              color: const Color(0xFF222233),
              child: const Icon(
                Icons.menu_book_rounded,
                color: Colors.grey,
                size: 50,
              ),
            );
    }

    if (url.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorWidget: (context, url, error) => Container(
          width: width,
          height: height,
          color: const Color(0xFF222233),
          child: const Icon(
            Icons.broken_image_rounded,
            color: Colors.grey,
            size: 50,
          ),
        ),
      );
    } else {
      return Image.file(
        File(url),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: width,
          height: height,
          color: const Color(0xFF222233),
          child: const Icon(
            Icons.broken_image_rounded,
            color: Colors.grey,
            size: 50,
          ),
        ),
      );
    }
  }

  void _showAddToLibraryPicker(bool isInLibrary) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF15151F),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isInLibrary
                            ? Icons.swap_horiz_rounded
                            : Icons.library_add_rounded,
                        color: accentColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isInLibrary ? 'Change Status' : 'Add to Library',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Choose a reading status',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                _buildShelfOption(
                  'Want to read',
                  Icons.bookmark_rounded,
                  isInLibrary,
                ),
                const SizedBox(height: 10),
                _buildShelfOption(
                  'Reading',
                  Icons.auto_stories_rounded,
                  isInLibrary,
                ),
                const SizedBox(height: 10),
                _buildShelfOption(
                  'Finished',
                  Icons.check_circle_rounded,
                  isInLibrary,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.white.withOpacity(0.08)),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShelfOption(String status, IconData icon, bool isInLibrary) {
    // Map status to visual config
    final Map<String, Map<String, dynamic>> statusConfig = {
      'Want to read': {
        'gradient': [const Color(0xFF6C63FF), const Color(0xFF9C8FFF)],
        'bgColor': const Color(0xFF6C63FF).withOpacity(0.12),
        'borderColor': const Color(0xFF6C63FF).withOpacity(0.35),
        'subtitle': 'Add to your reading wishlist',
      },
      'Reading': {
        'gradient': [const Color(0xFF00C9A7), const Color(0xFF00E5C2)],
        'bgColor': const Color(0xFF00C9A7).withOpacity(0.12),
        'borderColor': const Color(0xFF00C9A7).withOpacity(0.35),
        'subtitle': 'Mark as currently reading',
      },
      'Finished': {
        'gradient': [const Color(0xFFE91E63), const Color(0xFFFF5E9E)],
        'bgColor': const Color(0xFFE91E63).withOpacity(0.12),
        'borderColor': const Color(0xFFE91E63).withOpacity(0.35),
        'subtitle': 'Mark as completed · earn XP',
      },
    };

    final cfg =
        statusConfig[status] ??
        {
          'gradient': [accentColor, accentColor],
          'bgColor': accentColor.withOpacity(0.12),
          'borderColor': accentColor.withOpacity(0.35),
          'subtitle': '',
        };

    final gradientColors = cfg['gradient'] as List<Color>;
    final bgCol = cfg['bgColor'] as Color;
    final borderCol = cfg['borderColor'] as Color;
    final subtitle = cfg['subtitle'] as String;

    return GestureDetector(
      onTap: () async {
        Navigator.pop(context);
        if (isInLibrary) {
          await _updateStatus(status);
        } else {
          await _addToLibrary(status);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bgCol,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderCol, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: gradientColors[0].withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withOpacity(0.3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addToLibrary(String status) async {
    if (_bookId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not identify this book.')),
      );
      return;
    }

    setState(() => _isAdding = true);

    try {
      await LibraryService.addBook(
        bookId: _bookId,
        title: _volumeInfo['title'] ?? 'Unknown',
        authors: _volumeInfo['authors'] is List
            ? (_volumeInfo['authors'] as List).join(', ')
            : _volumeInfo['authors']?.toString() ?? 'Unknown',
        status: status,
        thumbnail:
            _volumeInfo['imageLinks']?['thumbnail']?.replaceFirst(
              'http:',
              'https:',
            ) ??
            _volumeInfo['thumbnail'],
        pageCount: _volumeInfo['pageCount'] is int
            ? _volumeInfo['pageCount']
            : int.tryParse(_volumeInfo['pageCount'].toString()),
        description: _volumeInfo['description'],
        publisher: _volumeInfo['publisher'],
        publishedDate: _volumeInfo['publishedDate'],
        categories: _volumeInfo['categories'] is List
            ? (_volumeInfo['categories'] as List).join(', ')
            : _volumeInfo['categories']?.toString(),
        industryIdentifiers: _volumeInfo['industryIdentifiers'],
        bookUrl: _bookUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added to "$status"!'),
            backgroundColor: accentColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _isAdding = true);
    try {
      final result = await LibraryService.updateBookDetailsWithXp(
        bookId: _bookId,
        updates: {'status': status},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status changed to "$status"!'),
            backgroundColor: accentColor,
          ),
        );

        final int xpGained = result['xpGained'] ?? 0;
        if (xpGained != 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                xpGained > 0
                    ? '+$xpGained XP Earned!'
                    : '$xpGained XP Reverted!',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: xpGained > 0
                  ? Colors.greenAccent.shade700
                  : Colors.orangeAccent.shade700,
            ),
          );
        }

        if (result['leveledUp'] == true) {
          LevelUpService.showLevelUp(
            result['newLevel'] as int,
            result['newTitle'] as String,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _removeFromLibrary() async {
    setState(() => _isRemoving = true);
    try {
      await LibraryService.removeBook(_bookId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from library.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isRemoving = false);
    }
  }

  void _showShelfSelector(Map<String, dynamic> firestoreBookData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddBookToShelvesModal(
        bookId: _bookId,
        onShelves: List<String>.from(firestoreBookData['onShelves'] ?? []),
        onSaved: () {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Shelves updated.'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  void _showEditNoteDialog(String currentNote) {
    final TextEditingController controller = TextEditingController(
      text: currentNote,
    );
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Edit Note', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            maxLines: 5,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Add a personal note about this book...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              filled: true,
              fillColor: bgColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await LibraryService.updateBookDetailsWithXp(
                    bookId: _bookId,
                    updates: {'note': controller.text.trim()},
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Note updated.'),
                        backgroundColor: accentColor,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating note: $e')),
                    );
                  }
                }
              },
              child: Text(
                'Save',
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateRating(int rating, {bool showMessage = false}) async {
    try {
      await LibraryService.updateBookDetailsWithXp(
        bookId: _bookId,
        updates: {'rating': rating},
      );
      if (showMessage && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(rating > 0 ? 'Rating updated.' : 'Rating cleared.'),
            backgroundColor: accentColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating rating: $e')));
      }
    }
  }

  void _showEditRatingSheet(int currentRating) {
    int selectedRating = currentRating;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF15151F),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border(
                  top: BorderSide(
                    color: Colors.amberAccent.withOpacity(0.18),
                    width: 1,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.10),
                    blurRadius: 32,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Colors.amberAccent.withOpacity(0.95),
                              Colors.orangeAccent.withOpacity(0.88),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amberAccent.withOpacity(0.28),
                              blurRadius: 22,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.star_rounded,
                          color: Color(0xFF3A2600),
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Edit Rating',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        selectedRating > 0
                            ? '$selectedRating of 5 stars'
                            : 'Choose a rating',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.45),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          5,
                          (index) => _ratingStarButton(
                            index: index,
                            currentRating: selectedRating,
                            size: 34,
                            padding: 5,
                            onSelected: (rating) {
                              setSheetState(() => selectedRating = rating);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          if (currentRating > 0)
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  Navigator.pop(sheetContext);
                                  await _updateRating(0, showMessage: true);
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                  ),
                                  side: BorderSide(
                                    color: Colors.white.withOpacity(0.12),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  'Clear',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.72),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          if (currentRating > 0) const SizedBox(width: 12),
                          Expanded(
                            flex: currentRating > 0 ? 1 : 2,
                            child: ElevatedButton(
                              onPressed: selectedRating == 0
                                  ? null
                                  : () async {
                                      Navigator.pop(sheetContext);
                                      await _updateRating(
                                        selectedRating,
                                        showMessage: true,
                                      );
                                    },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                backgroundColor: Colors.amber,
                                disabledBackgroundColor: Colors.white
                                    .withOpacity(0.08),
                                foregroundColor: const Color(0xFF2D1C00),
                                disabledForegroundColor: Colors.white
                                    .withOpacity(0.28),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              child: const Text('Save Rating'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _ratingStarButton({
    required int index,
    required int currentRating,
    required ValueChanged<int> onSelected,
    double size = 24,
    double padding = 3,
  }) {
    final filled = index < currentRating;

    return GestureDetector(
      onTap: () => onSelected(index + 1),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: padding),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: size + 14,
          height: size + 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: filled
                ? LinearGradient(
                    colors: [
                      Colors.amberAccent.withOpacity(0.28),
                      Colors.orangeAccent.withOpacity(0.16),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: filled ? null : Colors.white.withOpacity(0.045),
            border: Border.all(
              color: filled
                  ? Colors.amberAccent.withOpacity(0.42)
                  : Colors.white.withOpacity(0.08),
            ),
            boxShadow: filled
                ? [
                    BoxShadow(
                      color: Colors.amberAccent.withOpacity(0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            filled ? Icons.star_rounded : Icons.star_border_rounded,
            color: filled ? Colors.amberAccent : Colors.white.withOpacity(0.28),
            size: size,
          ),
        ),
      ),
    );
  }

  Widget _ratingStarDisplay({
    required int index,
    required int currentRating,
    double size = 24,
    double padding = 3,
  }) {
    final filled = index < currentRating;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding),
      child: Container(
        width: size + 14,
        height: size + 14,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: filled
              ? LinearGradient(
                  colors: [
                    Colors.amberAccent.withOpacity(0.28),
                    Colors.orangeAccent.withOpacity(0.16),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: filled ? null : Colors.white.withOpacity(0.045),
          border: Border.all(
            color: filled
                ? Colors.amberAccent.withOpacity(0.42)
                : Colors.white.withOpacity(0.08),
          ),
          boxShadow: filled
              ? [
                  BoxShadow(
                    color: Colors.amberAccent.withOpacity(0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Icon(
          filled ? Icons.star_rounded : Icons.star_border_rounded,
          color: filled ? Colors.amberAccent : Colors.white.withOpacity(0.28),
          size: size,
        ),
      ),
    );
  }

  Widget _buildRatingCard(int currentRating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            Colors.amberAccent.withOpacity(0.10),
            Colors.white.withOpacity(0.035),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.amberAccent.withOpacity(0.16)),
        boxShadow: [
          BoxShadow(
            color: Colors.amberAccent.withOpacity(0.07),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (index) => _ratingStarDisplay(
                    index: index,
                    currentRating: currentRating,
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  currentRating > 0
                      ? 'Your rating: $currentRating/5'
                      : 'Tap the pencil to rate',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.48),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.white.withOpacity(0.06),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _showEditRatingSheet(currentRating),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.edit_rounded,
                  color: Colors.amberAccent.withOpacity(0.92),
                  size: 17,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: LibraryService.getBookStream(_bookId),
      builder: (context, snapshot) {
        Map<String, dynamic> firestoreData = {};
        if (snapshot.hasData && snapshot.data!.exists) {
          firestoreData = snapshot.data!.data() as Map<String, dynamic>;
        }
        return _buildBody(context, firestoreData);
      },
    );
  }

  Widget _buildBody(BuildContext context, Map<String, dynamic> firestoreData) {
    final title =
        firestoreData['title'] ?? _volumeInfo['title'] ?? 'Unknown Title';

    String authors = 'Unknown Author';
    if (firestoreData['authors'] != null) {
      authors = firestoreData['authors'] is List
          ? (firestoreData['authors'] as List).join(', ')
          : firestoreData['authors'].toString();
    } else if (_volumeInfo['authors'] != null) {
      authors = _volumeInfo['authors'] is List
          ? (_volumeInfo['authors'] as List).join(', ')
          : _volumeInfo['authors'].toString();
    }

    final description =
        firestoreData['description'] ??
        _volumeInfo['description'] ??
        'No synopsis available for this book.';

    final thumbnailUrl =
        firestoreData['thumbnail'] ??
        _volumeInfo['imageLinks']?['thumbnail']?.replaceFirst(
          'http:',
          'https:',
        ) ??
        _volumeInfo['thumbnail'];

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.only(left: 8.0, top: 8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: cardColor.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            actions: [
              StreamBuilder<DocumentSnapshot>(
                stream: LibraryService.getBookStream(_bookId),
                builder: (context, snapshot) {
                  bool isInLibrary = snapshot.hasData && snapshot.data!.exists;
                  if (!isInLibrary) return const SizedBox.shrink();

                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0, top: 8.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: cardColor.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.share_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          final text =
                              "Check out this book I'm reading: $title by $authors!";
                          final shareContent = _bookUrl != null
                              ? '$text\n\n$_bookUrl'
                              : text;
                          Share.share(shareContent);
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                SizedBox(
                  height: 250,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (thumbnailUrl != null)
                        Positioned.fill(
                          child: _buildCoverImage(
                            thumbnailUrl,
                            double.infinity,
                            250,
                            isBlurred: true,
                          ),
                        ),
                      Positioned.fill(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(color: bgColor.withOpacity(0.5)),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black45,
                              blurRadius: 20,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _buildCoverImage(thumbnailUrl, 130, 200),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        authors,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[400], fontSize: 16),
                      ),
                      if (firestoreData['status'] == 'Finished') ...[
                        const SizedBox(height: 12),
                        _buildRatingCard(
                          (firestoreData['rating'] as num?)?.toInt() ?? 0,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                StreamBuilder<DocumentSnapshot>(
                  stream: LibraryService.getBookStream(_bookId),
                  builder: (context, snapshot) {
                    bool isInLibrary =
                        snapshot.hasData && snapshot.data!.exists;
                    Map<String, dynamic> firestoreBookData = {};
                    if (isInLibrary) {
                      firestoreBookData =
                          snapshot.data!.data() as Map<String, dynamic>;
                    }

                    final currentformat =
                        firestoreBookData['bookFormat'] ??
                        firestoreBookData['format'] ??
                        _volumeInfo['format'] ??
                        'Physical';

                    final currentPageCount =
                        firestoreBookData['pageCount']?.toString() ??
                        _volumeInfo['pageCount']?.toString() ??
                        'N/A';

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: IntrinsicHeight(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: cardColor,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white12),
                                    ),
                                    child: Column(
                                      children: [
                                        const Icon(
                                          Icons.book_rounded,
                                          color: Colors.blueAccent,
                                          size: 28,
                                        ),
                                        const SizedBox(height: 10),
                                        const Text(
                                          'FORMAT',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 10,
                                            letterSpacing: 1,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          currentformat,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: cardColor,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white12),
                                    ),
                                    child: Column(
                                      children: [
                                        const Icon(
                                          Icons.insert_drive_file_rounded,
                                          color: Colors.greenAccent,
                                          size: 28,
                                        ),
                                        const SizedBox(height: 10),
                                        const Text(
                                          'PAGES',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 10,
                                            letterSpacing: 1,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          currentPageCount,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
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

                        const SizedBox(height: 32),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                FullBookInfoScreen(
                                                  bookData: _volumeInfo,
                                                ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.info_outline_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      label: const Text(
                                        'All Details',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        side: const BorderSide(
                                          color: Colors.white24,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  Expanded(
                                    child: _AddToLibraryButton(
                                      isInLibrary: isInLibrary,
                                      isLoading: _isAdding,
                                      accentColor: accentColor,
                                      onTap: () =>
                                          _showAddToLibraryPicker(isInLibrary),
                                    ),
                                  ),
                                ],
                              ),

                              if (isInLibrary) ...[
                                const SizedBox(height: 20),
                                _isRemoving
                                    ? const Center(
                                        child: CircularProgressIndicator(
                                          color: Colors.redAccent,
                                        ),
                                      )
                                    : SizedBox(
                                        width: double.infinity,
                                        child: TextButton.icon(
                                          onPressed: _removeFromLibrary,
                                          icon: const Icon(
                                            Icons.delete_forever_rounded,
                                            color: Colors.redAccent,
                                            size: 18,
                                          ),
                                          label: const Text(
                                            'REMOVE FROM LIBRARY',
                                            style: TextStyle(
                                              color: Colors.redAccent,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ),

                                const SizedBox(height: 24),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: cardColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: StreamBuilder<QuerySnapshot>(
                                    stream: LibraryService.getShelvesStream(),
                                    builder: (context, shelfSnapshot) {
                                      final selectedIds = Set<String>.from(
                                        firestoreBookData['onShelves'] ?? [],
                                      );
                                      final shelves = shelfSnapshot.hasData
                                          ? shelfSnapshot.data!.docs
                                                .where(
                                                  (doc) => selectedIds.contains(
                                                    doc.id,
                                                  ),
                                                )
                                                .toList()
                                          : <QueryDocumentSnapshot>[];

                                      shelves.sort(
                                        (a, b) => (a['name'] ?? '')
                                            .toString()
                                            .toLowerCase()
                                            .compareTo(
                                              (b['name'] ?? '')
                                                  .toString()
                                                  .toLowerCase(),
                                            ),
                                      );

                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Expanded(
                                                child: Text(
                                                  'SHELVES',
                                                  style: TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 10,
                                                    letterSpacing: 1,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              TextButton.icon(
                                                onPressed: () =>
                                                    _showShelfSelector(
                                                      firestoreBookData,
                                                    ),
                                                icon: const Icon(
                                                  Icons.add_rounded,
                                                  color: Colors.amberAccent,
                                                  size: 18,
                                                ),
                                                label: const Text(
                                                  'Manage',
                                                  style: TextStyle(
                                                    color: Colors.amberAccent,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          if (selectedIds.isEmpty)
                                            Container(
                                              width: double.infinity,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 14,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(
                                                  0.04,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              child: const Text(
                                                'Not added to any custom shelf yet. Tap Manage to organize it.',
                                                style: TextStyle(
                                                  color: Colors.white60,
                                                  height: 1.4,
                                                ),
                                              ),
                                            )
                                          else
                                            Wrap(
                                              spacing: 10,
                                              runSpacing: 10,
                                              children: shelves
                                                  .map(
                                                    (shelf) => Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 14,
                                                            vertical: 10,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors
                                                            .amberAccent
                                                            .withOpacity(0.12),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              14,
                                                            ),
                                                        border: Border.all(
                                                          color: Colors
                                                              .amberAccent
                                                              .withOpacity(
                                                                0.28,
                                                              ),
                                                        ),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          const Icon(
                                                            Icons
                                                                .check_circle_rounded,
                                                            color: Colors
                                                                .amberAccent,
                                                            size: 16,
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Text(
                                                            shelf['name']
                                                                    ?.toString() ??
                                                                'Unnamed',
                                                            style:
                                                                const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: cardColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'NOTE',
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 10,
                                              letterSpacing: 1,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () => _showEditNoteDialog(
                                              firestoreBookData['note'] ?? '',
                                            ),
                                            child: const Icon(
                                              Icons.edit_rounded,
                                              color: Colors.grey,
                                              size: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        (firestoreBookData['note'] == null ||
                                                firestoreBookData['note']
                                                    .toString()
                                                    .trim()
                                                    .isEmpty)
                                            ? 'Tap the edit icon to add a personal note.'
                                            : firestoreBookData['note'],
                                        style: TextStyle(
                                          color:
                                              (firestoreBookData['note'] ==
                                                      null ||
                                                  firestoreBookData['note']
                                                      .toString()
                                                      .trim()
                                                      .isEmpty)
                                              ? Colors.white38
                                              : Colors.white,
                                          fontSize: 14,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 36),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                    border: const Border(
                      top: BorderSide(color: Colors.white12),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Synopsis',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.grey[300],
                          height: 1.6,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// Animated Add to Library Button
// ════════════════════════════════════════════════════════════
class _AddToLibraryButton extends StatefulWidget {
  final bool isInLibrary;
  final bool isLoading;
  final Color accentColor;
  final VoidCallback onTap;

  const _AddToLibraryButton({
    required this.isInLibrary,
    required this.isLoading,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_AddToLibraryButton> createState() => _AddToLibraryButtonState();
}

class _AddToLibraryButtonState extends State<_AddToLibraryButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _controller.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final bool added = widget.isInLibrary;

    return ScaleTransition(
      scale: _scaleAnim,
      child: GestureDetector(
        onTapDown: widget.isLoading ? null : _onTapDown,
        onTapUp: widget.isLoading ? null : _onTapUp,
        onTapCancel: widget.isLoading ? null : _onTapCancel,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          height: 50,
          decoration: BoxDecoration(
            gradient: added
                ? LinearGradient(
                    colors: [const Color(0xFF2A2A3A), const Color(0xFF222232)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [
                      widget.accentColor,
                      widget.accentColor.withRed(
                        (widget.accentColor.red * 0.75).toInt(),
                      ),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(14),
            border: added
                ? Border.all(
                    color: widget.accentColor.withOpacity(0.45),
                    width: 1.5,
                  )
                : null,
            boxShadow: widget.isLoading
                ? []
                : [
                    BoxShadow(
                      color: added
                          ? Colors.transparent
                          : widget.accentColor.withOpacity(0.38),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                      spreadRadius: -2,
                    ),
                  ],
          ),
          child: widget.isLoading
              ? Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: added ? widget.accentColor : Colors.white,
                      strokeWidth: 2.2,
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: Icon(
                        added
                            ? Icons.check_circle_rounded
                            : Icons.library_add_rounded,
                        key: ValueKey(added),
                        color: added ? widget.accentColor : Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Text(
                        added ? 'In Library' : 'Add to Library',
                        key: ValueKey(added),
                        style: TextStyle(
                          color: added ? widget.accentColor : Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// ════════════════════════════════════════════════════════════
class _AddBookToShelvesModal extends StatefulWidget {
  final String bookId;
  final List<String> onShelves;
  final VoidCallback onSaved;

  const _AddBookToShelvesModal({
    required this.bookId,
    required this.onShelves,
    required this.onSaved,
  });

  @override
  State<_AddBookToShelvesModal> createState() => _AddBookToShelvesModalState();
}

class _AddBookToShelvesModalState extends State<_AddBookToShelvesModal> {
  late Set<String> _shadowOnShelves;
  late final Stream<QuerySnapshot> _shelvesStream;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _shadowOnShelves = Set.from(widget.onShelves);
    _shelvesStream = LibraryService.getShelvesStream();
  }

  void _setShelfChecked(String shelfId, bool checked) {
    setState(() {
      if (checked) {
        _shadowOnShelves.add(shelfId);
      } else {
        _shadowOnShelves.remove(shelfId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.86,
        ),
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A26),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Manage Shelves',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amberAccent.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_shadowOnShelves.length} selected',
                    style: const TextStyle(
                      color: Colors.amberAccent,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Tick shelves to add this book. Untick shelves to remove it.',
              style: TextStyle(color: Colors.white60, height: 1.4),
            ),
            const SizedBox(height: 20),

            StreamBuilder<QuerySnapshot>(
              stream: _shelvesStream,
              builder: (ctx, snapshot) {
                if (!snapshot.hasData &&
                    snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(
                        color: Colors.amberAccent,
                      ),
                    ),
                  );
                }
                final shelves = snapshot.data?.docs.toList() ?? [];
                if (shelves.isEmpty) {
                  return const Text(
                    'No shelves created yet. Create one from your Library screen first.',
                    style: TextStyle(color: Colors.white54, height: 1.4),
                  );
                }

                shelves.sort(
                  (a, b) => (a['name'] ?? '')
                      .toString()
                      .toLowerCase()
                      .compareTo((b['name'] ?? '').toString().toLowerCase()),
                );

                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: shelves.length,
                    itemBuilder: (context, index) {
                      final shelf = shelves[index];
                      final shelfId = shelf.id;
                      final shelfName = shelf['name'] ?? 'Unnamed';
                      final bool isChecked = _shadowOnShelves.contains(shelfId);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            _setShelfChecked(shelfId, !isChecked);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isChecked
                                  ? Colors.amberAccent.withOpacity(0.12)
                                  : const Color(0xFF20202F),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isChecked
                                    ? Colors.amberAccent
                                    : Colors.white12,
                                width: 1.4,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: isChecked
                                        ? Colors.amberAccent.withOpacity(0.18)
                                        : Colors.white.withOpacity(0.04),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    isChecked
                                        ? Icons.check_circle_rounded
                                        : Icons.collections_bookmark_outlined,
                                    color: isChecked
                                        ? Colors.amberAccent
                                        : Colors.white70,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    shelfName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                Checkbox(
                                  activeColor: Colors.amberAccent,
                                  checkColor: Colors.black87,
                                  side: const BorderSide(color: Colors.white54),
                                  value: isChecked,
                                  onChanged: (bool? newVal) {
                                    _setShelfChecked(shelfId, newVal == true);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),

            const Divider(color: Colors.white12, height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amberAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _isSaving
                    ? null
                    : () async {
                        setState(() => _isSaving = true);
                        final navigator = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await LibraryService.saveBookShelves(
                            bookId: widget.bookId,
                            selectedShelfIds: _shadowOnShelves,
                          );
                          if (!mounted) return;
                          navigator.pop();
                          widget.onSaved();
                        } catch (e) {
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                          setState(() => _isSaving = false);
                        }
                      },
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.black87,
                          strokeWidth: 2.2,
                        ),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

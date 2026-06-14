import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/library_service.dart';
import 'book_detail_screen.dart';
import 'add_book_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ════════════════════════════════════════════════════════════
// UTILS & COLORS
// ════════════════════════════════════════════════════════════
Map<String, dynamic> _formatBookData(dynamic doc) {
  Map<String, dynamic> data;
  String id;

  if (doc is QueryDocumentSnapshot) {
    data = Map<String, dynamic>.from(doc.data() as Map);
    id = doc.id;
  } else if (doc is DocumentSnapshot) {
    data = Map<String, dynamic>.from(doc.data() as Map);
    id = doc.id;
  } else {
    data = Map<String, dynamic>.from(doc);
    id = data['id'] ?? '';
  }

  data['id'] = id;
  if (data['authors'] is String) data['authors'] = [data['authors']];
  if (data['thumbnail'] != null) {
    data['imageLinks'] = {'thumbnail': data['thumbnail']};
  }
  if (data['categories'] is String) data['categories'] = [data['categories']];
  return data;
}

Widget _buildCoverImage(String? url, double width, double height) {
  if (url == null || url.isEmpty || url == 'null') {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFF1E293B),
      child: const Icon(Icons.menu_book, color: Colors.white24, size: 40),
    );
  }
  if (url.startsWith('http')) {
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorWidget: (c, u, e) => Container(
        width: width,
        height: height,
        color: const Color(0xFF1E293B),
        child: const Icon(Icons.broken_image, color: Colors.white24),
      ),
    );
  } else {
    return Image.file(
      File(url),
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (c, e, s) => Container(
        width: width,
        height: height,
        color: const Color(0xFF1E293B),
        child: const Icon(Icons.broken_image, color: Colors.white24),
      ),
    );
  }
}

const Color bgColor = Color(0xFF0F172A);
const Color cardColor = Color(0xFF1E293B);
const Color accentColor = Color(0xFF8B5CF6);
const Color wantColor = Color(0xFFF43F5E);
const Color readColor = Color(0xFF0EA5E9);
const Color finColor = Color(0xFF10B981);

String _normalizeBookStatus(dynamic value) {
  final status = value?.toString().trim();
  if (status == 'Reading' || status == 'Finished') return status!;
  return 'Want to read';
}

Color _bookStatusColor(String status) {
  if (status == 'Reading') return readColor;
  if (status == 'Finished') return finColor;
  return wantColor;
}

IconData _bookStatusIcon(String status) {
  if (status == 'Reading') return Icons.auto_stories_rounded;
  if (status == 'Finished') return Icons.check_circle_rounded;
  return Icons.bookmark_rounded;
}

Widget _buildStatusBadge(String status, {int? count}) {
  final color = _bookStatusColor(status);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(0.14),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withOpacity(0.26)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_bookStatusIcon(status), color: color, size: 13),
        const SizedBox(width: 5),
        Text(
          count == null ? status : '$count $status',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

Map<String, int> _statusCountsForBooks(List<QueryDocumentSnapshot> books) {
  final counts = {'Want to read': 0, 'Reading': 0, 'Finished': 0};

  for (final book in books) {
    final data = book.data() as Map<String, dynamic>? ?? {};
    final status = _normalizeBookStatus(data['status']);
    counts[status] = (counts[status] ?? 0) + 1;
  }

  return counts;
}

// ════════════════════════════════════════════════════════════
// MAIN LIBRARY SCREEN
// ════════════════════════════════════════════════════════════
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  void _openLibrarySearch(List<QueryDocumentSnapshot> allBooks) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LibrarySearchModal(
        allBooks: allBooks,
        bgColor: bgColor,
        cardColor: cardColor,
      ),
    );
  }

  void _showCreateShelfModal({String? editShelfId, String? currentName}) {
    final nameCtrl = TextEditingController(text: currentName);
    final bool isEdit = editShelfId != null;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
              decoration: const BoxDecoration(
                color: Color(0xFF1A2035),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isEdit ? 'Rename Shelf' : 'Add a name to your shelf',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24, width: 2),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.tealAccent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              final name = nameCtrl.text.trim();
                              if (name.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Shelf name cannot be empty'),
                                  ),
                                );
                                return;
                              }

                              setModalState(() => isSaving = true);

                              try {
                                if (isEdit) {
                                  await LibraryService.renameShelf(
                                    editShelfId,
                                    name,
                                  );
                                } else {
                                  await LibraryService.createShelf(name);
                                }

                                if (!ctx.mounted) return;
                                if (Navigator.canPop(ctx)) {
                                  Navigator.pop(ctx);
                                }
                              } catch (e) {
                                if (!ctx.mounted) return;
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: $e'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                                setModalState(() => isSaving = false);
                              }
                            },
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.orangeAccent.shade200,
                              Colors.deepOrangeAccent.shade200,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          child: isSaving
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.black87,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Text(
                                  isEdit ? 'Update' : 'Create',
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showShelfActions({
    required String shelfId,
    required String shelfName,
    required int bookCount,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        decoration: const BoxDecoration(
          color: Color(0xFF1A2035),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              shelfName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$bookCount ${bookCount == 1 ? 'book' : 'books'}',
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.drive_file_rename_outline_rounded,
                color: Colors.white,
              ),
              title: const Text(
                'Rename shelf',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: const Text(
                'Update the shelf title',
                style: TextStyle(color: Colors.white54),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showCreateShelfModal(
                  editShelfId: shelfId,
                  currentName: shelfName,
                );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
              ),
              title: const Text(
                'Delete shelf',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: const Text(
                'Books stay in your library',
                style: TextStyle(color: Colors.white54),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteShelfDialog(
                  shelfId: shelfId,
                  shelfName: shelfName,
                  bookCount: bookCount,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteShelfDialog({
    required String shelfId,
    required String shelfName,
    required int bookCount,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Delete shelf?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Text(
          '"$shelfName" will be removed. $bookCount ${bookCount == 1 ? 'book is' : 'books are'} still safe in your main library.',
          style: const TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () async {
              await LibraryService.deleteShelf(shelfId);
              if (!mounted || !ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Deleted "$shelfName".'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            },
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        toolbarHeight: 80,
        title: const Text(
          'Library',
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: IconButton(
              icon: const Icon(Icons.add, color: Colors.white, size: 24),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddBookScreen()),
              ),
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: LibraryService.getLibraryStream(),
            builder: (context, snapshot) {
              List<QueryDocumentSnapshot> allBooks = snapshot.hasData
                  ? snapshot.data!.docs
                  : [];
              return Container(
                margin: const EdgeInsets.only(right: 20, top: 16, bottom: 16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: IconButton(
                  icon: const Icon(Icons.search, color: Colors.white, size: 24),
                  onPressed: () => _openLibrarySearch(allBooks),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: LibraryService.getLibraryStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: accentColor),
            );
          }

          final List<QueryDocumentSnapshot> docs = snapshot.hasData
              ? snapshot.data!.docs
              : [];

          final wantToRead = docs
              .where(
                (d) =>
                    (d.data() as Map<String, dynamic>)['status'] ==
                    'Want to read',
              )
              .toList();
          final reading = docs
              .where(
                (d) =>
                    (d.data() as Map<String, dynamic>)['status'] == 'Reading',
              )
              .toList();
          final finished = docs
              .where(
                (d) =>
                    (d.data() as Map<String, dynamic>)['status'] == 'Finished',
              )
              .toList();

          Map<String, List<QueryDocumentSnapshot>> authorsMap = {};
          Map<String, List<QueryDocumentSnapshot>> genresMap = {};

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            String aStr = data['authors']?.toString() ?? 'Unknown';
            for (var a in aStr.split(',').map((s) => s.trim())) {
              if (a.isNotEmpty) authorsMap.putIfAbsent(a, () => []).add(doc);
            }
            String gStr = data['categories']?.toString() ?? 'Uncategorized';
            genresMap.putIfAbsent(gStr, () => []).add(doc);
          }

          final Map<String, int> shelfCounts = {};
          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final onShelves = List<String>.from(data['onShelves'] ?? []);
            for (final shelfId in onShelves.toSet()) {
              shelfCounts[shelfId] = (shelfCounts[shelfId] ?? 0) + 1;
            }
          }

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // --- WANT TO READ SECTION ---
              SliverToBoxAdapter(
                child: _buildSectionHeader(
                  context,
                  'Want to read',
                  wantColor,
                  wantToRead,
                ),
              ),
              SliverToBoxAdapter(
                child: wantToRead.isEmpty
                    ? _buildEmptyPlaceholder('Want to read', wantColor)
                    : _buildHorizontalList(
                        context,
                        wantToRead,
                        wantColor,
                        showProgress: false,
                      ),
              ),

              // --- READING SECTION ---
              SliverToBoxAdapter(
                child: _buildSectionHeader(
                  context,
                  'Reading',
                  readColor,
                  reading,
                ),
              ),
              SliverToBoxAdapter(
                child: reading.isEmpty
                    ? _buildEmptyPlaceholder('Reading', readColor)
                    : _buildHorizontalList(
                        context,
                        reading,
                        readColor,
                        showProgress: true,
                      ),
              ),

              // --- FINISHED SECTION ---
              SliverToBoxAdapter(
                child: _buildSectionHeader(
                  context,
                  'Finished',
                  finColor,
                  finished,
                ),
              ),
              SliverToBoxAdapter(
                child: finished.isEmpty
                    ? _buildEmptyPlaceholder('Finished', finColor)
                    : _buildHorizontalList(
                        context,
                        finished,
                        finColor,
                        showProgress: false,
                      ),
              ),

              // --- MY SHELVES HEADER ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 40, 20, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Text(
                            'My Shelves',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => _showCreateShelfModal(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.amberAccent.withOpacity(0.5),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            '+ Add a new shelf',
                            style: TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // --- MY SHELVES LIST ---
              SliverToBoxAdapter(
                child: StreamBuilder<QuerySnapshot>(
                  stream: LibraryService.getShelvesStream(),
                  builder: (context, shelfSnap) {
                    if (shelfSnap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(
                            color: Colors.amberAccent,
                          ),
                        ),
                      );
                    }

                    if (!shelfSnap.hasData || shelfSnap.data!.docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: Text(
                            'Create a shelf to organize your books.',
                            style: TextStyle(color: Colors.white38),
                          ),
                        ),
                      );
                    }

                    final shelves = shelfSnap.data!.docs.toList();
                    shelves.sort(
                      (a, b) =>
                          (a['name'] ?? '').toString().toLowerCase().compareTo(
                            (b['name'] ?? '').toString().toLowerCase(),
                          ),
                    );

                    return ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: shelves.length,
                      itemBuilder: (ctx, i) {
                        final sData = shelves[i].data() as Map<String, dynamic>;
                        final sId = shelves[i].id;
                        final sName = sData['name'] ?? 'Unnamed';
                        final shelfBookCount = shelfCounts[sId] ?? 0;

                        return Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF182033),
                                const Color(0xFF111827),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            title: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: Colors.amberAccent.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.collections_bookmark_rounded,
                                    color: Colors.amberAccent,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        sName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        shelfBookCount == 0
                                            ? 'Empty shelf'
                                            : '$shelfBookCount ${shelfBookCount == 1 ? 'book' : 'books'} inside',
                                        style: const TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amberAccent.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(
                                    '$shelfBookCount',
                                    style: const TextStyle(
                                      color: Colors.amberAccent,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  onPressed: () => _showShelfActions(
                                    shelfId: sId,
                                    shelfName: sName,
                                    bookCount: shelfBookCount,
                                  ),
                                  icon: const Icon(
                                    Icons.more_horiz_rounded,
                                    color: Colors.white54,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: null,
                            minVerticalPadding: 0,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ShelfDetailScreen(
                                  shelfId: sId,
                                  shelfName: sName,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // --- GENRES & AUTHORS ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 30, 20, 40),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CategoryListScreen(
                                title: 'My Genres',
                                categoryMap: genresMap,
                              ),
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.redAccent.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.grid_view_rounded,
                                  color: Colors.redAccent,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Genres',
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CategoryListScreen(
                                title: 'My Authors',
                                categoryMap: authorsMap,
                              ),
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.blueAccent.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.people_alt_rounded,
                                  color: Colors.blueAccent,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Authors',
                                  style: TextStyle(
                                    color: Colors.blueAccent,
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
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    Color accent,
    List<QueryDocumentSnapshot> books,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
          const Spacer(),
          if (books.isNotEmpty)
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BookVerticalListScreen(
                    title: title,
                    books: books,
                    accentColor: accent,
                  ),
                ),
              ),
              child: Text(
                'View All',
                style: TextStyle(
                  color: accent,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyPlaceholder(String status, Color accentColor) {
    return Container(
      height: 160,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: cardColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withOpacity(0.15), width: 2),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_rounded,
              color: accentColor.withOpacity(0.4),
              size: 36,
            ),
            const SizedBox(height: 12),
            Text(
              'No books in $status',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalList(
    BuildContext context,
    List<QueryDocumentSnapshot> books,
    Color accent, {
    required bool showProgress,
  }) {
    return SizedBox(
      height: showProgress ? 290 : 260,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: books.length,
        itemBuilder: (context, index) {
          final data = books[index].data() as Map<String, dynamic>? ?? {};
          int pageCount = data['pageCount'] is int ? data['pageCount'] : 1;
          if (pageCount <= 0) pageCount = 1;
          double progress =
              (data['currentPage'] is int ? data['currentPage'] : 0) /
              pageCount;

          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    BookDetailScreen(bookData: _formatBookData(books[index])),
              ),
            ),
            child: Container(
              width: 135,
              margin: const EdgeInsets.only(right: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _buildCoverImage(
                        data['thumbnail']?.toString(),
                        135,
                        200,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    data['title']?.toString() ?? 'Unknown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data['authors']?.toString() ?? 'Unknown',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (showProgress) ...[
                    const Spacer(),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: const Color(0xFF1E293B),
                        color: accent,
                        minHeight: 5,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// SHELF DETAIL SCREEN
// ════════════════════════════════════════════════════════════
class ShelfDetailScreen extends StatefulWidget {
  final String shelfId;
  final String shelfName;

  const ShelfDetailScreen({
    super.key,
    required this.shelfId,
    required this.shelfName,
  });

  @override
  State<ShelfDetailScreen> createState() => _ShelfDetailScreenState();
}

class _ShelfDetailScreenState extends State<ShelfDetailScreen> {
  String _searchQuery = '';
  late String currentShelfName;
  bool _isGridView = true;
  String _sortBy = 'Title';

  @override
  void initState() {
    super.initState();
    currentShelfName = widget.shelfName;
  }

  void _showShelfOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShelfOptionsBottomSheet(
        screenContext: context,
        shelfId: widget.shelfId,
        currentName: currentShelfName,
        isGridView: _isGridView,
        sortBy: _sortBy,
        onShelfRenamed: (newName) => setState(() => currentShelfName = newName),
        onViewChanged: (isGrid) => setState(() => _isGridView = isGrid),
        onSortChanged: (sort) => setState(() => _sortBy = sort),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          currentShelfName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: LibraryService.getBooksInShelfStream(widget.shelfId),
            builder: (context, snapshot) {
              int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
              return Center(
                child: Text(
                  '$count books',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
            onPressed: _showShelfOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              onChanged: (val) =>
                  setState(() => _searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search a title or author',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white38),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.cancel_rounded,
                          color: Colors.white38,
                        ),
                        onPressed: () {
                          setState(() => _searchQuery = '');
                          FocusScope.of(context).unfocus();
                        },
                      )
                    : null,
                filled: true,
                fillColor: cardColor,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: LibraryService.getBooksInShelfStream(widget.shelfId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: accentColor),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'This shelf is empty.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }

                List<QueryDocumentSnapshot> docs = snapshot.data!.docs.where((
                  doc,
                ) {
                  final data = doc.data() as Map<String, dynamic>;
                  final title = (data['title'] ?? '').toString().toLowerCase();
                  final author = (data['authors'] ?? '')
                      .toString()
                      .toLowerCase();
                  return title.contains(_searchQuery) ||
                      author.contains(_searchQuery);
                }).toList();

                if (_sortBy == 'Title') {
                  docs.sort(
                    (a, b) => ((a.data() as Map)['title'] ?? '')
                        .toString()
                        .toLowerCase()
                        .compareTo(
                          ((b.data() as Map)['title'] ?? '')
                              .toString()
                              .toLowerCase(),
                        ),
                  );
                } else if (_sortBy == 'Added (Newest)') {
                  docs.sort((a, b) {
                    final aAdded = _getShelfAddedAt(
                      a.data() as Map<String, dynamic>,
                    );
                    final bAdded = _getShelfAddedAt(
                      b.data() as Map<String, dynamic>,
                    );
                    return bAdded.millisecondsSinceEpoch.compareTo(
                      aAdded.millisecondsSinceEpoch,
                    );
                  });
                }

                if (_isGridView) {
                  return GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    physics: const BouncingScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.55,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final bData = docs[index].data() as Map<String, dynamic>;
                      final bookId = docs[index].id;

                      return GestureDetector(
                        onTap: () async {
                          final fullDoc = await LibraryService.getBookStream(
                            bookId,
                          ).first;
                          if (!context.mounted || !fullDoc.exists) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BookDetailScreen(
                                bookData: _formatBookData(fullDoc),
                              ),
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: _buildCoverImage(
                                  bData['thumbnail'],
                                  double.infinity,
                                  double.infinity,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        bData['title'] ?? 'Unknown',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        bData['authors']?.toString() ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () =>
                                      _showRemoveDialog(context, bookId),
                                  child: const Icon(
                                    Icons.more_horiz_rounded,
                                    color: Colors.white54,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                } else {
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    physics: const BouncingScrollPhysics(),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final bData = docs[index].data() as Map<String, dynamic>;
                      final bookId = docs[index].id;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _buildCoverImage(bData['thumbnail'], 50, 75),
                        ),
                        title: Text(
                          bData['title'] ?? 'Unknown',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          bData['authors']?.toString() ?? '',
                          style: const TextStyle(color: Colors.white54),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.more_horiz_rounded,
                            color: Colors.white54,
                          ),
                          onPressed: () => _showRemoveDialog(context, bookId),
                        ),
                        onTap: () async {
                          final fullDoc = await LibraryService.getBookStream(
                            bookId,
                          ).first;
                          if (!context.mounted || !fullDoc.exists) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BookDetailScreen(
                                bookData: _formatBookData(fullDoc),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showRemoveDialog(BuildContext context, String bookId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cardColor,
        title: const Text('Unlink Book', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Remove this book from the shelf?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              LibraryService.unlinkBookFromShelf(bookId, widget.shelfId);
              Navigator.pop(context);
            },
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  Timestamp _getShelfAddedAt(Map<String, dynamic> data) {
    final shelfAddedAt = data['shelfAddedAt'];
    if (shelfAddedAt is Map && shelfAddedAt[widget.shelfId] is Timestamp) {
      return shelfAddedAt[widget.shelfId] as Timestamp;
    }

    final addedAt = data['addedAt'];
    if (addedAt is Timestamp) return addedAt;
    return Timestamp.fromMillisecondsSinceEpoch(0);
  }
}

// ════════════════════════════════════════════════════════════
// SHELF OPTIONS BOTTOM SHEET
// ════════════════════════════════════════════════════════════
class ShelfOptionsBottomSheet extends StatelessWidget {
  final BuildContext screenContext;
  final String shelfId;
  final String currentName;
  final bool isGridView;
  final String sortBy;
  final Function(String) onShelfRenamed;
  final Function(bool) onViewChanged;
  final Function(String) onSortChanged;

  const ShelfOptionsBottomSheet({
    super.key,
    required this.screenContext,
    required this.shelfId,
    required this.currentName,
    required this.isGridView,
    required this.sortBy,
    required this.onShelfRenamed,
    required this.onViewChanged,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: const BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                ListTile(
                  leading: const Icon(Icons.add_rounded, color: Colors.white),
                  title: const Text(
                    'Add book to this shelf',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Future.microtask(() {
                      if (screenContext.mounted) {
                        _showAddBooksToShelfModal(screenContext);
                      }
                    });
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit_rounded, color: Colors.white),
                  title: const Text(
                    'Rename',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Future.microtask(() {
                      if (screenContext.mounted) {
                        _showRenameDialog(screenContext);
                      }
                    });
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.remove_circle_outline,
                    color: Colors.amberAccent,
                  ),
                  title: const Text(
                    'Delete shelf',
                    style: TextStyle(
                      color: Colors.amberAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Future.microtask(() {
                      if (screenContext.mounted) {
                        _showDeleteDialog(screenContext);
                      }
                    });
                  },
                ),

                const Divider(color: Colors.white12, height: 32),

                ListTile(
                  leading: const Icon(
                    Icons.grid_view_rounded,
                    color: Colors.white54,
                  ),
                  title: const Text(
                    'Grid',
                    style: TextStyle(
                      color: Colors.white54,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: isGridView
                      ? const Icon(Icons.check_circle, color: Colors.redAccent)
                      : const Icon(
                          Icons.check_circle_outline,
                          color: Colors.white24,
                        ),
                  onTap: () {
                    onViewChanged(true);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.view_list_rounded,
                    color: Colors.white54,
                  ),
                  title: const Text(
                    'List',
                    style: TextStyle(
                      color: Colors.white54,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: !isGridView
                      ? const Icon(Icons.check_circle, color: Colors.redAccent)
                      : const Icon(
                          Icons.check_circle_outline,
                          color: Colors.white24,
                        ),
                  onTap: () {
                    onViewChanged(false);
                    Navigator.pop(context);
                  },
                ),

                const Divider(color: Colors.white12, height: 32),

                const Padding(
                  padding: EdgeInsets.only(left: 16, bottom: 6),
                  child: Text(
                    'Sort by',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                _buildOptionTile(
                  context,
                  icon: Icons.schedule_rounded,
                  label: 'Added (Newest)',
                  selected: sortBy == 'Added (Newest)',
                  onTap: () {
                    onSortChanged('Added (Newest)');
                    Navigator.pop(context);
                  },
                ),
                _buildOptionTile(
                  context,
                  icon: Icons.sort_by_alpha_rounded,
                  label: 'Title',
                  selected: sortBy == 'Title',
                  onTap: () {
                    onSortChanged('Title');
                    Navigator.pop(context);
                  },
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
        ),
      ),
    );
  }

  Widget _buildOptionTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      leading: Icon(
        icon,
        color: selected ? Colors.amberAccent : Colors.white54,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : Colors.white60,
          fontWeight: FontWeight.bold,
        ),
      ),
      trailing: Icon(
        selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
        color: selected ? Colors.amberAccent : Colors.white24,
      ),
      onTap: onTap,
    );
  }

  void _showRenameDialog(BuildContext context) {
    final ctrl = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: bgColor,
        title: const Text(
          'Rename Shelf',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: accentColor),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () async {
              final newName = ctrl.text.trim();
              if (newName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Shelf name cannot be empty.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                return;
              }

              if (newName == currentName) {
                Navigator.pop(context);
                return;
              }

              try {
                await LibraryService.renameShelf(shelfId, newName);
                onShelfRenamed(newName);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Renamed shelf to "$newName".')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            child: const Text('Save', style: TextStyle(color: accentColor)),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: bgColor,
        title: const Text(
          'Delete Shelf?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will delete the shelf. Your books will remain in your main library.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () async {
              await LibraryService.deleteShelf(shelfId);
              if (!context.mounted) return;
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Pop back to library screen
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  // --- BULK ADD BOOKS TO SHELF MODAL ---
  void _showAddBooksToShelfModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddBooksToShelfModal(shelfId: shelfId),
    );
  }
}

// ════════════════════════════════════════════════════════════
// BULK ADD BOOKS MODAL (Image 2 Replica)
// ════════════════════════════════════════════════════════════
class _AddBooksToShelfModal extends StatefulWidget {
  final String shelfId;
  const _AddBooksToShelfModal({required this.shelfId});

  @override
  State<_AddBooksToShelfModal> createState() => _AddBooksToShelfModalState();
}

class _AddBooksToShelfModalState extends State<_AddBooksToShelfModal> {
  String _searchQuery = '';
  Set<String> _selectedBookIds = {};
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Text(
                    'Organize books on shelves',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              autofocus: false,
              style: const TextStyle(color: Colors.white),
              onChanged: (val) =>
                  setState(() => _searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search book from your library',
                hintStyle: const TextStyle(color: Color(0xFF64748B)),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                filled: true,
                fillColor: cardColor,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: LibraryService.getLibraryStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.amberAccent),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'Your library is empty.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }

                // Filter books not currently on this specific shelf
                final allBooks = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final shelves = List<String>.from(data['onShelves'] ?? []);
                  return !shelves.contains(widget.shelfId);
                }).toList();

                // Search Filter
                final filteredBooks = allBooks.where((book) {
                  final data = book.data() as Map<String, dynamic>;
                  final title = (data['title'] ?? '').toString().toLowerCase();
                  final author = (data['authors'] ?? '')
                      .toString()
                      .toLowerCase();
                  return title.contains(_searchQuery) ||
                      author.contains(_searchQuery);
                }).toList();

                if (filteredBooks.isEmpty) {
                  return const Center(
                    child: Text(
                      'All matching books are already in this shelf.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }

                return ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: filteredBooks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final data =
                        filteredBooks[i].data() as Map<String, dynamic>;
                    final bookId = filteredBooks[i].id;
                    final isSelected = _selectedBookIds.contains(bookId);

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected)
                            _selectedBookIds.remove(bookId);
                          else
                            _selectedBookIds.add(bookId);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.amberAccent.withOpacity(0.1)
                              : cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? Colors.amberAccent
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: _buildCoverImage(
                                data['thumbnail']?.toString(),
                                50,
                                75,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['title'] ?? 'Unknown',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    data['authors']?.toString() ?? '',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? Colors.amberAccent
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.amberAccent
                                      : Colors.white24,
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.black87,
                                      size: 16,
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // SAVE BUTTON
          if (_selectedBookIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amberAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _isSaving
                      ? null
                      : () async {
                          setState(() => _isSaving = true);
                          await LibraryService.linkBooksToShelf(
                            widget.shelfId,
                            _selectedBookIds.toList(),
                          );
                          if (!context.mounted) return;
                          Navigator.pop(context);
                        },
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.black87,
                          ),
                        )
                      : Text(
                          'Add ${_selectedBookIds.length} book(s) to shelf',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
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
// EXISTING COMPONENTS
// ════════════════════════════════════════════════════════════
class _LibrarySearchModal extends StatefulWidget {
  final List<QueryDocumentSnapshot> allBooks;
  final Color bgColor;
  final Color cardColor;
  const _LibrarySearchModal({
    required this.allBooks,
    required this.bgColor,
    required this.cardColor,
  });

  @override
  State<_LibrarySearchModal> createState() => _LibrarySearchModalState();
}

class _LibrarySearchModalState extends State<_LibrarySearchModal> {
  String _searchQuery = '';
  String _sortBy = 'Added (Newest)';

  Color _getStatusColor(String status) {
    if (status == 'Want to read') return const Color(0xFFF43F5E);
    if (status == 'Reading') return const Color(0xFF0EA5E9);
    if (status == 'Finished') return const Color(0xFF10B981);
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    List<QueryDocumentSnapshot> filtered = widget.allBooks.where((book) {
      final data = book.data() as Map<String, dynamic>? ?? {};
      return (data['title'] ?? '').toString().toLowerCase().contains(
            _searchQuery,
          ) ||
          (data['authors'] ?? '').toString().toLowerCase().contains(
            _searchQuery,
          );
    }).toList();

    if (_sortBy == 'Title') {
      filtered.sort(
        (a, b) => ((a.data() as Map)['title'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo(
              ((b.data() as Map)['title'] ?? '').toString().toLowerCase(),
            ),
      );
    } else if (_sortBy == 'Added (Newest)') {
      filtered.sort((a, b) {
        final bAdded = (b.data() as Map)['addedAt'];
        final aAdded = (a.data() as Map)['addedAt'];
        if (bAdded is Timestamp && aAdded is Timestamp) {
          return bAdded.millisecondsSinceEpoch.compareTo(
            aAdded.millisecondsSinceEpoch,
          );
        }
        return 0;
      });
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: widget.bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: TextField(
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (val) =>
                      setState(() => _searchQuery = val.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search your library...',
                    hintStyle: const TextStyle(color: Color(0xFF64748B)),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF64748B),
                    ),
                    filled: true,
                    fillColor: widget.cardColor,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${filtered.length} books',
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w600,
                ),
              ),
              DropdownButton<String>(
                value: _sortBy,
                dropdownColor: widget.cardColor,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                icon: const Icon(Icons.sort, color: Colors.white, size: 20),
                underline: const SizedBox(),
                items: ['Added (Newest)', 'Title']
                    .map(
                      (String value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ),
                    )
                    .toList(),
                onChanged: (newValue) => setState(() => _sortBy = newValue!),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 24),
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final data =
                    filtered[index].data() as Map<String, dynamic>? ?? {};
                Color sColor = _getStatusColor(
                  data['status']?.toString() ?? '',
                );
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildCoverImage(
                      data['thumbnail']?.toString(),
                      45,
                      65,
                    ),
                  ),
                  title: Text(
                    data['title']?.toString() ?? 'Unknown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    data['authors']?.toString() ?? '',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: sColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      data['status']?.toString() ?? '',
                      style: TextStyle(
                        color: sColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookDetailScreen(
                        bookData: _formatBookData(filtered[index]),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class BookVerticalListScreen extends StatefulWidget {
  final String title;
  final List<QueryDocumentSnapshot> books;
  final Color accentColor;

  const BookVerticalListScreen({
    super.key,
    required this.title,
    required this.books,
    this.accentColor = const Color(0xFF0EA5E9),
  });

  @override
  State<BookVerticalListScreen> createState() => _BookVerticalListScreenState();
}

class _BookVerticalListScreenState extends State<BookVerticalListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredBooks = widget.books.where((book) {
      final data = book.data() as Map<String, dynamic>? ?? {};
      return (data['title'] ?? '').toString().toLowerCase().contains(
            _searchQuery,
          ) ||
          (data['authors'] ?? '').toString().toLowerCase().contains(
            _searchQuery,
          );
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 24,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              onChanged: (val) =>
                  setState(() => _searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search a title or author',
                hintStyle: const TextStyle(color: Color(0xFF64748B)),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              physics: const BouncingScrollPhysics(),
              itemCount: filteredBooks.length,
              separatorBuilder: (_, _) =>
                  const Divider(color: Colors.white12, height: 40),
              itemBuilder: (context, index) {
                final data =
                    filteredBooks[index].data() as Map<String, dynamic>? ?? {};
                final status = _normalizeBookStatus(data['status']);
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookDetailScreen(
                        bookData: _formatBookData(filteredBooks[index]),
                      ),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: _buildCoverImage(
                            data['thumbnail']?.toString(),
                            75,
                            115,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['title']?.toString() ?? 'Unknown',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              data['authors']?.toString() ?? 'Unknown',
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildStatusBadge(status),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: widget.accentColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: widget.accentColor.withOpacity(
                                        0.22,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.insert_drive_file_rounded,
                                        color: widget.accentColor,
                                        size: 13,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        '${data['pageCount']?.toString() ?? '?'} pages',
                                        style: TextStyle(
                                          color: widget.accentColor,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class CategoryListScreen extends StatefulWidget {
  final String title;
  final Map<String, List<QueryDocumentSnapshot>> categoryMap;
  const CategoryListScreen({
    super.key,
    required this.title,
    required this.categoryMap,
  });

  @override
  State<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 24,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: widget.title == 'My Genres' && user != null
            ? FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('custom_genres')
                  .snapshots()
            : null,
        builder: (context, snapshot) {
          Set<String> allKeys = Set.from(widget.categoryMap.keys);
          if (snapshot.hasData) {
            for (var doc in snapshot.data!.docs) {
              allKeys.add(doc['name']);
            }
          }

          final keys =
              allKeys
                  .where((k) => k.toLowerCase().contains(_searchQuery))
                  .toList()
                ..sort();

          return CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: TextField(
                    style: const TextStyle(color: Colors.white),
                    onChanged: (val) =>
                        setState(() => _searchQuery = val.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      hintStyle: const TextStyle(color: Color(0xFF64748B)),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFF64748B),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
              if (keys.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'No matches found.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  sliver: SliverList.separated(
                    itemCount: keys.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      String key = keys[index];
                      List<QueryDocumentSnapshot> books =
                          widget.categoryMap[key] ?? [];
                      final statusCounts = _statusCountsForBooks(books);
                      final visibleStatusCounts = statusCounts.entries
                          .where((entry) => entry.value > 0)
                          .toList();
                      return _buildCategoryTile(
                        context,
                        key: key,
                        books: books,
                        visibleStatusCounts: visibleStatusCounts,
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategoryTile(
    BuildContext context, {
    required String key,
    required List<QueryDocumentSnapshot> books,
    required List<MapEntry<String, int>> visibleStatusCounts,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: books.isEmpty
          ? null
          : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BookVerticalListScreen(
                    title: key,
                    books: books,
                    accentColor: const Color(0xFF8B5CF6),
                  ),
                ),
              );
            },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    key,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (visibleStatusCounts.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: visibleStatusCounts
                          .map(
                            (entry) => _buildStatusBadge(
                              entry.key,
                              count: entry.value,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${books.length}',
                    style: const TextStyle(
                      color: Color(0xFF0EA5E9),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white24,
                  size: 14,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

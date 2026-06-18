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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1E293B), const Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(Icons.menu_book_rounded, color: Color(0xFF334155), size: 32),
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
        child: const Icon(Icons.broken_image_rounded, color: Color(0xFF334155)),
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
        child: const Icon(Icons.broken_image_rounded, color: Color(0xFF334155)),
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
const Color shelfColor = Color(0xFFF59E0B);

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
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withOpacity(0.28)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_bookStatusIcon(status), color: color, size: 12),
        const SizedBox(width: 5),
        Text(
          count == null ? status : '$count $status',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
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
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
              decoration: const BoxDecoration(
                color: Color(0xFF111827),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    isEdit ? 'Rename Shelf' : 'Name your shelf',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isEdit
                        ? 'Give this shelf a new title'
                        : 'Shelves help you organise your library',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. Summer Reads, Sci-Fi...',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.28),
                        fontWeight: FontWeight.w400,
                        fontSize: 16,
                      ),
                      prefixIcon: Icon(
                        Icons.collections_bookmark_rounded,
                        color: shelfColor.withOpacity(0.7),
                        size: 20,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.06),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: shelfColor.withOpacity(0.7), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: shelfColor,
                        foregroundColor: Colors.black87,
                        elevation: 0,
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
                                  const SnackBar(content: Text('Shelf name cannot be empty')),
                                );
                                return;
                              }
                              setModalState(() => isSaving = true);
                              try {
                                if (isEdit) {
                                  await LibraryService.renameShelf(editShelfId, name);
                                } else {
                                  await LibraryService.createShelf(name);
                                }
                                if (!ctx.mounted) return;
                                if (Navigator.canPop(ctx)) Navigator.pop(ctx);
                              } catch (e) {
                                if (!ctx.mounted) return;
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
                                );
                                setModalState(() => isSaving = false);
                              }
                            },
                      child: isSaving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                color: Colors.black87,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              isEdit ? 'Update Shelf' : 'Create Shelf',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
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
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: const BoxDecoration(
          color: Color(0xFF111827),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: shelfColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.collections_bookmark_rounded, color: shelfColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shelfName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '$bookCount ${bookCount == 1 ? 'book' : 'books'}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.45),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _sheetTile(
              icon: Icons.drive_file_rename_outline_rounded,
              iconColor: Colors.white70,
              title: 'Rename shelf',
              subtitle: 'Update the shelf title',
              onTap: () {
                Navigator.pop(ctx);
                _showCreateShelfModal(editShelfId: shelfId, currentName: shelfName);
              },
            ),
            const SizedBox(height: 6),
            _sheetTile(
              icon: Icons.delete_outline_rounded,
              iconColor: Colors.redAccent,
              title: 'Delete shelf',
              subtitle: 'Books stay in your library',
              titleColor: Colors.redAccent,
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteShelfDialog(shelfId: shelfId, shelfName: shelfName, bookCount: bookCount);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: titleColor ?? Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.2), size: 14),
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
          style: TextStyle(color: Colors.white.withOpacity(0.65), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          TextButton(
            onPressed: () async {
              await LibraryService.deleteShelf(shelfId);
              if (!mounted || !ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Deleted "$shelfName".'), backgroundColor: Colors.redAccent),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: StreamBuilder<QuerySnapshot>(
        stream: LibraryService.getLibraryStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: accentColor, strokeWidth: 2.5),
                  const SizedBox(height: 16),
                  Text(
                    'Loading your library…',
                    style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 14),
                  ),
                ],
              ),
            );
          }

          final List<QueryDocumentSnapshot> docs =
              snapshot.hasData ? snapshot.data!.docs : [];

          final wantToRead = docs
              .where((d) => (d.data() as Map<String, dynamic>)['status'] == 'Want to read')
              .toList();
          final reading = docs
              .where((d) => (d.data() as Map<String, dynamic>)['status'] == 'Reading')
              .toList();
          final finished = docs
              .where((d) => (d.data() as Map<String, dynamic>)['status'] == 'Finished')
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
              // ── HEADER ──
              SliverToBoxAdapter(child: _buildHeader(docs, context)),

              // ── STATS BAR ──
              if (docs.isNotEmpty)
                SliverToBoxAdapter(child: _buildStatsBar(wantToRead.length, reading.length, finished.length)),

              // ── WANT TO READ ──
              SliverToBoxAdapter(
                child: _buildSectionHeader(context, 'Want to Read', wantColor, wantToRead, Icons.bookmark_rounded),
              ),
              SliverToBoxAdapter(
                child: wantToRead.isEmpty
                    ? _buildEmptyPlaceholder('Want to Read', wantColor, Icons.bookmark_add_outlined)
                    : _buildHorizontalList(context, wantToRead, wantColor, showProgress: false),
              ),

              // ── READING ──
              SliverToBoxAdapter(
                child: _buildSectionHeader(context, 'Reading', readColor, reading, Icons.auto_stories_rounded),
              ),
              SliverToBoxAdapter(
                child: reading.isEmpty
                    ? _buildEmptyPlaceholder('Reading', readColor, Icons.import_contacts_outlined)
                    : _buildHorizontalList(context, reading, readColor, showProgress: true),
              ),

              // ── FINISHED ──
              SliverToBoxAdapter(
                child: _buildSectionHeader(context, 'Finished', finColor, finished, Icons.check_circle_rounded),
              ),
              SliverToBoxAdapter(
                child: finished.isEmpty
                    ? _buildEmptyPlaceholder('Finished', finColor, Icons.done_all_rounded)
                    : _buildHorizontalList(context, finished, finColor, showProgress: false),
              ),

              // ── BROWSE BY ──
              SliverToBoxAdapter(
                child: _buildBrowseBySection(context, genresMap, authorsMap),
              ),

              // ── MY SHELVES HEADER ──
              SliverToBoxAdapter(child: _buildShelvesHeader()),

              // ── MY SHELVES LIST ──
              SliverToBoxAdapter(
                child: StreamBuilder<QuerySnapshot>(
                  stream: LibraryService.getShelvesStream(),
                  builder: (context, shelfSnap) {
                    if (shelfSnap.connectionState == ConnectionState.waiting) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: CircularProgressIndicator(color: shelfColor, strokeWidth: 2),
                        ),
                      );
                    }

                    if (!shelfSnap.hasData || shelfSnap.data!.docs.isEmpty) {
                      return _buildEmptyShelvesPlaceholder();
                    }

                    final shelves = shelfSnap.data!.docs.toList();
                    shelves.sort(
                      (a, b) => (a['name'] ?? '').toString().toLowerCase().compareTo(
                            (b['name'] ?? '').toString().toLowerCase(),
                          ),
                    );

                    return ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: shelves.length,
                      itemBuilder: (ctx, i) {
                        final sData = shelves[i].data() as Map<String, dynamic>;
                        final sId = shelves[i].id;
                        final sName = sData['name'] ?? 'Unnamed';
                        final shelfBookCount = shelfCounts[sId] ?? 0;
                        return _buildShelfCard(
                          context,
                          sId: sId,
                          sName: sName,
                          shelfBookCount: shelfBookCount,
                        );
                      },
                    );
                  },
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(List<QueryDocumentSnapshot> docs, BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Colors.white, Color(0xFFCBD5E1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: const Text(
                    'My Library',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.0,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${docs.length} book${docs.length == 1 ? '' : 's'} in your collection',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.42),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Row(
            children: [
              _headerButton(
                icon: Icons.search_rounded,
                onTap: () {
                  // Trigger library search inline
                  LibraryService.getLibraryStream().first.then((snap) {
                    _openLibrarySearch(snap.docs);
                  });
                },
              ),
              const SizedBox(width: 10),
              _headerButton(
                icon: Icons.add_rounded,
                isAccent: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddBookScreen()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isAccent = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: isAccent
              ? const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isAccent ? null : Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isAccent ? Colors.transparent : Colors.white.withOpacity(0.08),
          ),
          boxShadow: isAccent
              ? [BoxShadow(color: accentColor.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 6))]
              : null,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildStatsBar(int want, int reading, int finished) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            _statItem(want.toString(), 'Want to Read', wantColor),
            _statDivider(),
            _statItem(reading.toString(), 'Reading', readColor),
            _statDivider(),
            _statItem(finished.toString(), 'Finished', finColor),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String count, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.45),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _statDivider() {
    return Container(width: 1, height: 32, color: Colors.white.withOpacity(0.08));
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    Color accent,
    List<QueryDocumentSnapshot> books,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 16),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${books.length}',
              style: TextStyle(
                color: accent,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
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
              child: Row(
                children: [
                  Text(
                    'View all',
                    style: TextStyle(
                      color: accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_forward_ios_rounded, color: accent, size: 11),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyPlaceholder(String status, Color accent, IconData icon) {
    return Container(
      height: 140,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.12), width: 1.5),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: accent.withOpacity(0.3), size: 32),
            const SizedBox(height: 10),
            Text(
              'No books here yet',
              style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Search and add books to fill this shelf',
              style: TextStyle(
                color: Colors.white.withOpacity(0.22),
                fontSize: 12,
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
      height: showProgress ? 296 : 262,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: books.length,
        itemBuilder: (context, index) {
          final data = books[index].data() as Map<String, dynamic>? ?? {};
          int pageCount = data['pageCount'] is int ? data['pageCount'] : 1;
          if (pageCount <= 0) pageCount = 1;
          double progress = (data['currentPage'] is int ? data['currentPage'] : 0) / pageCount;

          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BookDetailScreen(bookData: _formatBookData(books[index])),
              ),
            ),
            child: Container(
              width: 130,
              margin: const EdgeInsets.only(right: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cover
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.45),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: accent.withOpacity(0.08),
                          blurRadius: 20,
                          spreadRadius: -4,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: _buildCoverImage(data['thumbnail']?.toString(), 130, 192),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Title
                  Text(
                    data['title']?.toString() ?? 'Unknown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: -0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  // Author
                  Text(
                    data['authors']?.toString() ?? 'Unknown',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.42),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (data['status'] == 'Finished') ...[
                    const Spacer(),
                    Row(
                      children: [
                        Text(
                          '${data['rating'] ?? 0}',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: 14,
                        ),
                      ],
                    ),
                  ],
                  if (showProgress) ...[
                    const Spacer(),
                    // Progress bar
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.white.withOpacity(0.08),
                              color: accent,
                              minHeight: 4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: TextStyle(
                            color: accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBrowseBySection(
    BuildContext context,
    Map<String, List<QueryDocumentSnapshot>> genresMap,
    Map<String, List<QueryDocumentSnapshot>> authorsMap,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.explore_rounded, color: Colors.white.withOpacity(0.7), size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                'Browse by',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildBrowseCard(
                  context,
                  label: 'Genres',
                  icon: Icons.grid_view_rounded,
                  count: genresMap.length,
                  color: const Color(0xFFEF4444),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CategoryListScreen(title: 'My Genres', categoryMap: genresMap),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildBrowseCard(
                  context,
                  label: 'Authors',
                  icon: Icons.people_alt_rounded,
                  count: authorsMap.length,
                  color: const Color(0xFF3B82F6),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CategoryListScreen(title: 'My Authors', categoryMap: authorsMap),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBrowseCard(
    BuildContext context, {
    required String label,
    required IconData icon,
    required int count,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.14), color.withOpacity(0.06)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.22)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '$count total',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.38),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: color.withOpacity(0.5), size: 13),
          ],
        ),
      ),
    );
  }

  Widget _buildShelvesHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: shelfColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.collections_bookmark_rounded, color: shelfColor, size: 16),
          ),
          const SizedBox(width: 10),
          const Text(
            'My Shelves',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => _showCreateShelfModal(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: shelfColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: shelfColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, color: shelfColor, size: 16),
                  const SizedBox(width: 5),
                  Text(
                    'New Shelf',
                    style: TextStyle(
                      color: shelfColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyShelvesPlaceholder() {
    return GestureDetector(
      onTap: () => _showCreateShelfModal(),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: shelfColor.withOpacity(0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: shelfColor.withOpacity(0.15), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: shelfColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.add_rounded, color: shelfColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create your first shelf',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Group books into custom shelves like "Sci-Fi Favs" or "To Review"',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.38),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShelfCard(
    BuildContext context, {
    required String sId,
    required String sName,
    required int shelfBookCount,
  }) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ShelfDetailScreen(shelfId: sId, shelfName: sName),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF1A2438), const Color(0xFF111827)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Shelf icon
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: shelfColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: shelfColor.withOpacity(0.18)),
              ),
              child: Icon(Icons.collections_bookmark_rounded, color: shelfColor, size: 20),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    shelfBookCount == 0
                        ? 'Empty shelf — tap to add books'
                        : '$shelfBookCount ${shelfBookCount == 1 ? 'book' : 'books'}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Count badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: shelfColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$shelfBookCount',
                style: TextStyle(
                  color: shelfColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 4),
            // More button
            GestureDetector(
              onTap: () => _showShelfActions(
                shelfId: sId,
                shelfName: sName,
                bookCount: shelfBookCount,
              ),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.more_horiz_rounded, color: Colors.white.withOpacity(0.4), size: 20),
              ),
            ),
          ],
        ),
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
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              currentShelfName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: -0.3,
              ),
            ),
            StreamBuilder<QuerySnapshot>(
              stream: LibraryService.getBooksInShelfStream(widget.shelfId),
              builder: (context, snapshot) {
                int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                return Text(
                  '$count ${count == 1 ? 'book' : 'books'}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.42),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: _showShelfOptions,
            child: Container(
              margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              style: const TextStyle(color: Colors.white, fontSize: 14),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search title or author…',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.3), size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.cancel_rounded, color: Colors.white.withOpacity(0.3), size: 18),
                        onPressed: () {
                          setState(() => _searchQuery = '');
                          FocusScope.of(context).unfocus();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: accentColor.withOpacity(0.6), width: 1.2),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: LibraryService.getBooksInShelfStream(widget.shelfId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: accentColor, strokeWidth: 2));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildShelfEmpty();
                }

                List<QueryDocumentSnapshot> docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final title = (data['title'] ?? '').toString().toLowerCase();
                  final author = (data['authors'] ?? '').toString().toLowerCase();
                  return title.contains(_searchQuery) || author.contains(_searchQuery);
                }).toList();

                if (_sortBy == 'Title') {
                  docs.sort((a, b) => ((a.data() as Map)['title'] ?? '')
                      .toString().toLowerCase()
                      .compareTo(((b.data() as Map)['title'] ?? '').toString().toLowerCase()));
                } else if (_sortBy == 'Added (Newest)') {
                  docs.sort((a, b) {
                    final aAdded = _getShelfAddedAt(a.data() as Map<String, dynamic>);
                    final bAdded = _getShelfAddedAt(b.data() as Map<String, dynamic>);
                    return bAdded.millisecondsSinceEpoch.compareTo(aAdded.millisecondsSinceEpoch);
                  });
                }

                if (_isGridView) {
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    physics: const BouncingScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.55,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final bData = docs[index].data() as Map<String, dynamic>;
                      final bookId = docs[index].id;
                      return GestureDetector(
                        onTap: () async {
                          final fullDoc = await LibraryService.getBookStream(bookId).first;
                          if (!context.mounted || !fullDoc.exists) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BookDetailScreen(bookData: _formatBookData(fullDoc)),
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: _buildCoverImage(bData['thumbnail'], double.infinity, double.infinity),
                                ),
                              ),
                            ),
                            const SizedBox(height: 7),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        bData['title'] ?? 'Unknown',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        bData['authors']?.toString() ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.38),
                                          fontSize: 10,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: _buildStatusBadge(_normalizeBookStatus(bData['status'])),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _showRemoveDialog(context, bookId),
                                  child: Icon(Icons.more_horiz_rounded, color: Colors.white.withOpacity(0.35), size: 16),
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
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    physics: const BouncingScrollPhysics(),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final bData = docs[index].data() as Map<String, dynamic>;
                      final bookId = docs[index].id;
                      return GestureDetector(
                        onTap: () async {
                          final fullDoc = await LibraryService.getBookStream(bookId).first;
                          if (!context.mounted || !fullDoc.exists) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BookDetailScreen(bookData: _formatBookData(fullDoc)),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: _buildCoverImage(bData['thumbnail'], 48, 72),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      bData['title'] ?? 'Unknown',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      bData['authors']?.toString() ?? '',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.42),
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    _buildStatusBadge(_normalizeBookStatus(bData['status'])),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _showRemoveDialog(context, bookId),
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Icon(Icons.more_horiz_rounded, color: Colors.white.withOpacity(0.35), size: 20),
                                ),
                              ),
                            ],
                          ),
                        ),
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

  Widget _buildShelfEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: shelfColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.collections_bookmark_outlined, color: shelfColor.withOpacity(0.5), size: 48),
          ),
          const SizedBox(height: 20),
          const Text(
            'This shelf is empty',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap ••• to add books from your library',
            style: TextStyle(color: Colors.white.withOpacity(0.38), fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _showRemoveDialog(BuildContext context, String bookId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove from shelf?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: Text(
          'This book will be removed from the shelf but stays in your library.',
          style: TextStyle(color: Colors.white.withOpacity(0.6), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          TextButton(
            onPressed: () {
              LibraryService.unlinkBookFromShelf(bookId, widget.shelfId);
              Navigator.pop(context);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
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
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.82),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: const BoxDecoration(
            color: Color(0xFF111827),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Section: Actions
                Text(
                  'ACTIONS',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                _optionCard(
                  icon: Icons.add_rounded,
                  iconColor: accentColor,
                  label: 'Add books to shelf',
                  onTap: () {
                    Navigator.pop(context);
                    Future.microtask(() {
                      if (screenContext.mounted) _showAddBooksToShelfModal(screenContext);
                    });
                  },
                ),
                const SizedBox(height: 8),
                _optionCard(
                  icon: Icons.edit_rounded,
                  iconColor: Colors.white70,
                  label: 'Rename shelf',
                  onTap: () {
                    Navigator.pop(context);
                    Future.microtask(() {
                      if (screenContext.mounted) _showRenameDialog(screenContext);
                    });
                  },
                ),
                const SizedBox(height: 8),
                _optionCard(
                  icon: Icons.delete_outline_rounded,
                  iconColor: Colors.redAccent,
                  label: 'Delete shelf',
                  labelColor: Colors.redAccent,
                  onTap: () {
                    Navigator.pop(context);
                    Future.microtask(() {
                      if (screenContext.mounted) _showDeleteDialog(screenContext);
                    });
                  },
                ),

                const SizedBox(height: 24),

                // Section: View
                Text(
                  'VIEW',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _viewToggleCard(
                        icon: Icons.grid_view_rounded,
                        label: 'Grid',
                        selected: isGridView,
                        onTap: () {
                          onViewChanged(true);
                          Navigator.pop(context);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _viewToggleCard(
                        icon: Icons.view_list_rounded,
                        label: 'List',
                        selected: !isGridView,
                        onTap: () {
                          onViewChanged(false);
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Section: Sort
                Text(
                  'SORT BY',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                _sortOptionCard(
                  icon: Icons.sort_by_alpha_rounded,
                  label: 'Title',
                  selected: sortBy == 'Title',
                  onTap: () {
                    onSortChanged('Title');
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 8),
                _sortOptionCard(
                  icon: Icons.schedule_rounded,
                  label: 'Added (Newest)',
                  selected: sortBy == 'Added (Newest)',
                  onTap: () {
                    onSortChanged('Added (Newest)');
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _optionCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    Color? labelColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 17),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: labelColor ?? Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _viewToggleCard({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? accentColor.withOpacity(0.15) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accentColor.withOpacity(0.5) : Colors.white.withOpacity(0.07),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? accentColor : Colors.white.withOpacity(0.4), size: 20),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? accentColor : Colors.white.withOpacity(0.45),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sortOptionCard({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? accentColor.withOpacity(0.1) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accentColor.withOpacity(0.45) : Colors.white.withOpacity(0.06),
            width: selected ? 1.3 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? accentColor : Colors.white.withOpacity(0.4), size: 18),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white.withOpacity(0.55),
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            if (selected)
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 12),
              ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final ctrl = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Rename Shelf', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: accentColor),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          TextButton(
            onPressed: () async {
              final newName = ctrl.text.trim();
              if (newName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Shelf name cannot be empty.'), backgroundColor: Colors.redAccent),
                );
                return;
              }
              if (newName == currentName) { Navigator.pop(context); return; }
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
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            child: const Text('Save', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete Shelf?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: Text(
          'This will delete the shelf. Your books will remain in your main library.',
          style: TextStyle(color: Colors.white.withOpacity(0.6), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          TextButton(
            onPressed: () async {
              await LibraryService.deleteShelf(shelfId);
              if (!context.mounted) return;
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

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
// BULK ADD BOOKS MODAL
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Add books to shelf',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: TextField(
              autofocus: false,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search your library…',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.3), size: 20),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: accentColor.withOpacity(0.6), width: 1.2),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: LibraryService.getLibraryStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: accentColor, strokeWidth: 2));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text('Your library is empty.', style: TextStyle(color: Colors.white.withOpacity(0.45))),
                  );
                }

                final allBooks = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final shelves = List<String>.from(data['onShelves'] ?? []);
                  return !shelves.contains(widget.shelfId);
                }).toList();

                final filteredBooks = allBooks.where((book) {
                  final data = book.data() as Map<String, dynamic>;
                  final title = (data['title'] ?? '').toString().toLowerCase();
                  final author = (data['authors'] ?? '').toString().toLowerCase();
                  return title.contains(_searchQuery) || author.contains(_searchQuery);
                }).toList();

                if (filteredBooks.isEmpty) {
                  return Center(
                    child: Text(
                      'All matching books are already in this shelf.',
                      style: TextStyle(color: Colors.white.withOpacity(0.4)),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: filteredBooks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final data = filteredBooks[i].data() as Map<String, dynamic>;
                    final bookId = filteredBooks[i].id;
                    final isSelected = _selectedBookIds.contains(bookId);

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) _selectedBookIds.remove(bookId);
                          else _selectedBookIds.add(bookId);
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? accentColor.withOpacity(0.1) : Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? accentColor.withOpacity(0.6) : Colors.white.withOpacity(0.07),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(9),
                              child: _buildCoverImage(data['thumbnail']?.toString(), 48, 72),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['title'] ?? 'Unknown',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    data['authors']?.toString() ?? '',
                                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? accentColor : Colors.transparent,
                                border: Border.all(
                                  color: isSelected ? accentColor : Colors.white.withOpacity(0.25),
                                  width: 1.5,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
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
          // Save button
          if (_selectedBookIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _isSaving
                      ? null
                      : () async {
                          setState(() => _isSaving = true);
                          await LibraryService.linkBooksToShelf(widget.shelfId, _selectedBookIds.toList());
                          if (!context.mounted) return;
                          Navigator.pop(context);
                        },
                  child: _isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          'Add ${_selectedBookIds.length} book${_selectedBookIds.length > 1 ? 's' : ''} to shelf',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
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
// LIBRARY SEARCH MODAL
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
    if (status == 'Want to read') return wantColor;
    if (status == 'Reading') return readColor;
    if (status == 'Finished') return finColor;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    List<QueryDocumentSnapshot> filtered = widget.allBooks.where((book) {
      final data = book.data() as Map<String, dynamic>? ?? {};
      return (data['title'] ?? '').toString().toLowerCase().contains(_searchQuery) ||
          (data['authors'] ?? '').toString().toLowerCase().contains(_searchQuery);
    }).toList();

    if (_sortBy == 'Title') {
      filtered.sort((a, b) => ((a.data() as Map)['title'] ?? '')
          .toString().toLowerCase()
          .compareTo(((b.data() as Map)['title'] ?? '').toString().toLowerCase()));
    } else if (_sortBy == 'Added (Newest)') {
      filtered.sort((a, b) {
        final bAdded = (b.data() as Map)['addedAt'];
        final aAdded = (a.data() as Map)['addedAt'];
        if (bAdded is Timestamp && aAdded is Timestamp) {
          return bAdded.millisecondsSinceEpoch.compareTo(aAdded.millisecondsSinceEpoch);
        }
        return 0;
      });
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Search your library…',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.28), fontSize: 15),
                      prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.3), size: 20),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.06),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: accentColor.withOpacity(0.6), width: 1.2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${filtered.length} ${filtered.length == 1 ? 'book' : 'books'}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.42),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                DropdownButton<String>(
                  value: _sortBy,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                  icon: Icon(Icons.sort_rounded, color: Colors.white.withOpacity(0.5), size: 18),
                  underline: const SizedBox(),
                  items: ['Added (Newest)', 'Title'].map((String value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  )).toList(),
                  onChanged: (newValue) => setState(() => _sortBy = newValue!),
                ),
              ],
            ),
          ),
          Divider(color: Colors.white.withOpacity(0.07), height: 1),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No books match your search',
                      style: TextStyle(color: Colors.white.withOpacity(0.38), fontSize: 14),
                    ),
                  )
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final data = filtered[index].data() as Map<String, dynamic>? ?? {};
                      final status = data['status']?.toString() ?? '';
                      final sColor = _getStatusColor(status);
                      return GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BookDetailScreen(bookData: _formatBookData(filtered[index])),
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: _buildCoverImage(data['thumbnail']?.toString(), 44, 66),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['title']?.toString() ?? 'Unknown',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      data['authors']?.toString() ?? '',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.42),
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                decoration: BoxDecoration(
                                  color: sColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: sColor.withOpacity(0.25)),
                                ),
                                child: Text(
                                  status.isEmpty ? '–' : status,
                                  style: TextStyle(
                                    color: sColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
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

// ════════════════════════════════════════════════════════════
// BOOK VERTICAL LIST SCREEN
// ════════════════════════════════════════════════════════════
class BookVerticalListScreen extends StatefulWidget {
  final String title;
  final List<QueryDocumentSnapshot> books;
  final Color accentColor;

  const BookVerticalListScreen({
    super.key,
    required this.title,
    required this.books,
    this.accentColor = readColor,
  });

  @override
  State<BookVerticalListScreen> createState() => _BookVerticalListScreenState();
}

class _BookVerticalListScreenState extends State<BookVerticalListScreen> {
  String _searchQuery = '';
  String _sortBy = 'Title';

  @override
  Widget build(BuildContext context) {
    List<String> sortOptions = ['Title'];
    if (widget.title == 'Finished') {
      sortOptions.addAll(['Rating High to Low', 'Rating Low to High']);
    } else if (widget.title == 'Reading') {
      sortOptions.addAll(['Progress High to Low', 'Progress Low to High']);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: LibraryService.getLibraryStream(),
      builder: (context, snapshot) {
        List<QueryDocumentSnapshot> freshBooks = widget.books;
        if (snapshot.hasData) {
          final allDocsMap = { for (var d in snapshot.data!.docs) d.id: d };
          freshBooks = widget.books.map((b) => allDocsMap[b.id]).whereType<QueryDocumentSnapshot>().toList();
        }

        final filteredBooks = freshBooks.where((book) {
          final data = book.data() as Map<String, dynamic>? ?? {};
          return (data['title'] ?? '').toString().toLowerCase().contains(_searchQuery) ||
              (data['authors'] ?? '').toString().toLowerCase().contains(_searchQuery);
        }).toList();

        if (_sortBy == 'Title') {
          filteredBooks.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>? ?? {};
            final dataB = b.data() as Map<String, dynamic>? ?? {};
            return (dataA['title'] ?? '').toString().toLowerCase().compareTo(
                (dataB['title'] ?? '').toString().toLowerCase());
          });
        } else if (_sortBy == 'Rating High to Low') {
          filteredBooks.sort((a, b) {
            final ratingA = (a.data() as Map<String, dynamic>?)?['rating'] ?? 0;
            final ratingB = (b.data() as Map<String, dynamic>?)?['rating'] ?? 0;
            return ratingB.compareTo(ratingA);
          });
        } else if (_sortBy == 'Rating Low to High') {
          filteredBooks.sort((a, b) {
            final ratingA = (a.data() as Map<String, dynamic>?)?['rating'] ?? 0;
            final ratingB = (b.data() as Map<String, dynamic>?)?['rating'] ?? 0;
            return ratingA.compareTo(ratingB);
          });
        } else if (_sortBy == 'Progress High to Low') {
          filteredBooks.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>? ?? {};
            final dataB = b.data() as Map<String, dynamic>? ?? {};
            int pageCountA = dataA['pageCount'] is int ? dataA['pageCount'] : 1;
            if (pageCountA <= 0) pageCountA = 1;
            int pageCountB = dataB['pageCount'] is int ? dataB['pageCount'] : 1;
            if (pageCountB <= 0) pageCountB = 1;
            
            double progressA = (dataA['currentPage'] is int ? dataA['currentPage'] : 0) / pageCountA;
            double progressB = (dataB['currentPage'] is int ? dataB['currentPage'] : 0) / pageCountB;
            return progressB.compareTo(progressA);
          });
        } else if (_sortBy == 'Progress Low to High') {
          filteredBooks.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>? ?? {};
            final dataB = b.data() as Map<String, dynamic>? ?? {};
            int pageCountA = dataA['pageCount'] is int ? dataA['pageCount'] : 1;
            if (pageCountA <= 0) pageCountA = 1;
            int pageCountB = dataB['pageCount'] is int ? dataB['pageCount'] : 1;
            if (pageCountB <= 0) pageCountB = 1;
            
            double progressA = (dataA['currentPage'] is int ? dataA['currentPage'] : 0) / pageCountA;
            double progressB = (dataB['currentPage'] is int ? dataB['currentPage'] : 0) / pageCountB;
            return progressA.compareTo(progressB);
          });
        }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 20,
                letterSpacing: -0.4,
              ),
            ),
            Text(
              '${widget.books.length} books',
              style: TextStyle(
                color: Colors.white.withOpacity(0.42),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          if (sortOptions.length > 1)
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort_rounded, color: Colors.white),
              color: const Color(0xFF1F2937),
              onSelected: (String result) {
                setState(() {
                  _sortBy = result;
                });
              },
              itemBuilder: (BuildContext context) => sortOptions
                  .map((option) => PopupMenuItem<String>(
                        value: option,
                        child: Text(
                          option,
                          style: TextStyle(
                            color: _sortBy == option ? widget.accentColor : Colors.white,
                            fontWeight: _sortBy == option ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ))
                  .toList(),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              style: const TextStyle(color: Colors.white, fontSize: 14),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search title or author…',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.28), fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.3), size: 20),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: widget.accentColor.withOpacity(0.7), width: 1.2),
                ),
              ),
            ),
          ),
          Expanded(
            child: filteredBooks.isEmpty
                ? Center(
                    child: Text(
                      'No books match your search',
                      style: TextStyle(color: Colors.white.withOpacity(0.38), fontSize: 14),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    physics: const BouncingScrollPhysics(),
                    itemCount: filteredBooks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final data = filteredBooks[index].data() as Map<String, dynamic>? ?? {};
                      final status = _normalizeBookStatus(data['status']);
                      
                      String pagesText = '${data['pageCount']?.toString() ?? '?'} pages';
                      String? extraBadgeText;
                      IconData? extraBadgeIcon;
                      
                      if (status == 'Finished') {
                        extraBadgeText = '${data['rating'] ?? 0} ★';
                      } else if (status == 'Reading') {
                        int pageC = data['pageCount'] is int ? data['pageCount'] : 1;
                        if (pageC <= 0) pageC = 1;
                        int currentP = data['currentPage'] is int ? data['currentPage'] : 0;
                        int pct = (currentP / pageC * 100).clamp(0, 100).toInt();
                        pagesText = '$currentP / $pageC pages';
                        extraBadgeText = '$pct%';
                        extraBadgeIcon = Icons.data_usage_rounded;
                      }
                      return GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BookDetailScreen(bookData: _formatBookData(filteredBooks[index])),
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.35),
                                      blurRadius: 12,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: _buildCoverImage(data['thumbnail']?.toString(), 70, 105),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['title']?.toString() ?? 'Unknown',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        letterSpacing: -0.2,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      data['authors']?.toString() ?? 'Unknown',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.48),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        _buildStatusBadge(status),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: widget.accentColor.withOpacity(0.10),
                                            borderRadius: BorderRadius.circular(999),
                                            border: Border.all(color: widget.accentColor.withOpacity(0.2)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.insert_drive_file_rounded, color: widget.accentColor, size: 11),
                                              const SizedBox(width: 4),
                                              Text(
                                                pagesText,
                                                style: TextStyle(
                                                  color: widget.accentColor,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (extraBadgeText != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: widget.accentColor.withOpacity(0.10),
                                              borderRadius: BorderRadius.circular(999),
                                              border: Border.all(color: widget.accentColor.withOpacity(0.2)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (extraBadgeIcon != null) ...[
                                                  Icon(extraBadgeIcon, color: widget.accentColor, size: 11),
                                                  const SizedBox(width: 4),
                                                ],
                                                Text(
                                                  extraBadgeText,
                                                  style: TextStyle(
                                                    color: widget.accentColor,
                                                    fontWeight: FontWeight.w800,
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
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════
// CATEGORY LIST SCREEN (Genres / Authors)
// ════════════════════════════════════════════════════════════
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
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
          ),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: -0.4,
          ),
        ),
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

          final keys = allKeys.where((k) => k.toLowerCase().contains(_searchQuery)).toList()..sort();

          return CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: TextField(
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Search…',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.28), fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.3), size: 20),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.06),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: accentColor.withOpacity(0.6), width: 1.2),
                      ),
                    ),
                  ),
                ),
              ),
              if (keys.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'No matches found.',
                      style: TextStyle(color: Colors.white.withOpacity(0.38)),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  sliver: SliverList.separated(
                    itemCount: keys.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      String key = keys[index];
                      List<QueryDocumentSnapshot> books = widget.categoryMap[key] ?? [];
                      final statusCounts = _statusCountsForBooks(books);
                      final visibleStatusCounts = statusCounts.entries.where((e) => e.value > 0).toList();
                      return _buildCategoryTile(context, key: key, books: books, visibleStatusCounts: visibleStatusCounts);
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
    return GestureDetector(
      onTap: books.isEmpty
          ? null
          : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BookVerticalListScreen(
                    title: key,
                    books: books,
                    accentColor: accentColor,
                  ),
                ),
              );
            },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
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
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                    ),
                  ),
                  if (visibleStatusCounts.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: visibleStatusCounts
                          .map((entry) => _buildStatusBadge(entry.key, count: entry.value))
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
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: readColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${books.length}',
                    style: const TextStyle(
                      color: readColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.2), size: 13),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

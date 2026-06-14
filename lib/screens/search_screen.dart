import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/book_api_service.dart';
import '../services/library_service.dart';
import 'book_detail_screen.dart';
import 'add_book_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _resultsScrollController = ScrollController();

  static const int _pageSize = 20;

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreResults = false;
  String _searchMode = 'General';
  int _currentStartIndex = 0;
  String _lastQuery = '';

  List<dynamic> _searchResults = [];
  List<String> _recentSearches = [];
  bool _hideRecent = false;

  // --- RECOMMENDATION STATES ---
  bool _isLoadingRecs = true;
  bool _recsError = false; // Tracks Google API 503 Errors
  List<dynamic> _trendingBooks = [];
  List<dynamic> _randomBooks = [];
  List<dynamic> _youMayLikeBooks = [];

  final Color bgColor = const Color(0xFF0F172A);
  final Color cardColor = const Color(0xFF1E293B);
  final Color accentColor = const Color(0xFF8B5CF6);

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _loadRecommendations();

    _resultsScrollController.addListener(_onResultsScroll);

    _searchController.addListener(() {
      if (!mounted) return;
      if (_searchController.text.isEmpty && _searchResults.isNotEmpty) {
        setState(() {
          _searchResults.clear();
          _currentStartIndex = 0;
          _lastQuery = '';
          _hasMoreResults = false;
          _isLoadingMore = false;
        });
      } else {
        // Rebuilds the suffix clear button and keeps the search panel responsive.
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _resultsScrollController.removeListener(_onResultsScroll);
    _resultsScrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // ==========================================
  // 1. REFRESH & RECOMMENDATION ENGINE
  // ==========================================
  Future<void> _refreshRecommendations() async {
    setState(() {
      _isLoadingRecs = true;
      _recsError = false; // Reset error state
    });
    await _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    try {
      _recsError = false;

      // A. Trending — first call
      final trendRes = await BookApiService.getRecommendations(
        'subject:fiction',
      );
      _trendingBooks = _cleanAndFilterResults(trendRes);

      // Wait 500ms before next call to avoid rate limiting
      await Future.delayed(const Duration(milliseconds: 500));

      // B. Random Discovery
      final randomSubjects = [
        'fantasy',
        'science fiction',
        'mystery',
        'thriller',
        'history',
        'adventure',
        'horror',
        'biography',
      ];
      randomSubjects.shuffle();
      final randRes = await BookApiService.getRecommendations(
        'subject:${randomSubjects.first}',
      );
      _randomBooks = _cleanAndFilterResults(randRes);

      // Wait 500ms before personalization calls
      await Future.delayed(const Duration(milliseconds: 500));

      // C. Personalization
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('library')
            .get();

        if (snap.docs.isNotEmpty) {
          Map<String, int> genreCounts = {};
          Map<String, int> authorCounts = {};

          for (var doc in snap.docs) {
            final data = doc.data();

            final cats = data['categories'];
            if (cats is List) {
              for (var c in cats) {
                String catName = c.toString().trim();
                if (catName.isNotEmpty && catName != 'Uncategorized') {
                  genreCounts[catName] = (genreCounts[catName] ?? 0) + 1;
                }
              }
            } else if (cats is String &&
                cats.trim().isNotEmpty &&
                cats != 'Uncategorized') {
              genreCounts[cats] = (genreCounts[cats] ?? 0) + 1;
            }

            final auths = data['authors'];
            if (auths is List) {
              for (var a in auths) {
                String authName = a.toString().trim();
                if (authName.isNotEmpty &&
                    authName != 'Unknown Author' &&
                    authName != 'Unknown') {
                  authorCounts[authName] = (authorCounts[authName] ?? 0) + 1;
                }
              }
            } else if (auths is String &&
                auths.trim().isNotEmpty &&
                auths != 'Unknown Author' &&
                auths != 'Unknown') {
              authorCounts[auths] = (authorCounts[auths] ?? 0) + 1;
            }
          }

          List<dynamic> combinedRecommendations = [];

          if (genreCounts.isNotEmpty) {
            var sortedGenres = genreCounts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            var topGenres = sortedGenres.take(3).toList()..shuffle();
            String selectedGenre = topGenres.first.key;

            // Wait before genre call
            await Future.delayed(const Duration(milliseconds: 500));
            final genreRes = await BookApiService.getRecommendations(
              'subject:"$selectedGenre"',
            );
            combinedRecommendations.addAll(_cleanAndFilterResults(genreRes));
          }

          if (authorCounts.isNotEmpty) {
            var sortedAuthors = authorCounts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            var topAuthors = sortedAuthors.take(3).toList()..shuffle();
            String selectedAuthor = topAuthors.first.key;

            // Wait before author call
            await Future.delayed(const Duration(milliseconds: 500));
            final authorRes = await BookApiService.getRecommendations(
              'inauthor:"$selectedAuthor"',
            );
            combinedRecommendations.addAll(_cleanAndFilterResults(authorRes));
          }

          var seenIds = <String>{};
          _youMayLikeBooks = combinedRecommendations.where((book) {
            final id = book['id'];
            if (seenIds.contains(id)) return false;
            seenIds.add(id);
            return true;
          }).toList();
          _youMayLikeBooks.shuffle();
        }
      }

      if (_trendingBooks.isEmpty && _randomBooks.isEmpty) {
        _recsError = true;
      }
    } catch (e) {
      debugPrint("Error loading recommendations: $e");
      _recsError = true;
    } finally {
      if (mounted) setState(() => _isLoadingRecs = false);
    }
  }

  // ==========================================
  // 2. SEARCH & HISTORY LOGIC
  // ==========================================
  Future<void> _loadRecentSearches() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (doc.exists && doc.data()!.containsKey('recentSearches')) {
      setState(
        () =>
            _recentSearches = List<String>.from(doc.data()!['recentSearches']),
      );
    }
  }

  Future<void> _addRecentSearch(String query) async {
    if (query.trim().isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() {
      _recentSearches.remove(query);
      _recentSearches.insert(0, query);
      if (_recentSearches.length > 10)
        _recentSearches = _recentSearches.sublist(0, 10);
    });
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'recentSearches': _recentSearches,
    }, SetOptions(merge: true));
  }

  Future<void> _clearRecentSearches() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _recentSearches.clear());
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'recentSearches': FieldValue.delete(),
    });
  }

  List<dynamic> _cleanAndFilterResults(List<dynamic> rawResults) {
    return rawResults.where((book) {
      final vInfo = book['volumeInfo'];
      if (vInfo == null) return false;
      final title = (vInfo['title'] ?? '').toLowerCase();
      final authors = (vInfo['authors'] as List<dynamic>? ?? [])
          .join(' ')
          .toLowerCase();
      if (authors.contains('wikipedia')) return false;
      if (title.contains('summary of')) return false;
      if (title.contains('guide to')) return false;
      return true;
    }).toList();
  }

  void _resetSearchState({bool clearText = true}) {
    if (clearText) _searchController.clear();
    _searchResults.clear();
    _currentStartIndex = 0;
    _lastQuery = '';
    _hasMoreResults = false;
    _isLoadingMore = false;
  }

  void _changeSearchMode(String mode) {
    if (_searchMode == mode) return;
    setState(() {
      _searchMode = mode;
      _resetSearchState();
    });
  }

  String get _searchHint {
    if (_searchMode == 'Title') return 'Search by title...';
    if (_searchMode == 'Author') return 'Search by author...';
    return 'Search books, authors, ISBN, keywords...';
  }

  Future<List<dynamic>> _searchBooks(
    String query, {
    required int startIndex,
    required int maxResults,
  }) {
    if (_searchMode == 'Title') {
      return BookApiService.searchByTitle(
        query,
        startIndex: startIndex,
        maxResults: maxResults,
      );
    }
    if (_searchMode == 'Author') {
      return BookApiService.searchByAuthor(
        query,
        startIndex: startIndex,
        maxResults: maxResults,
      );
    }
    return BookApiService.searchGeneral(
      query,
      startIndex: startIndex,
      maxResults: maxResults,
    );
  }

  void _onResultsScroll() {
    if (!_resultsScrollController.hasClients) return;
    if (!_hasMoreResults || _isLoadingMore || _isLoading) return;

    final position = _resultsScrollController.position;
    final isNearBottom = position.pixels >= position.maxScrollExtent - 250;

    if (isNearBottom) {
      _loadMoreResults();
    }
  }

  void _performSearch(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    _searchFocusNode.unfocus();
    _addRecentSearch(cleanQuery);

    setState(() {
      _isLoading = true;
      _isLoadingMore = false;
      _searchResults.clear();
      _currentStartIndex = 0;
      _lastQuery = cleanQuery;
      _hasMoreResults = true;
    });

    try {
      final rawResults = await _searchBooks(
        cleanQuery,
        startIndex: 0,
        maxResults: _pageSize,
      );

      final cleanedResults = _cleanAndFilterResults(rawResults);

      if (!mounted) return;
      setState(() {
        _searchResults = cleanedResults;
        _currentStartIndex = rawResults.length;
        _hasMoreResults = rawResults.length == _pageSize;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreResults() async {
    if (_lastQuery.isEmpty || !_hasMoreResults || _isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final rawResults = await _searchBooks(
        _lastQuery,
        startIndex: _currentStartIndex,
        maxResults: _pageSize,
      );

      final cleanedResults = _cleanAndFilterResults(rawResults);
      final existingIds = _searchResults.map((book) => book['id']).toSet();
      final newUniqueResults = cleanedResults.where((book) {
        final id = book['id'];
        return id != null && !existingIds.contains(id);
      }).toList();

      if (!mounted) return;
      setState(() {
        _searchResults.addAll(newUniqueResults);
        _currentStartIndex += rawResults.length;
        _hasMoreResults = rawResults.length == _pageSize;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load more books: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _navigateToBookFromIsbn(List<dynamic> results) {
    if (results.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No book found for this ISBN.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookDetailScreen(bookData: results.first),
      ),
    );
  }

  void _scanBarcode() async {
    String? res = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SimpleBarcodeScannerPage()),
    );
    if (res != null && res != '-1' && res.isNotEmpty) {
      setState(() => _isLoading = true);
      _addRecentSearch(res);
      try {
        final results = await BookApiService.searchBookByIsbn(res);
        if (mounted) _navigateToBookFromIsbn(_cleanAndFilterResults(results));
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Book not found!')));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showIsbnDialog() {
    final isbnController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.tag_rounded,
                      color: accentColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'ISBN Search',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter a 10 or 13-digit ISBN for an exact match.',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: isbnController,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 13,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: '9780000000000',
                  hintStyle: const TextStyle(
                    color: Colors.white12,
                    fontSize: 16,
                    letterSpacing: 1,
                  ),
                  counterStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: bgColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: accentColor, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white38),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () async {
                        final isbn = isbnController.text.trim();
                        if (isbn.length != 10 && isbn.length != 13) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please enter a valid 10 or 13-digit ISBN.',
                              ),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                          return;
                        }
                        Navigator.pop(context);
                        setState(() => _isLoading = true);
                        _addRecentSearch(isbn);
                        try {
                          final results = await BookApiService.searchBookByIsbn(
                            isbn,
                          );
                          if (mounted)
                            _navigateToBookFromIsbn(
                              _cleanAndFilterResults(results),
                            );
                        } catch (e) {
                          if (mounted) {
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Book not found!')),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _isLoading = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Search',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 3. UI BUILDERS
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final bool showResults =
        _searchController.text.trim().isNotEmpty && _searchResults.isNotEmpty;
    final bool showNoResults =
        _searchController.text.trim().isNotEmpty &&
        _searchResults.isEmpty &&
        !_isLoading;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          Positioned.fill(child: _buildBackgroundGlow()),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                _buildSearchPanel(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    child: _isLoading && _searchResults.isEmpty
                        ? _buildFullLoading()
                        : showResults
                        ? _buildSearchResults()
                        : showNoResults
                        ? _buildNoResults()
                        : _buildDiscoverView(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundGlow() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF111827), Color(0xFF0F172A), Color(0xFF090E1A)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -90,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withOpacity(0.18),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.18),
                    blurRadius: 90,
                    spreadRadius: 45,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 230,
            left: -110,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFD134B6).withOpacity(0.10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD134B6).withOpacity(0.12),
                    blurRadius: 90,
                    spreadRadius: 55,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Discover Books',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 29,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Find books by title, author, ISBN, or keywords.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.42),
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accentColor.withOpacity(0.26),
                  accentColor.withOpacity(0.10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: accentColor.withOpacity(0.25)),
            ),
            child: Icon(
              Icons.auto_stories_rounded,
              color: accentColor,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor.withOpacity(0.92),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                _buildActionButton(
                  icon: Icons.qr_code_scanner_rounded,
                  label: 'Scan',
                  onTap: _scanBarcode,
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  icon: Icons.tag_rounded,
                  label: 'ISBN',
                  onTap: _showIsbnDialog,
                  isAccent: true,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: _performSearch,
                    decoration: InputDecoration(
                      hintText: _searchHint,
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.28),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: _searchFocusNode.hasFocus
                            ? accentColor
                            : Colors.white.withOpacity(0.30),
                        size: 21,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              tooltip: 'Clear search',
                              icon: Icon(
                                Icons.cancel_rounded,
                                color: Colors.white.withOpacity(0.32),
                                size: 18,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                _searchFocusNode.unfocus();
                                setState(
                                  () => _resetSearchState(clearText: false),
                                );
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: bgColor.withOpacity(0.72),
                      contentPadding: const EdgeInsets.symmetric(vertical: 13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(17),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(17),
                        borderSide: BorderSide(
                          color: accentColor.withOpacity(0.85),
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildModeChip(
                    label: 'General',
                    icon: Icons.travel_explore_rounded,
                    isSelected: _searchMode == 'General',
                    onTap: () => _changeSearchMode('General'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildModeChip(
                    label: 'Title',
                    icon: Icons.title_rounded,
                    isSelected: _searchMode == 'Title',
                    onTap: () => _changeSearchMode('Title'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildModeChip(
                    label: 'Author',
                    icon: Icons.person_rounded,
                    isSelected: _searchMode == 'Author',
                    onTap: () => _changeSearchMode('Author'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isAccent = false,
  }) {
    final color = isAccent ? accentColor : Colors.white70;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: isAccent
              ? accentColor.withOpacity(0.14)
              : Colors.white.withOpacity(0.045),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isAccent
                ? accentColor.withOpacity(0.35)
                : Colors.white.withOpacity(0.07),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 19),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color.withOpacity(isAccent ? 1 : 0.70),
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    accentColor.withOpacity(0.92),
                    const Color(0xFFD134B6).withOpacity(0.75),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : bgColor.withOpacity(0.55),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected
                ? Colors.white.withOpacity(0.13)
                : Colors.white.withOpacity(0.06),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withOpacity(0.22),
                    blurRadius: 16,
                    offset: const Offset(0, 7),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : Colors.white38,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white38,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullLoading() {
    return Center(
      key: const ValueKey('loading'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withOpacity(0.08),
              border: Border.all(color: accentColor.withOpacity(0.20)),
            ),
            child: CircularProgressIndicator(
              color: accentColor,
              strokeWidth: 2.4,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Searching $_searchMode books...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      key: const ValueKey('no-results'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Icon(
                Icons.search_off_rounded,
                color: Colors.white.withOpacity(0.18),
                size: 56,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No books found',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different keyword, switch search mode, or add the book manually.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.38),
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddBookScreen()),
              ),
              icon: const Icon(Icons.library_add_rounded, size: 17),
              label: const Text('Add manually'),
              style: OutlinedButton.styleFrom(
                foregroundColor: accentColor,
                side: BorderSide(color: accentColor.withOpacity(0.45)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- DISCOVER VIEW ---
  Widget _buildDiscoverView() {
    return RefreshIndicator(
      key: const ValueKey('discover'),
      color: accentColor,
      backgroundColor: cardColor,
      onRefresh: _refreshRecommendations,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.only(bottom: 42),
        children: [
          _buildManualBanner(),
          _buildRecentSearches(),
          if (_isLoadingRecs)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 38),
              child: Center(
                child: CircularProgressIndicator(
                  color: accentColor,
                  strokeWidth: 2,
                ),
              ),
            )
          else if (_recsError)
            _buildApiErrorState()
          else ...[
            _buildCarousel(
              'Trending Now',
              _trendingBooks,
              Icons.local_fire_department_rounded,
              Colors.orangeAccent,
              subtitle: 'Popular fiction to explore today',
            ),
            if (_youMayLikeBooks.isNotEmpty)
              _buildCarousel(
                'You May Like',
                _youMayLikeBooks,
                Icons.favorite_rounded,
                accentColor,
                subtitle: 'Based on your saved genres and authors',
              ),
            _buildCarousel(
              'Discover Something New',
              _randomBooks,
              Icons.explore_rounded,
              Colors.greenAccent,
              subtitle: 'A fresh shelf for your next read',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildManualBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddBookScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [
                accentColor.withOpacity(0.22),
                const Color(0xFFD134B6).withOpacity(0.12),
                cardColor.withOpacity(0.88),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: accentColor.withOpacity(0.22)),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.10),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: const Icon(
                  Icons.library_add_rounded,
                  color: Colors.white,
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Can't find your book?",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create a manual book record and still track XP, streaks, and reports.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.46),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withOpacity(0.30),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentSearches() {
    if (_recentSearches.isEmpty) return const SizedBox(height: 4);

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionTitle(
                  Icons.history_rounded,
                  'Recent Searches',
                  Colors.white70,
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _hideRecent = !_hideRecent),
                      child: Text(
                        _hideRecent ? 'Show' : 'Hide',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.42),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    GestureDetector(
                      onTap: _clearRecentSearches,
                      child: const Text(
                        'Clear',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!_hideRecent) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                physics: const BouncingScrollPhysics(),
                itemCount: _recentSearches.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final query = _recentSearches[i];
                  return GestureDetector(
                    onTap: () {
                      _searchController.text = query;
                      _performSearch(query);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: cardColor.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.07),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.north_west_rounded,
                            color: Colors.white.withOpacity(0.27),
                            size: 13,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            query,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.66),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
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
        ],
      ),
    );
  }

  Widget _sectionTitle(
    IconData icon,
    String title,
    Color color, {
    String? subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 15),
        ),
        const SizedBox(width: 9),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildApiErrorState() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor.withOpacity(0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.redAccent.withOpacity(0.28),
          width: 1.3,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            color: Colors.redAccent.withOpacity(0.85),
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            'Servers are resting',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The Google Books API is temporarily busy. Swipe down to refresh and try again.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.48),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: _refreshRecommendations,
            icon: const Icon(
              Icons.refresh_rounded,
              color: Colors.redAccent,
              size: 18,
            ),
            label: const Text(
              'Retry Now',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarousel(
    String title,
    List<dynamic> books,
    IconData icon,
    Color iconColor, {
    String? subtitle,
  }) {
    if (books.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _sectionTitle(
                  icon,
                  title,
                  iconColor,
                  subtitle: subtitle,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: iconColor.withOpacity(0.18)),
                ),
                child: Text(
                  '${books.length}',
                  style: TextStyle(
                    color: iconColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 262,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              final info = _volumeInfo(book);
              final thumb = _thumbnailUrl(book);
              final bookTitle = info['title'] ?? 'Unknown Title';
              final authors = _authorsText(info);

              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BookDetailScreen(bookData: book),
                  ),
                ),
                child: Container(
                  width: 132,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          Container(
                            height: 178,
                            width: 132,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.32),
                                  blurRadius: 14,
                                  offset: const Offset(0, 9),
                                ),
                              ],
                            ),
                            child: _buildBookCover(thumb, 132, 178, radius: 18),
                          ),
                          Positioned(
                            top: 8,
                            left: 8,
                            child: _buildLibraryStatusBadge(
                              book,
                              compact: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        bookTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          height: 1.22,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        authors,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.38),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  // --- SEARCH RESULTS ---
  Widget _buildSearchResults() {
    return ListView.builder(
      key: const ValueKey('results'),
      controller: _resultsScrollController,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 42),
      physics: const BouncingScrollPhysics(),
      itemCount: _searchResults.length + 1 + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == 0) return _buildResultHeader();

        final resultIndex = index - 1;
        if (resultIndex >= _searchResults.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(
                color: accentColor,
                strokeWidth: 2,
              ),
            ),
          );
        }

        final book = _searchResults[resultIndex];
        final volumeInfo = _volumeInfo(book);
        final title = volumeInfo['title'] ?? 'Unknown Title';
        final authors = _authorsText(volumeInfo);
        final pageCount = _pageCountText(volumeInfo);
        final rating = _ratingText(volumeInfo);
        final category = _categoryText(volumeInfo);
        final thumbnailUrl = _thumbnailUrl(book);

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => BookDetailScreen(bookData: book)),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: cardColor.withOpacity(0.94),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.065)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    _buildBookCover(thumbnailUrl, 72, 104, radius: 14),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: _buildLibraryStatusBadge(book, compact: true),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w900,
                                height: 1.25,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildLibraryStatusBadge(book),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        authors,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.45),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (category.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: accentColor.withOpacity(0.14),
                            ),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              color: accentColor.withOpacity(0.94),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      const SizedBox(height: 11),
                      Row(
                        children: [
                          if (rating.isNotEmpty) ...[
                            const Icon(
                              Icons.star_rounded,
                              color: Colors.amber,
                              size: 14,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              rating,
                              style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            _dot(),
                          ],
                          Icon(
                            Icons.menu_book_rounded,
                            size: 13,
                            color: Colors.white.withOpacity(0.34),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            pageCount,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.38),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white.withOpacity(0.24),
                            size: 22,
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
    );
  }

  Widget _buildResultHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.manage_search_rounded,
              color: accentColor,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_searchMode Results',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_searchResults.length} shown${_hasMoreResults ? ' • scroll for more' : ''}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.36),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (_hasMoreResults && !_isLoadingMore)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.045),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Text(
                'More available',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.42),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dot() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      width: 3.5,
      height: 3.5,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.20),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildBookCover(
    String? url,
    double width,
    double height, {
    double radius = 12,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url != null && url.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: url,
              width: width,
              height: height,
              fit: BoxFit.cover,
              placeholder: (_, __) => _coverPlaceholder(width, height, radius),
              errorWidget: (_, __, ___) =>
                  _coverPlaceholder(width, height, radius),
            )
          : _coverPlaceholder(width, height, radius),
    );
  }

  Widget _coverPlaceholder(double width, double height, double radius) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.78),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Icon(
        Icons.menu_book_rounded,
        color: Colors.white.withOpacity(0.16),
        size: width < 80 ? 25 : 34,
      ),
    );
  }

  Widget _buildLibraryStatusBadge(dynamic book, {bool compact = false}) {
    final id = book is Map ? book['id']?.toString() : null;
    if (id == null || id.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: LibraryService.getBookStream(id),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final rawStatus = data?['status']?.toString() ?? 'In Library';
        final color = _statusColor(rawStatus);
        final icon = _statusIcon(rawStatus);
        final label = compact ? _compactStatus(rawStatus) : rawStatus;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 6 : 8,
            vertical: compact ? 4 : 5,
          ),
          decoration: BoxDecoration(
            color: color.withOpacity(0.90),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.28),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: compact ? 10 : 12),
              if (!compact || rawStatus != 'In Library') ...[
                SizedBox(width: compact ? 3 : 5),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 8.5 : 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Color _statusColor(String status) {
    if (status == 'Finished') return const Color(0xFF10B981);
    if (status == 'Reading') return const Color(0xFF0EA5E9);
    if (status == 'Want to read') return const Color(0xFFF43F5E);
    return accentColor;
  }

  IconData _statusIcon(String status) {
    if (status == 'Finished') return Icons.check_circle_rounded;
    if (status == 'Reading') return Icons.auto_stories_rounded;
    if (status == 'Want to read') return Icons.bookmark_rounded;
    return Icons.library_books_rounded;
  }

  String _compactStatus(String status) {
    if (status == 'Want to read') return 'Saved';
    if (status == 'Reading') return 'Reading';
    if (status == 'Finished') return 'Done';
    return 'Saved';
  }

  Map<String, dynamic> _volumeInfo(dynamic book) {
    if (book is Map && book['volumeInfo'] is Map) {
      return Map<String, dynamic>.from(book['volumeInfo'] as Map);
    }
    return <String, dynamic>{};
  }

  String? _thumbnailUrl(dynamic book) {
    final info = _volumeInfo(book);
    final imageLinks = info['imageLinks'];
    if (imageLinks is Map && imageLinks['thumbnail'] != null) {
      return imageLinks['thumbnail'].toString().replaceFirst('http:', 'https:');
    }
    return null;
  }

  String _authorsText(Map<String, dynamic> info) {
    final authors = info['authors'];
    if (authors is List && authors.isNotEmpty) {
      return authors.map((a) => a.toString()).join(', ');
    }
    if (authors is String && authors.trim().isNotEmpty) return authors;
    return 'Unknown Author';
  }

  String _pageCountText(Map<String, dynamic> info) {
    final count = info['pageCount'];
    if (count is int && count > 0) return '$count pages';
    if (count is num && count > 0) return '${count.toInt()} pages';
    return 'Pages unknown';
  }

  String _ratingText(Map<String, dynamic> info) {
    final rating = info['averageRating'];
    if (rating is num && rating > 0) return rating.toStringAsFixed(1);
    return '';
  }

  String _categoryText(Map<String, dynamic> info) {
    final categories = info['categories'];
    if (categories is List && categories.isNotEmpty) {
      return categories.first.toString();
    }
    if (categories is String && categories.trim().isNotEmpty) return categories;
    return '';
  }
}

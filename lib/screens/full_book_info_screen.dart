import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/library_service.dart';
import '../services/level_up_service.dart';

class FullBookInfoScreen extends StatefulWidget {
  final Map<String, dynamic> bookData;

  const FullBookInfoScreen({super.key, required this.bookData});

  @override
  State<FullBookInfoScreen> createState() => _FullBookInfoScreenState();
}

class _FullBookInfoScreenState extends State<FullBookInfoScreen> {
  final Color bgColor = const Color(0xFF111118);
  final Color cardColor = const Color(0xFF1A1A26);
  final Color accentColor = const Color(0xFFE91E63);

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isInLibrary = false;
  bool _isEditing = false;

  DocumentSnapshot? _firestoreDoc;
  File? _newCoverImage;
  int _currentRating = 0;

  String _editingformat = 'Physical';

  final _titleCtrl = TextEditingController();
  final _authorCtrl = TextEditingController();
  final _genresCtrl = TextEditingController();
  final _publisherCtrl = TextEditingController();
  final _publishedDateCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _pagesCtrl = TextEditingController();
  final _isbn13Ctrl = TextEditingController();
  final _isbn10Ctrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _bookUrlCtrl = TextEditingController();
  final _startedReadingCtrl = TextEditingController();
  final _finishedReadingCtrl = TextEditingController();
  final _progressCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchBookData();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    _genresCtrl.dispose();
    _publisherCtrl.dispose();
    _publishedDateCtrl.dispose();
    _descriptionCtrl.dispose();
    _pagesCtrl.dispose();
    _isbn13Ctrl.dispose();
    _isbn10Ctrl.dispose();
    _locationCtrl.dispose();
    _bookUrlCtrl.dispose();
    _startedReadingCtrl.dispose();
    _finishedReadingCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchBookData() async {
    final bookId = widget.bookData['id'] ?? '';
    if (bookId.isEmpty) {
      _populateFromFallback(widget.bookData);
      setState(() => _isLoading = false);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _populateFromFallback(widget.bookData);
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('library')
          .doc(bookId)
          .get();

      if (!mounted) return;
      if (doc.exists) {
        _isInLibrary = true;
        _firestoreDoc = doc;
        _populateFromFirestore(doc.data() as Map<String, dynamic>);
      } else {
        _populateFromFallback(widget.bookData);
      }
    } catch (e) {
      if (!mounted) return;
      _populateFromFallback(widget.bookData);
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _populateFromFirestore(Map<String, dynamic> data) {
    _titleCtrl.text = data['title'] ?? '';
    _authorCtrl.text = data['authors'] is List
        ? (data['authors'] as List).join(', ')
        : (data['authors'] ?? '');
    _genresCtrl.text = data['categories'] is List
        ? (data['categories'] as List).join(', ')
        : (data['categories'] ?? '');
    _editingformat = data['bookFormat'] ?? data['format'] ?? 'Physical';
    _publisherCtrl.text = data['publisher'] ?? '';
    _publishedDateCtrl.text = data['publishedDate'] ?? '';
    _descriptionCtrl.text = data['description'] ?? '';
    _pagesCtrl.text = data['pageCount']?.toString() ?? '';
    _locationCtrl.text = data['location'] ?? '';
    _bookUrlCtrl.text = data['bookUrl'] ?? '';
    _startedReadingCtrl.text = data['startedReading'] ?? '';
    _finishedReadingCtrl.text = data['finishedReading'] ?? '';
    _progressCtrl.text = data['currentPage']?.toString() ?? '0';
    _currentRating = data['rating'] ?? 0;

    if (data['industryIdentifiers'] != null) {
      for (var id in data['industryIdentifiers']) {
        if (id['type'] == 'ISBN_13') _isbn13Ctrl.text = id['identifier'] ?? '';
        if (id['type'] == 'ISBN_10') _isbn10Ctrl.text = id['identifier'] ?? '';
      }
    }
  }

  void _populateFromFallback(Map<String, dynamic> data) {
    Map<String, dynamic> info = data.containsKey('volumeInfo')
        ? data['volumeInfo']
        : data;
    _titleCtrl.text = info['title'] ?? '';
    _authorCtrl.text = info['authors'] is List
        ? (info['authors'] as List).join(', ')
        : (info['authors'] ?? '');
    _genresCtrl.text = info['categories'] is List
        ? (info['categories'] as List).join(', ')
        : (info['categories'] ?? '');
    _editingformat = 'Physical';
    _publisherCtrl.text = info['publisher'] ?? '';
    _publishedDateCtrl.text = info['publishedDate'] ?? '';
    _descriptionCtrl.text = info['description'] ?? '';
    _pagesCtrl.text = info['pageCount']?.toString() ?? '';
    _bookUrlCtrl.text =
        data['bookUrl'] ??
        info['bookUrl'] ??
        info['infoLink'] ??
        info['canonicalVolumeLink'] ??
        '';

    if (info['industryIdentifiers'] != null) {
      for (var id in info['industryIdentifiers']) {
        if (id['type'] == 'ISBN_13') _isbn13Ctrl.text = id['identifier'] ?? '';
        if (id['type'] == 'ISBN_10') _isbn10Ctrl.text = id['identifier'] ?? '';
      }
    }
  }

  bool _isValidHttpUrl(String value) {
    final text = value.trim();
    if (text.contains(RegExp(r'\s'))) return false;
    final uri = Uri.tryParse(text);
    return uri != null &&
        uri.isAbsolute &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  Future<void> _openBookUrl() async {
    final text = _bookUrlCtrl.text.trim();
    if (text.isEmpty || !_isValidHttpUrl(text)) {
      _showLinkError();
      return;
    }

    final uri = Uri.parse(text);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) _showLinkError();
  }

  void _showLinkError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open this link.'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  Future<void> _copyBookUrl() async {
    final text = _bookUrlCtrl.text.trim();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Book URL copied.')));
  }

  Future<void> _saveEdits() async {
    if (_titleCtrl.text.trim().isEmpty || _pagesCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Title and Page Count are required.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final bookUrl = _bookUrlCtrl.text.trim();
    if (bookUrl.isNotEmpty && !_isValidHttpUrl(bookUrl)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a valid URL starting with http:// or https://',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      Map<String, dynamic> updates = {
        'title': _titleCtrl.text.trim(),
        'authors': _authorCtrl.text.trim().isEmpty
            ? null
            : _authorCtrl.text.trim(),
        'categories': _genresCtrl.text.trim().isEmpty
            ? null
            : _genresCtrl.text.trim(),
        'bookFormat': _editingformat,
        'publisher': _publisherCtrl.text.trim().isEmpty
            ? null
            : _publisherCtrl.text.trim(),
        'publishedDate': _publishedDateCtrl.text.trim().isEmpty
            ? null
            : _publishedDateCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim().isEmpty
            ? null
            : _descriptionCtrl.text.trim(),
        'pageCount': int.tryParse(_pagesCtrl.text.trim()) ?? 0,
        'location': _locationCtrl.text.trim().isEmpty
            ? null
            : _locationCtrl.text.trim(),
        'bookUrl': bookUrl.isEmpty ? null : bookUrl,
        'startedReading': _startedReadingCtrl.text.trim().isEmpty
            ? null
            : _startedReadingCtrl.text.trim(),
        'finishedReading': _finishedReadingCtrl.text.trim().isEmpty
            ? null
            : _finishedReadingCtrl.text.trim(),
        'currentPage': int.tryParse(_progressCtrl.text.trim()) ?? 0,
        'rating': _currentRating,
      };

      List<Map<String, String>> identifiers = [];
      if (_isbn13Ctrl.text.isNotEmpty) {
        identifiers.add({
          'type': 'ISBN_13',
          'identifier': _isbn13Ctrl.text.trim(),
        });
      }
      if (_isbn10Ctrl.text.isNotEmpty) {
        identifiers.add({
          'type': 'ISBN_10',
          'identifier': _isbn10Ctrl.text.trim(),
        });
      }
      updates['industryIdentifiers'] = identifiers;

      if (_newCoverImage != null) {
        updates['thumbnail'] = _newCoverImage!.path;
      }

      // --- CRITICAL FIX: NOW CALLS THE SMART XP TRANSACTION ---
      final result = await LibraryService.updateBookDetailsWithXp(
        bookId: widget.bookData['id'],
        updates: updates,
      );

      // Wait briefly for Firestore's local cache to synchronize the transaction
      // before we fetch the data again, preventing old data from overwriting edits.
      await Future.delayed(const Duration(milliseconds: 400));

      await _fetchBookData();

      setState(() {
        _isEditing = false;
        _newCoverImage = null;
      });

      if (result['leveledUp'] == true) {
        LevelUpService.showLevelUp(
          result['newLevel'] as int,
          result['newTitle'] as String,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Book details & XP updated!'),
            backgroundColor: Colors.greenAccent,
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
      setState(() => _isSaving = false);
    }
  }

  Future<void> _changeCoverImage() async {
    if (!_isEditing) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 2, ratioY: 3),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Cover',
            toolbarColor: bgColor,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: true,
          ),
          IOSUiSettings(title: 'Crop Cover', aspectRatioLockEnabled: true),
        ],
      );

      if (croppedFile != null) {
        setState(() {
          _newCoverImage = File(croppedFile.path);
        });
      }
    }
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: accentColor,
            onPrimary: Colors.white,
            surface: cardColor,
            onSurface: Colors.white,
          ),
          dialogTheme: DialogThemeData(backgroundColor: cardColor),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        controller.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  void _showFormatPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Change format',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _buildFormatTile('Physical', Icons.menu_book_rounded),
              const SizedBox(height: 12),
              _buildFormatTile('E-Book', Icons.phone_android_rounded),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFormatTile(String title, IconData icon) {
    bool isSelected = _editingformat == title;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: isSelected ? accentColor.withOpacity(0.1) : Colors.transparent,
      leading: Icon(icon, color: isSelected ? accentColor : Colors.grey),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.grey,
          fontWeight: FontWeight.bold,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: accentColor)
          : null,
      onTap: () {
        setState(() => _editingformat = title);
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(child: CircularProgressIndicator(color: accentColor)),
      );
    }

    String? originalThumbnailUrl;
    if (_firestoreDoc != null) {
      originalThumbnailUrl = _firestoreDoc!['thumbnail'];
    } else {
      Map<String, dynamic> info = widget.bookData.containsKey('volumeInfo')
          ? widget.bookData['volumeInfo']
          : widget.bookData;
      originalThumbnailUrl =
          info['imageLinks']?['thumbnail']?.replaceFirst('http:', 'https:') ??
          info['thumbnail'];
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          _isEditing ? 'Edit Book Info' : 'Full Book Info',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_isInLibrary)
            _isSaving
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : IconButton(
                    icon: Icon(
                      _isEditing ? Icons.check : Icons.edit_rounded,
                      color: _isEditing ? Colors.greenAccent : Colors.white,
                    ),
                    onPressed: () {
                      if (_isEditing) {
                        _saveEdits();
                      } else {
                        setState(() => _isEditing = true);
                      }
                    },
                  ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          children: [
            GestureDetector(
              onTap: _changeCoverImage,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 140,
                    height: 210,
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isEditing ? accentColor : Colors.white24,
                        width: _isEditing ? 2 : 1,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black38,
                          blurRadius: 15,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: _newCoverImage != null
                          ? Image.file(_newCoverImage!, fit: BoxFit.cover)
                          : _buildSmartImage(originalThumbnailUrl),
                    ),
                  ),
                  if (_isEditing)
                    Container(
                      width: 140,
                      height: 210,
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _isEditing ? _buildEditForm() : _buildViewDetails(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartImage(String? url) {
    if (url == null || url.isEmpty || url == 'null') {
      return const Icon(Icons.book_rounded, color: Colors.grey, size: 50);
    }
    if (url.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        errorWidget: (c, u, e) =>
            const Icon(Icons.broken_image_rounded, color: Colors.grey),
      );
    } else {
      return Image.file(
        File(url),
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) =>
            const Icon(Icons.broken_image_rounded, color: Colors.grey),
      );
    }
  }

  Widget _buildViewDetails() {
    String isbns = '';
    if (_isbn13Ctrl.text.isNotEmpty) isbns += 'ISBN 13: ${_isbn13Ctrl.text}\n';
    if (_isbn10Ctrl.text.isNotEmpty) isbns += 'ISBN 10: ${_isbn10Ctrl.text}';

    return Column(
      key: const ValueKey('viewMode'),
      children: [
        _buildDetailSection(
          title: 'Book Details',
          icon: Icons.auto_stories_rounded,
          color: const Color(0xFF8B5CF6),
          children: [
            _buildInfoRow('Title', _titleCtrl.text),
            _buildInfoRow('Author', _authorCtrl.text),
            _buildInfoRow('Genres', _genresCtrl.text, highlight: true),
            _buildInfoRow('Format', _editingformat),
            _buildInfoRow('Pages', _pagesCtrl.text),
          ],
        ),
        _buildDetailSection(
          title: 'Reading Progress',
          icon: Icons.trending_up_rounded,
          color: const Color(0xFF10B981),
          children: [
            _buildRatingRow(),
            _buildInfoRow(
              'Started Reading',
              _startedReadingCtrl.text.isEmpty
                  ? 'N/A'
                  : _startedReadingCtrl.text,
            ),
            _buildInfoRow(
              'Finished Reading',
              _finishedReadingCtrl.text.isEmpty
                  ? 'N/A'
                  : _finishedReadingCtrl.text,
            ),
            _buildInfoRow('Current Progress', '${_progressCtrl.text} Pages'),
          ],
        ),
        _buildDetailSection(
          title: 'Publishing Details',
          icon: Icons.business_rounded,
          color: const Color(0xFF06B6D4),
          children: [
            _buildInfoRow('Publisher', _publisherCtrl.text),
            _buildInfoRow('Published Date', _publishedDateCtrl.text),
            _buildInfoRow(
              'Identifiers',
              isbns.trim().isEmpty ? 'N/A' : isbns.trim(),
            ),
          ],
        ),
        _buildDetailSection(
          title: 'Storage & Links',
          icon: Icons.link_rounded,
          color: const Color(0xFFD134B6),
          children: [
            _buildInfoRow(
              'Physical Location',
              _locationCtrl.text.isEmpty ? 'N/A' : _locationCtrl.text,
            ),
            _buildBookUrlCard(),
          ],
        ),
        _buildDetailSection(
          title: 'Description',
          icon: Icons.description_rounded,
          color: accentColor,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(
                _descriptionCtrl.text.isEmpty
                    ? 'No synopsis available.'
                    : _descriptionCtrl.text,
                style: const TextStyle(
                  color: Colors.white,
                  height: 1.6,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 50),
      ],
    );
  }

  Widget _buildDetailSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.07),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withOpacity(0.18)),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildRatingRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            flex: 2,
            child: Text(
              'Rating',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),
          Expanded(
            flex: 4,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: List.generate(
                5,
                (index) => Icon(
                  index < _currentRating
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: index < _currentRating
                      ? Colors.amber
                      : Colors.grey[700],
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookUrlCard() {
    final url = _bookUrlCtrl.text.trim();
    if (url.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor.withOpacity(0.65),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: Row(
            children: [
              Icon(Icons.link_off_rounded, color: Colors.white38, size: 20),
              const SizedBox(width: 12),
              Text(
                'No URL added',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final displayUrl = url
        .replaceFirst(RegExp(r'^https?://'), '')
        .replaceFirst(RegExp(r'/$'), '');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Container(
        padding: const EdgeInsets.all(1.2),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4), Color(0xFFD134B6)],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF06B6D4).withOpacity(0.12),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(21),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFF06B6D4).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.link_rounded,
                  color: Color(0xFF67E8F9),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Book URL',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Copy URL',
                onPressed: _copyBookUrl,
                icon: const Icon(
                  Icons.copy_rounded,
                  color: Colors.white54,
                  size: 19,
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: _openBookUrl,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Open',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 4,
            child: highlight
                ? Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: accentColor.withOpacity(0.5)),
                      ),
                      child: Text(
                        value.isEmpty ? 'N/A' : value,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  )
                : Text(
                    value.isEmpty ? 'N/A' : value,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.right,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm() {
    return Column(
      key: const ValueKey('editMode'),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 18),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: accentColor.withOpacity(0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_rounded, color: accentColor, size: 15),
                const SizedBox(width: 7),
                Text(
                  'Editing details',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'My Rating',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < _currentRating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: Colors.amber,
                    size: 38,
                  ),
                  onPressed: () => setState(() => _currentRating = index + 1),
                );
              }),
            ),
          ],
        ),
        const SizedBox(height: 28),

        _buildTextField(
          'Title*',
          _titleCtrl,
          isRequired: true,
          icon: Icons.title_rounded,
        ),
        _buildTextField(
          'Author',
          _authorCtrl,
          helpText: 'Comma separated for multiple',
          icon: Icons.person_rounded,
        ),
        _buildTextField(
          'Genres',
          _genresCtrl,
          highlight: true,
          helpText: 'Fiction, Drama, etc.',
          icon: Icons.category_rounded,
        ),

        _buildFormatSelector(),
        _buildTextField(
          'Page count*',
          _pagesCtrl,
          type: TextInputType.number,
          isRequired: true,
          icon: Icons.pages_rounded,
        ),
        _buildTextField(
          'Current Progress (Pages)',
          _progressCtrl,
          type: TextInputType.number,
          icon: Icons.auto_stories_rounded,
        ),
        _buildTextField(
          'Physical Location',
          _locationCtrl,
          helpText: 'e.g. Shelf 3',
          icon: Icons.location_on_rounded,
        ),
        _buildTextField(
          'Book URL',
          _bookUrlCtrl,
          type: TextInputType.url,
          helpText: 'Online reference, eBook, PDF, or purchase link',
          icon: Icons.link_rounded,
        ),

        _buildDateTextField('Started Reading', _startedReadingCtrl),
        _buildDateTextField('Finished Reading', _finishedReadingCtrl),

        _buildTextField(
          'Publisher',
          _publisherCtrl,
          icon: Icons.business_rounded,
        ),
        _buildDateTextField('Published Date', _publishedDateCtrl),
        _buildTextField(
          'ISBN 13',
          _isbn13Ctrl,
          type: TextInputType.number,
          icon: Icons.qr_code_rounded,
        ),
        _buildTextField(
          'ISBN 10',
          _isbn10Ctrl,
          type: TextInputType.number,
          icon: Icons.qr_code_2_rounded,
        ),

        _buildTextField(
          'Synopsis',
          _descriptionCtrl,
          maxLines: 6,
          icon: Icons.description_rounded,
        ),

        const SizedBox(height: 50),
      ],
    );
  }

  Widget _buildFormatSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            const Icon(Icons.book_rounded, color: Colors.grey),
            const SizedBox(width: 16),
            const Text(
              'Format:',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _showFormatPicker,
              icon: Icon(
                _editingformat == 'Physical'
                    ? Icons.menu_book_rounded
                    : Icons.phone_android_rounded,
                color: accentColor,
                size: 16,
              ),
              label: Text(
                _editingformat,
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType type = TextInputType.text,
    int maxLines = 1,
    bool isRequired = false,
    bool highlight = false,
    String? helpText,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: controller,
            keyboardType: type,
            maxLines: maxLines,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: const TextStyle(color: Colors.grey),
              floatingLabelStyle: TextStyle(
                color: isRequired ? accentColor : Colors.white,
                fontWeight: FontWeight.bold,
              ),
              prefixIcon: icon != null
                  ? Icon(
                      icon,
                      color: highlight ? accentColor : Colors.white24,
                      size: 20,
                    )
                  : null,
              filled: true,
              fillColor: cardColor,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isRequired ? accentColor : Colors.white,
                  width: 2,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.white12, width: 1),
              ),
            ),
          ),
          if (helpText != null) ...[
            const SizedBox(height: 6),
            Text(
              '  $helpText',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey),
          filled: true,
          prefixIcon: const Icon(
            Icons.calendar_month_rounded,
            color: Colors.white24,
            size: 20,
          ),
          fillColor: cardColor,
          suffixIcon: IconButton(
            icon: const Icon(Icons.calendar_month_rounded, color: Colors.grey),
            onPressed: () => _selectDate(controller),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.white12, width: 1),
          ),
        ),
      ),
    );
  }
}

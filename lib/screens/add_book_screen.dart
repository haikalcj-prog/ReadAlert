import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../services/library_service.dart';
import '../services/audio_service.dart';
import '../widgets/library_action_toast.dart';
import '../widgets/xp_toast.dart';

class AddBookScreen extends StatefulWidget {
  const AddBookScreen({super.key});

  @override
  State<AddBookScreen> createState() => _AddBookScreenState();
}

class _AddBookScreenState extends State<AddBookScreen> {
  // --- AURORA COLOR PALETTE ---
  final Color bgColor = const Color(0xFF0F172A); // Space Blue
  final Color cardColor = const Color(0xFF1E293B); // Slate
  final Color wantColor = const Color(0xFFF43F5E); // Rose
  final Color readColor = const Color(0xFF0EA5E9); // Cyan
  final Color finColor = const Color(0xFF10B981); // Emerald

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  File? _selectedImage;

  String _selectedStatus = 'Want to read';
  String _selectedFormat = 'Physical';

  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _genresController = TextEditingController();
  final _publisherController = TextEditingController();
  final _publishedDateController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _pagesController = TextEditingController();
  final _currentProgressController = TextEditingController(text: '0');
  final _isbn13Controller = TextEditingController();
  final _isbn10Controller = TextEditingController();
  final _locationController = TextEditingController();
  final _bookUrlController = TextEditingController();
  final _startedReadingController = TextEditingController();
  final _finishedReadingController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _genresController.dispose();
    _publisherController.dispose();
    _publishedDateController.dispose();
    _descriptionController.dispose();
    _pagesController.dispose();
    _currentProgressController.dispose();
    _isbn13Controller.dispose();
    _isbn10Controller.dispose();
    _locationController.dispose();
    _bookUrlController.dispose();
    _startedReadingController.dispose();
    _finishedReadingController.dispose();
    super.dispose();
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

  Color _getActiveColor() {
    if (_selectedStatus == 'Want to read') return wantColor;
    if (_selectedStatus == 'Reading') return readColor;
    return finColor;
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
            primary: _getActiveColor(),
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
      setState(
        () => controller.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}",
      );
    }
  }

  Future<void> _pickAndCropImage() async {
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
        setState(() => _selectedImage = File(croppedFile.path));
      }
    }
  }

  // --- FLOATING MODAL (FIXES BOTTOM CUT-OFF) ---
  void _showFormatPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Book Format',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 20),
                _buildFormatTile('Physical', Icons.menu_book),
                const SizedBox(height: 12),
                _buildFormatTile('E-Book', Icons.phone_android),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFormatTile(String title, IconData icon) {
    bool isSelected = _selectedFormat == title;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      tileColor: isSelected ? _getActiveColor().withOpacity(0.15) : bgColor,
      leading: Icon(icon, color: isSelected ? _getActiveColor() : Colors.grey),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.grey,
          fontWeight: FontWeight.bold,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: _getActiveColor())
          : null,
      onTap: () {
        setState(() => _selectedFormat = title);
        Navigator.pop(context);
      },
    );
  }

  void _showXpToast(Map<String, dynamic> result, {double topOffset = 16}) {
    AudioService.playXpGain();
    final accentColor = _getActiveColor();
    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder: (ctx) => Positioned(
        top: MediaQuery.of(ctx).padding.top + topOffset,
        left: 20,
        right: 20,
        child: XpToastWidget(result: result, accentColor: accentColor),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3), () {
      if (entry.mounted) entry.remove();
    });
  }

  void _showBookAddedToast(String title, String status) {
    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder: (ctx) => Positioned(
        top: MediaQuery.of(ctx).padding.top + 16,
        left: 20,
        right: 20,
        child: LibraryActionToast(title: title, status: status),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 2600), () {
      if (entry.mounted) entry.remove();
    });
  }

  Future<void> _saveBook() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final bookUrl = _bookUrlController.text.trim();
      final int pages = int.parse(_pagesController.text.trim());
      int progress = _selectedStatus == 'Reading'
          ? (int.tryParse(_currentProgressController.text.trim()) ?? 0)
          : (_selectedStatus == 'Finished' ? pages : 0);
      if (progress > pages) progress = pages;

      final result = await LibraryService.addManualBook(
        title: _titleController.text.trim(),
        authors: _authorController.text.trim(),
        pageCount: pages,
        currentPage: progress,
        status: _selectedStatus,
        bookFormat: _selectedFormat,
        genres: _genresController.text.trim().isEmpty
            ? null
            : _genresController.text.trim(),
        publisher: _publisherController.text.trim().isEmpty
            ? null
            : _publisherController.text.trim(),
        publishedDate: _publishedDateController.text.trim().isEmpty
            ? null
            : _publishedDateController.text.trim(),
        isbn13: _isbn13Controller.text.trim().isEmpty
            ? null
            : _isbn13Controller.text.trim(),
        isbn10: _isbn10Controller.text.trim().isEmpty
            ? null
            : _isbn10Controller.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        bookUrl: bookUrl.isEmpty ? null : bookUrl,
        startedReading: _startedReadingController.text.trim().isEmpty
            ? null
            : _startedReadingController.text.trim(),
        finishedReading: _finishedReadingController.text.trim().isEmpty
            ? null
            : _finishedReadingController.text.trim(),
        coverImage: _selectedImage,
      );

      if (mounted) {
        final int xpGained = result['xpGained'] is int
            ? result['xpGained'] as int
            : int.tryParse(result['xpGained']?.toString() ?? '') ?? 0;
        AudioService.playSuccess();
        _showBookAddedToast(_titleController.text.trim(), _selectedStatus);
        if (xpGained > 0) {
          _showXpToast(result, topOffset: 92);
        }
        Navigator.pop(context);
      }
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

  @override
  Widget build(BuildContext context) {
    Color dynamicAccent = _getActiveColor();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: const Text(
          'Add a book',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          physics: const BouncingScrollPhysics(),
          children: [
            // --- GLOWING COVER UPLOADER ---
            Center(
              child: GestureDetector(
                onTap: _pickAndCropImage,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 140,
                  height: 210,
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _selectedImage == null
                          ? Colors.white12
                          : dynamicAccent,
                      width: 2,
                    ),
                    boxShadow: [
                      if (_selectedImage != null)
                        BoxShadow(
                          color: dynamicAccent.withOpacity(0.4),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                    ],
                    image: _selectedImage != null
                        ? DecorationImage(
                            image: FileImage(_selectedImage!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _selectedImage == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: dynamicAccent.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.add_photo_alternate_rounded,
                                color: dynamicAccent,
                                size: 36,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Upload Cover',
                              style: TextStyle(
                                color: Colors.white54,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 40),

            // --- DYNAMIC STATUS SELECTOR ---
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Row(
                children: ['Want to read', 'Reading', 'Finished'].map((status) {
                  bool isSelected = _selectedStatus == status;
                  Color statusColor = status == 'Want to read'
                      ? wantColor
                      : (status == 'Reading' ? readColor : finColor);
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedStatus = status;
                          if (status == 'Want to read') {
                            _startedReadingController.clear();
                            _finishedReadingController.clear();
                          } else if (status == 'Reading') {
                            _finishedReadingController.clear();
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected ? statusColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: statusColor.withOpacity(0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : [],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          status,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white54,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 32),

            _buildSectionCard(
              title: 'Book Identity',
              subtitle: 'The essentials that make this book searchable.',
              icon: Icons.auto_stories_rounded,
              accent: dynamicAccent,
              children: [
                _buildTextField(
                  label: 'Title *',
                  controller: _titleController,
                  icon: Icons.title_rounded,
                  isRequired: true,
                ),
                _buildTextField(
                  label: 'Author *',
                  controller: _authorController,
                  icon: Icons.person_rounded,
                  isRequired: true,
                  helpText: 'Required for accurate author statistics',
                ),
                _buildTextField(
                  label: 'Genre',
                  controller: _genresController,
                  icon: Icons.category_rounded,
                  helpText: 'e.g. Fantasy, Thriller, Science Fiction',
                ),
              ],
            ),

            _buildSectionCard(
              title: 'Reading Progress',
              subtitle: 'Set your status and page progress.',
              icon: Icons.trending_up_rounded,
              accent: dynamicAccent,
              children: [
                _buildTextField(
                  label: 'Page count *',
                  controller: _pagesController,
                  icon: Icons.pages_rounded,
                  type: TextInputType.number,
                  isRequired: true,
                ),
                if (_selectedStatus == 'Reading')
                  _buildTextField(
                    label: 'Current Progress (Pages)',
                    controller: _currentProgressController,
                    icon: Icons.auto_stories_rounded,
                    type: TextInputType.number,
                  ),
                if (_selectedStatus == 'Reading' ||
                    _selectedStatus == 'Finished')
                  _buildDateTextField(
                    label: 'Started Reading',
                    controller: _startedReadingController,
                  ),
                if (_selectedStatus == 'Finished')
                  _buildDateTextField(
                    label: 'Finished Reading',
                    controller: _finishedReadingController,
                  ),
              ],
            ),

            _buildSectionCard(
              title: 'Extra Details',
              subtitle: 'Optional metadata for richer reports and lookup.',
              icon: Icons.tune_rounded,
              accent: dynamicAccent,
              children: [
                _buildTextField(
                  label: 'Publisher',
                  controller: _publisherController,
                  icon: Icons.business_rounded,
                ),
                _buildTextField(
                  label: 'Published Date',
                  controller: _publishedDateController,
                  icon: Icons.calendar_today_rounded,
                  helpText: 'Format: yyyy-MM-dd',
                ),
                _buildTextField(
                  label: 'ISBN 13',
                  controller: _isbn13Controller,
                  icon: Icons.qr_code_rounded,
                  type: TextInputType.number,
                ),
                _buildTextField(
                  label: 'ISBN 10',
                  controller: _isbn10Controller,
                  icon: Icons.qr_code_2_rounded,
                  type: TextInputType.number,
                ),
                _buildTextField(
                  label: 'Description',
                  controller: _descriptionController,
                  icon: Icons.description_rounded,
                  maxLines: 4,
                ),
              ],
            ),

            _buildSectionCard(
              title: 'Storage & Links',
              subtitle: 'Where it lives, physically or online.',
              icon: Icons.link_rounded,
              accent: dynamicAccent,
              children: [
                _buildFormatPickerField(dynamicAccent),
                _buildTextField(
                  label: 'Physical Location',
                  controller: _locationController,
                  icon: Icons.location_on_rounded,
                  helpText: 'e.g. Shelf 3, Bedroom',
                ),
                _buildTextField(
                  label: 'Book URL',
                  controller: _bookUrlController,
                  icon: Icons.link_rounded,
                  type: TextInputType.url,
                  helpText:
                      'Save an online reference, eBook, PDF, or purchase link.',
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return null;
                    if (_isValidHttpUrl(text)) return null;
                    return 'Please enter a valid URL starting with http:// or https://';
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            // --- AURORA SUBMIT BUTTON ---
            _isLoading
                ? Center(child: CircularProgressIndicator(color: dynamicAccent))
                : Container(
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                      ), // Vibrant Neon Blue Gradient
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0072FF).withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _saveBook,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Add to Library',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: cardColor.withOpacity(0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withOpacity(0.16)),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
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
                  gradient: LinearGradient(
                    colors: [
                      accent.withOpacity(0.24),
                      accent.withOpacity(0.06),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withOpacity(0.20)),
                ),
                child: Icon(icon, color: accent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }

  Widget _buildFormatPickerField(Color dynamicAccent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: GestureDetector(
        onTap: _showFormatPicker,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: bgColor.withOpacity(0.55),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              const Icon(Icons.book_rounded, color: Colors.white38, size: 22),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Book Format',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                _selectedFormat,
                style: TextStyle(
                  color: dynamicAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white24,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType type = TextInputType.text,
    int maxLines = 1,
    bool isRequired = false,
    String? helpText,
    String? Function(String?)? validator,
  }) {
    Color dynamicAccent = _getActiveColor();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: controller,
            keyboardType: type,
            maxLines: maxLines,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
              floatingLabelStyle: TextStyle(
                color: dynamicAccent,
                fontWeight: FontWeight.bold,
              ),
              prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 22),
              filled: true,
              fillColor: cardColor,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: dynamicAccent, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.05),
                  width: 1,
                ),
              ),
            ),
            validator:
                validator ??
                (isRequired
                    ? (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'This field is required';
                        }
                        if (type == TextInputType.number) {
                          final number = int.tryParse(val.trim());
                          if (number == null) {
                            return 'Must be a valid number';
                          }
                          if (number <= 0) {
                            return 'Must be greater than 0';
                          }
                        }
                        return null;
                      }
                    : null),
          ),
          if (helpText != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: Text(
                helpText,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateTextField({
    required String label,
    required TextEditingController controller,
  }) {
    Color dynamicAccent = _getActiveColor();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w500,
          ),
          floatingLabelStyle: TextStyle(
            color: dynamicAccent,
            fontWeight: FontWeight.bold,
          ),
          prefixIcon: const Icon(
            Icons.date_range_rounded,
            color: Color(0xFF64748B),
            size: 22,
          ),
          filled: true,
          fillColor: cardColor,
          hintText: 'yyyy-mm-dd',
          hintStyle: const TextStyle(color: Colors.white24),
          suffixIcon: IconButton(
            icon: Icon(Icons.calendar_month_rounded, color: dynamicAccent),
            onPressed: () => _selectDate(controller),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: dynamicAccent, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Colors.white.withOpacity(0.05),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }
}

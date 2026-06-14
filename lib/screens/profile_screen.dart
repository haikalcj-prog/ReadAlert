import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../services/stats_service.dart';
import '../services/xp_service.dart';
import '../services/notification_service.dart';
import 'reports_screen.dart';
import 'achievements_screen.dart';
import 'streak_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  // ── Firebase ─────────────────────────────────────────────
  User? get _user => FirebaseAuth.instance.currentUser;
  StreamSubscription<QuerySnapshot>? _librarySub;

  // ── State ────────────────────────────────────────────────
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  bool _isPickingImage = false;
  bool _dailyReminderEnabled = false;
  bool _isReminderSaving = false;
  late AnimationController _shimmerCtrl;

  // ── Palette ──────────────────────────────────────────────
  static const Color bgColor = Color(0xFF0F172A);
  static const Color cardColor = Color(0xFF1E293B);
  static const Color accent = Color(0xFF8B5CF6);
  static const Color pink = Color(0xFFD134B6);
  static const Color gold = Color(0xFFFFBB33);

  static const List<List<Color>> tierGradients = [
    [Color(0xFFE2E8F0), Color(0xFF94A3B8)],
    [Color(0xFF86EFAC), Color(0xFF059669)],
    [Color(0xFF7DD3FC), Color(0xFF0284C7)],
    [Color(0xFFD8B4FE), Color(0xFF7C3AED)],
    [Color(0xFFFCA5A5), Color(0xFFE11D48)],
    [Color(0xFFFDE047), Color(0xFFD97706)],
    [Color(0xFF67E8F9), Color(0xFF0F766E)],
    [Color(0xFFFDA4AF), Color(0xFF9F1239)],
    [Color(0xFFF9A8D4), Color(0xFFBE185D)],
    [Color(0xFFFFD700), Color(0xFFFF8C00)],
  ];

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _loadStats();
    _loadReminderPreference();

    if (_user != null) {
      _librarySub = FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .collection('library')
          .snapshots()
          .listen((_) {
            _loadStats();
          });
    }
  }

  @override
  void dispose() {
    _librarySub?.cancel();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    if (_stats.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final stats = await StatsService.fetchAllStats();
      if (mounted) setState(() => _stats = stats);
    } catch (e) {
      debugPrint('ProfileScreen error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── DAILY STREAK REMINDER ───────────────────────────────
  Future<void> _loadReminderPreference() async {
    final user = _user;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data();
      final enabled = data?['dailyStreakReminderEnabled'] == true;

      if (mounted) {
        setState(() => _dailyReminderEnabled = enabled);
      }
    } catch (e) {
      debugPrint('Reminder preference error: $e');
    }
  }

  Future<void> _toggleDailyReminder(bool enabled) async {
    final user = _user;
    if (user == null || _isReminderSaving) return;

    final previousValue = _dailyReminderEnabled;

    setState(() {
      _dailyReminderEnabled = enabled;
      _isReminderSaving = true;
    });

    try {
      if (enabled) {
        final scheduled = await NotificationService.scheduleDailyStreakReminder(
          hour: 20,
          minute: 0,
        );

        if (!scheduled) {
          throw Exception('Notification permission was not granted.');
        }
      } else {
        await NotificationService.cancelDailyStreakReminder();
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'dailyStreakReminderEnabled': enabled,
        'dailyStreakReminderTime': '20:00',
      }, SetOptions(merge: true));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'Daily streak reminder enabled at 8:00 PM.'
                : 'Daily streak reminder disabled.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('Toggle reminder error: $e');

      if (mounted) {
        setState(() => _dailyReminderEnabled = previousValue);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to update reminder. Please try again.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isReminderSaving = false);
      }
    }
  }

  Future<void> _showTestReminder() async {
    try {
      final sent = await NotificationService.showTestReminder();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sent
                ? 'Test reminder sent. Check your notification panel.'
                : 'Notification permission was not granted.',
          ),
          backgroundColor: sent ? null : Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('Test reminder error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to send test reminder.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── AVATAR OPTIONS DIALOG ───────────────────────────────
  Future<void> _showAvatarOptionsDialog() async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Change Profile Picture',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'What would you like to do?',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              _pickAndSaveAvatar();
            },
            icon: const Icon(Icons.image_rounded, size: 18),
            label: const Text(
              'Gallery',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.withOpacity(0.8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              _deleteAvatar();
            },
            icon: const Icon(Icons.delete_rounded, size: 18),
            label: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── DELETE AVATAR ────────────────────────────────────────
  Future<void> _deleteAvatar() async {
    if (_user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .update({'photoURL': ''});

      try {
        await _user!.updatePhotoURL('');
      } catch (_) {}

      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture deleted'),
            backgroundColor: Colors.greenAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not delete photo: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── PICK → CROP → SAVE ───────────────────────────────────
  Future<void> _pickAndSaveAvatar() async {
    if (_user == null) return;
    setState(() => _isPickingImage = true);

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 1024,
      );
      if (picked == null) return;

      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 85,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Photo',
            toolbarColor: bgColor,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: accent,
            backgroundColor: bgColor,
            dimmedLayerColor: Colors.black87,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'Crop Photo',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );
      if (cropped == null) return;

      final localPath = cropped.path;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .update({'photoURL': localPath});

      try {
        await _user!.updatePhotoURL(localPath);
      } catch (_) {}

      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not update photo: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  // ── EDIT NAME ─────────────────────────────────────────────
  Future<void> _showEditNameDialog(String currentName) async {
    final ctrl = TextEditingController(text: currentName);
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Change Name',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter your name',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            filled: true,
            fillColor: bgColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: accent, width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withOpacity(0.4)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              final newName = ctrl.text.trim();
              if (newName.isEmpty) return;
              Navigator.pop(context);
              await _user!.updateDisplayName(newName);
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(_user!.uid)
                  .update({'name': newName});
              setState(() {});
            },
            child: const Text(
              'Save',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  //  BUILD
  // ═════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: accent, strokeWidth: 2),
            )
          : CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                _buildSliverHeader(),
                SliverToBoxAdapter(child: _buildBody()),
              ],
            ),
    );
  }

  // ── SLIVER HEADER ─────────────────────────────────────────
  Widget _buildSliverHeader() {
    final claimed = List<String>.from(_stats['claimedAchievements'] ?? []);
    final allAchievements = StatsService.getAllAchievements();
    final claimedBadges = allAchievements
        .where((a) => claimed.contains(a['id']))
        .toList();

    return SliverToBoxAdapter(
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(_user?.uid)
            .snapshots(),
        builder: (context, snap) {
          final data = snap.data?.data() as Map<String, dynamic>?;
          final String name = data?['name'] ?? _user?.displayName ?? 'Reader';
          final String? photoURL = data?['photoURL'] ?? _user?.photoURL;

          // FIX: Grab the LIVE XP and calculate the LIVE Rank & Progress!
          final int liveXp =
              data?['totalXp'] ?? data?['points'] ?? _stats['totalXp'] ?? 0;
          final levelData = XpService.calculateLevel(liveXp);

          final int level = levelData['level'] as int;
          final int tierIndex = levelData['tierIndex'] as int;
          final colors = tierGradients[tierIndex];
          final double prog = levelData['progress'] as double;
          final int xpNeeded = levelData['xpNeeded'] as int;
          final String title = levelData['title'] as String;

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors[0].withOpacity(0.18), bgColor],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        _xpPill(liveXp, colors[0]),
                      ],
                    ),
                    const SizedBox(height: 28),
                    _buildAvatar(photoURL, colors, level),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _showEditNameDialog(name),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.edit_rounded,
                              color: Colors.white.withOpacity(0.5),
                              size: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _rankPill(title, colors),
                    const SizedBox(height: 16),
                    _xpBar(prog, xpNeeded, liveXp, colors),
                    const SizedBox(height: 20),
                    if (claimedBadges.isNotEmpty) ...[
                      _badgeCollectionRow(claimedBadges),
                      const SizedBox(height: 20),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── AVATAR ────────────────────────────────────────────────
  Widget _buildAvatar(String? photoURL, List<Color> colors, int level) {
    return GestureDetector(
      onTap: _showAvatarOptionsDialog,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _shimmerCtrl,
            builder: (_, __) => Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  transform: GradientRotation(_shimmerCtrl.value * 2 * 3.14159),
                  colors: [colors[0], colors[1], pink, colors[0]],
                ),
              ),
            ),
          ),
          Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: bgColor,
            ),
          ),
          CircleAvatar(
            radius: 54,
            backgroundColor: cardColor,
            child: _isPickingImage
                ? CircularProgressIndicator(color: colors[0], strokeWidth: 2)
                : _buildAvatarImage(photoURL, colors),
          ),
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
                border: Border.all(color: bgColor, width: 2),
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 13,
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: bgColor, width: 2),
              ),
              child: Text(
                'Lv.$level',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarImage(String? photoURL, List<Color> colors) {
    if (photoURL != null && photoURL.isNotEmpty && photoURL != 'null') {
      if (photoURL.startsWith('http')) {
        return ClipOval(
          child: Image.network(
            photoURL,
            width: 108,
            height: 108,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _avatarInitial(colors),
          ),
        );
      } else {
        final file = File(photoURL);
        if (file.existsSync()) {
          return ClipOval(
            child: Image.file(
              file,
              width: 108,
              height: 108,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _avatarInitial(colors),
            ),
          );
        }
      }
    }
    return _avatarInitial(colors);
  }

  Widget _avatarInitial(List<Color> colors) {
    final name = _user?.displayName ?? 'R';
    return ShaderMask(
      shaderCallback: (b) => LinearGradient(colors: colors).createShader(b),
      child: Text(
        name[0].toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 42,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  // ── SMALL UI HELPERS ──────────────────────────────────────
  Widget _xpPill(int xp, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: color, size: 13),
          const SizedBox(width: 5),
          Text(
            '$xp XP',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _rankPill(String title, List<Color> colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [colors[0].withOpacity(0.2), colors[1].withOpacity(0.1)],
        ),
        border: Border.all(color: colors[0].withOpacity(0.4)),
      ),
      child: ShaderMask(
        shaderCallback: (b) => LinearGradient(colors: colors).createShader(b),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 12,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _xpBar(
    double progress,
    int xpNeeded,
    int totalXp,
    List<Color> colors,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: colors),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: colors[0].withOpacity(0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$totalXp XP total',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 11,
                ),
              ),
              Text(
                xpNeeded > 0 ? '$xpNeeded XP to next level' : '🎉 Max Level!',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _achievementAssetWidget(
    Map<String, dynamic> achievement, {
    double size = 42,
    double fallbackSize = 26,
  }) {
    final asset = achievement['asset']?.toString();
    final icon = achievement['icon']?.toString() ?? '🏅';

    if (asset == null || asset.isEmpty) {
      return Text(icon, style: TextStyle(fontSize: fallbackSize));
    }

    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) =>
          Text(icon, style: TextStyle(fontSize: fallbackSize)),
    );
  }

  String _badgeRequirementText(Map<String, dynamic> badge) {
    final description = badge['description']?.toString().trim() ?? '';
    if (description.isNotEmpty) return description;

    final field = badge['field']?.toString() ?? '';
    final threshold = badge['threshold'];

    switch (field) {
      case 'libraryCount':
        return 'Add $threshold book${threshold == 1 ? '' : 's'} to the library.';
      case 'completedBooks':
        return 'Finish $threshold book${threshold == 1 ? '' : 's'}.';
      case 'totalPages':
        return 'Read $threshold pages.';
      case 'longestStreak':
        return 'Reach a $threshold-day reading streak.';
      case 'level':
        return 'Reach Level $threshold.';
      case 'uniqueGenres':
        return 'Add books from $threshold different genres.';
      case 'uniqueAuthors':
        return 'Add books from $threshold different authors.';
      case 'topAuthorCount':
        return 'Add $threshold books by the same author.';
      default:
        return 'No requirement available.';
    }
  }

  Future<void> _showBadgeInfoDialog(Map<String, dynamic> badge) async {
    final title = badge['title']?.toString() ?? 'Badge';
    final requirement = _badgeRequirementText(badge);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: gold.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: gold.withOpacity(0.25)),
              ),
              child: Center(
                child: _achievementAssetWidget(
                  badge,
                  size: 30,
                  fallbackSize: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Requirement',
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              requirement,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: accent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badgeCollectionRow(List<Map<String, dynamic>> badges) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(
            children: [
              const Icon(Icons.military_tech_rounded, color: gold, size: 14),
              const SizedBox(width: 6),
              Text(
                'BADGE COLLECTION',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 78,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: badges.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final badge = badges[i];
              return GestureDetector(
                onTap: () => _showBadgeInfoDialog(badge),
                onLongPress: () => _showBadgeInfoDialog(badge),
                child: Container(
                  width: 68,
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                    boxShadow: [
                      BoxShadow(
                        color: gold.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _achievementAssetWidget(
                        badge,
                        size: 42,
                        fallbackSize: 27,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReminderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.orangeAccent.withOpacity(0.25),
                  ),
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: Colors.orangeAccent,
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Daily Streak Reminder',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Remind me at 8:00 PM to keep my reading streak.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.38),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              _isReminderSaving
                  ? const SizedBox(
                      width: 36,
                      height: 36,
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: accent,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    )
                  : Switch(
                      value: _dailyReminderEnabled,
                      activeThumbColor: accent,
                      onChanged: _toggleDailyReminder,
                    ),
            ],
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _showTestReminder,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accent.withOpacity(0.22)),
              ),
              child: const Center(
                child: Text(
                  'Send test reminder',
                  style: TextStyle(
                    color: accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  //  BODY
  // ═════════════════════════════════════════════════════════
  Widget _buildBody() {
    // FIX: Body now also wraps itself in a StreamBuilder to keep colors
    // and live streak/goals completely synced without refresh!
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_user?.uid)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>?;

        final int liveXp =
            data?['totalXp'] ?? data?['points'] ?? _stats['totalXp'] ?? 0;
        // Display-only streak fix:
        // Firestore may still store an old currentStreak after the user misses days.
        // XpService.displayCurrentStreakFromData() returns 0 if lastReadDate is
        // older than yesterday. This keeps ProfileScreen and StreakScreen synced
        // with HomeScreen.
        final int liveStreak = data != null
            ? XpService.displayCurrentStreakFromData(data)
            : (_stats['currentStreak'] ?? 0);
        final int liveLongestStreak =
            data?['longestStreak'] ?? _stats['longestStreak'] ?? 0;

        final levelData = XpService.calculateLevel(liveXp);
        final int tierIdx = levelData['tierIndex'] as int;
        final colors = tierGradients[tierIdx];
        final int currentLevel = levelData['level'] as int;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              _sectionLabel('📊 OVERVIEW'),
              const SizedBox(height: 12),
              _buildQuickStatsGrid(liveStreak),
              const SizedBox(height: 28),
              _sectionLabel('📈 READING REPORTS'),
              const SizedBox(height: 12),
              _buildReportsPreviewCard(colors),
              const SizedBox(height: 28),
              _sectionLabel('🔥 STREAK CALENDAR'),
              const SizedBox(height: 12),
              _buildStreakCard(liveStreak, liveLongestStreak),
              const SizedBox(height: 12),
              _buildReminderCard(),
              const SizedBox(height: 28),
              _sectionLabel('🎭 TOP GENRES'),
              const SizedBox(height: 12),
              _buildTagStats(
                _stats['genreCounts'] as Map<String, int>? ?? {},
                accent,
                title: 'Genres you read most',
                icon: Icons.theater_comedy_rounded,
                itemPrefix: '#',
                emptyMessage:
                    'No genres yet — add more books to build your taste profile.',
              ),
              const SizedBox(height: 28),
              _sectionLabel('✍️ TOP AUTHORS'),
              const SizedBox(height: 12),
              _buildTagStats(
                _stats['authorCounts'] as Map<String, int>? ?? {},
                pink,
                title: 'Authors you read most',
                icon: Icons.draw_rounded,
                emptyMessage:
                    'No author data yet — your favorite writers will appear here.',
              ),
              const SizedBox(height: 28),
              _sectionLabel('🏅 ACHIEVEMENTS'),
              const SizedBox(height: 12),
              _buildAchievementsPreview(liveLongestStreak, currentLevel),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async => await FirebaseAuth.instance.signOut(),
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  label: const Text(
                    'Log Out',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.redAccent.withOpacity(0.4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: TextStyle(
      color: Colors.white.withOpacity(0.4),
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
    ),
  );

  // ── QUICK STATS GRID ──────────────────────────────────────
  int _libraryCount() {
    final directCount = _stats['libraryCount'];
    if (directCount is int) return directCount;

    final completed = _stats['completedBooks'];
    final reading = _stats['readingBooks'] ?? _stats['readingCount'];
    final wantToRead = _stats['wantToReadBooks'] ?? _stats['wantToReadCount'];

    if (completed is int || reading is int || wantToRead is int) {
      return (completed is int ? completed : 0) +
          (reading is int ? reading : 0) +
          (wantToRead is int ? wantToRead : 0);
    }

    return 0;
  }

  Widget _buildQuickStatsGrid(int liveStreak) {
    final libraryCount = _libraryCount();
    final items = [
      _StatItem(
        '${_stats['totalPages'] ?? 0}',
        'Pages Read',
        Icons.menu_book_rounded,
        accent,
      ),
      _StatItem(
        '${_stats['completedBooks'] ?? 0}',
        'Finished',
        Icons.check_circle_rounded,
        Colors.greenAccent,
      ),
      _StatItem(
        '$liveStreak',
        'Day Streak',
        Icons.local_fire_department_rounded,
        Colors.orangeAccent,
      ),
      _StatItem(
        '$libraryCount',
        'Books in Library',
        Icons.library_books_rounded,
        pink,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.6,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(item.icon, color: item.color, size: 16),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.value,
                    style: TextStyle(
                      color: item.color,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    item.label,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── REPORTS PREVIEW ───────────────────────────────────────
  void _openReports(int initialTabIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ReportsScreen(stats: _stats, initialTabIndex: initialTabIndex),
      ),
    );
  }

  Widget _buildReportsPreviewCard(List<Color> colors) {
    final Map<int, int> weekly = Map<int, int>.from(
      _stats['weeklyPages'] ?? {},
    );
    final int weekTotal = weekly.values.fold(0, (a, b) => a + b);
    final int monthTotal = (Map<int, int>.from(
      _stats['monthlyPages'] ?? {},
    )).values.fold(0, (a, b) => a + b);
    final int yearTotal = (Map<int, int>.from(
      _stats['yearlyPages'] ?? {},
    )).values.fold(0, (a, b) => a + b);

    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final maxVal = weekly.values.isEmpty
        ? 1
        : weekly.values.reduce((a, b) => a > b ? a : b);

    return GestureDetector(
      onTap: () => _openReports(0), // Default card tap opens Weekly report
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'This Week',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                GestureDetector(
                  onTap: () => _openReports(0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors[0].withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Full report',
                          style: TextStyle(
                            color: colors[0],
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: colors[0],
                          size: 10,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 110,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (i) {
                  final val = weekly[i] ?? 0;
                  final barH = maxVal == 0
                      ? 4.0
                      : (val / maxVal * 56).clamp(4.0, 56.0);
                  final isToday = i == (DateTime.now().weekday - 1);
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (val > 0)
                            Text(
                              '$val',
                              style: TextStyle(
                                color: isToday
                                    ? colors[0]
                                    : Colors.white.withOpacity(0.3),
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          else
                            const SizedBox(height: 10),
                          const SizedBox(height: 2),
                          AnimatedContainer(
                            duration: Duration(milliseconds: 400 + i * 60),
                            curve: Curves.easeOutCubic,
                            height: barH,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isToday
                                    ? [pink, accent]
                                    : val > 0
                                    ? [colors[1], colors[0]]
                                    : [
                                        Colors.white.withOpacity(0.07),
                                        Colors.white.withOpacity(0.04),
                                      ],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            days[i],
                            style: TextStyle(
                              color: isToday
                                  ? colors[0]
                                  : Colors.white.withOpacity(0.3),
                              fontSize: 10,
                              fontWeight: isToday
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _miniStatPill(
                  '$weekTotal',
                  'This week',
                  colors[0],
                  onTap: () => _openReports(0),
                ),
                const SizedBox(width: 8),
                _miniStatPill(
                  '$monthTotal',
                  'This month',
                  Colors.greenAccent,
                  onTap: () => _openReports(1),
                ),
                const SizedBox(width: 8),
                _miniStatPill(
                  '$yearTotal',
                  'This year',
                  pink,
                  onTap: () => _openReports(2),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStatPill(
    String value,
    String label,
    Color color, {
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: 3),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: color.withOpacity(0.55),
                      size: 12,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── STREAK CARD ───────────────────────────────────────────
  Widget _buildStreakCard(int liveStreak, int liveLongest) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StreakScreen(
            currentStreak: liveStreak,
            longestStreak: liveLongest,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.orangeAccent.withOpacity(0.25),
                ),
              ),
              child: const Center(
                child: Text('🔥', style: TextStyle(fontSize: 30)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$liveStreak day${liveStreak == 1 ? '' : 's'} streak',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Best: $liveLongest days  •  Tap to see calendar',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white.withOpacity(0.2),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  // ── TAG STATS ─────────────────────────────────────────────
  Widget _buildTagStatsEmptyState({
    required String title,
    required IconData icon,
    required Color color,
    required String emptyMessage,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 18),
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
                      'We will show your reading taste here soon.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.35),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.04)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: color.withOpacity(0.55),
                  size: 22,
                ),
                const SizedBox(height: 10),
                Text(
                  emptyMessage,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.38),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagStats(
    Map<String, int> counts,
    Color color, {
    required String title,
    required IconData icon,
    String itemPrefix = '',
    String emptyMessage = 'No data yet — keep reading!',
  }) {
    if (counts.isEmpty) {
      return _buildTagStatsEmptyState(
        title: title,
        icon: icon,
        color: color,
        emptyMessage: emptyMessage,
      );
    }

    final cleaned = <MapEntry<String, int>>[];
    for (final entry in counts.entries) {
      final raw = entry.key.trim();
      final value = entry.value;
      if (value <= 0) continue;
      String label = raw;
      if (label.isEmpty) label = 'Unknown';
      if (label.toLowerCase() == 'unknown author' ||
          label.toLowerCase() == 'unknown') {
        label = 'Unknown Author';
      }
      cleaned.add(MapEntry(label, value));
    }

    if (cleaned.isEmpty) {
      return _buildTagStatsEmptyState(
        title: title,
        icon: icon,
        color: color,
        emptyMessage: emptyMessage,
      );
    }

    cleaned.sort((a, b) => b.value.compareTo(a.value));
    final top = cleaned.take(5).toList();
    final maxVal = top.first.value;
    final total = cleaned.fold<int>(0, (sum, e) => sum + e.value);
    final uniqueCount = cleaned.length;
    final topLabel = top.first.key;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.06),
            blurRadius: 22,
            offset: const Offset(0, 10),
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
                    colors: [color.withOpacity(0.22), color.withOpacity(0.08)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withOpacity(0.22)),
                ),
                child: Icon(icon, color: color, size: 18),
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
                      'Your top ${itemPrefix == '#' ? 'genres' : 'authors'} based on books in library.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.35),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _tagStatChip(
                  title: 'Unique',
                  value: '$uniqueCount',
                  subtitle: itemPrefix == '#' ? 'genres' : 'authors',
                  color: color,
                  emphasize: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _tagStatChip(
                  title: 'Top Pick',
                  value: topLabel,
                  subtitle:
                      '${top.first.value} book${top.first.value == 1 ? '' : 's'}',
                  color: Colors.white54,
                  textValueSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...List.generate(top.length, (i) {
            final entry = top[i];
            final double pct = maxVal == 0 ? 0 : entry.value / maxVal;
            final double share = total == 0 ? 0 : (entry.value / total) * 100;
            final bool isLeader = i == 0;
            final Color rowAccent = isLeader ? color : Colors.white;
            return Container(
              margin: EdgeInsets.only(bottom: i == top.length - 1 ? 0 : 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isLeader
                    ? color.withOpacity(0.09)
                    : Colors.white.withOpacity(0.025),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isLeader
                      ? color.withOpacity(0.20)
                      : Colors.white.withOpacity(0.05),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isLeader
                          ? LinearGradient(
                              colors: [gold.withOpacity(0.95), color],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isLeader ? null : Colors.white.withOpacity(0.06),
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          color: isLeader ? Colors.white : Colors.white70,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${itemPrefix}${entry.key}',
                                    style: TextStyle(
                                      color: isLeader
                                          ? color
                                          : Colors.white.withOpacity(0.92),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${share.toStringAsFixed(0)}% of your ${itemPrefix == '#' ? 'genre' : 'author'} activity',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.34),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: rowAccent.withOpacity(
                                  isLeader ? 0.14 : 0.08,
                                ),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: rowAccent.withOpacity(
                                    isLeader ? 0.22 : 0.12,
                                  ),
                                ),
                              ),
                              child: Text(
                                '${entry.value} book${entry.value == 1 ? '' : 's'}',
                                style: TextStyle(
                                  color: isLeader ? color : Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: Stack(
                            children: [
                              Container(
                                height: 8,
                                color: Colors.white.withOpacity(0.06),
                              ),
                              FractionallySizedBox(
                                widthFactor: pct.clamp(0.0, 1.0),
                                child: Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        isLeader
                                            ? gold.withOpacity(0.95)
                                            : color,
                                        color,
                                        color.withOpacity(0.65),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _tagStatChip({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    bool emphasize = false,
    double textValueSize = 20,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(emphasize ? 0.10 : 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(emphasize ? 0.22 : 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withOpacity(0.35),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: emphasize ? color : Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: textValueSize,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.38),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── ACHIEVEMENTS PREVIEW ──────────────────────────────────
  Widget _buildAchievementsPreview(int liveStreak, int liveLevel) {
    final claimed = List<String>.from(_stats['claimedAchievements'] ?? []);
    final allA = StatsService.getAllAchievements();
    final statsForCheck = {
      'completedBooks': _stats['completedBooks'] ?? 0,
      'totalPages': _stats['totalPages'] ?? 0,
      'longestStreak': liveStreak,
      'level': liveLevel,
      'libraryCount': _libraryCount(),
      'uniqueGenres': _stats['uniqueGenres'] ?? 0,
      'uniqueAuthors': _stats['uniqueAuthors'] ?? 0,
      'topAuthorCount': _stats['topAuthorCount'] ?? 0,
    };

    final unlocked = allA
        .where((a) => StatsService.checkCondition(a, statsForCheck))
        .toList();
    final ready = unlocked.where((a) => !claimed.contains(a['id'])).toList();
    final pct = allA.isEmpty ? 0.0 : claimed.length / allA.length;
    final previewBadges = [
      ...ready.take(3),
      ...unlocked.where((a) => claimed.contains(a['id'])).take(5),
    ].take(6).toList();

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AchievementsScreen(stats: _stats)),
      ).then((_) => _loadStats()),
      child: Container(
        padding: const EdgeInsets.all(1.2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            colors: [
              gold.withOpacity(0.50),
              accent.withOpacity(0.28),
              pink.withOpacity(0.35),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: gold.withOpacity(0.08),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [gold, pink, accent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: gold.withOpacity(0.22),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text('🏆', style: TextStyle(fontSize: 27)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Badge Vault',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          ready.isNotEmpty
                              ? '${ready.length} achievement${ready.length == 1 ? '' : 's'} ready to claim'
                              : '${claimed.length} / ${allA.length} badges claimed',
                          style: TextStyle(
                            color: ready.isNotEmpty
                                ? gold.withOpacity(0.95)
                                : Colors.white.withOpacity(0.38),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: ready.isNotEmpty
                          ? gold.withOpacity(0.13)
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: ready.isNotEmpty
                            ? gold.withOpacity(0.35)
                            : Colors.white.withOpacity(0.08),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          ready.isNotEmpty ? 'Claim' : 'View',
                          style: TextStyle(
                            color: ready.isNotEmpty ? gold : Colors.white54,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: ready.isNotEmpty ? gold : Colors.white54,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _achievementMiniStat(
                      'Claimed',
                      '${claimed.length}',
                      'of ${allA.length}',
                      gold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _achievementMiniStat(
                      'Unlocked',
                      '${unlocked.length}',
                      'available',
                      accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _achievementMiniStat(
                      'Ready',
                      '${ready.length}',
                      'claim now',
                      ready.isNotEmpty ? Colors.greenAccent : Colors.white54,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 9,
                  backgroundColor: Colors.white.withOpacity(0.07),
                  valueColor: const AlwaysStoppedAnimation<Color>(gold),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(pct * 100).toInt()}% badge collection completed',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.34),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (previewBadges.isNotEmpty) ...[
                const SizedBox(height: 18),
                SizedBox(
                  height: 78,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: previewBadges.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) {
                      final a = previewBadges[i];
                      final isClaimed = claimed.contains(a['id']);
                      final color = _achievementCategoryColor(
                        a['category'] ?? '',
                      );
                      return Container(
                        width: 66,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isClaimed
                              ? color.withOpacity(0.08)
                              : gold.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isClaimed
                                ? color.withOpacity(0.30)
                                : gold.withOpacity(0.30),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _achievementAssetWidget(
                              a,
                              size: 38,
                              fallbackSize: 24,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isClaimed ? 'Claimed' : 'Ready',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isClaimed ? color : gold,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _achievementMiniStat(
    String title,
    String value,
    String subtitle,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withOpacity(0.32),
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.30),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _achievementCategoryColor(String category) {
    switch (category) {
      case 'Library':
        return const Color(0xFF06B6D4);
      case 'Finished':
        return gold;
      case 'Pages':
        return accent;
      case 'Streak':
        return const Color(0xFFFF6B35);
      case 'Rank':
        return pink;
      case 'Discovery':
        return const Color(0xFF10B981);
      default:
        return accent;
    }
  }
}

class _StatItem {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const _StatItem(this.value, this.label, this.icon, this.color);
}

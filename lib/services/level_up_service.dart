import 'package:flutter/material.dart';
import '../widgets/level_up_dialog.dart';
import 'audio_service.dart';

/// Global service that can show the level-up popup from any screen.
///
/// Uses a [GlobalKey<NavigatorState>] attached to [MaterialApp] so dialogs
/// can be pushed without needing a local [BuildContext].
///
/// A simple [_isShowing] guard prevents duplicate popups when multiple
/// XP updates fire in quick succession.
class LevelUpService {
  LevelUpService._();

  static GlobalKey<NavigatorState>? _navigatorKey;
  static bool _isShowing = false;
  static final List<Map<String, dynamic>> _queue = [];

  /// Call once from main.dart to wire the navigator key.
  static void init(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  /// Show the level-up dialog globally.
  ///
  /// Adds the request to a pending queue and processes it safely via a 
  /// post-frame callback. This prevents the dialog from stealing synchronous
  /// Navigator.pop() calls from other screens (like AddBookScreen).
  static void showLevelUp(int newLevel, String newTitle) {
    _queue.add({'newLevel': newLevel, 'newTitle': newTitle});
    _processQueue();
  }

  static void _processQueue() {
    if (_isShowing || _queue.isEmpty) return;
    
    _isShowing = true;

    // Use a post-frame callback so we don't interfere with any synchronous
    // navigation (like popping the AddBookScreen) that the caller might be doing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_queue.isEmpty) {
        _isShowing = false;
        return;
      }

      final nav = _navigatorKey?.currentState;
      final ctx = nav?.overlay?.context;
      
      if (ctx == null) {
        _isShowing = false;
        return;
      }

      final popup = _queue.removeAt(0);
      final newLevel = popup['newLevel'] as int;
      final newTitle = popup['newTitle'] as String;

      final tier = ((newLevel - 1) ~/ 10).clamp(0, 9);
      final t = kTierThemes[tier];

      AudioService.playLevelUp();

      showDialog(
        context: ctx,
        barrierDismissible: false,
        barrierColor: Colors.black87,
        builder: (_) => LevelUpDialog(
          tier: tier,
          theme: t,
          newLevel: newLevel,
          newTitle: newTitle,
        ),
      ).then((_) {
        _isShowing = false;
        _processQueue();
      });
    });
  }
}

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Centralized service to handle playing sounds in the app.
class AudioService {
  AudioService._();

  static final AudioPlayer _player = AudioPlayer();

  /// Play an audio file from the assets/sounds/ directory.
  /// 
  /// Example: [playSound]('level_up.mp3')
  static Future<void> playSound(String fileName) async {
    try {
      // Create a short-lived instance to allow overlapping sounds
      final player = AudioPlayer();
      await player.play(AssetSource('sounds/$fileName'));
      
      // Clean up the player after the sound finishes
      player.onPlayerComplete.listen((_) {
        player.dispose();
      });
    } catch (e) {
      debugPrint('Error playing sound $fileName: $e');
    }
  }

  /// Plays the level up fanfare.
  static Future<void> playLevelUp() => playSound('level_up.mp3');

  /// Plays the XP gain chime.
  static Future<void> playXpGain() => playSound('xp_gain.mp3');

  /// Plays the success positive sound (e.g., adding a book).
  static Future<void> playSuccess() => playSound('success.mp3');

  /// Plays the achievement unlocked jingle.
  static Future<void> playAchievement() => playSound('achievement.mp3');
}

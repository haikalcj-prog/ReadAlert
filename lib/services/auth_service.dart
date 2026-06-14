import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static bool _googleInitialized = false;

  // ── PRIVATE: CREATE / KEEP USER DOCUMENT ─────────────────
  Future<void> _ensureUserDocument(
    User user, {
    String? fallbackName,
    bool forceName = false,
  }) async {
    final userRef = _firestore.collection('users').doc(user.uid);
    final snap = await userRef.get();

    final displayName = fallbackName?.trim().isNotEmpty == true
        ? fallbackName!.trim()
        : (user.displayName?.trim().isNotEmpty == true
              ? user.displayName!.trim()
              : 'Reader');

    if (!snap.exists) {
      await userRef.set({
        'name': displayName,
        'email': user.email ?? '',
        'photoURL': user.photoURL ?? '',
        'totalXp': 0,
        'points': 0,
        'level': 1,
        'currentStreak': 0,
        'longestStreak': 0,
        'booksRead': 0,
        'claimedAchievements': [],
        'equippedBadge': '',
        'lastReadDate': '',
        'createdAt': Timestamp.now(),
      });
      return;
    }

    final data = snap.data() ?? {};
    final updateData = <String, dynamic>{
      'email': user.email ?? data['email'] ?? '',
    };

    if (user.photoURL != null && user.photoURL!.isNotEmpty) {
      updateData['photoURL'] = user.photoURL;
    }

    if (forceName ||
        (data['name'] == null || '${data['name']}'.trim().isEmpty)) {
      updateData['name'] = displayName;
    }

    await userRef.set(updateData, SetOptions(merge: true));
  }

  static Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized || kIsWeb) return;
    await GoogleSignIn.instance.initialize();
    _googleInitialized = true;
  }

  // ── REGISTER WITH EMAIL/PASSWORD ─────────────────────────
  Future<User?> register(String name, String email, String password) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user;
    if (user == null) {
      throw Exception('Registration failed: no user returned from Firebase.');
    }

    await user.updateDisplayName(name.trim());
    await _ensureUserDocument(user, fallbackName: name, forceName: true);

    return user;
  }

  // ── LOGIN WITH EMAIL/PASSWORD ────────────────────────────
  Future<User?> login(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user;
    if (user != null) {
      await _ensureUserDocument(user);
    }

    return user;
  }

  // ── GOOGLE SIGN-IN / REGISTER ────────────────────────────
  Future<User?> signInWithGoogle() async {
    UserCredential credential;

    if (kIsWeb) {
      final googleProvider = GoogleAuthProvider();
      credential = await _auth.signInWithPopup(googleProvider);
    } else {
      await _ensureGoogleInitialized();

      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw Exception('Google sign-in is not supported on this platform.');
      }

      final GoogleSignInAccount? googleUser = await GoogleSignIn.instance
          .authenticate();

      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      if (googleAuth.idToken == null || googleAuth.idToken!.isEmpty) {
        throw Exception('Google sign-in failed: missing ID token.');
      }

      final authCredential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      credential = await _auth.signInWithCredential(authCredential);
    }

    final user = credential.user;
    if (user == null) {
      throw Exception('Google sign-in failed: no user returned from Firebase.');
    }

    await _ensureUserDocument(user);
    return user;
  }

  // ── LOGOUT ───────────────────────────────────────────────
  Future<void> logout() async {
    if (!kIsWeb) {
      try {
        await _ensureGoogleInitialized();
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Ignore Google sign-out errors so Firebase sign-out still happens.
      }
    }

    await _auth.signOut();
  }
}

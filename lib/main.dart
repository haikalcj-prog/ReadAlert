import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'screens/welcome_screen.dart';
import 'screens/main_screen.dart';
import 'services/notification_service.dart';
import 'services/level_up_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'readalert startup',
        context: ErrorDescription('initializing Firebase'),
      ),
    );
    runApp(StartupErrorApp(error: error.toString()));
    return;
  }

  unawaited(_initializeNotifications());
  LevelUpService.init(navigatorKey);
  runApp(const ReadAlertApp());
}

Future<void> _initializeNotifications() async {
  try {
    await NotificationService.initialize();
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'readalert startup',
        context: ErrorDescription('initializing notifications'),
      ),
    );
  }
}

class StartupErrorApp extends StatelessWidget {
  final String error;

  const StartupErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFF87171),
                    size: 42,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ReadAlert could not start',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.70),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ReadAlertApp extends StatelessWidget {
  final Stream<User?>? authStateChanges;

  const ReadAlertApp({super.key, this.authStateChanges});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'ReadAlert',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      // FIX #14: StreamBuilder on authStateChanges is the single place that
      // decides whether to show LoginScreen or MainScreen. When the user logs
      // out (from ProfileScreen or anywhere else), Firebase emits null here
      // and the whole navigator stack is replaced with LoginScreen
      // automatically — no manual Navigator.pushReplacement() needed anywhere.
      home: StreamBuilder<User?>(
        stream: authStateChanges ?? FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Still waiting for Firebase to respond
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFF0F172A),
              body: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF8B5CF6),
                  strokeWidth: 2,
                ),
              ),
            );
          }

          // Logged in → go to main app
          if (snapshot.hasData && snapshot.data != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              navigatorKey.currentState?.popUntil((route) => route.isFirst);
            });
            return const MainScreen();
          }

          // Logged out or never logged in → go to welcome
          return const WelcomeScreen();
        },
      ),
    );
  }
}

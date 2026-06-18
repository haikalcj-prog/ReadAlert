import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'services/notification_service.dart';
import 'services/level_up_service.dart';
// import 'firebase_options.dart'; // uncomment if using FlutterFire CLI

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    // options: DefaultFirebaseOptions.currentPlatform, // uncomment if using FlutterFire CLI
  );
  await NotificationService.initialize();
  LevelUpService.init(navigatorKey);
  runApp(const ReadAlertApp());
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
            return const MainScreen();
          }

          // Logged out or never logged in → go to login
          return const LoginScreen();
        },
      ),
    );
  }
}

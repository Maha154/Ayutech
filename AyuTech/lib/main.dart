// lib/main.dart
import 'dart:async';
import 'package:ayutech/screens/diet_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/app_store.dart';
import 'screens/dashboard_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/admin_home_page_all_in_one.dart';
import 'screens/staff_home_screen.dart';
import 'firebase_options.dart';
import 'screens/adminstaffs_page.dart';
import 'screens/admindoctors_page.dart';
import 'screens/adminbilling_patients_page.dart';
import 'screens/admin_reports_page.dart';

// add near other imports
import 'theme/app_theme.dart';

import 'screens/patient_report_screen.dart';
import 'lib/screens/diet_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize shared preferences (clinic info)
  Future<void> setupClinicInfo() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString("clinicName", "AyuTech Clinic");
    await sp.setString("clinicAddress", "Velachery");
    await sp.setString("clinicEmail", "doc@gmail.com");
    await sp.setString("clinicPhone", "7646178180");
  }

  await setupClinicInfo();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AppStore().init();

  runApp(const MyApp());
}

/// Strongly-typed arguments for PatientReportScreen navigation.
class PatientReportArgs {
  final String uid;
  final String name;
  final String age;
  final String gender;
  final List<String> initialConditions;
  final String previousHistory;
  final String region;
  final String allergy;
  final String phoneNumber;
  final DateTime startDate;
  final String? prakriti;
  final bool autoExport;

  PatientReportArgs({
    required this.uid,
    required this.name,
    required this.age,
    required this.gender,
    this.initialConditions = const <String>[],
    this.previousHistory = '',
    this.region = '',
    this.allergy = '',
    this.phoneNumber = '',
    DateTime? startDate,
    this.prakriti,
    this.autoExport = false,
    
  }) : startDate = startDate ?? DateTime.now();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AyuTech',
      debugShowCheckedModeBanner: false,
      // Keep your simple static routes (do NOT include a dummy patient_report route)
      routes: {
        '/admin/home': (_) => const AdminHomePageAllInOne(),
        '/doctor/home': (_) => const DashboardScreen(),
        '/staff/home': (_) => const StaffHomeScreen(),
        '/staffs': (_) => const StaffsPage(),
        '/doctors': (_) => const DoctorsPage(),
        '/billing': (_) => const AdminBillingPatientPage(),
        '/reports': (_) => const AdminReportsPage(),
        '/welcome': (_) => const WelcomeScreen(),
        
        '/diet-ai': (_) => const DietScreen(),

        // note: no '/patient_report' here
      },

      // Use onGenerateRoute for screens that require runtime data (PatientReportScreen)
      onGenerateRoute: (RouteSettings settings) {
        if (settings.name == '/patient_report') {
          final args = settings.arguments;
          if (args is PatientReportArgs) {
            return MaterialPageRoute(
              builder: (ctx) => PatientReportScreen(
                uid: args.uid,
                name: args.name,
                age: args.age,
                gender: args.gender,
                initialConditions: args.initialConditions,
                previousHistory: args.previousHistory,
                region: args.region,
                allergy: args.allergy,
                phoneNumber: args.phoneNumber,
                startDate: args.startDate,
                prakriti: args.prakriti,
                autoExport: args.autoExport,
              ),
            );
          } else {
            // If incorrect or missing args, send the user to a safe screen
            return MaterialPageRoute(builder: (_) => const WelcomeScreen());
          }
        }

        // let Flutter fall back to the routes map (or return null)
        return null;
      },

      home: const InitialScreen(),
    );
  }
}

class InitialScreen extends StatefulWidget {
  const InitialScreen({Key? key}) : super(key: key);

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen> {
  late final Future<Widget> _initialFuture;
  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();
    _initialFuture = _determineInitialWidget();

    // Auth listener (safe navigation)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      bool handling = false;

      _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
        if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) {
          debugPrint('AUTH_LISTENER: not current route or unmounted — ignoring auth event');
          return;
        }

        if (user == null || user.isAnonymous) {
          if (handling) return;
          handling = true;
          if (!mounted) {
            handling = false;
            return;
          }
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const WelcomeScreen()),
            (r) => false,
          );
          handling = false;
          return;
        }

        if (handling) return;
        handling = true;

        final role = await _getRoleWithRetry(user.uid, retries: 3, delayMillis: 350);
        debugPrint('AUTH_LISTENER: role lookup for uid=${user.uid} -> $role');

        if (!mounted) {
          handling = false;
          return;
        }

        if (role == 'admin') {
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AdminHomePageAllInOne()),
            (r) => false,
          );
        } else if (role == 'doctor') {
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
            (r) => false,
          );
        } else if (role == 'staff') {
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const StaffHomeScreen()),
            (r) => false,
          );
        } else {
          debugPrint('AUTH_LISTENER: unknown role for uid=${user.uid} — not navigating here.');
        }

        handling = false;
      });
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<String?> _getRole(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection("users").doc(uid).get();
      if (doc.exists) return doc.data()?['role'] as String?;
    } catch (e) {
      debugPrint('Error fetching role for $uid: $e');
    }
    return null;
  }

  Future<String?> _getRoleWithRetry(String uid, {int retries = 1, int delayMillis = 250}) async {
    String? role;
    for (var attempt = 0; attempt <= retries; attempt++) {
      role = await _getRole(uid);
      if (role != null) return role;
      if (attempt < retries) await Future.delayed(Duration(milliseconds: delayMillis));
    }
    return role;
  }

  Future<Widget> _determineInitialWidget() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return const WelcomeScreen();

    final role = await _getRoleWithRetry(user.uid, retries: 2, delayMillis: 300);
    if (role == 'admin') return const AdminHomePageAllInOne();
    if (role == 'doctor') return const DashboardScreen();
    if (role == 'staff') return const StaffHomeScreen();

    final r2 = await _getRoleWithRetry(user.uid, retries: 3, delayMillis: 350);
    debugPrint('AUTH-LISTENER: uid=${user.uid} role=$r2');
    return const WelcomeScreen();
  }

  Widget _loadingScaffold() => const Scaffold(body: Center(child: CircularProgressIndicator()));

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _initialFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return _loadingScaffold();
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Error starting app'),
                  const SizedBox(height: 8),
                  Text('${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: () => setState(() {}), child: const Text('Retry')),
                ],
              ),
            ),
          );
        }
        return snapshot.data!;
      },
    );
  }
}

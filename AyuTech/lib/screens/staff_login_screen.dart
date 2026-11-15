// lib/screens/staff_login_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'welcome_screen.dart';

// Use shared AyuColors palette
import 'package:ayutech/screens/staff_home_screen.dart';

class StaffLoginScreen extends StatefulWidget {
  const StaffLoginScreen({Key? key}) : super(key: key);

  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen>
    with TickerProviderStateMixin {
  final _staffId = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? error;

  late AnimationController _panelController;
  late AnimationController _logoController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // staff id pattern: "staff" + ddMMyyyy, e.g. staff15061990
  final RegExp _staffIdRegex = RegExp(r'^staff\d{8}$', caseSensitive: false);

  // alias domain used for staff auth emails (ensure this matches how auth accounts were created)
  static const String _aliasDomain = 'ayutech.local';

  @override
  void initState() {
    super.initState();
    _panelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _panelController, curve: Curves.easeInOutCubic),
    );

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(parent: _logoController, curve: Curves.easeIn);
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack));

    _panelController.forward().whenComplete(() => _logoController.forward());
  }

  @override
  void dispose() {
    _panelController.dispose();
    _logoController.dispose();
    _staffId.dispose();
    _password.dispose();
    super.dispose();
  }

  String _mapStaffIdToAuthEmail(String rawId) {
    final loginId = rawId.trim().toLowerCase();
    return '$loginId@$_aliasDomain';
  }

  bool _isValidStaffId(String raw) => _staffIdRegex.hasMatch(raw.trim());

  Future<void> _login() async {
    setState(() {
      _loading = true;
      error = null;
    });

    try {
      final input = _staffId.text.trim();
      if (input.isEmpty) {
        setState(() => error = 'Enter Staff ID');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter Staff ID')));
        return;
      }

      if (!_isValidStaffId(input)) {
        setState(() => error = 'Invalid Staff ID. Format: staffddMMyyyy (e.g. staff15061990)');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid Staff ID format')));
        return;
      }

      final authEmail = _mapStaffIdToAuthEmail(input);

      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: authEmail,
        password: _password.text,
      );

      final uid = cred.user?.uid;
      if (uid == null) {
        throw Exception("User ID not found after login");
      }

      // Get user role from Firestore
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final role = doc.exists ? (doc.data()?['role'] as String?) : null;

      if (!mounted) return;

      if (role == 'staff') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Staff login successful')),
        );

        Navigator.of(context).pushNamedAndRemoveUntil('/staff/home', (route) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access denied: This account is not registered as staff')),
        );
        await FirebaseAuth.instance.signOut();
      }
    } on FirebaseAuthException catch (e) {
      setState(() => error = e.message ?? 'Login failed');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: ${e.message}')),
      );
    } catch (e) {
      setState(() => error = 'Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goBackToWelcome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    const leftFlex = 52;
    const rightFlex = 48;

    return Scaffold(
      body: Container(
        // match app background
        color: AyuColors.bgBody,
        child: Stack(
          children: [
            // Back button (top-left)
            Positioned(
              top: 28,
              left: 16,
              child: IconButton(
                icon: Icon(Icons.arrow_back, size: 28, color: AyuColors.teal),
                tooltip: 'Back to Welcome',
                onPressed: _goBackToWelcome,
              ),
            ),

            Row(
              children: [
                // LEFT: form
                Expanded(
                  flex: leftFlex,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: _buildForm(),
                    ),
                  ),
                ),

                // RIGHT: green panel with logo
                Expanded(
                  flex: rightFlex,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: ClipPath(
                        clipper: MediumCurveClipper(),
                        child: Container(
                          color: AyuColors.teal,
                          child: Center(
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: ScaleTransition(
                                scale: _scaleAnimation,
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  width: 300,
                                  height: 300,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'STAFF LOGIN',
          style: TextStyle(
            fontSize: 40,
            fontFamily: 'Jomolhari',
            fontWeight: FontWeight.w400,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 40),
        TextField(
          controller: _staffId,
          decoration: _inputDecoration('Staff ID (e.g. staff15061990)'),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter Staff ID only. Format: staff followed by date of birth ddMMyyyy (example: staff15061990).',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _password,
          obscureText: true,
          decoration: _inputDecoration('Password'),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () async {
            final input = _staffId.text.trim();
            if (input.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Enter Staff ID first')),
              );
              return;
            }
            if (!_isValidStaffId(input)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invalid Staff ID format')),
              );
              return;
            }
            final authEmail = _mapStaffIdToAuthEmail(input);
            try {
              await FirebaseAuth.instance.sendPasswordResetEmail(email: authEmail);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Password reset email sent')),
              );
            } on FirebaseAuthException catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Could not send reset: ${e.message}')),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            }
          },
          child: Text(
            'Forgot Password?',
            style: TextStyle(
              color: AyuColors.teal,
              fontSize: 16,
              fontFamily: 'Jomolhari',
            ),
          ),
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: _loading ? null : _login,
            style: ElevatedButton.styleFrom(
              backgroundColor: AyuColors.teal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _loading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'LOGIN',
                    style: TextStyle(
                      fontSize: 20,
                      fontFamily: 'Jomolhari',
                      fontWeight: FontWeight.w400,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 10),
          Text(
            error!,
            style: const TextStyle(color: Colors.red),
          ),
        ],
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
    );
  }
}

class MediumCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(size.width * 0.22, 0);
    path.quadraticBezierTo(
      size.width * 0.05,
      size.height / 2,
      size.width * 0.22,
      size.height,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

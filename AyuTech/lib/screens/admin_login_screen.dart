// lib/screens/admin_login_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'welcome_screen.dart'; // back button target

// IMPORTANT: do NOT import the admin home page here to avoid circular imports.
// Use named routes (defined in main.dart) to navigate instead.

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({Key? key}) : super(key: key);

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen>
    with TickerProviderStateMixin {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _loading = false;
  bool _showResetFields = false;
  String? error;

  late final AnimationController _panelController;
  late final AnimationController _logoController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _panelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _panelController, curve: Curves.easeInOutCubic));

    _logoController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation = CurvedAnimation(parent: _logoController, curve: Curves.easeIn);
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );

    _panelController.forward().whenComplete(() => _logoController.forward());
  }

  @override
  void dispose() {
    _panelController.dispose();
    _logoController.dispose();
    _email.dispose();
    _password.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  String _genPassword([int len = 12]) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@#\$%';
    final rnd = Random.secure();
    return List.generate(len, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  /// Robust login flow:
  /// - sign in
  /// - read users/{uid}.role
  /// - navigate using named route '/admin/home' to avoid circular imports
  Future<void> _login() async {
    setState(() {
      _loading = true;
      error = null;
    });

    try {
      // debug: show what is being attempted (not password)
      // ignore: avoid_print
      print('DEBUG_LOGIN: Attempting signIn with email=${_email.text.trim()}');

      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );

      // --- SAFER BLOCK START (replaces previous uid/role/nav logic) ---
      final uid = cred.user?.uid;
      final authEmail = cred.user?.email;
      debugPrint('DEBUG_LOGIN: signIn returned uid=$uid isAnonymous=${cred.user?.isAnonymous} email=$authEmail');

      if (uid == null) throw Exception('Missing uid after sign-in');

      // fetch user doc role
      DocumentSnapshot userDoc;
      try {
        userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      } catch (e) {
        debugPrint('DEBUG_LOGIN: Firestore read error for users/$uid -> $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not read user role: $e')));
        }
        await FirebaseAuth.instance.signOut();
        return;
      }

      if (!mounted) {
        debugPrint('DEBUG_LOGIN: widget unmounted after fetching userDoc — aborting');
        await FirebaseAuth.instance.signOut();
        return;
      }

      final data = userDoc.data();
      final role = (data is Map<String, dynamic>) ? (data['role'] as String?) : null;
      final firestoreEmail = (data is Map<String, dynamic>) ? (data['email'] as String?) : null;

      debugPrint('ADMIN_LOGIN: uid=$uid role=$role authEmail=$authEmail firestoreEmail=$firestoreEmail');

      if (!mounted) return;

      // safe to use context now (we checked), show snack
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login successful — role: ${role ?? 'null'}')),
      );

      if (!mounted) return;

      if (role == 'admin') {
        // navigate via root navigator
        Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil('/admin/home', (route) => false);
        return;
      }

      // non-admin handling: show the existing access-denied dialog (keeps original messaging)
      final msg = role != null
          ? 'Logged in but role is "$role". Admin access denied.'
          : 'This account has no role assigned. Contact admin.';

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Access denied'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(msg),
              const SizedBox(height: 12),
              Text('uid: $uid', style: const TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 6),
              Text('role (from Firestore): ${role ?? 'null'}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 6),
              const Text('If you expected admin access, ensure users/{uid}.role == "admin" in Firestore.'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
          ],
        ),
      );

      await FirebaseAuth.instance.signOut();
      debugPrint('DEBUG_LOGIN: signOut() called due to non-admin role or missing role.');
      // --- SAFER BLOCK END ---
    } on FirebaseAuthException catch (e) {
      setState(() => error = e.message ?? 'Login failed');
      // ignore: avoid_print
      print('DEBUG_LOGIN: FirebaseAuthException: ${e.code} ${e.message}');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login failed: ${e.message}')));
    } catch (e) {
      setState(() => error = 'Error: $e');
      // ignore: avoid_print
      print('DEBUG_LOGIN: Exception: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createDefaultAdmin() async {
    setState(() => _loading = true);
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final email = 'admin_default_$ts@ayutech.local';
      final password = _genPassword(12);

      final userCred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      final uid = userCred.user!.uid;

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'name': 'Default Admin',
        'email': email,
        'role': 'admin',
        'institution': 'Default',
        'phone': '',
        'username': 'admin_default_$ts',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Default admin created'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Email: $email'),
            const SizedBox(height: 6),
            Text('Password: $password'),
            const SizedBox(height: 8),
            const Text('Save these credentials.'),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error creating admin: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleResetFields() {
    setState(() {
      _showResetFields = !_showResetFields;
      error = null;
      _newPassword.clear();
      _confirmPassword.clear();
    });
  }

  Future<void> _setNewPassword() async {
    final newPass = _newPassword.text.trim();
    final conf = _confirmPassword.text.trim();

    if (newPass.isEmpty || conf.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill both fields')));
      return;
    }
    if (newPass != conf) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }
    if (newPass.length < 6) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password must be at least 6 characters')));
      return;
    }

    setState(() => _loading = true);
    final currentUser = FirebaseAuth.instance.currentUser;

    try {
      if (currentUser != null) {
        await currentUser.updatePassword(newPass);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully')));
        setState(() => _showResetFields = false);
      } else {
        if (_email.text.trim().isEmpty) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter email to send reset link')));
        } else {
          await FirebaseAuth.instance.sendPasswordResetEmail(email: _email.text.trim());
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset email sent. Check your inbox.')));
          setState(() => _showResetFields = false);
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
    final screenWidth = MediaQuery.of(context).size.width;
    final leftFlex = 45;
    final rightFlex = 55;

return Scaffold(
  body: Stack(
    children: [
      // Main content
      Positioned.fill(
        child: Container(
          color: const Color(0xFFFAFAF8),
          width: double.infinity,
          height: double.infinity,
          child: Row(
            children: [
              // LEFT
              Expanded(
                flex: leftFlex,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.03.clamp(0.0, 48.0),
                      ),
                      child: _showResetFields
                          ? _buildResetForm()
                          : _buildLoginForm(),
                    ),
                  ),
                ),
              ),

              // RIGHT
              Expanded(
                flex: rightFlex,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: ClipPath(
                      clipper: MediumCurveClipper(),
                      child: Container(
                        color: const Color(0xFF2F5C56),
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
        ),
      ),

      // ✅ BACK BUTTON — MUST BE LAST
      Positioned(
        top: 16,
        left: 16,
        child: SafeArea(
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back,
              size: 28,
              color: Color(0xFF3A6631),
            ),
            tooltip: 'Back to Welcome',
            onPressed: _goBackToWelcome,
          ),
        ),
      ),
    ],
  ),
);

  }

  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'ADMIN LOGIN',
          style: TextStyle(
            fontSize: 40,
            fontFamily: 'Jomolhari',
            fontWeight: FontWeight.w400,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 40),
        TextField(controller: _email, decoration: _inDecoration('Email/Username')),
        const SizedBox(height: 20),
        TextField(controller: _password, obscureText: true, decoration: _inDecoration('Password')),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _toggleResetFields,
          child: const Text(
            'Forgot Password?',
            style: TextStyle(
              color: Color(0xFF466643), // matched link color from welcome_screen
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
              backgroundColor: const Color(0xFF2F5C56), // primary button color matched to welcome
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _loading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'LOGIN',
                    style: TextStyle(
                      fontSize: 20,
                      fontFamily: 'Jomolhari',
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 10),
          Text(error!, style: const TextStyle(color: Colors.red, fontSize: 14)),
        ],
      ],
    );
  }

  Widget _buildResetForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'RESET PASSWORD',
          style: TextStyle(
            fontSize: 36,
            fontFamily: 'Jomolhari',
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 24),
        TextField(controller: _email, decoration: _inDecoration('Email')),
        const SizedBox(height: 12),
        TextField(controller: _newPassword, obscureText: true, decoration: _inDecoration('New password')),
        const SizedBox(height: 12),
        TextField(controller: _confirmPassword, obscureText: true, decoration: _inDecoration('Confirm password')),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _loading ? null : _setNewPassword,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2F5C56)), // matched
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white))
                    : const Text('Set Password'),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: _toggleResetFields,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 14),
                child: Text('Cancel'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  InputDecoration _inDecoration(String hint) => InputDecoration(
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
      );
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

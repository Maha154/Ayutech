// lib/screens/admin_page.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_signup_screen.dart'; // navigate to signup
import '../utils/slide_page_route.dart'; // slide navigation used elsewhere
import 'welcome_screen.dart';


class AdminPage extends StatefulWidget {
  const AdminPage({Key? key}) : super(key: key);

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> with TickerProviderStateMixin {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? error;

  late AnimationController _panelController;
  late AnimationController _logoController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _panelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _panelController, curve: Curves.easeInOutCubic));

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
    super.dispose();
  }

  String _genPassword([int len = 12]) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@#\$%';
    final rnd = Random.secure();
    return List.generate(len, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      error = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login successful')));
        Navigator.of(context).pop(); // or navigate to admin dashboard
      }
    } on FirebaseAuthException catch (e) {
      setState(() => error = e.message ?? 'Login failed');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login failed: ${e.message}')));
    } catch (e) {
      setState(() => error = 'Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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

  Future<void> _createDefaultAdmin() async {
    setState(() => _loading = true);
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final email = 'admin_default_$ts@ayutech.local';
      final password = _genPassword(12);

      final userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
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
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
        ),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error creating default admin: ${e.message}')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_email.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter email first')));
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _email.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset email sent')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _openSignup() {
    Navigator.push(
      context,
      SlidePageRoute(page: const AdminSignupScreen(), fromLeft: true),
    );
  }

 void _backToWelcome() {
  Navigator.pushReplacement(
    context,
    SlidePageRoute(page: const WelcomeScreen(), fromLeft: true),
  );
}


  @override
  Widget build(BuildContext context) {
    final rightPanelWidth = MediaQuery.of(context).size.width * 0.55;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFFFAFAF8),

        child: Stack(
          children: [
            // BACK button — top-left
          Positioned(
  top: 28,
  left: 16,
  child: IconButton(
    icon: const Icon(
      Icons.arrow_back,
      size: 28,
      color: Color(0xFF2F5C56),

    ),
    tooltip: 'Back to Welcome',
    onPressed: _goBackToWelcome,
  ),
),


            // Right panel with green curve and logo
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ClipPath(
                    clipper: MediumCurveClipper(),
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.55,
                      color: const Color(0xFF2F5C56),

                      child: Center(
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: ScaleTransition(
                            scale: _scale_animation_safe(),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset('assets/images/logo.png',
                                    width: 300, height: 300, color: Colors.white),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Left side content
            Positioned(
              top: 140,
              left: 120,
              child: SizedBox(
                width: 520,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ADMIN LOGIN',
                      style: TextStyle(
                        fontSize: 30,
                        fontFamily: 'Jomolhari',
                        fontWeight: FontWeight.w400,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 24),

                    _roundedField(controller: _email, hint: 'Email/Username'),
                    const SizedBox(height: 20),
                    _roundedField(controller: _password, hint: 'Password', obscure: true),

                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _resetPassword,
                      child: const Text(
                        "Forgot Password?",
                        style: TextStyle(
                          color: const Color(0xFF2F5C56),

                          fontSize: 16,
                          fontFamily: "Jomolhari",
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    SizedBox(
                      width: 480,
                      height: 64,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3A6631),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                        ),
                        child: _loading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                'LOGIN',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontFamily: 'Jomolhari',
                                  color: Color(0xFF9A6EE3),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    SizedBox(
                      width: 320,
                      child: OutlinedButton(
                        onPressed: _loading ? null : _createDefaultAdmin,
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          side: const BorderSide(color: Color(0xFF8A7B9E)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Generate default admin credentials'),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // SIGNUP link like your login page (inline text)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don’t have an account?",
                          style: TextStyle(
                            fontSize: 16,
                            fontFamily: "Jomolhari",
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: _openSignup,
                          child: const Text(
                            "Sign Up",
                            style: TextStyle(
                              fontSize: 16,
                              fontFamily: "Jomolhari",
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF466643),
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(error!, style: const TextStyle(color: Colors.red)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // helper to avoid non-nullable access in the widget tree
  Animation<double> _scale_animation_safe() => _scaleAnimation;

  Widget _roundedField({required TextEditingController controller, required String hint, bool obscure = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(40)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(40),
          borderSide: const BorderSide(color: Color(0xFFBDB0BC)),
        ),
      ),
    );
  }
}

/// Clipper used in the design
class MediumCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(size.width * 0.22, 0);
    path.quadraticBezierTo(size.width * 0.05, size.height / 2, size.width * 0.22, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

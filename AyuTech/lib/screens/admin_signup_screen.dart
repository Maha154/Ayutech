// lib/screens/admin_signup_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_page.dart'; // for back navigation
import '../utils/slide_page_route.dart'; // smooth slide transition
import 'admin_home_page_all_in_one.dart';

class AdminSignupScreen extends StatefulWidget {
  const AdminSignupScreen({Key? key}) : super(key: key);

  @override
  State<AdminSignupScreen> createState() => _AdminSignupScreenState();
}

class _AdminSignupScreenState extends State<AdminSignupScreen>
    with TickerProviderStateMixin {
  final _institution = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _contact = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  late final AnimationController _panelCtrl;
  late final AnimationController _logoCtrl;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _panelCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _slideAnim = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _panelCtrl, curve: Curves.easeInOut));

    _logoCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeIn);
    _scaleAnim = Tween<double>(begin: 0.9, end: 1.0)
        .animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutBack));

    _panelCtrl.forward().whenComplete(() => _logoCtrl.forward());
  }

  @override
  void dispose() {
    _panelCtrl.dispose();
    _logoCtrl.dispose();
    _institution.dispose();
    _name.dispose();
    _email.dispose();
    _contact.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _createAdmin() async {
    if (_email.text.trim().isEmpty ||
        _name.text.trim().isEmpty ||
        _password.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final email = _email.text.trim();
      final username = _username.text.trim().isNotEmpty
          ? _username.text.trim()
          : email.split('@').first;
      final password = _password.text.trim();

      // create user in Firebase Auth
      final uc = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      final uid = uc.user!.uid;

      // add user doc in Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'name': _name.text.trim(),
        'email': email,
        'role': 'admin',
        'institution': _institution.text.trim(),
        'phone': _contact.text.trim(),
        'username': username,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // verify write (temporary debug info)
      final verify =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      // debug console info — remove later if you want
      // ignore: avoid_print
      print('DEBUG: admin signup wrote doc exists=${verify.exists} data=${verify.data()}');

      // navigate only if widget still mounted
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/admin/home', (route) => false);
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Signup error: ${e.message}')),
      );
    } on FirebaseException catch (e) {
      // Firestore-specific error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Database error: ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unexpected error: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goBack() {
    Navigator.pushReplacement(
      context,
      SlidePageRoute(page: const AdminPage(), fromLeft: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFFF1EFE0),
        child: Stack(
          children: [
            // ✅ Back button at top-left
            Positioned(
              top: 40,
              left: 40,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, size: 30, color: Color(0xFF3A6631)),
                onPressed: _goBack,
              ),
            ),

            // Right green logo panel
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: SlideTransition(
                  position: _slideAnim,
                  child: ClipPath(
                    clipper: MediumCurveClipper(),
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.55,
                      color: const Color(0xFF466643),
                      child: Center(
                        child: FadeTransition(
                          opacity: _fadeAnim,
                          child: ScaleTransition(
                            scale: _scaleAnim,
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

            // Left signup form
            Positioned(
              top: 110,
              left: 120,
              child: SizedBox(
                width: 460,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ADMIN SIGNUP',
                        style: TextStyle(
                            fontSize: 36,
                            fontFamily: 'Jomolhari',
                            fontWeight: FontWeight.w400)),
                    const SizedBox(height: 26),
                    TextField(
                        controller: _institution,
                        decoration: _inDecoration('Institution name')),
                    const SizedBox(height: 12),
                    TextField(controller: _name, decoration: _inDecoration('Full name')),
                    const SizedBox(height: 12),
                    TextField(controller: _email, decoration: _inDecoration('Official email id')),
                    const SizedBox(height: 12),
                    TextField(controller: _contact, decoration: _inDecoration('Contact number')),
                    const SizedBox(height: 12),
                    TextField(controller: _username, decoration: _inDecoration('Username (optional)')),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        hintText: 'Set your password',
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _createAdmin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3A6631),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: _loading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                'Create Admin',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontFamily: 'Jomolhari',
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
    path.quadraticBezierTo(size.width * 0.05, size.height / 2, size.width * 0.22, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

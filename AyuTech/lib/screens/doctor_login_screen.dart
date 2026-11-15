// lib/screens/doctor_login_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ayutech/screens/welcome_screen.dart';

// Use the shared AyuColors palette
import 'package:ayutech/screens/staff_home_screen.dart';

class DoctorLoginScreen extends StatefulWidget {
  const DoctorLoginScreen({Key? key}) : super(key: key);

  @override
  State<DoctorLoginScreen> createState() => _DoctorLoginScreenState();
}

class _DoctorLoginScreenState extends State<DoctorLoginScreen>
    with TickerProviderStateMixin {
  final _doctorId = TextEditingController();
  final _password = TextEditingController();

  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _loading = false;
  bool _showResetFields = false;
  String? error;

  late AnimationController _panelController;
  late AnimationController _logoController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // Doctor login id pattern: 2 letters + 8 digits (ddMMyyyy) e.g. AB15061990
  final RegExp _doctorIdRegex = RegExp(r'^[A-Za-z]{2}\d{8}$');

  // Domain used for doctor login alias (must match how accounts were created)
  static const String _doctorAliasDomain = 'ayutech.local';

  @override
  void initState() {
    super.initState();

    _panelController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _slideAnimation = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _panelController, curve: Curves.easeInOutCubic));

    _logo_controller_init();
    _panelController.forward().whenComplete(() => _logoController.forward());
  }

  void _logo_controller_init() {
    _logoController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation = CurvedAnimation(parent: _logoController, curve: Curves.easeIn);
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack));
  }

  @override
  void dispose() {
    _panelController.dispose();
    _logoController.dispose();
    _doctorId.dispose();
    _password.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  String _mapDoctorIdToAuthEmail(String rawId) {
    final loginId = rawId.trim().toLowerCase();
    return '$loginId@$_doctorAliasDomain';
  }

  bool _isValidDoctorId(String raw) => _doctorIdRegex.hasMatch(raw.trim());

  // ---------- LOGIN: authenticate + role check ----------
  Future<void> _login() async {
    setState(() {
      _loading = true;
      error = null;
    });

    try {
      final input = _doctorId.text.trim();
      if (input.isEmpty) {
        setState(() => error = 'Enter Doctor ID');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter Doctor ID')));
        return;
      }

      if (!_isValidDoctorId(input)) {
        setState(() => error = 'Invalid Doctor ID. Format: 2 letters + ddMMyyyy (e.g. AB15061990)');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid Doctor ID format')));
        return;
      }

      final authEmail = _mapDoctorIdToAuthEmail(input);

      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: authEmail,
        password: _password.text,
      );

      final uid = cred.user?.uid;
      if (uid == null) throw Exception("User ID not found after login");

      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final role = doc.exists ? (doc.data()?['role'] as String?) : null;

      if (!mounted) return;

      if (role == 'doctor') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Doctor login successful')),
        );
        // make sure this named route exists in main.dart
        Navigator.of(context).pushNamedAndRemoveUntil('/doctor/home', (route) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access denied: This account is not registered as a doctor')),
        );
        await FirebaseAuth.instance.signOut();
      }
    } on FirebaseAuthException catch (e) {
      setState(() => error = e.message ?? 'Login failed');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login failed: ${e.message}')));
    } catch (e) {
      setState(() => error = 'Error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goBackToWelcome() {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WelcomeScreen()));
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
        // User is currently signed-in: update password directly
        await currentUser.updatePassword(newPass);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully')));
        setState(() => _showResetFields = false);
      } else {
        // Not signed in: send password reset email to mapped address
        final input = _doctorId.text.trim();
        if (input.isEmpty) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter your Doctor ID to send reset link')));
        } else {
          if (!_isValidDoctorId(input)) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid Doctor ID format')));
          } else {
            final authEmail = _mapDoctorIdToAuthEmail(input);
            await FirebaseAuth.instance.sendPasswordResetEmail(email: authEmail);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset email sent. Check your inbox.')));
            setState(() => _showResetFields = false);
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      var message = e.message ?? 'Could not update password';
      if (e.code == 'requires-recent-login') {
        message = 'Please login again and try changing password (for security).';
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const leftFlex = 52;
    const rightFlex = 48;

    return Scaffold(
      body: Container(
        // use AyuColors background to match app theme
        color: AyuColors.bgBody,
        child: Stack(
          children: [
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
                Expanded(
                  flex: leftFlex,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: _showResetFields ? _buildResetForm() : _buildLoginForm(),
                    ),
                  ),
                ),
                Expanded(
                  flex: rightFlex,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: ClipPath(
                        clipper: MediumCurveClipper(),
                        child: Container(
                          width: double.infinity,
                          // right panel uses the primary teal from AyuColors
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

  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'DOCTOR LOGIN',
          style: TextStyle(
            fontSize: 40,
            fontFamily: 'Jomolhari',
            fontWeight: FontWeight.w400,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 40),
        TextField(
          controller: _doctorId,
          decoration: _inputDecoration('Doctor ID (e.g. AB15061990)'),
          keyboardType: TextInputType.text,
          autofillHints: const [AutofillHints.username],
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter Doctor ID only. Format: 2 letters followed by date of birth ddMMyyyy (example: AB15061990).',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 12),
        TextField(controller: _password, obscureText: true, decoration: _inputDecoration('Password')),
        const SizedBox(height: 12),
        GestureDetector(onTap: _toggleResetFields, child: Text('Forgot Password?', style: TextStyle(color: AyuColors.teal, fontSize: 16, fontFamily: 'Jomolhari'))),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: _loading ? null : _login,
            style: ElevatedButton.styleFrom(
              backgroundColor: AyuColors.teal,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('LOGIN', style: TextStyle(fontSize: 20, fontFamily: 'Jomolhari', fontWeight: FontWeight.w400, color: Colors.white)),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 10),
          Text(error!, style: const TextStyle(color: Colors.red)),
        ],
      ],
    );
  }

  Widget _buildResetForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('RESET PASSWORD', style: TextStyle(fontSize: 36, fontFamily: 'Jomolhari', fontWeight: FontWeight.w500, color: Colors.black)),
        const SizedBox(height: 24),
        TextField(controller: _doctorId, decoration: _inputDecoration('Doctor ID (e.g. AB15061990)')),
        const SizedBox(height: 12),
        TextField(controller: _newPassword, obscureText: true, decoration: _inputDecoration('New password')),
        const SizedBox(height: 12),
        TextField(controller: _confirmPassword, obscureText: true, decoration: _inputDecoration('Confirm password')),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _loading ? null : _setNewPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AyuColors.teal,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white)) : const Text('Set Password'),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: _toggleResetFields,
              style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Padding(padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 14), child: Text('Cancel')),
            ),
          ],
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(hintText: hint, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)));
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

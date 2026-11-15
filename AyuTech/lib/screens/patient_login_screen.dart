// lib/screens/patient_login_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'welcome_screen.dart';
import 'patient_home_page.dart';
import 'set_credentials_screen.dart';

// Use shared AyuColors palette (same file where palette is defined)
import 'package:ayutech/screens/staff_home_screen.dart';

class PatientLoginScreen extends StatefulWidget {
  const PatientLoginScreen({Key? key}) : super(key: key);

  @override
  State<PatientLoginScreen> createState() => _PatientLoginScreenState();
}

class _PatientLoginScreenState extends State<PatientLoginScreen>
    with TickerProviderStateMixin {
  final TextEditingController _patientIdController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _credentialsExist = false; // toggles UI to show username+password
  String? _patientIdChecked; // patientId (human-readable) that was validated in Firestore
  String? _patientDocId; // Firestore auto doc id for the found patient doc
  String? _usernameFromDoc; // username value fetched from Firestore

  // Animation controllers (kept from your original)
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
      duration: const Duration(milliseconds: 900),
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

    _fadeAnimation =
        CurvedAnimation(parent: _logoController, curve: Curves.easeIn);
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );

    _panelController.forward().whenComplete(() => _logoController.forward());

    // Ensure Firebase auth is available (anonymous sign-in if needed)
    // This preserves your Firestore rules that require request.auth != null
    _initAuth();
  }

  @override
  void dispose() {
    _panelController.dispose();
    _logoController.dispose();
    _patientIdController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Called from initState to perform async auth setup
  Future<void> _initAuth() async {
    try {
      await _ensureSignedInAnonymously();
      debugPrint('Auth ready: ${FirebaseAuth.instance.currentUser?.uid}');
    } catch (e) {
      debugPrint('Auth init failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Authentication setup failed: $e')),
        );
      }
    }
  }

  // Ensure client is signed in. Keeps your Firestore rules requiring auth intact.
  Future<void> _ensureSignedInAnonymously() async {
    final auth = FirebaseAuth.instance;
    try {
      if (auth.currentUser == null) {
        final cred = await auth.signInAnonymously();
        debugPrint('Signed in anonymously: ${cred.user?.uid}');
      } else {
        debugPrint('Already signed in: ${auth.currentUser?.uid}');
      }
    } catch (e) {
      debugPrint('Anonymous sign-in failed: $e');
      rethrow;
    }
  }

  void _goBackToWelcome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
    );
  }

  String _emailFromPatientId(String pid) =>
      '${pid.trim().toLowerCase()}@ayutech.local';

  /// First step: verify patient ID and decide whether to prompt to set credentials
  /// or show username+password. Important: your staff-created patient docs keep the
  /// human patientId inside a field called 'patientId', so we query the collection.
  Future<void> _verifyPatientId() async {
    final patientIdInput = _patientIdController.text.trim();
    if (patientIdInput.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please enter your Patient ID')));
      return;
    }

    setState(() => _loading = true);

    try {
      // Query by the patientId field (your docs use auto doc IDs)
      final q = await FirebaseFirestore.instance
          .collection('patients')
          .where('patientId', isEqualTo: patientIdInput)
          .limit(1)
          .get();

      if (q.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Patient ID not found. Please check with staff.')),
          );
        }
        setState(() {
          _credentialsExist = false;
          _patientIdChecked = null;
          _patientDocId = null;
          _usernameFromDoc = null;
          _usernameController.clear();
        });
        return;
      }

      final doc = q.docs.first;
      final data = doc.data();
      final credentialsSet = (data['credentialsSet'] == true);

      if (!credentialsSet) {
        // First-time flow: go to set credentials screen
        if (!mounted) return;

        // NOTE: SetCredentialsScreen currently expects patientId (string).
        // If you update SetCredentialsScreen to also accept patientDocId, pass it here:
        // Navigator.push(..., MaterialPageRoute(builder: (_) => SetCredentialsScreen(patientId: patientIdInput, patientDocId: doc.id)));
        // new — pass both patientDocId and patientId
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SetCredentialsScreen(
              patientDocId: doc.id,      // Firestore auto doc id
              patientId: patientIdInput, // human patient id like snj0001
            ),
          ),
        );

        // Clear UI state after navigation
        setState(() {
          _credentialsExist = false;
          _patientIdChecked = null;
          _patientDocId = null;
          _usernameFromDoc = null;
          _usernameController.clear();
          _passwordController.clear();
        });
        return;
      }

      // Credentials exist -> show username (read-only, prefilled) and password field
      final username = (data['username'] ?? '') as String;
      setState(() {
        _credentialsExist = true;
        _patientIdChecked = patientIdInput;
        _patientDocId = doc.id; // store the Firestore document id
        _usernameFromDoc = username;
        _usernameController.text = username;
        _passwordController.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Credentials found. Enter your password to sign in.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error checking Patient ID: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Sign in using the password and validate username matches the stored one
  Future<void> _signInWithPassword() async {
    if (_patientIdChecked == null || _patientDocId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please verify Patient ID first')));
      return;
    }

    final password = _passwordController.text;
    if (password.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter your password')));
      return;
    }

    // ensure we have usernameFromDoc
    if (_usernameFromDoc == null || _usernameFromDoc!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Username missing in record — contact staff.')));
      return;
    }

    setState(() => _loading = true);

    try {
      // re-fetch the patient doc by its Firestore auto-id (safer)
      final docSnap = await FirebaseFirestore.instance
          .collection('patients')
          .doc(_patientDocId!)
          .get();
      if (!docSnap.exists) throw 'Patient record disappeared.';

      final data = docSnap.data()!;
      final storedUsername = (data['username'] ?? '') as String;

      if (storedUsername != _usernameController.text.trim()) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Username mismatch. Please contact staff.')));
        return;
      }

      final email = _emailFromPatientId(_patientIdChecked!);

      // Sign in with synthetic email and password
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      // on success navigate to home
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => PatientHomePage(patientId: _patientIdChecked!)),
      );
    } on FirebaseAuthException catch (fae) {
      String err;
      if (fae.code == 'user-not-found') {
        err = 'No account found for this patient. Please set credentials first.';
      } else if (fae.code == 'wrong-password') {
        err = 'Incorrect password';
      } else {
        err = fae.message ?? fae.code;
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Sign in failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'PATIENT LOGIN',
            style: TextStyle(
              fontSize: 34,
              fontFamily: 'Jomolhari',
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Enter your unique Patient ID to continue',
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 28),
          TextFormField(
            controller: _patientIdController,
            decoration: _inputDecoration('Patient ID'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your Patient ID' : null,
            enabled: !_loading && !_credentialsExist, // disable editing patient id while in credentials stage
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 18),

          // If credentials exist for this patientId: show username (prefilled, read-only) and password
          if (_credentialsExist) ...[
            TextFormField(
              controller: _usernameController,
              decoration: _inputDecoration('Username'),
              enabled: false, // read-only because username is chosen earlier by patient
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              decoration: _inputDecoration('Password'),
              obscureText: true,
              enabled: !_loading,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _signInWithPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AyuColors.teal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text(
                        'SIGN IN',
                        style: TextStyle(fontSize: 18, fontFamily: 'Jomolhari', fontWeight: FontWeight.w600, color: Colors.white),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                // allow the user to re-verify a different patient ID
                setState(() {
                  _credentialsExist = false;
                  _patientIdChecked = null;
                  _patientDocId = null;
                  _usernameFromDoc = null;
                  _usernameController.clear();
                  _passwordController.clear();
                });
              },
              child: const Text('Use another Patient ID'),
            ),
          ] else ...[
            // First-time or not-verified state: show continue button to verify patient id
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _verifyPatientId,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AyuColors.teal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text(
                        'CONTINUE',
                        style: TextStyle(fontSize: 18, fontFamily: 'Jomolhari', fontWeight: FontWeight.w600, color: Colors.white),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide(color: AyuColors.teal),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const leftFlex = 52;
    const rightFlex = 48;
    final screenW = MediaQuery.of(context).size.width;
    final rightPanelWidth = screenW * 0.48;

    return Scaffold(
      backgroundColor: AyuColors.bgBody,
      body: SafeArea(
        child: Stack(
          children: [
            // Back button
            Positioned(
              top: 16,
              left: 12,
              child: IconButton(
                icon: Icon(Icons.arrow_back, size: 28, color: AyuColors.teal),
                tooltip: 'Back to Welcome',
                onPressed: _goBackToWelcome,
              ),
            ),

            Row(
              children: [
                // LEFT: login form
                Expanded(
                  flex: leftFlex,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Card(
                        elevation: 6,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                          child: _buildForm(),
                        ),
                      ),
                    ),
                  ),
                ),

                // RIGHT: logo panel (unchanged visually, now uses AyuColors)
                Expanded(
                  flex: rightFlex,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: ClipPath(
                        clipper: MediumCurveClipper(),
                        child: Container(
                          width: rightPanelWidth,
                          color: AyuColors.teal,
                          child: Center(
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: ScaleTransition(
                                scale: _scaleAnimation,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.asset(
                                      'assets/images/logo.png',
                                      width: 260,
                                      height: 260,
                                      color: Colors.white,
                                      fit: BoxFit.contain,
                                    ),
                                    const SizedBox(height: 12),
                                    const Text('Herbal Health Solutions', style: TextStyle(color: Colors.white70)),
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Curved green side panel
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

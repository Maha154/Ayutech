// lib/screens/set_credentials_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'patient_home_page.dart';

class SetCredentialsScreen extends StatefulWidget {
  final String patientDocId; // Firestore auto doc id
  final String patientId; // human id e.g. snj0001

  const SetCredentialsScreen({
    Key? key,
    required this.patientDocId,
    required this.patientId,
  }) : super(key: key);

  @override
  State<SetCredentialsScreen> createState() => _SetCredentialsScreenState();
}

class _SetCredentialsScreenState extends State<SetCredentialsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;

  String _emailFromPatientId(String pid) =>
      '${pid.trim().toLowerCase()}@ayutech.local';

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  /// Returns true if username is already taken by another patient doc.
  /// Allows the same username if it already belongs to THIS patient document.
  Future<bool> _isUsernameTaken(String username) async {
    final q = await FirebaseFirestore.instance
        .collection('patients')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();

    if (q.docs.isEmpty) return false;
    final foundDoc = q.docs.first;
    // If the found doc is this patient doc, treat it as available (re-using own username).
    if (foundDoc.id == widget.patientDocId) return false;
    return true;
  }

  Future<void> _sendPasswordResetIfRealEmailExists(String realEmail) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: realEmail);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Password reset email sent to your registered email.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to send reset email: $e')));
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // canonicalize username: trimmed and lowercase (optional but recommended)
    final username = _usernameCtrl.text.trim().toLowerCase();
    final password = _passwordCtrl.text;

    setState(() => _loading = true);

    try {
      // 1) Check username availability
      final taken = await _isUsernameTaken(username);
      if (taken) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Username already taken. Choose another.')),
          );
        }
        return;
      }

      final email = _emailFromPatientId(widget.patientId);

      // 2) Create Firebase Auth user (synthetic email)
      UserCredential? createdUser;
      try {
        createdUser = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);
      } on FirebaseAuthException catch (fae) {
        if (fae.code == 'email-already-in-use') {
          // If an auth user already exists for this patientId:
          final docSnap = await FirebaseFirestore.instance
              .collection('patients')
              .doc(widget.patientDocId)
              .get();
          final data = docSnap.data() ?? {};
          final realEmail = (data['email'] as String?)?.trim();
          if (realEmail != null && realEmail.isNotEmpty) {
            final accept = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Account already exists'),
                content: Text(
                    'An account was already created for this Patient ID. We can send a password reset to $realEmail. Send reset email?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
                ],
              ),
            );
            if (accept == true) await _sendPasswordResetIfRealEmailExists(realEmail);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please check your email for reset instructions.')),
              );
            }
            return;
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Account already exists. Contact staff for help.')),
              );
            }
            return;
          }
        } else if (fae.code == 'weak-password') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Password is too weak. Use at least 6 characters.')),
            );
          }
          return;
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('Auth error: ${fae.message ?? fae.code}')));
          }
          return;
        }
      }

      // 3) Determine authUid
      String? authUid = createdUser?.user?.uid;
      if (authUid == null) {
        // Fallback: try signing in (if createUser didn't sign in for some reason)
        try {
          final sign = await FirebaseAuth.instance
              .signInWithEmailAndPassword(email: email, password: password);
          authUid = sign.user?.uid;
        } catch (_) {
          // ignore fallback errors
        }
      }

      // 4) Update patient doc with username and credentials flags
      final patientRef = FirebaseFirestore.instance.collection('patients').doc(widget.patientDocId);
      final updateData = <String, dynamic>{
        'username': username,
        'credentialsSet': true,
        'credentialsCreatedAt': FieldValue.serverTimestamp(),
      };
      if (authUid != null && authUid.isNotEmpty) updateData['authUid'] = authUid;

      await patientRef.update(updateData);

      // 5) Ensure the client is signed in as this user
      if (FirebaseAuth.instance.currentUser == null) {
        try {
          await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
        } catch (_) {
          // ignore
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Credentials created — redirecting...')));

      // 6) Navigate to patient home (remove previous routes)
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => PatientHomePage(patientId: widget.patientId)),
        (route) => false,
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Login Credentials'),
        backgroundColor: const Color(0xFF3A6631),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Patient ID: ${widget.patientId}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _usernameCtrl,
                      decoration: _inputDecoration('Choose a username'),
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter a username';
                        if (v.trim().length < 3) return 'Username must be at least 3 characters';
                        if (v.contains(' ')) return 'No spaces allowed';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordCtrl,
                      decoration: _inputDecoration('Choose a password'),
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter a password';
                        if (v.length < 6) return 'Password must be at least 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmCtrl,
                      decoration: _inputDecoration('Confirm password'),
                      obscureText: true,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Confirm your password';
                        if (v != _passwordCtrl.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3A6631)),
                        child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Create my account'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(onPressed: _loading ? null : () => Navigator.pop(context), child: const Text('Back to Login')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

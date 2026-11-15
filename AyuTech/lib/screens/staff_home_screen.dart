// File: lib/screens/staff_home_screen.dart
// Staff portal restyled to match Admin dashboard theme and sidebar.
// Functionality unchanged — only visual/layout changes (sidebar, colors, logout).

import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'patient_entry_screen.dart';
import 'patient_history_screen.dart';
import 'welcome_screen.dart';
import 'package:ayutech/models/patient.dart';
import 'ongoing_patients_screen.dart';
import 'package:ayutech/screens/staff_patient_record_screen.dart';
import 'package:ayutech/services/token_allocator.dart';
import 'package:ayutech/services/storage_service.dart';

/// Reused AyuTech palette (matches admin_home_page_all_in_one.dart)
class AyuColors {
  static const Color teal = Color(0xFF2F5C56);
  static const Color gold = Color(0xFFD6A657);
  static const Color sidebarBg = Color(0xFF2F5C56);
  static const Color bgBody = Color(0xFFFAFAF8);
  static const Color cardSurface = Colors.white;
  static const Color surfaceAlt = Color(0xFFF7F5EC);
  static const Color tileBg = Color(0xFFE7E5D1);
  static const Color text = Color(0xFF333333);
}

class StaffHomeScreen extends StatefulWidget {
  const StaffHomeScreen({Key? key}) : super(key: key);

  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen> {
  final List<Patient> _patients = [];

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _fire = FirebaseFirestore.instance;

  String? _lastGeneratedPdfPath;

  // Sidebar width kept same as admin
  static const double _sidebarWidth = 260.0;

  void _addPatient(Patient patient) async {
    setState(() {
      _patients.add(patient);
    });

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .collection("patients")
          .add({
        "name": patient.name,
        "age": patient.age,
        "gender": patient.gender,
        "region": patient.region,
        "contact": patient.phoneNumber,
        "disease": patient.diseases,
        "status": patient.status,
        "prescriber": patient.prescriber,
        "allergy": patient.allergy,
        "bowelMovement": patient.bowelMovement,
        "waterIntake": patient.waterIntake,
        "history": patient.medicalHistory,
        "startDate": patient.startDate.toIso8601String(),
        "createdAt": FieldValue.serverTimestamp(),
      });
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Patient '${patient.name}' added ✅")),
    );
  }

  Future<void> _handleLogoutSidebar() async {
    // Try to sign out but always navigate to WelcomeScreen (clear stack)
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
    }

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  // -------------------------
  // Minimal new patient form
  // -------------------------
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtl = TextEditingController();
  final TextEditingController _ageCtl = TextEditingController();
  String _gender = 'Male';
  DateTime? _dob;
  DateTime? _startDate;
  final TextEditingController _phoneCtl = TextEditingController();
  final TextEditingController _regionCtl = TextEditingController();

  String? _assignedDoctorUid;
  String? _assignedDoctorName;

  bool _saving = false;

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = _dob ?? DateTime(now.year - 20);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final initial = _startDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _ageCtl.dispose();
    _phoneCtl.dispose();
    _regionCtl.dispose();
    super.dispose();
  }

  String _nameSlug(String name, {int maxLen = 6}) {
    final slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return slug.isEmpty ? 'patient' : slug.substring(0, min(maxLen, slug.length));
  }

  String _pad(int n, int width) => n.toString().padLeft(width, '0');

  Future<String> _generatePatientId(String name) async {
    final counterRef = _fire.collection('counters').doc('patientIdSeq');
    await counterRef.set({'last': FieldValue.increment(1)}, SetOptions(merge: true));
    final snap = await counterRef.get();
    final raw = snap.data()?['last'] ?? 0;
    final pSeq = (raw is num) ? raw.toInt() : int.tryParse(raw.toString()) ?? 0;
    final slug = _nameSlug(name, maxLen: 6);
    return '$slug${_pad(pSeq, 4)}';
  }

  Future<void> _uploadPdfIfAvailable(String patientDocId) async {
    try {
      final path = _lastGeneratedPdfPath;
      if (path == null || path.isEmpty) return;
      final file = File(path);
      if (!await file.exists()) return;
      final url = await StorageService.uploadDietChartPdf(pdfFile: file, patientDocId: patientDocId);
      if (url != null) {
        debugPrint('Diet chart uploaded: $url');
      }
    } catch (e) {
      debugPrint('Upload PDF failed: $e');
    }
  }

  Future<void> _saveMinimalPatient() async {
    if (!_formKey.currentState!.validate()) return;
    if (_assignedDoctorUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please assign a doctor')),
      );
      return;
    }

    if (_saving) return;
    setState(() => _saving = true);

    try {
      final staffUid = _auth.currentUser?.uid ?? '';
      if (staffUid.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not signed in')));
        setState(() => _saving = false);
        return;
      }

      final doctorUid = _assignedDoctorUid!;


final ageText = _ageCtl.text.trim();
final age = int.tryParse(ageText);

if (age == null) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Please enter a valid age')),
  );
  setState(() => _saving = false);
  return;
}

if (_dob == null) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Please select DOB')),
  );
  setState(() => _saving = false);
  return;
}

if (_startDate == null) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Please select Start Date')),
  );
  setState(() => _saving = false);
  return;
}


final patientMap = {
  'name': _nameCtl.text.trim(),
  'age': age,
  'gender': _gender,
  'dob': _dob!.toIso8601String(),
  'phone': _phoneCtl.text.trim(),
  'startDate': _startDate!.toIso8601String(),
  'region': _regionCtl.text.trim(),
  'status': 'ongoing',
  'assignedDoctorUid': doctorUid,
  'assignedDoctorName': _assignedDoctorName ?? '',
  'createdByStaff': staffUid,
  'credentialsSet': false,
  'username': '',
  'dietChartUrl': '',
  'dietChartName': '',
};



      final allocResult = await TokenAllocator.createOngoingPatientWithAtomicToken({
        ...patientMap,
        'clinicDate': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'createdByStaff': staffUid,
        'assignedDoctorUid': doctorUid,
        'assignedDoctorName': _assignedDoctorName ?? '',
      });

      if (allocResult['docRef'] == null) {
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Token allocation failed')),
    );
  }
  setState(() => _saving = false);
  return;
}


      final DocumentReference ongoingDocRef = allocResult['docRef'] as DocumentReference;
      final String token = allocResult['token']?.toString() ?? '';
      final int tokenNumber = (allocResult['tokenNumber'] is num)
          ? (allocResult['tokenNumber'] as num).toInt()
          : int.tryParse(allocResult['token']?.toString() ?? '') ?? 0;

      final patientId = await _generatePatientId(patientMap['name'] as String? ?? 'patient');
      final DocumentReference globalPatientRef = _fire.collection('patients').doc();
      await globalPatientRef.set({
        ...patientMap,
        'patientId': patientId,
        'token': token,
        'tokenNumber': tokenNumber,
        'ongoingPatientDocId': ongoingDocRef.id,
        'createdAt': FieldValue.serverTimestamp(),
        'createdAtClient': DateTime.now().toIso8601String(),
      });

      await _uploadPdfIfAvailable(globalPatientRef.id);

      DocumentReference? staffDocRef;
      if (staffUid.isNotEmpty) {
        staffDocRef = await _fire.collection('users').doc(staffUid).collection('patients').add({
          ...patientMap,
          'patientId': patientId,
          'token': token,
          'tokenNumber': tokenNumber,
          'globalPatientDocId': globalPatientRef.id,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      final doctorDocRef = await _fire.collection('users').doc(doctorUid).collection('patients').add({
        ...patientMap,
        'patientId': patientId,
        'token': token,
        'tokenNumber': tokenNumber,
        'globalPatientDocId': globalPatientRef.id,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (staffDocRef != null) {
        await staffDocRef.update({'doctorPatientDocId': doctorDocRef.id});
      }
      await doctorDocRef.update({'staffPatientDocId': staffDocRef?.id ?? ''});

      await globalPatientRef.update({
        'staffPatientDocId': staffDocRef?.id ?? '',
        'doctorPatientDocId': doctorDocRef.id,
      });

      try {
        await ongoingDocRef.update({
          'globalPatientDocId': globalPatientRef.id,
          'staffPatientDocId': staffDocRef?.id ?? '',
          'doctorPatientDocId': doctorDocRef.id,
          'patientId': patientId,
        });
      } catch (e) {
        debugPrint('Failed to update ongoing doc links: $e');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Patient saved — ID: $patientId    Token: $token")),
      );

      // reset form
      _formKey.currentState!.reset();
      setState(() {
        _dob = null;
        _startDate = null;
        _gender = 'Male';
        _assignedDoctorUid = null;
        _assignedDoctorName = null;
      });
      _nameCtl.clear();
      _ageCtl.clear();
      _phoneCtl.clear();
      _regionCtl.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save error: $e')));
    } finally {
      if (!mounted) return;
      setState(() => _saving = false);
    }
  }

  

  Widget _buildMinimalPatientForm(double innerWidth) {
    return Form(
      key: _formKey,
      child: SizedBox(
        width: innerWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              children: const [
                SizedBox(height: 6),
                Text("New Patient Entry", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 6),
                Text("Fill basic details and assign doctor", style: TextStyle(color: Colors.black54)),
                SizedBox(height: 12),
              ],
            ),

            _LabeledFieldBox(
              label: 'Full name',
              child: TextFormField(
                controller: _nameCtl,
                decoration: const InputDecoration.collapsed(hintText: 'Enter full name'),
                validator: (v) => (v == null || v.trim().length < 2) ? 'Enter valid name' : null,
              ),
            ),

            Row(
              children: [
                Flexible(
                  flex: 2,
                  child: _LabeledFieldBox(
                    label: 'Age',
                    child: TextFormField(
                      controller: _ageCtl,
                      decoration: const InputDecoration.collapsed(hintText: 'e.g. 34'),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter age';
                        final n = int.tryParse(v);
                        if (n == null || n <= 0) return 'Enter valid age';
                        return null;
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  flex: 3,
                  child: _LabeledFieldBox(
                    label: 'Gender',
                    child: DropdownButtonFormField<String>(
                      value: _gender,
                      decoration: const InputDecoration.collapsed(hintText: ''),
                      items: const [
                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                        DropdownMenuItem(value: 'Female', child: Text('Female')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (v) => setState(() => _gender = v ?? 'Male'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Flexible(
                  child: _LabeledFieldBox(
                    label: 'DOB',
                    child: InkWell(
                      onTap: _pickDob,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Text(_dob == null ? 'Select DOB' : _dob!.toLocal().toString().split(' ')[0]),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: _LabeledFieldBox(
                    label: 'Start date',
                    child: InkWell(
                      onTap: _pickStartDate,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Text(_startDate == null ? 'Select start date' : _startDate!.toLocal().toString().split(' ')[0]),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            _LabeledFieldBox(
              label: 'Phone number',
              child: TextFormField(
                controller: _phoneCtl,
                decoration: const InputDecoration.collapsed(hintText: 'Enter phone number'),
                keyboardType: TextInputType.phone,
                validator: (v) => (v == null || v.trim().length < 6) ? 'Enter valid phone' : null,
              ),
            ),

            _LabeledFieldBox(
              label: 'Region',
              child: TextFormField(
                controller: _regionCtl,
                decoration: const InputDecoration.collapsed(hintText: 'Enter region'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter region' : null,
              ),
            ),

            _LabeledFieldBox(
              label: 'Assign doctor',
              child: StreamBuilder<QuerySnapshot>(
                stream: _fire.collection('users').where('role', isEqualTo: 'doctor').snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: LinearProgressIndicator(),
                    );
                  }
                  final docs = snap.data?.docs ?? [];
                  final items = docs.map((d) {
                    final data = d.data() as Map<String, dynamic>? ?? {};
                    final display = (data['name'] ?? d.id).toString();
                    return DropdownMenuItem<String>(value: d.id, child: Text(display));
                  }).toList();

                  return DropdownButtonFormField<String>(
                    value: _assignedDoctorUid,
                    decoration: const InputDecoration.collapsed(hintText: ''),
                    items: items,
                    onChanged: (val) {
                      setState(() {
                        _assignedDoctorUid = val;
                        if (val != null) {
                          final doc = docs.firstWhere((d) => d.id == val);
                          _assignedDoctorName = (doc.data() as Map<String, dynamic>)['name'] ?? doc.id;
                        } else {
                          _assignedDoctorName = null;
                        }
                      });
                    },
                    validator: (v) => (v == null || v.isEmpty) ? 'Select a doctor' : null,
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
  onPressed: _saving
      ? null
      : () async {
          try {
            await _saveMinimalPatient();
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            }
          }
        },
  child: const Text('Save & Assign'),
),

              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openNewPatientDialog(double innerWidth) {
    showDialog(
      context: context,
      builder: (dctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: Container(
            decoration: BoxDecoration(
              color: AyuColors.bgBody,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: innerWidth + 20, maxHeight: 700),
                child: _buildMinimalPatientForm(innerWidth),
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------- Sidebar builder (admin style) ----------------
  Widget _sidebarItem(String title, IconData icon, {bool active = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: active ? Colors.white.withOpacity(0.06) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: active ? Border(left: BorderSide(color: AyuColors.gold, width: 4)) : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 18),
            const SizedBox(width: 10),
            Text(title, style: TextStyle(color: Colors.white.withOpacity(active ? 1 : 0.95), fontWeight: active ? FontWeight.w700 : FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ---------------------- UI ----------------------
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
  final double panelsHeight = max(360.0, size.height * 0.45);
    return Scaffold(
      backgroundColor: AyuColors.bgBody,
      body: SafeArea(
        child: Row(
          children: [
            // Sidebar (Admin-style but with staff options)
            Container(
              width: _sidebarWidth,
              color: AyuColors.sidebarBg,
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(children: [
                      Container(
                        decoration: BoxDecoration(color: AyuColors.gold, borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.all(8),
                        child: const Icon(Icons.spa, color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('AyuTech', style: TextStyle(fontFamily: 'Merriweather', color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                      )
                    ]),
                  ),
                  const SizedBox(height: 18),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text('Main', style: TextStyle(color: Colors.white.withOpacity(0.6), fontWeight: FontWeight.w700))),
                  const SizedBox(height: 8),

                  // Sidebar items requested by user
                  _sidebarItem('Dashboard', Icons.dashboard, active: true, onTap: () {
                    // Scroll to top / refresh UI - here it's a no-op placeholder

                  }),
                  _sidebarItem('New Patient Entry', Icons.person_add_alt, onTap: () {
                    final innerWidth = min(size.width * 0.6, 720.0);
                    _openNewPatientDialog(innerWidth);
                  }),
                  _sidebarItem('Ongoing Patients', Icons.access_time, onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const OngoingPatientsScreen()));
                  }),
                  _sidebarItem('Existing Records', Icons.folder_open, onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => StaffPatientRecordScreen()));
                  }),
                  _sidebarItem('Settings', Icons.settings, onTap: () {
                    // If you have a settings route, change this to Navigator.pushNamed(context, '/settings')

                  }),

                  const SizedBox(height: 18),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text('More', style: TextStyle(color: Colors.white.withOpacity(0.6), fontWeight: FontWeight.w700))),
                  const SizedBox(height: 8),

                  // Spacer pushes profile + logout to bottom
                  const Spacer(),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=12'), radius: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text('Staff', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                  SizedBox(height: 2),
                                  Text('Clinic Staff', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 40,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white24,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                            ),
                            onPressed: _handleLogoutSidebar,
                            icon: const Icon(Icons.logout, color: Colors.white70, size: 18),
                            label: const Text('Logout', style: TextStyle(color: Colors.white70)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Main content (dashboard tiles)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      // Top header area matches admin style (but simplified)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(color: AyuColors.bgBody, borderRadius: BorderRadius.circular(6)),
                        child: Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(border: Border(left: BorderSide(color: AyuColors.teal, width: 3))),
                              padding: const EdgeInsets.only(left: 15),
                              child: Text(
                                'Staff Dashboard',
                                style: TextStyle(color: AyuColors.teal, fontSize: 20, fontFamily: 'Merriweather', fontWeight: FontWeight.w700),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              width: 300,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                              child: Row(children: [Icon(Icons.search, color: Colors.grey.shade400), const SizedBox(width: 8), const Expanded(child: TextField(decoration: InputDecoration.collapsed(hintText: 'Search...')))]),
                            ),
                            const SizedBox(width: 12),

                            const SizedBox(width: 8),
                            ElevatedButton(onPressed: () {
                              final innerWidth = min(size.width * 0.6, 720.0);
                              _openNewPatientDialog(innerWidth);
                            }, style: ElevatedButton.styleFrom(backgroundColor: AyuColors.gold, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('+ New Patient')),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Tiles area (replaced)
                      // Compact dashboard top: stats row + main content (ongoing list + existing quick lookup)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Column(
                          children: [
                            // Top stats row (4 cards)
                        // ---------- top stats (live counts) ----------
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    // 1) New patients today
    Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: () {
          final now = DateTime.now();
          final todayStart = DateTime(now.year, now.month, now.day);
          return _fire
              .collection('patients')
              .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
              .snapshots();
        }(),
        builder: (context, snap) {
          final count = (snap.hasData) ? snap.data!.docs.length.toString() : '-';
          return _StatCard(
            title: 'New Patient Entry',
            value: count,
            subtitle: 'Start Registration',
            icon: Icons.add,
            onTap: () {
              final innerWidth = min(MediaQuery.of(context).size.width * 0.6, 720.0);
              _openNewPatientDialog(innerWidth);
            },
          );
        },
      ),
    ),

    const SizedBox(width: 12),

    // 2) Ongoing patients
    Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: _fire
            .collection('patients')
            .where('status', isEqualTo: 'ongoing') // adjust if you use a different status key/value
            .snapshots(),
        builder: (context, snap) {
          final count = (snap.hasData) ? snap.data!.docs.length.toString() : '-';
          return _StatCard(
            title: 'Ongoing Patients',
            value: count,
            subtitle: '+ admitted today', // you can compute delta if you want; kept generic
            icon: Icons.access_time,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const OngoingPatientsScreen()));
            },
          );
        },
      ),
    ),

    const SizedBox(width: 12),

    // 3) Existing / ended patients
    Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: _fire
            .collection('patients')
            .where('status', isEqualTo: 'ended') // change 'ended' to 'discharged' / 'completed' if needed
            .snapshots(),
        builder: (context, snap) {
          final count = (snap.hasData) ? snap.data!.docs.length.toString() : '-';
          return _StatCard(
            title: 'Existing Patient',
            value: count,
            subtitle: 'ended sessions',
            icon: Icons.folder_open,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => StaffPatientRecordScreen()));
            },
          );
        },
      ),
    ),

    const SizedBox(width: 12),

    // 4) Tokens available (adapt query to your tokens storage)
    Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: _fire
            .collection('tokens') // <-- change this if you keep tokens on a different collection
            .where('status', isEqualTo: 'available') // change to your token-availability field
            .snapshots(),
        builder: (context, snap) {
          // If your app does not have a 'tokens' collection, change this stream to your real source,
          // or show '-' / 0 as fallback.
          final count = (snap.hasData) ? snap.data!.docs.length.toString() : '-';
          return _StatCard(
            title: 'Token Available',
            value: count,
            subtitle: 'Pending approval: 2', // optional: compute real pending count similarly
            icon: Icons.confirmation_number,
            onTap: () {
              // navigate to tokens screen if you have one
            },
          );
        },
      ),
    ),
  ],
),

 const SizedBox(height: 20),

// Main content with independent scroll areas for left & right panels
// (fixed height so each side can scroll independently)




Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    // Left column: ongoing patients — scrollable list
    Expanded(
      flex: 3,
      child: Container(
        height: panelsHeight,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: Offset(0,4))],
          border: Border.all(color: Colors.black.withOpacity(0.03)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text('Ongoing Patients', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const OngoingPatientsScreen()));
                  },
                  child: const Text('View All'),
                )
              ],
            ),
            const SizedBox(height: 12),
            // Scrollbar + inner list view. _OngoingPatientsPanel already returns a ListView,
            // so wrap it with Scrollbar for a nicer UX.
            Expanded(
              child: Scrollbar(
                thumbVisibility: true,
                child: _OngoingPatientsPanel(fire: _fire),
              ),
            ),
          ],
        ),
      ),
    ),

    const SizedBox(width: 16),

    // Right column: existing patients (fixed width on wide screens)
    // Make it scrollable independently. Use a constrained width for right column.
    ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 360, minWidth: 240),
      child: Container(
        height: panelsHeight,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AyuColors.cardSurface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: Offset(0,4))],
          border: Border.all(color: Colors.black.withOpacity(0.02)),
        ),
        child: Scrollbar(
          thumbVisibility: true,
          child: _ExistingPatientsPanel(fire: _fire),

        ),
      ),
    ),
  ],
),

                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Bottom sign out (redundant to sidebar but kept for user convenience)
                   
                    ]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- small UI helpers ----------------

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _StatCard({
    Key? key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AyuColors.cardSurface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: Offset(0, 3))],
          border: Border.all(color: Colors.black.withOpacity(0.03)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AyuColors.surfaceAlt, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: AyuColors.teal),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, color: Colors.black54)),
                  const SizedBox(height: 6),
                  Text(value.isEmpty ? '-' : value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black45)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OngoingPatientsPanel extends StatelessWidget {
  final FirebaseFirestore fire;

  const _OngoingPatientsPanel({Key? key, required this.fire}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Query: show ongoing patients (most recent first). Adjust limit as needed.
    final stream = fire
        .collection('patients')
        .where('status', isEqualTo: 'ongoing')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const Center(child: Text('No ongoing patients'));

        // Build a scrollable list showing name, id, diagnosis & status badge.
        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1, thickness: 1),
          itemBuilder: (ctx, i) {
            final doc = docs[i];
            final data = doc.data() as Map<String, dynamic>? ?? {};
            final name = (data['name'] ?? 'Unknown').toString();
            final pid = (data['patientId'] ?? doc.id).toString();
            final diag = (data['disease'] ?? data['diagnosis'] ?? '-').toString();
            final status = (data['status'] ?? '-').toString();

            // Optionally customize status color
            Color statusBg = Colors.orange.shade100;
            if (status.toLowerCase() == 'stable') statusBg = Colors.green.shade100;
            else if (status.toLowerCase() == 'critical') statusBg = Colors.red.shade100;

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              leading: CircleAvatar(
                radius: 20,
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
              ),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('ID: $pid • $diag'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(status, style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              onTap: () {
                // Navigate to patient record screen, passing document id (adjust constructor if needed)
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => StaffPatientRecordScreen(/* optionally pass doc.id */)),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ExistingPatientsPanel extends StatelessWidget {
  final FirebaseFirestore fire;

  const _ExistingPatientsPanel({Key? key, required this.fire}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Existing Patients', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        TextFormField(
          decoration: InputDecoration(
            hintText: 'Enter Patient ID...',
            suffixIcon: IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: () {
                // implement lookup action
              },
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            filled: true,
            fillColor: AyuColors.surfaceAlt,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
        ),
        const SizedBox(height: 12),
        const Text('Recently Viewed', style: TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 10),

        // This query returns only patients whose status is 'ended'
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: fire
                .collection('patients')
                .where('status', isEqualTo: 'ended') // <-- change 'ended' to your actual value if different
                .orderBy('createdAt', descending: true)
                .limit(40)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) return const Center(child: Text('No ended sessions yet'));
              return ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final data = docs[i].data() as Map<String, dynamic>? ?? {};
                  final name = data['name'] ?? 'Unknown';
                  final lastVisit = data['createdAt'] != null
                      ? (data['createdAt'] is Timestamp ? (data['createdAt'] as Timestamp).toDate().toLocal().toString().split(' ')[0] : data['createdAt'].toString())
                      : '';
                  return ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(child: Text(name.toString().isNotEmpty ? name.toString()[0] : '?')),
                    title: Text(name.toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Last visit: $lastVisit', style: const TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => StaffPatientRecordScreen()));
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}


// Outer box wrapper for each dashboard tile (keeps previous look)
class _OuterTileBox extends StatelessWidget {
  final Widget child;
  final double width;

  const _OuterTileBox({Key? key, required this.child, required this.width}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AyuColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.black.withOpacity(0.03)),
      ),
      child: child,
    );
  }
}

// Dashboard Card Widget (unchanged look inside the outer box)
class _DashboardCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AyuColors.tileBg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              offset: const Offset(0, 4),
              blurRadius: 6,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AyuColors.teal),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontFamily: 'Jomolhari',
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Labeled field box (used for the form dialog)
class _LabeledFieldBox extends StatelessWidget {
  final String label;
  final Widget child;
  final EdgeInsetsGeometry margin;

  const _LabeledFieldBox({
    Key? key,
    required this.label,
    required this.child,
    this.margin = const EdgeInsets.symmetric(vertical: 8),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6.0, bottom: 6.0),
          child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54)),
        ),
        Container(
          margin: margin,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFEFEBD9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
            boxShadow: const [BoxShadow(color: Color.fromRGBO(0,0,0,0.04), blurRadius: 4, offset: Offset(0,2))],
          ),
          child: child,
        ),
      ],
    );
  }
}

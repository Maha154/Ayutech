// lib/screens/ongoing_patients_screen.dart
// Visual integration: persistent left sidebar added to match provided design.
// NOTE: Only UI/styling changed. All business logic kept intact.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:ayutech/screens/patient_entry_screen.dart';
import 'package:ayutech/models/patient.dart';
import 'package:ayutech/services/token_allocator.dart';

class OngoingPatientsScreen extends StatefulWidget {
  final String? doctorUid;
  const OngoingPatientsScreen({Key? key, this.doctorUid}) : super(key: key);

  @override
  State<OngoingPatientsScreen> createState() => _OngoingPatientsScreenState();
}

class _OngoingPatientsScreenState extends State<OngoingPatientsScreen> {
  final FirebaseFirestore _fire = FirebaseFirestore.instance;
  final TextEditingController _searchCtl = TextEditingController();
  String? _currentUid;
  String _currentRole = ''; // 'doctor' or 'staff'

  // Prevent repeated automatic repairs while screen is mounted
  bool _alreadyAttemptedRepair = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserRole();
  }

  Future<void> _loadCurrentUserRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await _fire.collection('users').doc(uid).get();
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final role = (data['role'] ?? '').toString().toLowerCase();
      setState(() {
        _currentUid = uid;
        _currentRole = role;
      });
    } catch (_) {
      setState(() {
        _currentUid = uid;
        _currentRole = '';
      });
    }
  }

  // Optional date filter: null = show all dates (no clinicDate filter)
  DateTime? _selectedDate;
  bool get _isFilteringByDate => _selectedDate != null;
  String _selectedYmd() => DateFormat('yyyy-MM-dd').format(_selectedDate ?? DateTime.now());

  // Base query
  Query _baseQuery() {
    const collectionName = 'ongoingPatients';
    Query q = _fire.collection(collectionName).where('status', isEqualTo: 'ongoing');

    if (_isFilteringByDate) {
      q = q.where('clinicDate', isEqualTo: _selectedYmd());
    }
    return q;
  }

  Future<void> _callNumber(String phone) async {
    if (phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot launch phone on this device')));
    }
  }

  Future<void> _markCalled(DocumentSnapshot doc) async {
    try {
      await doc.reference.update({
        'status': 'called',
        'calledAt': FieldValue.serverTimestamp(),
        'calledBy': 'staff',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Patient called')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _markServed(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final globalId = data['globalPatientDocId'] as String?;
      if (globalId != null && globalId.isNotEmpty) {
        try {
          await _fire.collection('patients').doc(globalId).update({
            'status': 'done',
            'servedAt': FieldValue.serverTimestamp(),
          });
        } catch (_) {}
      }
      await doc.reference.delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as served and token freed')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _confirmAndMarkServed(DocumentSnapshot doc, dynamic token) async {
    final tokenText = token?.toString() ?? 'this patient';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark served?'),
        content: Text('Mark token $tokenText as served?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
        ],
      ),
    );
    if (ok == true) {
      await _markServed(doc);
    }
  }

  void _viewRecord(DocumentSnapshot doc) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Open patient record (not implemented)')));
  }

  int? _toIntToken(dynamic token) {
    if (token == null) return null;
    if (token is int) return token;
    if (token is double) return token.toInt();
    if (token is String) {
      final digits = RegExp(r'\d+').firstMatch(token)?.group(0);
      if (digits != null) return int.tryParse(digits);
      return int.tryParse(token);
    }
    return null;
  }

  void _showDoctorPatientPopup(Map<String, dynamic> data, DocumentSnapshot doc) {
    final name = data['name'] ?? 'Unknown';
    final patientId = data['patientId'] ?? '-';
    final token = data['tokenNumber']?.toString() ?? (data['token']?.toString() ?? '-');
    final phone = data['phone'] ?? data['contact'] ?? '';
    String startDate = '';

    if (data['startDate'] != null) {
      final sd = data['startDate'].toString();
      startDate = sd.contains('T') ? sd.split('T')[0] : sd;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Patient Details', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: $name'),
            const SizedBox(height: 6),
            Text('Patient ID: $patientId'),
            const SizedBox(height: 6),
            Text('Token: $token'),
            const SizedBox(height: 6),
            if (startDate.isNotEmpty) Text('Start: $startDate'),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2F5C56), // teal from your tailwind
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);

                final Map<String, dynamic> prefill = Map<String, dynamic>.from(data);

                prefill['staffPatientDocId'] = doc.id;
                prefill['staffUid'] = data['staffUid'] ?? data['createdByStaff'] ?? FirebaseAuth.instance.currentUser?.uid;
                prefill['token'] = token;
                prefill['tokenNumber'] = data['tokenNumber'] ?? _toIntToken(data['token']);
                prefill['patientId'] = prefill['patientId'] ?? patientId;
                prefill['startDate'] = prefill['startDate'] ?? startDate;
                prefill['clinicDate'] = prefill['clinicDate'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
                prefill['ongoingDocId'] = doc.id;

                final String? targetDoctorUid = (data['doctorUid'] ?? data['assignedDoctorUid'] ?? widget.doctorUid) as String?;
                final String? doctorPatientDocId = data['doctorPatientDocId'] as String?;

                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PatientEntryScreen(
                      prefill: prefill,
                      doctorUid: targetDoctorUid,
                      patientDocId: doctorPatientDocId,
                      onSave: (Patient saved) async {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Patient details saved by doctor')));
                        }

                        try {
                          final ongoingId = prefill['ongoingDocId'] as String?;
                          if (ongoingId != null && ongoingId.isNotEmpty) {
                            await FirebaseFirestore.instance.collection('ongoingPatients').doc(ongoingId).update({
                              'status': 'called',
                              'calledAt': FieldValue.serverTimestamp(),
                              'calledBy': 'doctor',
                            });
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed updating waiting entry: $e')));
                          }
                        }
                      },
                    ),
                  ),
                );
              },
              child: const Text("Call Patient"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _pickDateAndFilter() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Widget _buildIndexErrorWidget(String err) {
    final urlRegex = RegExp(r'https?://[^\s]+');
    final match = urlRegex.firstMatch(err);
    final urlStr = match?.group(0);
    final requiresIndex = err.toLowerCase().contains('requires an index');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Error: $err', style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
          if (requiresIndex)
            const Text(
              'This query requires a Firestore composite index. You can create it in the Firebase console.',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          if (urlStr != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final uri = Uri.tryParse(urlStr);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot open URL')));
                }
              },
              child: const Text('Open suggested index in Firebase Console',
                  style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
            ),
          ],
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => setState(() {}),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  List<QueryDocumentSnapshot> _sortByTokenNumber(List<QueryDocumentSnapshot> docs) {
    final copied = List<QueryDocumentSnapshot>.from(docs);
    copied.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>? ?? {};
      final bData = b.data() as Map<String, dynamic>? ?? {};
      final aNum = (aData['tokenNumber'] is num) ? (aData['tokenNumber'] as num).toInt() : _toIntToken(aData['token']);
      final bNum = (bData['tokenNumber'] is num) ? (bData['tokenNumber'] as num).toInt() : _toIntToken(bData['token']);
      final an = aNum ?? 999999;
      final bn = bNum ?? 999999;
      return an.compareTo(bn);
    });
    return copied;
  }

  Future<void> _repairTokensForAllDates(List<QueryDocumentSnapshot> docs) async {
    if (docs.isEmpty) return;
    final byDate = <String, List<QueryDocumentSnapshot>>{};
    for (var d in docs) {
      final m = d.data() as Map<String, dynamic>? ?? {};
      final cd = (m['clinicDate'] ?? 'unknown').toString();
      (byDate[cd] ??= []).add(d);
    }

    final batch = _fire.batch();
    int updatedCount = 0;

    for (final entry in byDate.entries) {
      final date = entry.key;
      final list = entry.value;

      list.sort((a, b) {
        final A = a.data() as Map<String, dynamic>? ?? {};
        final B = b.data() as Map<String, dynamic>? ?? {};
        DateTime? aStart;
        DateTime? bStart;
        if (A['startDate'] != null) {
          final sd = A['startDate'].toString();
          try {
            aStart = DateTime.tryParse(sd.split('T').first) ?? DateTime.tryParse(sd);
          } catch (_) {}
        }
        if (B['startDate'] != null) {
          final sd = B['startDate'].toString();
          try {
            bStart = DateTime.tryParse(sd.split('T').first) ?? DateTime.tryParse(sd);
          } catch (_) {}
        }

        if (aStart != null && bStart != null) return aStart.compareTo(bStart);
        if (aStart != null && bStart == null) return -1;
        if (aStart == null && bStart != null) return 1;

        final aCreated = (A['createdAt'] is Timestamp) ? (A['createdAt'] as Timestamp).toDate() : null;
        final bCreated = (B['createdAt'] is Timestamp) ? (B['createdAt'] as Timestamp).toDate() : null;
        if (aCreated != null && bCreated != null) return aCreated.compareTo(bCreated);
        if (aCreated != null && bCreated == null) return -1;
        if (aCreated == null && bCreated != null) return 1;

        return a.id.compareTo(b.id);
      });

      for (int i = 0; i < list.length; i++) {
        final desiredToken = i + 1;
        final d = list[i];
        final data = d.data() as Map<String, dynamic>? ?? {};

        final currentTokenNum = (data['tokenNumber'] is num) ? (data['tokenNumber'] as num).toInt() : _toIntToken(data['token']);

        if (currentTokenNum != desiredToken) {
          batch.update(_fire.collection('ongoingPatients').doc(d.id), {'tokenNumber': desiredToken});
          updatedCount++;
        }
      }
    }

    if (updatedCount > 0) {
      try {
        await batch.commit();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Repaired $updatedCount duplicate token(s) in Firestore')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Token repair failed: $e')));
      }
    } else {
      // nothing to update
    }
  }

  // ---------- Sidebar UI builder ----------
  Widget _buildSidebar(BuildContext context) {
    const sidebarWidth = 260.0;
    const Color ayuTeal = Color(0xFF2F5C56);
    const Color sidebarAccent = Color(0xFFD6A657);
    const Color activeBg = Color(0xFF395B52); // slightly darker teal for active item

    final TextStyle menuStyle = const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600);
    final TextStyle menuSubStyle = const TextStyle(color: Colors.white70, fontSize: 12);

    return Container(
      width: sidebarWidth,
      color: ayuTeal,
      child: SafeArea(
        child: Column(
          children: [
            // Logo area
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                    child: const Icon(Icons.local_hospital_outlined, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('AyuTech', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('DOCTOR PORTAL', style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 0.8)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Menu
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Dashboard
                    _SidebarMenuItem(
                      icon: Icons.dashboard_outlined,
                      label: 'Dashboard',
                      active: false,
                      onTap: () {
                        Navigator.pushReplacementNamed(context, '/dashboard');
                      },
                    ),

                    // New Entry
                    _SidebarMenuItem(
                      icon: Icons.add_circle_outline,
                      label: 'New Entry',
                      active: false,
                      onTap: () {
                        Navigator.pushNamed(context, '/new_entry');
                      },
                    ),

                    // Ongoing Patient (active)
                    _SidebarMenuItem(
                      icon: Icons.access_time,
                      label: 'Ongoing Patient',
                      active: true,
                      onTap: () {
                        // already on this screen — do nothing
                      },
                    ),

                    // Records
                    _SidebarMenuItem(
                      icon: Icons.folder_open,
                      label: 'Records',
                      active: false,
                      onTap: () {
                        Navigator.pushNamed(context, '/records');
                      },
                    ),

                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),

            // bottom doctor card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: ayuTeal.withOpacity(0.95),
                border: const Border(top: BorderSide(color: Colors.black12)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: Colors.transparent, shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
                    alignment: Alignment.center,
                    child: const Text('DR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Dr. Sharma', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        SizedBox(height: 2),
                        Text('MD (Ayurveda)', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- end Sidebar UI ----------

  @override
  Widget build(BuildContext context) {
    final base = _baseQuery();

    // color palette from your Tailwind config
    const Color ayuTeal = Color(0xFF2F5C56);
    const Color ayuCream = Color(0xFFFAFAF8);
    const Color ayuBanner = Color(0xFFEAF7EE);
    const Color bannerTextGreen = Color(0xFF2E6B2E);

    void _goBackToDashboard() {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    }

    // text styles (fontFamily names match your HTML; ensure fonts bundled for exact match)
    const TextStyle headingStyle = TextStyle(fontFamily: 'Merriweather', fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF333333));
    const TextStyle subtitleStyle = TextStyle(fontFamily: 'Lato', fontSize: 14, color: Color(0xFF333333));
    const TextStyle tableHeaderStyle = TextStyle(fontFamily: 'Lato', fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black54);
    const TextStyle tableRowName = TextStyle(fontFamily: 'Lato', fontSize: 16, fontWeight: FontWeight.w600);

    // Outer layout is a Row: left sidebar + right content
    return Scaffold(
      backgroundColor: ayuCream,
      body: Row(
        children: [
          // Left persistent sidebar
          _buildSidebar(context),

          // Right content
          Expanded(
            child: Column(
              children: [
                // Top header container with only back button and small spacer/logo space to maintain visual balance
                Expanded(
  child: Column(
    children: [
      // Page Title + Date chip
    Padding(
  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
  child: Align(
    alignment: Alignment.centerLeft,
    child: IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: 'Back',
      onPressed: () {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          Navigator.pushReplacementNamed(context, '/dashboard');
        }
      },
    ),
  ),
),



                // Page Title + Date chip (moved below header)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            SizedBox(height: 6),
                            Text('Ongoing Patients', style: headingStyle),
                          ],
                        ),
                      ),
                      // current date chip (matches right top in HTML)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
                        ),
                        child: Text(DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()), style: subtitleStyle),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
                          ),
                          child: TextField(
                            controller: _searchCtl,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search),
                              hintText: 'Search by Patient ID / Name / Phone',
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                              hintStyle: const TextStyle(fontFamily: 'Lato'),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      TextButton.icon(
                        onPressed: _pickDateAndFilter,
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(_isFilteringByDate ? _selectedYmd() : 'All dates', style: const TextStyle(fontFamily: 'Lato')),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtl.clear();
                          setState(() => _selectedDate = null);
                        },
                      )
                    ],
                  ),
                ),

                // Now-serving banner (kept but styled to match your palette)
                StreamBuilder<QuerySnapshot>(
                  stream: base.snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return _buildIndexErrorWidget(snap.error.toString());
                    }
                    if (!snap.hasData || snap.data!.docs.isEmpty) {
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('No patients are waiting right now', style: TextStyle(fontSize: 16)),
                      );
                    }

                    final allDocs = snap.data!.docs;

                    if (!_alreadyAttemptedRepair) {
                      final map = <String, Map<int, int>>{};
                      for (final d in allDocs) {
                        final data = d.data() as Map<String, dynamic>? ?? {};
                        final cd = (data['clinicDate'] ?? 'unknown').toString();
                        final tnum = (data['tokenNumber'] is num) ? (data['tokenNumber'] as num).toInt() : _toIntToken(data['token']);
                        if (tnum != null) {
                          map[cd] ??= {};
                          map[cd]![tnum] = (map[cd]![tnum] ?? 0) + 1;
                        }
                      }

                      bool hasDup = false;
                      map.forEach((k, v) {
                        v.forEach((token, count) {
                          if (count > 1) hasDup = true;
                        });
                      });

                      if (hasDup) {
                        _alreadyAttemptedRepair = true;
                        _repairTokensForAllDates(allDocs.cast<QueryDocumentSnapshot>());
                      }
                    }

                    final sortedAll = _sortByTokenNumber(allDocs.cast<QueryDocumentSnapshot>());

                    final uid = (_currentUid ?? FirebaseAuth.instance.currentUser?.uid) ?? '';
                    List<QueryDocumentSnapshot> visibleForBanner;
                    if (_currentRole == 'doctor' && uid.isNotEmpty) {
                      visibleForBanner = sortedAll.where((d) {
                        final data = d.data() as Map<String, dynamic>? ?? {};
                        final docDoctorUid = (data['doctorUid'] ?? data['assignedDoctorUid'] ?? '').toString().trim();
                        final docStaffUid = (data['staffUid'] ?? data['createdByStaff'] ?? '').toString().trim();
                        return docDoctorUid == uid || docStaffUid == uid;
                      }).toList();
                    } else {
                      visibleForBanner = sortedAll;
                    }

                    if (visibleForBanner.isEmpty) {
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('No patients are waiting right now', style: TextStyle(fontSize: 16)),
                      );
                    }

                    final doc = visibleForBanner.first;
                    final d = doc.data() as Map<String, dynamic>? ?? {};
                    final token = (d['tokenNumber'] != null) ? d['tokenNumber'].toString() : (d['token']?.toString() ?? '-');
                    final pid = d['patientId'] ?? '';

                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                      decoration: BoxDecoration(
                        color: ayuBanner,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
                      ),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Now serving', style: TextStyle(fontSize: 12, color: Colors.black54)),
                              const SizedBox(height: 6),
                              Text('$token', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: bannerTextGreen)),
                              const SizedBox(height: 4),
                              Text('Patient ID: $pid', style: const TextStyle(color: Colors.black87)),
                            ],
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: () => _viewRecord(doc),
                            icon: const Icon(Icons.info_outline),
                            label: const Text('Details'),
                              style: ElevatedButton.styleFrom(
    backgroundColor: ayuTeal,
    foregroundColor: Colors.white, // ← THIS makes the text white
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 14),

                // Centered table-like card (matches the HTML visual)
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: base.snapshots(),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snap.hasError) {
                        return _buildIndexErrorWidget(snap.error.toString());
                      }
                      final docs = snap.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const Center(child: Text('No ongoing patients.'));
                      }

                      List<QueryDocumentSnapshot> sorted = _sortByTokenNumber(docs.cast<QueryDocumentSnapshot>());

                      final uid = (_currentUid ?? FirebaseAuth.instance.currentUser?.uid) ?? '';
                      List<QueryDocumentSnapshot> roleFiltered;
                      if (_currentRole == 'doctor' && uid.isNotEmpty) {
                        roleFiltered = sorted.where((d) {
                          final data = d.data() as Map<String, dynamic>? ?? {};
                          final docDoctorUid = (data['doctorUid'] ?? data['assignedDoctorUid'] ?? '').toString().trim();
                          final docStaffUid = (data['staffUid'] ?? data['createdByStaff'] ?? '').toString().trim();
                          return docDoctorUid == uid || docStaffUid == uid;
                        }).toList();
                      } else {
                        roleFiltered = sorted;
                      }

                      final search = _searchCtl.text.trim().toLowerCase();
                      List<QueryDocumentSnapshot> filtered = roleFiltered;
                      if (search.isNotEmpty) {
                        filtered = roleFiltered.where((d) {
                          final data = d.data() as Map<String, dynamic>;
                          final pid = (data['patientId'] ?? '').toString().toLowerCase();
                          final name = (data['name'] ?? '').toString().toLowerCase();
                          final phone = (data['phone'] ?? data['contact'] ?? '').toString().toLowerCase();
                          return pid == search || name.contains(search) || phone.contains(search);
                        }).toList();
                      }

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final cardWidth = constraints.maxWidth.clamp(600.0, 1100.0);
                          return SingleChildScrollView(
                            child: Center(
                              child: Container(
                                width: cardWidth,
                                margin: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 14, offset: Offset(0, 8))],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // header / column titles
                                    Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                      decoration: const BoxDecoration(
                                        border: Border(bottom: BorderSide(color: Color(0xFFF0EFEF))),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(flex: 3, child: Text('FULL NAME', style: tableHeaderStyle)),
                                          Expanded(flex: 2, child: Text('PATIENT ID', style: tableHeaderStyle)),
                                          Expanded(flex: 1, child: Text('TOKEN', style: tableHeaderStyle)),
                                          const SizedBox(width: 16),
                                          SizedBox(width: 160, child: Text('ACTIONS', textAlign: TextAlign.right, style: tableHeaderStyle)),
                                        ],
                                      ),
                                    ),

                                    // rows
                                    const SizedBox(height: 6),
                                    ...filtered.map((doc) {
                                      final data = doc.data() as Map<String, dynamic>? ?? {};
                                      final tokenDisplay = (data['tokenNumber'] != null)
                                          ? data['tokenNumber'].toString()
                                          : (data['token']?.toString() ?? '-');
                                      final patientId = data['patientId'] ?? '';
                                      final name = data['name'] ?? 'Patient';
                                      final phone = data['phone'] ?? data['contact'] ?? '';

                                      return Container(
                                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                                        decoration: const BoxDecoration(
                                          border: Border(bottom: BorderSide(color: Color(0xFFFAFAFA))),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Expanded(flex: 3, child: Text(name.toString(), style: tableRowName)),
                                            Expanded(flex: 2, child: Text(patientId.toString(), style: const TextStyle(color: Colors.black87))),
                                            Expanded(flex: 1, child: Text(tokenDisplay.toString(), style: const TextStyle(color: Colors.black87))),
                                            const SizedBox(width: 16),
                                            SizedBox(
                                              width: 160,
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  ElevatedButton(
                                                    onPressed: () {
                                                      // navigate to PatientEntryScreen with same prefill logic (exactly like popup's Call Patient)
                                                      final token = data['tokenNumber']?.toString() ?? (data['token']?.toString() ?? '-');
                                                      final patientIdLocal = data['patientId'] ?? '';
                                                      final startDate = data['startDate'] != null ? data['startDate'].toString().split('T').first : null;

                                                      final Map<String, dynamic> prefill = Map<String, dynamic>.from(data);
                                                      prefill['staffPatientDocId'] = doc.id;
                                                      prefill['staffUid'] = data['staffUid'] ?? data['createdByStaff'] ?? FirebaseAuth.instance.currentUser?.uid;
                                                      prefill['token'] = token;
                                                      prefill['tokenNumber'] = data['tokenNumber'] ?? _toIntToken(data['token']);
                                                      prefill['patientId'] = prefill['patientId'] ?? patientIdLocal;
                                                      prefill['startDate'] = prefill['startDate'] ?? startDate;
                                                      prefill['clinicDate'] = prefill['clinicDate'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
                                                      prefill['ongoingDocId'] = doc.id;

                                                      final String? targetDoctorUid = (data['doctorUid'] ?? data['assignedDoctorUid'] ?? widget.doctorUid) as String?;
                                                      final String? doctorPatientDocId = data['doctorPatientDocId'] as String?;

                                                      Navigator.of(context).push(
                                                        MaterialPageRoute(
                                                          builder: (_) => PatientEntryScreen(
                                                            prefill: prefill,
                                                            doctorUid: targetDoctorUid,
                                                            patientDocId: doctorPatientDocId,
                                                            onSave: (Patient saved) async {
                                                              if (mounted) {
                                                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Patient details saved by doctor')));
                                                              }

                                                              try {
                                                                final ongoingId = prefill['ongoingDocId'] as String?;
                                                                if (ongoingId != null && ongoingId.isNotEmpty) {
                                                                  await FirebaseFirestore.instance.collection('ongoingPatients').doc(ongoingId).update({
                                                                    'status': 'called',
                                                                    'calledAt': FieldValue.serverTimestamp(),
                                                                    'calledBy': 'doctor',
                                                                  });
                                                                }
                                                              } catch (e) {
                                                                if (mounted) {
                                                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed updating waiting entry: $e')));
                                                                }
                                                              }
                                                            },
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                     style: ElevatedButton.styleFrom(
    backgroundColor: ayuTeal,
    foregroundColor: Colors.white, // ← THIS makes the text white
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  ),
                                                    child: const Text('Call Patient'),
                                                    
                                                  ),
                                                ],
                                              ),
                                            )
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
          )]
      )
    );
  }
}

// Simple widget for sidebar items (keeps visual consistent)
class _SidebarMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SidebarMenuItem({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = active ? Colors.white24 : Colors.transparent;
    final leftAccent = active ? Colors.orangeAccent.withOpacity(0.98) : Colors.transparent;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
        ),
        child: Row(
          children: [
            // left accent bar when active
            Container(width: 6, height: 36, color: leftAccent),
            const SizedBox(width: 10),
            Icon(icon, color: Colors.white70),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

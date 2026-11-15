// lib/screens/patient_home_page.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:flutter/foundation.dart' show kIsWeb, consolidateHttpClientResponseBytes;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_file/open_file.dart';

// --- DESIGN CONSTANTS FOR AyuTech ---
// --- AYUTECH DESIGN SYSTEM ---
const Color kBackgroundColor = Color(0xFFF7F5EC); // same as admin bg
const Color kPrimaryGreen   = Color(0xFF2F6A5A); // main brand green
const Color kGreenDark      = Color(0xFF154E46); // headers / goal card
const Color kGreenSoft      = Color(0xFFE7F2EF); // soft chips / icons

const Color kGoldAccent     = Color(0xFFD6A657); // billing / revenue

const Color kDarkText       = Color(0xFF1B4332);
const Color kLightText      = Colors.black54;
const Color kCardColor      = Colors.white;

const double kCardRadius = 16.0;



class PatientHomePage extends StatefulWidget {
  final String patientId;
  const PatientHomePage({Key? key, required this.patientId}) : super(key: key);

  @override
  State<PatientHomePage> createState() => _PatientHomePageState();
}

class _PatientHomePageState extends State<PatientHomePage> {
  String? _patientDocId;
  bool _findingDoc = false;
  String? dietPdfUrl;
bool isLoadingDietPdf = true;


  Future<void> _ensurePatientDocId() async {
    if (_patientDocId != null || _findingDoc) return;
    _findingDoc = true;
    try {
      final q = await FirebaseFirestore.instance
          .collection('patients')
          .where('patientId', isEqualTo: widget.patientId)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) {
  _patientDocId = q.docs.first.id;
  await loadDietPdf(); // ✅ CALL HERE
} else {
        _patientDocId = null;
      }
    } catch (_) {
      _patientDocId = null;
    } finally {
      _findingDoc = false;
      if (mounted) setState(() {});
    }
  }

Future<void> loadDietPdf() async {
  if (_patientDocId == null) return;

  final doc = await FirebaseFirestore.instance
      .collection("patients")
      .doc(_patientDocId)
      .collection("documents")
      .doc("diet")
      .get();

  if (!doc.exists) return;

  final path = doc.data()?["localPath"];
  if (path != null && File(path).existsSync()) {
    await OpenFile.open(path);
  }
}


  Future<void> _prebookAppointment(DateTime date) async {
    await FirebaseFirestore.instance.collection('appointments').add({
      'patientId': widget.patientId,
      'date': Timestamp.fromDate(date),
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'prebooked',
      'type': 'prebook',
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Appointment prebooked for ${date.toLocal().toString().split(' ')[0]}')),
      );
    }
  }

@override
void initState() {
  super.initState();
  _ensurePatientDocId();
}



  Future<void> _createPdfRequest({
    required String type,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to request documents.')));
      return;
    }

    if (!['diet', 'billing', 'report'].contains(type)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid request type')));
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('pdfRequests').add({
        'patientId': widget.patientId,
        'patientDocId': _patientDocId ?? '',
        'type': type,
        'status': 'pending',
        'requestedBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request created. Staff will handle it soon.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create request: $e')));
    }
  }

  Stream<int> _pendingRequestCountStream(String type) {
    return FirebaseFirestore.instance
        .collection('pdfRequests')
        .where('patientId', isEqualTo: widget.patientId)
        .where('type', isEqualTo: type)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.size);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTopSection(width),
                  const SizedBox(height: 24),
                  _buildDailyHealthSnapshot(),
                  const SizedBox(height: 24),
                  _buildQuickActionsAndDoctorSection(width),
                  const SizedBox(height: 24),
                  _buildAppointmentsSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Top row layout tuned to match screenshot: left big profile, center ayurvedic, right stacked goal + allergy
  Widget _buildTopSection(double width) {
    final bool isLarge = width > 900;

    // Profile card — fetches patient doc and displays name/id/age/sex/height/weight/bmi/prakriti/vikriti/allergies
    Widget profileCard = Container(
      constraints: const BoxConstraints(minHeight: 230),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(kCardRadius),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: _patientDocId == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Patient', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: kDarkText)),
                const SizedBox(height: 8),
                Text('Resolving patient details...', style: TextStyle(color: kLightText)),
              ],
            )
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('patients').doc(_patientDocId).snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Patient', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: kDarkText)),
                      const SizedBox(height: 8),
                      Text('Error loading patient.', style: TextStyle(color: kLightText)),
                    ],
                  );
                }
                if (!snap.hasData) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Patient', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: kDarkText)),
                      const SizedBox(height: 8),
                      Text('Loading patient details...', style: TextStyle(color: kLightText)),
                    ],
                  );
                }

                final data = snap.data!.data() as Map<String, dynamic>? ?? {};

                final name = (data['name'] as String?)?.trim() ?? 'Unnamed Patient';
                final pid = (data['patientId'] as String?)?.trim() ?? widget.patientId;
                final sex = (data['sex'] as String?)?.trim() ?? '';
                final age = data['age'] != null ? data['age'].toString() : '';
                final height = (data['height'] != null) ? data['height'].toString() : '';
                final weight = (data['weight'] != null) ? data['weight'].toString() : '';
                final bmi = (data['bmi'] != null) ? data['bmi'].toString() : '';
                final prakriti = (data['prakriti'] as String?)?.trim() ?? '';
                final vikriti = (data['vikriti'] as String?)?.trim() ?? '';
                final allergiesRaw = data['allergies'];
                String allergyText = '';
                if (allergiesRaw is List) {
                  allergyText = allergiesRaw.map((e) => e.toString()).join(', ');
                } else if (allergiesRaw is String) {
                  allergyText = allergiesRaw;
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: kDarkText)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('ID: $pid', style: TextStyle(color: kLightText)),
                        const SizedBox(width: 14),
                        Text('${sex.isNotEmpty ? sex : '—'}${age.isNotEmpty ? ', $age' : ''}', style: TextStyle(color: kLightText)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildProfileMetric('HEIGHT', height.isNotEmpty ? '$height cm' : '—'),
                        _buildProfileMetric('WEIGHT', weight.isNotEmpty ? '$weight kg' : '—'),
                        _buildProfileMetric('BMI', bmi.isNotEmpty ? bmi : '—'),
                        CircleAvatar(radius: 34, backgroundColor: kBackgroundColor),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.check_circle, size: 16, color: kPrimaryGreen),
                        const SizedBox(width: 6),
                        Text(
                          'Last Updated: ${data['lastUpdated'] != null ? (data['lastUpdated'] is Timestamp ? (data['lastUpdated'] as Timestamp).toDate().toLocal().toString().split(' ')[0] : data['lastUpdated'].toString()) : '—'}',
                          style: TextStyle(fontSize: 12, color: kPrimaryGreen),
                        ),
                        const Spacer(),
                        TextButton(onPressed: () {}, child: Text('View Full Profile >', style: TextStyle(color: kPrimaryGreen))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // show a compact line of chips if present
                    Row(
                      children: [
                        if (prakriti.isNotEmpty)
                          Chip(label: Text('Prakriti: $prakriti', style: TextStyle(color: kPrimaryGreen)), backgroundColor: kPrimaryGreen.withOpacity(0.06)),
                        if (vikriti.isNotEmpty) const SizedBox(width: 6),
                        if (vikriti.isNotEmpty)
                          Chip(label: Text('Vikriti: $vikriti', style: TextStyle(color: Colors.deepOrange.shade700)), backgroundColor: Colors.deepOrange.shade50),
                        if (allergyText.isNotEmpty) const SizedBox(width: 6),
                        if (allergyText.isNotEmpty)
                          Chip(label: Text('Allergies: $allergyText', style: TextStyle(color: Colors.red.shade700)), backgroundColor: Colors.red.shade50),
                      ],
                    ),
                  ],
                );
              },
            ),
    );

    // Ayurvedic card — now reads agniType & dietType from patient doc
    Widget ayurvedicCard = Container(
      constraints: const BoxConstraints(minHeight: 230),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(kCardRadius),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: _patientDocId == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ayurvedic Constitution', style: TextStyle(fontWeight: FontWeight.bold, color: kDarkText)),
                const SizedBox(height: 12),
                Container(
                  height: 110,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200)),
                  child: Text('Dosha Chart Placeholder', style: TextStyle(color: kLightText)),
                ),
              ],
            )
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('patients').doc(_patientDocId).snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ayurvedic Constitution', style: TextStyle(fontWeight: FontWeight.bold, color: kDarkText)),
                      const SizedBox(height: 12),
                      Container(
                        height: 110,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200)),
                        child: Text('Dosha Chart Placeholder', style: TextStyle(color: kLightText)),
                      ),
                    ],
                  );
                }
                if (!snap.hasData) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ayurvedic Constitution', style: TextStyle(fontWeight: FontWeight.bold, color: kDarkText)),
                      const SizedBox(height: 12),
                      Container(
                        height: 110,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200)),
                        child: Text('Dosha Chart Placeholder', style: TextStyle(color: kLightText)),
                      ),
                    ],
                  );
                }

                final data = snap.data!.data() as Map<String, dynamic>? ?? {};
                final agniType = (data['agniType'] as String?)?.trim() ?? '—';
                final dietType = (data['dietType'] as String?)?.trim() ?? '—';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ayurvedic Constitution', style: TextStyle(fontWeight: FontWeight.bold, color: kDarkText)),
                    const SizedBox(height: 10),
                    Container(
                      height: 110,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200)),
                      child: Text('Dosha Chart Placeholder', style: TextStyle(color: kLightText)),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('AGNI TYPE:', style: TextStyle(fontSize: 12, color: kLightText)),
                        Chip(
                          label: Text(agniType, style:TextStyle(color: kGreenDark)
),
                          backgroundColor: kGreenSoft,

                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('DIET TYPE:', style: TextStyle(fontSize: 12, color: kLightText)),
                        Chip(
                          label: Text(dietType, style: TextStyle(color: kPrimaryGreen)),
                          backgroundColor: kPrimaryGreen.withOpacity(0.1),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
    );





    // Goal card (green) — now reads currentGoal & goalProgress from patient doc (if present)
    Widget goalCard = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kGreenDark,

        borderRadius: BorderRadius.circular(kCardRadius),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: _patientDocId == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Current Goal', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                SizedBox(height: 6),
                Text('Loading...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
              ],
            )
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('patients').doc(_patientDocId).snapshots(),
              builder: (context, snap) {
                String currentGoal = 'No goal set';
                double goalProgress = 0.0;
                if (snap.hasData) {
                  final data = snap.data!.data() as Map<String, dynamic>? ?? {};
                  currentGoal = (data['currentGoal'] as String?)?.trim() ?? currentGoal;
                  final gp = data['goalProgress'];
                  if (gp is num) goalProgress = gp.toDouble().clamp(0.0, 1.0);
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Current Goal', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                    const SizedBox(height: 6),
                    Text(currentGoal, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: goalProgress,
                      backgroundColor: kPrimaryGreen.withOpacity(0.5),
                      color: Colors.white,
                    ),
                    const SizedBox(height: 4),
                    Align(alignment: Alignment.centerRight, child: Text('${(goalProgress * 100).toStringAsFixed(0)}% Achieved', style: const TextStyle(color: Colors.white70, fontSize: 11))),
                  ],
                );
              },
            ),
    );

    // Allergy card — make it dynamic by reading allergies from patient doc if present
    Widget allergyCard = Container(
      height: 90,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(kCardRadius),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: _patientDocId == null
          ? Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Text('ALLERGY ALERT', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade700, fontSize: 12)),
              ],
            )
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('patients').doc(_patientDocId).snapshots(),
              builder: (context, snap) {
                List<String> allergyList = [];
                if (snap.hasData) {
                  final data = snap.data!.data() as Map<String, dynamic>? ?? {};
                  final a = data['allergies'];
                  if (a is List) {
                    allergyList = a.map((e) => e.toString()).toList();
                  } else if (a is String && a.trim().isNotEmpty) {
                    allergyList = [a.trim()];
                  }
                }

                return Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ALLERGY ALERT', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade700, fontSize: 12)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            children: allergyList.isEmpty
                                ? [const Text('No known allergies', style: TextStyle(fontSize: 12))]
                                : allergyList.map((x) => Chip(label: Text(x), backgroundColor: Colors.white)).toList(),
                          )
                        ],
                      ),
                    )
                  ],
                );
              },
            ),
    );

    if (isLarge) {
      // Three-column top row: profile | ayurvedic | right stack (goal + allergy)
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 5, child: profileCard),
          const SizedBox(width: 18),
          Expanded(flex: 3, child: ayurvedicCard),
          const SizedBox(width: 18),
          // right column with stacked goal + allergy
          Expanded(
            flex: 2,
            child: Column(
              children: [
                goalCard,
                const SizedBox(height: 18),
                allergyCard,
              ],
            ),
          ),
        ],
      );
    } else {
      // Mobile / narrow layout: stack vertically in same order but more compact spacing
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          profileCard,
          const SizedBox(height: 14),
          ayurvedicCard,
          const SizedBox(height: 14),
          goalCard,
          const SizedBox(height: 12),
          allergyCard,
        ],
      );
    }
  }

  Widget _buildProfileMetric(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 11, color: kLightText, letterSpacing: 0.8)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kPrimaryGreen)),
      ],
    );
  }

  Widget _buildDailyHealthSnapshot() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Daily Health Snapshot', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kDarkText)),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          final isWide = constraints.maxWidth > 900;
          final crossAxis = isWide ? 4 : 2;
          return GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxis,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 3.0,
            ),
            children: [
              _buildSnapshotMetric('2.4 L', 'WATER INTAKE', Icons.water_drop, Colors.blue.shade400),
              _buildSnapshotMetric('8,432', 'STEPS TAKEN', Icons.directions_walk, Colors.orange.shade400),
              _buildSnapshotMetric('7 h 15 m', 'SLEEP', Icons.bedtime, Colors.purple.shade400),
              _buildSnapshotMetric('72.5 kg', 'CURRENT WEIGHT', Icons.scale, kPrimaryGreen),
            ],
          );
        })
      ],
    );
  }

  Widget _buildSnapshotMetric(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kDarkText)),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 11, color: kLightText)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildQuickActionsAndDoctorSection(double width) {
    final bool isLarge = width > 800;

    Widget quickActionsCard = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(kCardRadius),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kDarkText)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildQuickActionButton(Icons.add, 'Book Appt.'),
              _buildQuickActionButton(Icons.upload_file, 'Upload Report'),
              _buildQuickActionButton(Icons.note_alt_rounded, 'Diet Chart'),
            ],
          ),
        ],
      ),
    );

    Widget assignedDoctorCard = _buildAssignedDoctorCard();

    if (isLarge) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: quickActionsCard),
          const SizedBox(width: 18),
          Expanded(flex: 2, child: assignedDoctorCard),
        ],
      );
    } else {
      return Column(children: [quickActionsCard, const SizedBox(height: 18), assignedDoctorCard]);
    }
  }

  /// Builds the Assigned Doctor card.
  /// Behavior:
  /// - Reads patient document.
  /// - If patient doc contains 'assignedDoctor' (Map) it uses that.
  /// - Else if patient doc contains 'assignedDoctorId' it fetches doctor doc from 'doctors' collection.
  /// - Falls back to a simple placeholder if nothing found.
  Widget _buildAssignedDoctorCard() {
    if (_patientDocId == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(kCardRadius),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Assigned Doctor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kDarkText)),
            const SizedBox(height: 12),
            const Text('Resolving doctor...', style: TextStyle(color: kLightText)),
          ],
        ),
      );
    }

    final patientRef = FirebaseFirestore.instance.collection('patients').doc(_patientDocId);
    return StreamBuilder<DocumentSnapshot>(
      stream: patientRef.snapshots(),
      builder: (context, patientSnap) {
        if (patientSnap.hasError) {
          return _styledSimpleCard('Assigned Doctor', 'Error loading doctor info', Icons.person);
        }
        if (!patientSnap.hasData) {
          return _styledSimpleCard('Assigned Doctor', 'Loading doctor info...', Icons.person);
        }

        final pdata = patientSnap.data!.data() as Map<String, dynamic>? ?? {};

        // Try inline assignedDoctor map first
        final assignedDoctorMap = pdata['assignedDoctor'];
        final assignedDoctorId = (pdata['assignedDoctorId'] as String?)?.trim();

        if (assignedDoctorMap is Map && assignedDoctorMap.isNotEmpty) {
          // Use inline map
          final dname = (assignedDoctorMap['name'] as String?)?.trim() ?? 'Doctor';
          final dqual = (assignedDoctorMap['qualification'] as String?)?.trim() ?? '';
          final dspec = (assignedDoctorMap['specialty'] as String?)?.trim() ?? '';
          final dphone = (assignedDoctorMap['phone'] as String?)?.trim() ?? '';
          final davail = (assignedDoctorMap['availableNow'] == true);

          return _assignedDoctorCardFromFields(dname, dqual, dspec, dphone, davail);
        }

        if (assignedDoctorId != null && assignedDoctorId.isNotEmpty) {
          // Fetch doctor doc from 'doctors' collection
          final doctorRef = FirebaseFirestore.instance.collection('doctors').doc(assignedDoctorId);
          return StreamBuilder<DocumentSnapshot>(
            stream: doctorRef.snapshots(),
            builder: (context, docSnap) {
              if (docSnap.hasError) return _styledSimpleCard('Assigned Doctor', 'Error loading doctor', Icons.person);
              if (!docSnap.hasData) return _styledSimpleCard('Assigned Doctor', 'Loading doctor...', Icons.person);

              final ddata = docSnap.data!.data() as Map<String, dynamic>? ?? {};
              final dname = (ddata['name'] as String?)?.trim() ?? 'Doctor';
              final dqual = (ddata['qualification'] as String?)?.trim() ?? '';
              final dspec = (ddata['specialty'] as String?)?.trim() ?? '';
              final dphone = (ddata['phone'] as String?)?.trim() ?? '';
              final davail = (ddata['availableNow'] == true);

              return _assignedDoctorCardFromFields(dname, dqual, dspec, dphone, davail);
            },
          );
        }

        // Nothing present — fallback placeholder
        return _styledSimpleCard('Assigned Doctor', 'No doctor assigned yet.', Icons.person);
      },
    );
  }

  // Helper to build the assigned doctor card UI from simple fields
  Widget _assignedDoctorCardFromFields(String name, String qualification, String specialty, String phone, bool availableNow) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(kCardRadius),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Assigned Doctor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kDarkText)),
          const SizedBox(height: 12),
          Row(
            children: [
              const CircleAvatar(radius: 20, backgroundColor: kBackgroundColor, child: Icon(Icons.person, color: kPrimaryGreen)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: kDarkText)),
                    if (qualification.isNotEmpty || specialty.isNotEmpty)
                      Text(
                        ((qualification.isNotEmpty ? qualification : '') + (qualification.isNotEmpty && specialty.isNotEmpty ? ' • ' : '') + (specialty.isNotEmpty ? specialty : '')).trim(),
                        style: TextStyle(fontSize: 12, color: kLightText),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
                child: Text(availableNow ? 'Available Now' : 'Unavailable', style: TextStyle(fontSize: 10, color: kPrimaryGreen, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () async {
                  if (phone.isNotEmpty) {
                    final uri = Uri(scheme: 'tel', path: phone);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    } else {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot dial number.')));
                    }
                  } else {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone number not available.')));
                  }
                },
                child: Icon(Icons.call, color: kPrimaryGreen),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('NEXT REVIEW', style: TextStyle(fontSize: 12, color: kLightText)),
              Text('Oct 24, 2024', style: TextStyle(fontWeight: FontWeight.bold, color: kDarkText)),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: () {}, child: Text('View Schedule', style: TextStyle(color: kPrimaryGreen))),
          )
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(IconData icon, String label) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: kPrimaryGreen,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: kCardColor, size: 30),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: kDarkText, fontSize: 12)),
      ],
    );
  }

  Widget _buildAppointmentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Dashboard Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kDarkText)),
        const SizedBox(height: 18),
        _buildDietChartCard(),
        const SizedBox(height: 14),
        _buildBillingCard(),
        const SizedBox(height: 14),
        _buildReviewDateCard(),
        const SizedBox(height: 14),
        _buildPrebookCard(),
      ],
    );
  }

  Widget _buildDietChartCard() {
    if (_patientDocId == null) {
      return _styledSimpleCard('Diet Chart', 'Resolving account details...', Icons.food_bank);
    }

    

    final docRef = FirebaseFirestore.instance.collection('patients').doc(_patientDocId);
    return StreamBuilder<DocumentSnapshot>(
      stream: docRef.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return _styledSimpleCard('Diet Chart', 'Error loading diet chart.', Icons.error);
        if (!snap.hasData) return _styledSimpleCard('Diet Chart', 'Loading diet chart...', Icons.food_bank);
        final data = snap.data!.data() as Map<String, dynamic>? ?? {};
        final dietUrl = dietPdfUrl;

        final dietName = (data['dietChartName'] as String?)?.trim();

        if (dietUrl == null || dietUrl.isEmpty) {
          return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kCardRadius)),
            color: kCardColor,
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: kPrimaryGreen.withOpacity(0.12),
                    child: const Icon(Icons.food_bank, color: kPrimaryGreen),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Diet Chart', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: kDarkText)),
                        const SizedBox(height: 6),
                        const Text('No diet chart available yet. Request one now.', style: TextStyle(color: kLightText)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: () => _createPdfRequest(type: 'diet'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kPrimaryGreen,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Request Diet Chart PDF', style: TextStyle(color: kCardColor)),
                            ),
                            const SizedBox(width: 10),
                            StreamBuilder<int>(
                              stream: _pendingRequestCountStream('diet'),
                              builder: (ctx, snapCount) {
                                final count = snapCount.data ?? 0;
                                if (count == 0) return const SizedBox.shrink();
                                return Chip(
                                  label: Text('$count pending', style: TextStyle(color: Colors.orange.shade900)),
                                  backgroundColor: Colors.orange.shade100,
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
          
        }

        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kCardRadius)),
          color: kCardColor,
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: kPrimaryGreen.withOpacity(0.12),
                  child: const Icon(Icons.picture_as_pdf, color: kPrimaryGreen),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Diet Chart', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: kDarkText)),
                      const SizedBox(height: 6),
                      Text(dietName ?? 'Diet chart available', style: const TextStyle(color: kLightText)),
                    ],
                  ),
                ),
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => _openUrl(dietUrl),
                      child: const Text('Open', style: TextStyle(color: kPrimaryGreen)),
                    ),
                    TextButton(
                      onPressed: () => _downloadAndOpen(context, dietUrl, dietName ?? 'dietchart.pdf'),
                      child: const Text('Download', style: TextStyle(color: kPrimaryGreen)),
                    ),
                    ElevatedButton(
                      onPressed: () => _createPdfRequest(type: 'diet'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Request Latest', style: TextStyle(color: kCardColor)),
                    ),
                    StreamBuilder<int>(
                      stream: _pendingRequestCountStream('diet'),
                      builder: (ctx, snapCount) {
                        final count = snapCount.data ?? 0;
                        if (count == 0) return const SizedBox.shrink();
                        return Chip(
                          label: Text('$count pending', style: TextStyle(color: Colors.orange.shade900)),
                          backgroundColor: Colors.orange.shade100,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBillingCard() {
    if (_patientDocId == null) {
      return _styledSimpleCard('Billing', 'Resolving account details...', Icons.receipt_long);
    }

    final patientDocRef = FirebaseFirestore.instance.collection('patients').doc(_patientDocId);
    final billingRef = patientDocRef.collection('billing');

    return StreamBuilder<DocumentSnapshot>(
      stream: patientDocRef.snapshots(),
      builder: (context, docSnap) {
        if (docSnap.hasError) return _styledSimpleCard('Billing', 'Error loading billing', Icons.error);
        if (!docSnap.hasData) return _styledSimpleCard('Billing', 'Loading billing...', Icons.receipt_long);

        final pdata = docSnap.data!.data() as Map<String, dynamic>? ?? {};
        final billingPdfUrl = (pdata['billingPdfUrl'] as String?)?.trim();
        final billingName = (pdata['billingPdfName'] as String?)?.trim();

        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kCardRadius)),
          color: kCardColor,
          elevation: 4,
          child: InkWell(
            borderRadius: BorderRadius.circular(kCardRadius),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => BillingDetailsScreen(patientDocId: _patientDocId!)));
            },
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: kPrimaryGreen.withOpacity(0.12),
                    child: const Icon(Icons.receipt_long, color: kPrimaryGreen),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Billing & Invoices', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: kDarkText)),
                        const SizedBox(height: 6),
                        StreamBuilder<QuerySnapshot>(
                          stream: billingRef.where('paid', isEqualTo: false).orderBy('createdAt', descending: true).limit(1).snapshots(),
                          builder: (context, snap) {
                            if (snap.hasError) return const Text('Error loading billing', style: TextStyle(color: kLightText));
                            if (!snap.hasData) return const Text('Loading billing...', style: TextStyle(color: kLightText));
                            final docs = snap.data!.docs;
                            if (docs.isEmpty) return const Text('No pending bills.', style: TextStyle(color: kLightText));

                            final m = docs.first.data() as Map<String, dynamic>;
                            final title = (m['title'] ?? 'Pending Bill').toString();
                            final amount = (m['amount'] ?? 0).toDouble();

                            return Text('*Pending:* $title - ₹${amount.toStringAsFixed(0)}', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold));
                          },
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: () => _createPdfRequest(type: 'billing'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kPrimaryGreen,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Request Bill PDF', style: TextStyle(color: kCardColor)),
                            ),
                            const SizedBox(width: 10),
                            if (billingPdfUrl != null && billingPdfUrl.isNotEmpty)
                              TextButton(
                                onPressed: () => _downloadAndOpen(context, billingPdfUrl, billingName ?? 'invoice.pdf'),
                                child: const Text('Download Latest', style: TextStyle(color: kPrimaryGreen)),
                              ),
                            StreamBuilder<int>(
                              stream: _pendingRequestCountStream('billing'),
                              builder: (ctx, snapCount) {
                                final count = snapCount.data ?? 0;
                                if (count == 0) return const SizedBox.shrink();
                                return Chip(
                                  label: Text('$count pending', style: TextStyle(color: Colors.orange.shade900)),
                                  backgroundColor: Colors.orange.shade100,
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.black26),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReviewDateCard() {
    final stream = FirebaseFirestore.instance
        .collection('appointments')
        .where('patientId', isEqualTo: widget.patientId)
        .where('type', isEqualTo: 'review')
        .orderBy('date', descending: true)
        .limit(1)
        .snapshots();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kCardRadius)),
      color: kCardColor,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: kPrimaryGreen.withOpacity(0.12),
              child: const Icon(Icons.event_note, color: kPrimaryGreen),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Next Review Appointment', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: kDarkText)),
                  const SizedBox(height: 6),
                  StreamBuilder<QuerySnapshot>(
                    stream: stream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Text('Fetching latest review date...', style: TextStyle(color: kLightText));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Text('No review date scheduled yet.', style: TextStyle(color: kLightText));
                      }
                      final data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                      final ts = data['date'] as Timestamp?;
                      if (ts == null) return const Text('No review date scheduled yet.', style: TextStyle(color: kLightText));
                      final date = ts.toDate();
                      return Text('Next review: ${date.toLocal().toString().split(' ')[0]}', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold));
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }

  Widget _buildPrebookCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kCardRadius)),
      color: kCardColor,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: kPrimaryGreen.withOpacity(0.12),
              child: const Icon(Icons.calendar_today, color: kPrimaryGreen),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Prebook Appointment', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: kDarkText)),
                  const SizedBox(height: 6),
                  const Text('Pick a date to request your next appointment.', style: TextStyle(color: kLightText)),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(const Duration(days: 3)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) await _prebookAppointment(picked);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Pick Date', style: TextStyle(color: kCardColor)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _styledSimpleCard(String title, String subtitle, IconData icon) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kCardRadius)),
      color: kCardColor,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: kPrimaryGreen.withOpacity(0.12),
              child: Icon(icon, color: kPrimaryGreen),
            ),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: kDarkText)),
                const SizedBox(height: 6),
                Text(subtitle, style: const TextStyle(color: kLightText)),
              ],
            )),
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await canLaunchUrl(uri)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot open link.')));
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _downloadAndOpen(BuildContext context, String url, String filename) async {
    final scaffold = ScaffoldMessenger.of(context);
    try {
      scaffold.showSnackBar(const SnackBar(content: Text('Downloading...')));

      if (url.startsWith('gs://') || url.contains('firebasestorage.googleapis.com')) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(url);
          final bytes = await ref.getData();
          if (bytes == null) throw 'No data';
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/$filename');
          await file.writeAsBytes(bytes);
          scaffold.hideCurrentSnackBar();
          if (!kIsWeb) await OpenFile.open(file.path);
          return;
        } catch (e) {
          // fallback
        }
      }

      if (kIsWeb) {
        scaffold.hideCurrentSnackBar();
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          scaffold.showSnackBar(const SnackBar(content: Text('Cannot open the file URL on web.')));
        }
        return;
      }

      final uri = Uri.parse(url);
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != 200) throw 'Download failed: ${response.statusCode}';

      final bytes = await consolidateHttpClientResponseBytes(response);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);
      scaffold.hideCurrentSnackBar();
      if (!kIsWeb) await OpenFile.open(file.path);
    } catch (e) {
      scaffold.hideCurrentSnackBar();
      scaffold.showSnackBar(SnackBar(content: Text('Download failed: $e')));
    }
  }
}

// Billing details screen (unchanged logic)
class BillingDetailsScreen extends StatelessWidget {
  final String patientDocId;
  const BillingDetailsScreen({Key? key, required this.patientDocId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final billingRef = FirebaseFirestore.instance.collection('patients').doc(patientDocId).collection('billing');
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text('Reports & Bills', style: TextStyle(color: kDarkText)),
        backgroundColor: kCardColor,
        iconTheme: IconThemeData(color: kDarkText),
        elevation: 2,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: StreamBuilder<QuerySnapshot>(
              stream: billingRef.orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snap) {
                if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snap.data!.docs;
                if (docs.isEmpty) return const Center(child: Text('No bills yet.'));
                return ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final d = docs[index];
                    final m = d.data()! as Map<String, dynamic>;
                    final title = m['title'] ?? 'Item';
                    final amount = (m['amount'] ?? 0).toString();
                    final paid = (m['paid'] ?? false) as bool;
                    final invoiceUrl = (m['invoiceUrl'] as String?)?.trim();
                    final dateString = m['createdAt'] != null ? (m['createdAt'] as Timestamp).toDate().toLocal().toString().split(' ')[0] : '';

                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kCardRadius)),
                      elevation: 2,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: paid ? kPrimaryGreen.withOpacity(0.12) : Colors.orange.shade100,
                          child: Icon(paid ? Icons.check_circle : Icons.pending, color: paid ? kPrimaryGreen : Colors.orange.shade700),
                        ),
                        title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: kDarkText)),
                        subtitle: Text('Date: $dateString | Status: ${paid ? "Paid" : "Pending"}', style: TextStyle(color: kLightText, fontSize: 12)),
                        trailing: Text('₹$amount', style: TextStyle(fontWeight: FontWeight.bold, color: paid ? kPrimaryGreen : Colors.red.shade700)),
                        onTap: invoiceUrl != null && invoiceUrl.isNotEmpty ? () async {
                          final uri = Uri.parse(invoiceUrl);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot open invoice link.')));
                          }
                        } : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

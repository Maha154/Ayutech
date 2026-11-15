// lib/screens/staff_patient_record_screen.dart
import 'dart:typed_data';

import 'package:ayutech/screens/billing_details_screen.dart';
import 'package:ayutech/screens/staff_home_screen.dart';
import 'package:ayutech/screens/patient_report_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// PDF / printing (ensure these packages are in pubspec.yaml)
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
// If you have a helper, keep this import; otherwise remove or implement generatePatientReport.
import 'package:ayutech/utils/pdf_generator.dart';
import 'package:open_file/open_file.dart';


class StaffPatientRecordScreen extends StatefulWidget {
  const StaffPatientRecordScreen({Key? key}) : super(key: key);

  @override
  State<StaffPatientRecordScreen> createState() => _StaffPatientRecordScreenState();
}

class _StaffPatientRecordScreenState extends State<StaffPatientRecordScreen> {




  // ===================== DIET FETCH & PDF EXPORT =====================





// ================================================================

  final TextEditingController _search = TextEditingController();
  String _statusFilter = 'All';

  final FirebaseFirestore _fire = FirebaseFirestore.instance;

  String _fmtDate(DateTime d) => DateFormat('dd MMMM yyyy').format(d);

  // ------------------ Design palette (from PatientReportScreen) ------------------
  final Color _primaryTeal = const Color(0xFF2F5C56);
  final Color _accentGold = const Color(0xFFD6A657);
  final Color _bgBody = const Color(0xFFFAFAF8);
  final Color _cardSurface = Colors.white;
  final Color _shadow = const Color(0x11000000);
  // ------------------------------------------------------------------------------

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }



  // Stream: patient docs for this staff (returns QueryDocumentSnapshot so we can get doc.id)
  Stream<QuerySnapshot> _patientsDocStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream<QuerySnapshot>.empty();
    return FirebaseFirestore.instance.collection("users").doc(uid).collection("patients").orderBy("createdAt", descending: true).snapshots();
  }

  Widget _buildHeaderCell(String title, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF374151),
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    // Keep this header (matches your previous table columns)
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF0EDE0),
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // aligned to match the second screenshot: small checkbox area + patient column.
          SizedBox(width: 28), // checkbox placeholder space
          const SizedBox(width: 12),
          Expanded(flex: 3, child: Text('PATIENT', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)))),
          Expanded(flex: 2, child: Text('TOKEN', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)))),
          Expanded(flex: 2, child: Text('PATIENT ID', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)))),
          Expanded(flex: 2, child: Text('STATUS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)))),
          Expanded(flex: 2, child: Text('BILLING UPDATE', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)))),
          Expanded(flex: 2, child: Text('START DATE', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)))),
          SizedBox(width: 120, child: Align(alignment: Alignment.centerRight, child: Text('ACTIONS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))))),
        ],
      ),
    );
  }

  Widget _buildTableRowFromDoc(QueryDocumentSnapshot doc) {
    // Keep this function as-is (user requested no logic changes).
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] ?? '';

    // token handling (kept as you already applied)
    final statusLower = (data['status'] ?? '').toString().toLowerCase();
    final rawToken = data['tokenNumber'] ?? data['token'];
    final token = (statusLower == 'ended') ? '-' : (rawToken == null || rawToken.toString().isEmpty) ? '-' : rawToken.toString();

    final patientId = data['patientId'] ?? doc.id;
    final status = (data['status'] ?? '--').toString();
    final billingStatus = (data['billingStatus'] ?? 'Unpaid').toString();
    final startDate = data['startDate'] is Timestamp ? (data['startDate'] as Timestamp).toDate() : DateTime.tryParse(data['startDate'] ?? '') ?? DateTime.now();

    // Build row matching the single-table layout (slightly adapted presentation only).
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // small checkbox placeholder
          const SizedBox(width: 12),

         

          // Patient avatar + name
          Expanded(
            flex: 3,
            child: Row(
              children: [
              
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    name.toString(),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Token
          Expanded(flex: 2, child: Text(token.toString(), style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)))),

          // Patient ID
          Expanded(flex: 2, child: Text(patientId.toString(), style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)))),

          // Status pill
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: status.toLowerCase() == 'active' ? const Color(0xFFDFF6EE) : const Color(0xFFF0F9FF).withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: status.toLowerCase() == 'active' ? const Color(0xFF166534) : const Color(0xFF0EA5E9),
                  ),
                ),
              ),
            ),
          ),

          // Billing update pill
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: billingStatus.toLowerCase() == 'paid' ? const Color(0xFFDFF6EE) : const Color(0xFFFFF5E6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  billingStatus,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: billingStatus.toLowerCase() == 'paid' ? const Color(0xFF166534) : const Color(0xFFB85B00),
                  ),
                ),
              ),
            ),
          ),

          // Start date
          Expanded(flex: 2, child: Text(_fmtDate(startDate), style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)))),

          // Actions (view + delete)
       SizedBox(
  width: 180,
  child: Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      OutlinedButton.icon(
        onPressed: () {
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => BillingDetailsScreen(
      patientDocId: doc.id, // ✅ staff patient doc id
      globalPatientDocId: data['globalPatientDocId'], // ✅ from Firestore
      patientData: data, // ✅ full patient map
    ),
  ),
);



        },
        icon: const Icon(Icons.remove_red_eye, size: 16),
        label: const Text('View'),
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: const BorderSide(color: Color(0xFF2F5C56)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
      ),

if ((data['status'] ?? '').toString().toLowerCase() == 'treated') ...[
  const SizedBox(width: 8),
  OutlinedButton.icon(
    onPressed: () {
      _openDietPdf(staffPatientDocId: doc.id);
    },
    icon: const Icon(Icons.picture_as_pdf, size: 16),
    label: const Text('Diet PDF'),
    style: OutlinedButton.styleFrom(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      side: const BorderSide(color: Colors.red),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
  ),
],


    ],
  ),
),

          

        ],
      ),
    );
  }





Future<void> _openDietPdf({
  required String staffPatientDocId,
}) async {
  final staffUid = FirebaseAuth.instance.currentUser!.uid;

  final docSnap = await FirebaseFirestore.instance
      .collection("users")
      .doc(staffUid)
      .collection("patients")
      .doc(staffPatientDocId)
      .collection("documents")
      .doc("diet")
      .get();

  if (!docSnap.exists || docSnap.data()?['localPath'] == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Diet PDF not available yet")),
    );
    return;
  }

  final String filePath = docSnap.data()!['localPath'];

  await OpenFile.open(filePath);
}


  // ------------------ Keep your billing/index/delete functions unchanged below ------------------
  Future<void> _saveBillingSummaryAndIndex({
    required String staffUid,
    required String staffPatientDocId,
    required num totalAmount,
    required String status,
  }) async {
    final FirebaseFirestore _fire = FirebaseFirestore.instance;
    try {
      final staffRef = _fire.collection('users').doc(staffUid).collection('patients').doc(staffPatientDocId);

      // Read existing staff doc to find global patient id / patientId
      final staffSnap = await staffRef.get();
      if (!staffSnap.exists) {
        debugPrint('staff patient doc not found: $staffPatientDocId');
        return;
      }
      final staffData = staffSnap.data() as Map<String, dynamic>? ?? {};

      final String? globalPatientDocId = (staffData['globalPatientDocId'] as String?)?.trim();
      final String patientId = (staffData['patientId'] ?? staffPatientDocId).toString();

      final now = FieldValue.serverTimestamp();
      final numeric = totalAmount;

      // 1) Create top-level billing doc for indexes / admin reads (helpful for collectionGroup or queries)
      await _fire.collection('billings').add({
        'patientId': patientId,
        'staffPatientDocId': staffPatientDocId,
        'globalPatientDocId': globalPatientDocId ?? '',
        'total': numeric,
        'amount': numeric,
        'billingTotal': numeric,
        'status': status,
        'billingStatus': status,
        'createdAt': now,
        'lastUpdatedAt': now,
      });

      // 2) Update staff copy with compact billing summary
      await staffRef.update({
        'billingTotal': numeric,
        'amountBilled': numeric,
        'lastBilled': numeric,
        'billingStatus': status,
        'lastBilledAt': now,
        'billingUpdatedAt': now,
      });

      // 3) Update global patient doc if present (so admin/global reads easily see billed amount)
      if (globalPatientDocId != null && globalPatientDocId.isNotEmpty) {
        final globalRef = _fire.collection('patients').doc(globalPatientDocId);
        await globalRef.set({
          'billingTotal': numeric,
          'amountBilled': numeric,
          'lastBilled': numeric,
          'billingStatus': status,
          'lastBilledAt': now,
          'billingUpdatedAt': now,
        }, SetOptions(merge: true));
      } else {
        // optionally try to update patients collection by patientId if you store that
        try {
          final q = await _fire.collection('patients').where('patientId', isEqualTo: patientId).limit(1).get();
          if (q.docs.isNotEmpty) {
            await q.docs.first.reference.set({
              'billingTotal': numeric,
              'amountBilled': numeric,
              'lastBilled': numeric,
              'billingStatus': status,
              'lastBilledAt': now,
              'billingUpdatedAt': now,
            }, SetOptions(merge: true));
          }
        } catch (_) {}
      }

      debugPrint('Billing summary saved: patientId=$patientId total=$numeric status=$status');
    } catch (e) {
      debugPrint('Failed saving billing summary: $e');
      rethrow;
    }
  }

  Future<void> _deletePatientAndCleanup(String uid, String staffPatientDocId) async {
    final staffPatientRef = _fire.collection('users').doc(uid).collection('patients').doc(staffPatientDocId);

    final staffSnap = await staffPatientRef.get();
    if (!staffSnap.exists) return;

    final staffData = staffSnap.data() as Map<String, dynamic>? ?? {};
    final String? globalId = (staffData['globalPatientDocId'] as String?)?.trim();
    final String? patientId = (staffData['patientId'] as String?)?.trim();

    final WriteBatch batch = _fire.batch();

    // 1) delete staff copy
    batch.delete(staffPatientRef);

    // 2) delete global doc and any ongoingPatients pointing to it
    if (globalId != null && globalId.isNotEmpty) {
      final globalRef = _fire.collection('patients').doc(globalId);
      batch.delete(globalRef);

      final ongoingQ = await _fire.collection('ongoingPatients').where('globalPatientDocId', isEqualTo: globalId).get();
      for (final d in ongoingQ.docs) {
        batch.delete(d.reference);
      }
    } else if (patientId != null && patientId.isNotEmpty) {
      // fallback: delete ongoingPatients by patientId
      final ongoingQ = await _fire.collection('ongoingPatients').where('patientId', isEqualTo: patientId).get();
      for (final d in ongoingQ.docs) {
        batch.delete(d.reference);
      }
    } else {
      // final fallback: try deleting ongoingPatients that reference this staff doc id
      final fallbackQ = await _fire.collection('ongoingPatients').where('staffPatientDocId', isEqualTo: staffPatientDocId).get();
      for (final d in fallbackQ.docs) {
        batch.delete(d.reference);
      }
    }

    await batch.commit();
  }
  // ------------------------------------------------------------------------------------

  // ----------------- Sidebar helper (re-usable) -----------------
  Widget _sideNavItem(String title, IconData icon, {bool active = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: active ? _primaryTeal.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: active ? Border(left: BorderSide(color: _accentGold, width: 4)) : null,
        ),
        child: Row(children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: TextStyle(color: Colors.white.withOpacity(active ? 1 : 0.9), fontWeight: active ? FontWeight.w700 : FontWeight.w600))),
          if (active) const Icon(Icons.chevron_right, color: Colors.white),
        ]),
      ),
    );
  }

  // -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBody,
      body: SafeArea(
        child: Row(
          children: [
            // SIDEBAR (kept visual style similar to admin page you provided)
            Container(
              width: 260,
              color: _primaryTeal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(children: [
                      Container(width: 52, height: 52, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child:  Icon(Icons.local_hospital, color: _primaryTeal)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                        Text('AyuTech', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                        SizedBox(height: 4),
                        Text('STAFF PANEL', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                      ]))
                    ]),
                  ),
                  const SizedBox(height: 18),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text('MAIN', style: TextStyle(color: Colors.white.withOpacity(0.6), fontWeight: FontWeight.w700))),
                  const SizedBox(height: 8),
                  _sideNavItem('Dashboard', Icons.dashboard_outlined, onTap: () {
                    // navigate back to dashboard/home
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const StaffHomeScreen()));
                  }),
                  _sideNavItem('Patient Records', Icons.folder_open, active: true, onTap: () {}),
                  _sideNavItem('Billing', Icons.receipt_long, onTap: () {}),
                  _sideNavItem('Reports', Icons.bar_chart, onTap: () {}),
                  const Spacer(),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0x15555555)))),
                    child: Row(children: [
                      Container(width: 46, height: 46, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white24)), child: const CircleAvatar(radius: 22, backgroundColor: Colors.white, child: Icon(Icons.person, color: Color(0xFF2F5C56)))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                        Text('Staff Member', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                        SizedBox(height: 4),
                        Text('Reception', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ])),
                    ]),
                  ),
                ],
              ),
            ),

            // MAIN CONTENT
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 4),

                  // Page title block
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Patient Records', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _primaryTeal)),
                        const SizedBox(height: 6),
                        Text('Find and manage patient records and billing details.', style: TextStyle(fontSize: 14, color: Colors.black54)),
                      ]),
                      // quick stats or total records can be placed here if desired
                      const SizedBox(width: 16),
                      // placeholder space for right-side controls
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Filters row (search + dropdowns)
                  Row(children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _search,
                        decoration: InputDecoration(
                          hintText: 'Search by name, token or patient ID...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _primaryTeal)),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _statusFilter,
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('Status')),
                          DropdownMenuItem(value: 'ongoing', child: Text('Ongoing')),
                          DropdownMenuItem(value: 'ended', child: Text('Ended')),
                        ],
                        onChanged: (v) => setState(() => _statusFilter = v ?? 'All'),
                        decoration: InputDecoration(filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB)))),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))), child: const Text('All Regions', style: TextStyle(color: Color(0xFF6B7280), fontSize: 16))),
                    const SizedBox(width: 16),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))), child: const Text('dd-mm-yyyy', style: TextStyle(color: Color(0xFF6B7280), fontSize: 16))),
                  ]),

                  const SizedBox(height: 24),

                  // Single large table card (like the second screenshot)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _cardSurface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: _shadow, blurRadius: 8, offset: const Offset(0, 4))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Top row inside card: title + view all
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Existing Patient Records', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _primaryTeal)),
                            Text('Total Records', style: TextStyle(color: _primaryTeal)),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Header
                        _buildTableHeader(),

                        // Table body - use stream for this staff's patients
                        StreamBuilder<QuerySnapshot>(
                          stream: _patientsDocStream(),
                          builder: (context, snap) {
                            if (snap.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()));
                            if (snap.hasError) return Center(child: Padding(padding: EdgeInsets.all(12), child: Text('Error loading patients: ${snap.error}')));
                            final docs = snap.data?.docs ?? [];

                            // Apply local filters
                            final q = _search.text.toLowerCase().trim();
                            final filteredDocs = docs.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final name = (data['name'] ?? '').toString().toLowerCase();
                              final region = (data['region'] ?? '').toString().toLowerCase();
                              final matchesQuery = q.isEmpty || name.contains(q) || region.contains(q) || (data['tokenNumber']?.toString().toLowerCase() ?? '').contains(q) || (data['patientId']?.toString().toLowerCase() ?? '').contains(q);
                              final matchesStatus = _statusFilter.toLowerCase() == 'all' ? true : (data['status'] ?? '').toString().toLowerCase() == _statusFilter.toLowerCase();
                              return matchesQuery && matchesStatus;
                            }).toList();

                            if (filteredDocs.isEmpty) {
                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 40),
                                child: const Center(child: Text('No patient records found.', style: TextStyle(color: Color(0xFF6B7280), fontSize: 16))),
                              );
                            }

                            return Column(
                              children: [
                                // map rows
                                ...List.generate(filteredDocs.length, (index) {
                                  final doc = filteredDocs[index];
                                  return Column(
                                    children: [
                                      _buildTableRowFromDoc(doc),
                                      // divider between rows
                                      Divider(color: Colors.grey.shade200, height: 1, indent: 72)

                                    ],
                                  );
                                }),
                                const SizedBox(height: 12),
                                // footer: showing x to y results & pagination placeholder
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                                      child: Text('Showing 1 to ${filteredDocs.length} of ${filteredDocs.length} results', style: const TextStyle(color: Color(0xFF6B7280))),
                                    ),
                                    Row(
                                     
                                    ),
                                  ],
                                )
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }


  
  // ----------------- Small UI helpers (styling only) -----------------
  Widget _sectionContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _cardSurface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: _shadow, blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }

  Widget _summaryCard({required String title, String? subtitle, String? value, required IconData icon, Color? color, bool wide = false, VoidCallback? onTap}) {
    return Expanded(
      flex: wide ? 4 : 2,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 92,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color == _primaryTeal ? _primaryTeal : _cardSurface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 4))],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color == _primaryTeal ? Colors.white24 : _bgBody, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color == _primaryTeal ? Colors.white : _primaryTeal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color == _primaryTeal ? Colors.white : Colors.black87)),
                  const SizedBox(height: 6),
                  Row(children: [
                    if (value != null) Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color == _primaryTeal ? Colors.white : _primaryTeal)),
                    const SizedBox(width: 8),
                    if (subtitle != null) Expanded(child: Text(subtitle, style: TextStyle(color: color == _primaryTeal ? Colors.white70 : Colors.black54))),
                  ]),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
  // -------------------------------------------------------------------
}

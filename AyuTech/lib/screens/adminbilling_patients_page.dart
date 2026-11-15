// lib/screens/adminbilling_patient_page.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// <-- new import for the admin home page (adjust path/name if needed)
import 'admin_home_page_all_in_one.dart';




class AdminBillingPatientPage extends StatefulWidget {
  const AdminBillingPatientPage({super.key});
  @override
  State<AdminBillingPatientPage> createState() => _AdminBillingPatientPageState();
}

class _AdminBillingPatientPageState extends State<AdminBillingPatientPage> {
  // theme colors tuned to match the provided screenshot
  static const Color _sideGreen = Color(0xFF2F5C56);
 // darker green for side & names
  static const Color _accentGold = Color(0xFFD6A657); // gold used in headings
  static const Color _pageBg = Color(0xFFF7F3EE); // warm off-white background
  static const Color _cardBg = Color(0xFFFFFFFF); // card white
  static const Color _mutedRow = Color(0xFFF7F4F6); // subtle row tint
final bool isAdmin = true;


// TODO: later replace with actual role check from auth/user doc


  

  final TextEditingController _searchCtl = TextEditingController();
  String _search = '';
  String? _filterDoctorId;
  String? _filterDept;

  Map<String, String> _doctorMap = {}; // docId or loginId -> name

  // cache billed amount futures to avoid repeated reads for same patient row
  final Map<String, Future<num>> _billedAmountCache = {};

  // NEW: cache for billing amount read from top-level/global patients doc
  final Map<String, Future<num>> _globalBillingCache = {};

  @override
  void initState() {
    super.initState();
    _loadDoctorNames();
    _searchCtl.addListener(() => setState(() => _search = _searchCtl.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _loadDoctorNames() async {
    try {
      final map = <String, String>{};

      // 1) try `doctors` collection if your project uses it
      try {
        final snap = await FirebaseFirestore.instance.collection('doctors').get();
        for (final d in snap.docs) {
          final data = d.data();
          final id = d.id;
          final name = (data['name'] ?? data['fullName'] ?? data['displayName'] ?? '').toString();
          final loginId = (data['loginId'] ?? data['doctorId'] ?? '').toString();
          if (name.isNotEmpty) {
            map[id] = name;
            if (loginId.isNotEmpty) map[loginId] = name;
          } else {
            map[id] = id;
            if (loginId.isNotEmpty) map[loginId] = id;
          }
        }
      } catch (e) {
        debugPrint('doctors collection read skipped/failed: $e');
      }

      // 2) load doctors stored under `users` where role == 'doctor'
      try {
        final snap = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'doctor').get();
        for (final d in snap.docs) {
          final data = d.data();
          final id = d.id;
          final name = (data['name'] ?? data['fullName'] ?? data['displayName'] ?? '').toString();
          final loginId = (data['loginId'] ?? data['username'] ?? '').toString();
          if (name.isNotEmpty) {
            map[id] = name;
            if (loginId.isNotEmpty) map[loginId] = name;
          } else {
            map[id] = id;
            if (loginId.isNotEmpty) map[loginId] = id;
          }
        }
      } catch (e) {
        debugPrint('users(role==doctor) read failed: $e');
      }

      if (mounted) setState(() => _doctorMap = map);
    } catch (e) {
      debugPrint('Failed loading doctor names: $e');
    }
  }

  String _fmtDate(dynamic ts) {
    try {
      if (ts == null) return '-';
      if (ts is Timestamp) {
        final d = ts.toDate();
        return '${d.day.toString().padLeft(2, '0')} ${_monthName(d.month)} ${d.year}';
      }
      if (ts is DateTime) {
        return '${ts.day.toString().padLeft(2, '0')} ${_monthName(ts.month)} ${ts.year}';
      }
      if (ts is String && ts.isNotEmpty) return ts;
    } catch (_) {}
    return '-';
  }

  String _monthName(int m) {
    const names = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return (m>=1 && m<=12) ? names[m-1] : '';
  }

  num _parseAmount(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    if (v is String) {
      final cleaned = v.replaceAll(RegExp(r'[^\d\.\-]'), '');
      return num.tryParse(cleaned) ?? 0;
    }
    return 0;
  }

  // extended status color mapping: handles billing status and patient 'ongoing/ended' states
  Color _statusColorBg(String s) {
    final v = s.toLowerCase();
    if (v.contains('paid')) return const Color(0xFFDFF6EE); // pale mint bg
    if (v.contains('pending')) return const Color(0xFFFFF1E6); // pale orange bg
    if (v.contains('unpaid')) return const Color(0xFFFEECEC); // pale red/pink bg
    if (v.contains('ongoing') || v.contains('active')) return const Color(0xFFDFF6EE); // treat ongoing/active as greenish bg
    if (v.contains('ended')) return const Color(0xFFFEECEC); // ended -> pale red bg
    return const Color(0xFFEDEDED);
  }

  Color _statusColorText(String s) {
    final v = s.toLowerCase();
    if (v.contains('paid')) return const Color(0xFF00694F); // dark mint text
    if (v.contains('pending')) return const Color(0xFFB85B00); // orange text
    if (v.contains('unpaid')) return const Color(0xFFDC2626); // red text
    if (v.contains('ongoing') || v.contains('active')) return const Color(0xFF166534); // green
    if (v.contains('ended')) return const Color(0xFFDC2626); // red
    return Colors.black54;
  }

  Future<void> _exportCsvRows(List<Map<String, dynamic>> rows) async {
    final sb = StringBuffer();
    sb.writeln('ID,Name,Doctor,LastVisit,Billed,Status');
    for (final r in rows) {
      final id = (r['id'] ?? '').toString().replaceAll(',', ' ');
      final name = (r['name'] ?? '').toString().replaceAll(',', ' ');
      final dr = (r['doctorName'] ?? '').toString().replaceAll(',', ' ');
      final lv = (r['lastVisit'] ?? '').toString().replaceAll(',', ' ');
      final billed = (r['billed'] ?? '').toString().replaceAll(',', ' ');
      final status = (r['status'] ?? '').toString().replaceAll(',', ' ');
      sb.writeln('$id,$name,$dr,$lv,$billed,$status');
    }
    await Clipboard.setData(ClipboardData(text: sb.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV copied to clipboard')));
  }

  // build charts data for revenue and billing history
  Future<Map<String, dynamic>> _computeChartsAndRevenue(List<QueryDocumentSnapshot> docs) async {
    final now = DateTime.now();
    final firstOfMonth = DateTime(now.year, now.month, 1);
    num revenueThisMonth = 0;
    final sumsByWeekday = List<num>.filled(7, 0);

    for (final doc in docs) {
      final data = (doc.data() as Map<String, dynamic>? ?? {});
      // pick billed amount from patient doc fields
      num billedAmt = 0;
      if (data.containsKey('amountBilled')) billedAmt = _parseAmount(data['amountBilled']);
      else if (data.containsKey('lastBilled')) billedAmt = _parseAmount(data['lastBilled']);
      else if (data.containsKey('billingAmount')) billedAmt = _parseAmount(data['billingAmount']);
      else if (data.containsKey('billingTotal')) billedAmt = _parseAmount(data['billingTotal']);
      // date
      dynamic billedDate;
      if (data.containsKey('billedAt')) billedDate = data['billedAt'];
      else if (data.containsKey('lastVisit')) billedDate = data['lastVisit'];
      else if (data.containsKey('lastBilledAt')) billedDate = data['lastBilledAt'];
      DateTime? billedDt;
      try {
        if (billedDate is Timestamp) billedDt = billedDate.toDate();
        else if (billedDate is DateTime) billedDt = billedDate;
        else if (billedDate is String && billedDate.isNotEmpty) billedDt = DateTime.tryParse(billedDate);
      } catch (_) {}
      if (billedDt != null) {
        if (billedDt.isAfter(firstOfMonth) || (billedDt.year == firstOfMonth.year && billedDt.month == firstOfMonth.month)) {
          revenueThisMonth += billedAmt;
        }
        final idx = (billedDt.weekday - 1).clamp(0,6);
        sumsByWeekday[idx] += billedAmt;
      }
    }

    return {'revenue': revenueThisMonth, 'weekly': sumsByWeekday};
  }

  /// Resolve numeric billed amount for a patient doc (try doc fields, then possible bill subcollections)
  Future<num> _resolveBilledAmountForPatientDoc(Map<String, dynamic> data, String docId) async {
    try {
      final tryKeys = [
        'billingTotal',
        'amountBilled',
        'lastBilled',
        'amountBilled',
        'amount',
        'billingAmount',
        'billingTotal',
        'totalBilled',
        'total',
        'amount',
        'grandTotal',
        'invoiceAmount'
      ];
      for (final k in tryKeys) {
        if (data.containsKey(k)) {
          final val = _parseAmount(data[k]);
          if (val > 0) {
            debugPrint('Found billed amount on patient doc $docId via $k -> $val');
            return val;
          }
        }
      }

      // try patients/{docId}/billings subcollection
      try {
        final collRef = FirebaseFirestore.instance.collection('patients').doc(docId).collection('billings');
        final snap = await collRef.orderBy('createdAt', descending: true).limit(1).get();
        if (snap.docs.isNotEmpty) {
          final bdata = snap.docs.first.data();
          for (final k in ['total','amount','grandTotal','billingTotal','invoiceAmount']) {
            if (bdata.containsKey(k)) {
              final a = _parseAmount(bdata[k]);
              if (a > 0) {
                debugPrint('Found billed amount under patients/$docId/billings -> $a');
                return a;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('patients/{docId}/billings read failed for $docId: $e');
      }

      // try top-level `billings` collection (patientId match)
      try {
        final possiblePid = (data['patientId'] ?? docId).toString();
        final snapTop = await FirebaseFirestore.instance.collection('billings').where('patientId', isEqualTo: possiblePid).orderBy('createdAt', descending: true).limit(1).get();
        if (snapTop.docs.isNotEmpty) {
          final bdata = snapTop.docs.first.data();
          for (final k in ['total','amount','grandTotal','billingTotal','invoiceAmount']) {
            if (bdata.containsKey(k)) {
              final a = _parseAmount(bdata[k]);
              if (a > 0) {
                debugPrint('Found billed amount in top-level billings for patientId $possiblePid -> $a');
                return a;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('top-level billings read failed: $e');
      }

      // try collectionGroup('billings')
      try {
        final possiblePid = (data['patientId'] ?? docId).toString();
        final cg = await FirebaseFirestore.instance.collectionGroup('billings').where('patientId', isEqualTo: possiblePid).orderBy('createdAt', descending: true).limit(1).get();
        if (cg.docs.isNotEmpty) {
          final bdata = cg.docs.first.data();
          for (final k in ['total','amount','grandTotal','billingTotal','invoiceAmount']) {
            if (bdata.containsKey(k)) {
              final a = _parseAmount(bdata[k]);
              if (a > 0) {
                debugPrint('Found billed amount via collectionGroup for $possiblePid -> $a');
                return a;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('collectionGroup billings search failed (maybe index needed): $e');
      }
    } catch (e) {
      debugPrint('resolve billed amount error for $docId: $e');
    }

    return 0;
  }

  Future<num> _getBilledAmount(String docId, Map<String, dynamic> docData) {
    if (_billedAmountCache.containsKey(docId)) return _billedAmountCache[docId]!;
    final f = _resolveBilledAmountForPatientDoc(docData, docId);
    _billedAmountCache[docId] = f;
    return f;
  }

  // NEW: Attempt to read billing amount from top-level/global patients doc (the one BillingDetailsScreen writes to).
  // This tries common keys for a global doc id or searches by patientId.
  Future<num> _getBillingFromGlobalDocIfAny(Map<String, dynamic> staffData, String staffDocId) {
    // use staffDocId as cache key (fast)
    if (_globalBillingCache.containsKey(staffDocId)) return _globalBillingCache[staffDocId]!;

    final f = () async {
      try {
        // 1) Many staff docs already mirror a reference to global doc id under common keys
        String? globalId = (staffData['globalPatientDocId'] ?? staffData['globalId'] ?? staffData['patientDocId'])?.toString();
        if (globalId != null && globalId.isNotEmpty) {
          try {
            final snap = await FirebaseFirestore.instance.collection('patients').doc(globalId).get();
            if (snap.exists) {
              final g = snap.data() as Map<String, dynamic>? ?? {};
              // check common amount keys
              final keys = ['billingAmount', 'billingTotal', 'amountBilled', 'amount', 'total', 'grandTotal', 'invoiceAmount'];
              for (final k in keys) {
                if (g.containsKey(k)) {
                  final val = _parseAmount(g[k]);
                  if (val > 0) return val;
                }
              }
            }
          } catch (e) {
            debugPrint('global doc read by id failed: $e');
          }
        }

        // 2) fallback: try find global doc by patientId field (best-effort)
        final pid = (staffData['patientId'] ?? staffData['patientIdString'] ?? staffData['patientId'])?.toString() ?? '';
        if (pid.isNotEmpty) {
          try {
            final q = await FirebaseFirestore.instance.collection('patients').where('patientId', isEqualTo: pid).limit(1).get();
            if (q.docs.isNotEmpty) {
              final g = q.docs.first.data();
              final keys = ['billingAmount', 'billingTotal', 'amountBilled', 'amount', 'total', 'grandTotal', 'invoiceAmount'];
              for (final k in keys) {
                if (g.containsKey(k)) {
                  final val = _parseAmount(g[k]);
                  if (val > 0) return val;
                }
              }
            }
          } catch (e) {
            debugPrint('global doc search by patientId failed: $e');
          }
        }
      } catch (e) {
        debugPrint('getBillingFromGlobalDocIfAny error: $e');
      }
      return 0;
    }();

    _globalBillingCache[staffDocId] = f;
    return f;
  }

  /// Robust resolver for assigned doctor's display name from many possible shapes
  String _resolveDoctorNameFromData(Map<String, dynamic> data) {
    // 1) common direct fields
    if (data.containsKey('assignedDoctorName') && (data['assignedDoctorName'] ?? '').toString().trim().isNotEmpty) {
      return data['assignedDoctorName'].toString();
    }
    if (data.containsKey('doctorName') && (data['doctorName'] ?? '').toString().trim().isNotEmpty) {
      return data['doctorName'].toString();
    }

    // 2) assignedDoctor as string or map
    if (data.containsKey('assignedDoctor')) {
      final ad = data['assignedDoctor'];
      if (ad is String && ad.trim().isNotEmpty) return ad;
      if (ad is Map && (ad['name'] ?? '').toString().trim().isNotEmpty) return ad['name'].toString();
    }

    // 3) nested 'doctor' object (map or string)
    if (data.containsKey('doctor')) {
      final d = data['doctor'];
      if (d is Map && (d['name'] ?? '').toString().trim().isNotEmpty) return d['name'].toString();
      if (d is String && d.trim().isNotEmpty) return d;
    }

    // 4) explicit fields used in your staff save flow
    if (data.containsKey('assignedDoctorUid') && (data['assignedDoctorUid'] ?? '').toString().isNotEmpty) {
      final key = data['assignedDoctorUid'].toString();
      return _doctorMap[key] ?? key;
    }
    if (data.containsKey('assignedDoctor') && (data['assignedDoctor'] ?? '').toString().isNotEmpty) {
      final key = data['assignedDoctor'].toString();
      return _doctorMap[key] ?? key;
    }

    // 5) doctorId -> lookup map
    if (data.containsKey('doctorId') && (data['doctorId'] ?? '').toString().isNotEmpty) {
      final key = data['doctorId'].toString();
      return _doctorMap[key] ?? key;
    }

    // 6) doctorRef (DocumentReference)
    if (data.containsKey('doctorRef') && data['doctorRef'] is DocumentReference) {
      final ref = data['doctorRef'] as DocumentReference;
      return _doctorMap[ref.id] ?? ref.id;
    }

    // 7) fallback keys
    for (final k in ['doctorLoginId', 'doctor_login', 'doctor_display', 'doctorFullName', 'doctor_display_name', 'doctor_user']) {
      if (data.containsKey(k) && (data[k] ?? '').toString().trim().isNotEmpty) return data[k].toString();
    }

    return '-';
  }

  // simple currency formatter adding commas (no external package)
  String _formatCurrency(num val) {
    if (val == 0) return '₹1000';

    final isNegative = val < 0;
    final absVal = val.abs();
    final hasDecimal = (absVal - absVal.floor()) > 0;
    String integerPart = absVal.floor().toString();
    // insert commas
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+$)');
    integerPart = integerPart.replaceAllMapped(reg, (Match m) => '${m[1]},');
    String result = '₹' + integerPart;
    if (hasDecimal) {
      final cents = (absVal - absVal.floor()).toStringAsFixed(2).split('.').last;
      result = '$result.$cents';
    }
    if (isNegative) result = '-$result';
    return result;
  }

  Future<void> _confirmDeletePatient(BuildContext context, String patientId) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete Patient'),
      content: const Text(
        'This will permanently delete the patient from all records.\n\nThis action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (confirm == true) {
    await _deletePatientEverywhere(patientId, isAdmin);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Patient deleted successfully')),
    );
  }
}

Future<void> _deletePatientEverywhere(
  String patientId,
  bool isAdmin,
) async {
  final fire = FirebaseFirestore.instance;

  // 🔴 Safety: only admin can delete
  if (!isAdmin) {
    throw Exception('Only admin can delete patients');
  }

  final batch = fire.batch();

  // 1️⃣ Delete from ALL staff patient subcollections
  final staffPatients =
      await fire.collectionGroup('patients').get();

  for (final doc in staffPatients.docs) {
    final data = doc.data();
    if (data['patientId'] == patientId || doc.id == patientId) {
      batch.delete(doc.reference);
    }
  }

  // 2️⃣ Delete from global patients collection
  final globalPatients =
      await fire.collection('patients').get();

  for (final doc in globalPatients.docs) {
    final data = doc.data();
    if (data['patientId'] == patientId || doc.id == patientId) {
      batch.delete(doc.reference);
    }
  }

  // 3️⃣ Delete from ongoingPatients
  final ongoing =
      await fire.collection('ongoingPatients').get();

  for (final doc in ongoing.docs) {
    final data = doc.data();
    if (data['patientId'] == patientId || doc.id == patientId) {
      batch.delete(doc.reference);
    }
  }

  // 4️⃣ Delete ALL billing records
  final billings =
      await fire.collectionGroup('billings').get();

  for (final doc in billings.docs) {
    final data = doc.data();
    if (data['patientId'] == patientId) {
      batch.delete(doc.reference);
    }
  }

  await batch.commit();
}


  @override
  Widget build(BuildContext context) {
    // STREAM: collect patient docs created by staff under users/{uid}/patients/{doc}
   final patientsStream =
    FirebaseFirestore.instance.collection('patients').snapshots();

    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        child: Row(
          children: [
            // Sidebar
            Container(
              width: 260,
              color: _sideGreen,
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(children: [
                        Container(width: 52, height: 52, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.local_hospital, color: _sideGreen)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                          Text('AyuTech', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                          SizedBox(height: 4),
                          Text('MEDICAL ADMIN', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                        ]))
                      ]),
                    ),

                    
                    const SizedBox(height: 18),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text('MAIN', style: TextStyle(color: Colors.white.withOpacity(0.6), fontWeight: FontWeight.w700))),
                    const SizedBox(height: 8),
                    _sideNavItem('Dashboard', Icons.dashboard_outlined, onTap: () {}),
                    _sideNavItem('Staffs', Icons.group_outlined, onTap: () {}),
                    _sideNavItem('Doctors', Icons.medical_services_outlined, onTap: () {}),
                    _sideNavItem('Billing & Patients', Icons.receipt_long_outlined, active: true, onTap: () {}),
                    const SizedBox(height: 18),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text('REPORTS', style: TextStyle(color: Colors.white.withOpacity(0.6), fontWeight: FontWeight.w700))),
                    const SizedBox(height: 8),
                    _sideNavItem('Reports & Insights', Icons.bar_chart, onTap: () {}),
                    const Spacer(),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0x15555555)))),
                      child: Row(children: [
                        Container(width: 46, height: 46, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white24)), child: const CircleAvatar(radius: 22, backgroundColor: Colors.white, child: Icon(Icons.person, color: _sideGreen))),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                          Text('Dr. James Smith', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                          SizedBox(height: 4),
                          Text('Chief Resident', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ])),
                      ]),
                    )
                  ],
                ),
              ),
            ),

            // Main content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
                // <-- Make the whole central content scrollable
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    // Header row
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(children: [
                        // <-- NEW back button placed to the left of the existing header container
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: _sideGreen),

                          onPressed: () {
                            // prefer popping if possible, else push/replace to admin home page
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            } else {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => const AdminHomePageAllInOne()),
                              );
                            }
                          },
                        ),

                        Container(decoration: BoxDecoration(border: Border(left: BorderSide(color: _sideGreen, width: 4))), padding: const EdgeInsets.only(left: 12), child: const Text(
  'Billing & Patients',
  style: TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: _sideGreen,
  ),
)
) ,
                        const Spacer(),
                        SizedBox(
                          width: 420,
                          child: TextField(controller: _searchCtl, decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Search... (name, id, doctor)', filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
                        ),
                        const SizedBox(width: 12),
                        Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)), child: IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none))),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.add), label: const Text('+ New Appointment'), style: ElevatedButton.styleFrom(backgroundColor: _accentGold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
                      ]),
                    ),

                    const SizedBox(height: 12),

                    // Filter card
                    Card(
                      color: _cardBg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(children: [
                          Expanded(child: TextField(decoration: InputDecoration(hintText: 'Patient ID', filled: true, fillColor: _sideGreen.withOpacity(0.06),
 border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)))),
                          const SizedBox(width: 12),
                          FutureBuilder<QuerySnapshot>(
                            future: FirebaseFirestore.instance.collection('doctors').orderBy('name').get(),
                            builder: (c, ds) {
                              final docs = ds.data?.docs ?? [];
                              return Expanded(
                                child: DropdownButtonFormField<String?>(
                                  value: _filterDoctorId,
                                  items: [
                                    const DropdownMenuItem(value: null, child: Text('All Doctors')),
                                    ...docs.map((d) {
                                      String label;
                                      try {
                                        final data = d.data() as Map<String, dynamic>?;
                                        label = (data != null && data['name'] != null && data['name'].toString().trim().isNotEmpty) ? data['name'].toString() : d.id;
                                      } catch (_) {
                                        label = d.id;
                                      }
                                      return DropdownMenuItem<String?>(value: d.id, child: Text(label));
                                    }).toList()
                                  ],
                                  onChanged: (v) => setState(() => _filterDoctorId = v),
                                  decoration: const InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))), contentPadding: EdgeInsets.symmetric(horizontal: 12), filled: true),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String?>(
                              value: _filterDept,
                              items: const [
                                DropdownMenuItem(value: null, child: Text('All Departments')),
                                DropdownMenuItem(value: 'Cardiology', child: Text('Cardiology')),
                                DropdownMenuItem(value: 'Panchakarma', child: Text('Panchakarma')),
                                DropdownMenuItem(value: 'General Medicine', child: Text('General Medicine')),
                              ],
                              onChanged: (v) => setState(() => _filterDept = v),
                              decoration: const InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))), filled: true, contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: _accentGold), child: const Text('Filter'))
                        ]),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // KPI row + charts (keeps your existing chart code)
                    SizedBox(
                      height: 190,
                      child: Row(children: [
                        // revenue (left)
                        Expanded(
                          child: Card(
                            color: _cardBg,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: FutureBuilder<QuerySnapshot>(
                                future: FirebaseFirestore.instance.collection('patients').get(),

                                builder: (c, snap) {
                                  final docs = snap.data?.docs ?? [];
                                  return FutureBuilder<Map<String, dynamic>>(
                                    future: _computeChartsAndRevenue(docs),
                                    builder: (c2, csnap) {
                                      final revenue = csnap.data?['revenue'] ?? 0;
                                      final weekly = (csnap.data?['weekly'] as List<num>?) ?? List<num>.filled(7, 0);
                                      final spots = <FlSpot>[];
                                      for (var i = 0; i < weekly.length; i++) spots.add(FlSpot(i.toDouble(), weekly[i].toDouble()));
                                      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        const Text('Revenue (Mo)', style: TextStyle(fontWeight: FontWeight.w700, color: _sideGreen)),
                                        const SizedBox(height: 8),
                                        Text(_formatCurrency(revenue), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: _sideGreen)),
                                        const Spacer(),
                                        SizedBox(
                                          height: 80,
                                          child: LineChart(
                                            LineChartData(
                                              gridData: FlGridData(show: false),
                                              titlesData: FlTitlesData(show: false),
                                              borderData: FlBorderData(show: false),
                                              lineBarsData: [
                                                LineChartBarData(
                                                  spots: spots.isNotEmpty ? spots : [FlSpot(0,0), FlSpot(1,0)],
                                                  isCurved: true,
                                                  barWidth: 3,
                                                  color: _sideGreen,
                                                  belowBarData: BarAreaData(show: true, color: _sideGreen.withOpacity(0.06)),
                                                  dotData: FlDotData(show: false),
                                                )
                                              ],
                                            ),
                                          ),
                                        ),
                                      ]);
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                   

                        const SizedBox(width: 12),

                        // billing history (right) - small bar chart
                        Expanded(
                          child: Card(
                            color: _cardBg,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: FutureBuilder<QuerySnapshot>(
                                future: FirebaseFirestore.instance.collection('patients').get(),

                                builder: (c, snap) {
                                  final docs = snap.data?.docs ?? [];
                                  return FutureBuilder<Map<String, dynamic>>(
                                    future: _computeChartsAndRevenue(docs),
                                    builder: (c2, csnap) {
                                      final weekly = (csnap.data?['weekly'] as List<num>?) ?? List<num>.filled(7, 0);
                                      final maxY = (weekly.isNotEmpty ? weekly.reduce((a,b) => a>b?a:b) : 1) + 10;
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Billing History', style: TextStyle(fontWeight: FontWeight.w700, color: _sideGreen)),
                                          const SizedBox(height: 6),
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.only(top: 6.0),
                                              child: BarChart(
                                                BarChartData(
                                                  alignment: BarChartAlignment.spaceAround,
                                                  maxY: maxY.toDouble(),
                                                  barGroups: List.generate(7, (i) {
                                                    return BarChartGroupData(x: i, barRods: [BarChartRodData(toY: weekly[i].toDouble(), width: 12, borderRadius: BorderRadius.circular(4))]);
                                                  }),
                                                  titlesData: FlTitlesData(
                                                    topTitles: AxisTitles(),
                                                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                                    rightTitles: AxisTitles(),
                                                    bottomTitles: AxisTitles(
                                                      sideTitles: SideTitles(
                                                        showTitles: true,
                                                        getTitlesWidget: (value, meta) {
                                                          const labels = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
                                                          final idx = value.toInt().clamp(0, 6);
                                                          return Text(labels[idx], style: const TextStyle(fontSize: 10));
                                                        },
                                                        reservedSize: 28,
                                                      ),
                                                    ),
                                                  ),
                                                  gridData: FlGridData(show: false),
                                                  borderData: FlBorderData(show: false),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ]),
                    ),

                    const SizedBox(height: 18),

                    // Patient records & Billing table
                    // Changed from Expanded to SizedBox with a fairly large height so the page scrolls as a single page.
                    // The list inside uses shrinkWrap:true and non-scrollable physics so the outer SingleChildScrollView scrolls.
                    SizedBox(
                      height: 620, // <-- adjust height to suit your screen or make dynamic
                      child: Card(
                        color: _cardBg,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(18.0),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Row(children: [
                              Expanded(child: Text('Patient Records & Billing', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _sideGreen))),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final snapshot =
    await FirebaseFirestore.instance.collection('patients').get();

                                  // build CSV rows based on staff patient docs
                                  final rows = <Map<String, dynamic>>[];
                                  final docs = snapshot.docs.toList();
                                  docs.sort((a, b) {
                                    final aName = ((a.data() as Map<String,dynamic>?)?['name'] ?? '').toString();
                                    final bName = ((b.data() as Map<String,dynamic>?)?['name'] ?? '').toString();
                                    return aName.compareTo(bName);
                                  });
                                  for (final s in docs) {
                                    final data = s.data() as Map<String, dynamic>;
                                    final row = <String, dynamic>{};
                                    row['id'] = data['patientId'] ?? s.id;
                                    row['name'] = data['name'] ?? '';
                                    String docName = _resolveDoctorNameFromData(data);
                                    row['doctorName'] = docName;
                                    row['lastVisit'] = _fmtDate(data['lastVisit']);
                                    final amt = await _getBilledAmount(s.id, data);
                                    row['billed'] = (amt > 0) ? _formatCurrency(amt) : '';
                                    row['status'] = (data['billingStatus'] ?? data['status'] ?? '').toString();
                                    rows.add(row);
                                  }
                                  await _exportCsvRows(rows);
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: _sideGreen, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                                icon: const Icon(Icons.download_rounded, color: Colors.white),
                                label: const Text('Export', style: TextStyle(color: Colors.white)),
                              )
                            ]),
                            const SizedBox(height: 12),

                            // Table header (gold labels)
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                              decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(8)),
                              child: Row(children: [
                                // Increased flex for ID so login id is more visible
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'ID',
                                    style: TextStyle(fontWeight: FontWeight.w700, color: _accentGold),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    'NAME',
                                    style: TextStyle(fontWeight: FontWeight.w700, color: _accentGold),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    'DOCTOR',
                                    style: TextStyle(fontWeight: FontWeight.w700, color: _accentGold),
                                  ),
                                ),
                                // Removed LAST VISIT column as requested

                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'BILLED',
                                    style: TextStyle(fontWeight: FontWeight.w700, color: _accentGold),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    'STATUS',
                                    style: TextStyle(fontWeight: FontWeight.w700, color: _accentGold),
                                  ),
                                ),
                                SizedBox(
                                  width: 48,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      'ACTIONS',
                                      style: TextStyle(fontWeight: FontWeight.w700, color: _accentGold),
                                    ),
                                  ),
                                ),
                              ]),
                            ),

                            const SizedBox(height: 8),

                            // Table body: stream from staff patients collectionGroup
                            Expanded(
                              child: StreamBuilder<QuerySnapshot>(
                                stream: patientsStream,

                                builder: (context, snap) {
                                  if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
                                  if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                                  final docs = snap.data?.docs ?? [];

                                  // convert and sort by name for consistent display
                                  final filtered = docs.where((d) {
                                    final data = d.data() as Map<String, dynamic>;
                                    final name = (data['name'] ?? '').toString().toLowerCase();
                                    final idLower = (data['patientId'] ?? d.id).toString().toLowerCase();
                                    final doctorNameField = (data['doctorName'] ?? '').toString().toLowerCase();
                                    if (_search.isNotEmpty) {
                                      if (!name.contains(_search) && !idLower.contains(_search) && !doctorNameField.contains(_search)) return false;
                                    }
                                    // doctor filter
                                    if (_filterDoctorId != null && _filterDoctorId!.isNotEmpty) {
                                      final docIdField = (data['doctorId'] ?? '').toString();
                                      if (docIdField.isNotEmpty) {
                                        if (docIdField != _filterDoctorId) return false;
                                      } else if (data['doctorRef'] is DocumentReference) {
                                        if ((data['doctorRef'] as DocumentReference).id != _filterDoctorId) return false;
                                      }
                                    }
                                    if (_filterDept != null && _filterDept!.isNotEmpty) {
                                      final dept = (data['department'] ?? '').toString();
                                      if (dept.toLowerCase() != _filterDept!.toLowerCase()) return false;
                                    }
                                    return true;
                                  }).toList();

                                  filtered.sort((a, b) {
                                    final aName = ((a.data() as Map<String,dynamic>?)?['name'] ?? '').toString();
                                    final bName = ((b.data() as Map<String,dynamic>?)?['name'] ?? '').toString();
                                    return aName.compareTo(bName);
                                  });

                                  if (filtered.isEmpty) return const Center(child: Text('No patient records found.'));

                                  return ListView.separated(
                                    // important: shrinkWrap and non-scrollable so outer SingleChildScrollView handles scrolling
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: filtered.length,
                                    separatorBuilder: (_, __) => Divider(color: Colors.grey.shade200, height: 1),
                                    itemBuilder: (context, index) {
                                      final doc = filtered[index];
                                      final data = (doc.data() as Map<String, dynamic>? ?? {});
                                      final id = (data['patientId'] ?? doc.id).toString();
                                      final name = (data['name'] ?? 'Unnamed').toString();
                                      final docName = _resolveDoctorNameFromData(data);

                                      // Determine a status string showing billingStatus (preferred) or patient status (ongoing/ended)
                                      final billingStatusField = (data['billingStatus'] ?? '').toString();
                                      final patientStatusField = (data['status'] ?? '').toString();
                                      final displayStatus = billingStatusField.isNotEmpty ? billingStatusField : (patientStatusField.isNotEmpty ? patientStatusField : '');

                                      // Alternate row background for subtle banding
                                      final rowBg = (index % 2 == 0) ? Colors.transparent : _mutedRow;

                                      return Container(
                                        color: rowBg,
                                        // slightly reduced horizontal padding so columns get more room
                                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                                        child: Row(children: [
                                          // ID - increased flex so login id is more visible
                                          Expanded(
                                            flex: 2,
                                            child: Text(id, style: const TextStyle(color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          ),

                                          // NAME (dark green)
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              name,
                                              style: TextStyle(
                                                color: _sideGreen,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),

                                          // DOCTOR resolved
                                          Expanded(
                                            flex: 3,
                                            child: Text(docName.isNotEmpty ? docName : '-', style: const TextStyle(color: Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          ),

                                          // billed numeric total only
                                          Expanded(
                                            flex: 2,
                                            child: Builder(builder: (context) {
                                              // NEW: Prefer billing amount from global patient doc (if present)
                                              return FutureBuilder<num>(
                                                future: _getBillingFromGlobalDocIfAny(data, doc.id),
                                                builder: (context, globalSnap) {
                                                  // if global doc returned a positive amount, show it
                                                  if (globalSnap.connectionState == ConnectionState.done && (globalSnap.data ?? 0) > 0) {
                                                    return Text(_formatCurrency(globalSnap.data!), style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600));
                                                  }

                                                  // else try direct staff doc fields first (fast)
                                                  final directAmtKeys = ['billingTotal', 'amountBilled', 'lastBilled', 'billingAmount', 'total', 'amount', 'grandTotal', 'invoiceAmount'];
                                                  num directAmt = 0;
                                                  for (final k in directAmtKeys) {
                                                    if (data.containsKey(k)) {
                                                      directAmt = _parseAmount(data[k]);
                                                      if (directAmt > 0) break;
                                                    }
                                                  }

                                                  if (directAmt > 0) {
                                                    return Text(_formatCurrency(directAmt), style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600));
                                                  }

                                                  // fallback to resolving via billings subcollections / top-level billings / collectionGroup
                                                  return FutureBuilder<num>(
                                                    future: _getBilledAmount(doc.id, data),
                                                    builder: (context, snapAmt) {
                                                      if (snapAmt.connectionState == ConnectionState.waiting) {
                                                        return const Text('-', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600));
                                                      }
                                                      if (snapAmt.hasError) {
                                                        return const Text('-', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600));
                                                      }
                                                      final amt = snapAmt.data ?? 0;
                                                      if (amt <= 0) return const Text('-', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600));
                                                      final displayed = _formatCurrency(amt);
                                                      return Text(displayed, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600));
                                                    },
                                                  );
                                                },
                                              );
                                            }),
                                          ),

                                          // STATUS pill - uses billingStatus or patient status (ongoing/ended)
                                          Expanded(
                                            flex: 1,
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                decoration: BoxDecoration(color: _statusColorBg(displayStatus), borderRadius: BorderRadius.circular(8)),
                                                child: Text(displayStatus.isNotEmpty ? displayStatus : '-', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _statusColorText(displayStatus))),
                                              ),
                                            ),
                                          ),

                                          // actions
SizedBox(
  width: 80,
  child: Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      IconButton(
        icon: const Icon(Icons.visibility, size: 18),
        onPressed: () {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Open patient $id')));
        },
      ),

      if (isAdmin)
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.red, size: 18),
          tooltip: 'Delete Patient',
          onPressed: () {
            _confirmDeletePatient(context, id);
          },
        ),
    ],
  ),
),


                                          
                                        ]),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24), // bottom padding so content isn't flush with edge
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sideNavItem(String title, IconData icon, {bool active = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: active ? _sideGreen.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: active ? const Border(left: BorderSide(color: Color(0xFFD6A657), width: 4)) : null,
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
}

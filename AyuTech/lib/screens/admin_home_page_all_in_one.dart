// lib/screens/admin_home_page_all_in_one.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'adminbilling_patients_page.dart';
import 'admin_reports_page.dart';
import 'welcome_screen.dart';

class AdminHomePageAllInOne extends StatefulWidget {
  const AdminHomePageAllInOne({Key? key}) : super(key: key);

  @override
  State<AdminHomePageAllInOne> createState() => _AdminHomePageAllInOneState();
}

class _AdminHomePageAllInOneState extends State<AdminHomePageAllInOne> {
  // Palette
// Palette — MATCHES ADMIN LOGIN SCREEN
static const Color _primaryTeal = Color(0xFF2F5C56); // MAIN GREEN
static const Color _sidebarBg = Color(0xFF2F5C56);  // SIDEBAR
static const Color _accentGold = Color(0xFFD6A657);
static const Color _bgBody = Color(0xFFFAFAF8);
static const Color _cardSurface = Colors.white;

  static const double _sidebarWidth = 260;
  static const double _maxContentWidth = 1200;

  // KPI state
  int? _patientsCount;
  int? _activeDoctorsCount;
  double? _revenueSum;
  int? _todaysAppointments;

  // Top doctors computed
  List<_DoctorStat> _topDoctors = [];
  bool _loadingKpis = true;
  String? _kpiError;

  final TextEditingController _searchController = TextEditingController();

  // Chart controls
  String _chartSource = 'patients'; // 'patients' or 'appointments'
  String _chartFreq = 'daily'; // 'daily' or 'monthly'

  // --- canonical department list (from your message)
  static const List<String> _canonicalDepartments = [
    'Panchakarma',
    'Kayachikitsa (General Medicine)',
    'Shalya Tantra (Surgery & Wound Care)',
    'Shalakya Tantra (Eye, ENT, Dental)',
    'Prasuti & Stri Roga (Women’s Care)',
    'Kaumarbhritya (Pediatrics)',
    'Ayurvedic Physiotherapy & Rehab',
    'Swasthavritta (Wellness & Lifestyle)',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadKpisAndTopDoctors();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadKpisAndTopDoctors() async {
    setState(() {
      _loadingKpis = true;
      _kpiError = null;
    });

    try {
      final db = FirebaseFirestore.instance;

      final pSnap = await db.collection('patients').get();
      final patientsCount = pSnap.docs.length;

      final dSnap = await db.collection('doctors').get();
      final activeDoctorsCount = dSnap.docs.length;

      double revenue = 0.0;
      try {
        final billSnap = await db.collection('billings').get();
        for (final doc in billSnap.docs) {
          final data = doc.data();
          final amt = data['amount'];
          if (amt is num) revenue += amt.toDouble();
          else if (amt is String) revenue += double.tryParse(amt) ?? 0.0;
        }
      } catch (_) {
        final paySnap = await db.collection('payments').get();
        for (final doc in paySnap.docs) {
          final data = doc.data();
          final amt = data['amount'];
          if (amt is num) revenue += amt.toDouble();
          else if (amt is String) revenue += double.tryParse(amt) ?? 0.0;
        }
      }

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final apptSnap = await db
          .collection('appointments')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();
      final todaysAppointments = apptSnap.docs.length;

      // Compute top doctors (last year)
      final yearAgo = DateTime(now.year - 1, now.month, now.day);
      final apptYearSnap = await db
          .collection('appointments')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(yearAgo))
          .get();
      final Map<String, int> counts = {};
      for (var doc in apptYearSnap.docs) {
        final data = doc.data();
        final doctorId = (data['doctorId'] ?? data['doctor'] ?? '') as String;
        if (doctorId.isEmpty) continue;
        counts[doctorId] = (counts[doctorId] ?? 0) + 1;
      }

      final doctorDocsSnap = await db.collection('doctors').get();
      final List<_DoctorStat> stats = [];
      for (var d in doctorDocsSnap.docs) {
        final data = d.data();
        final id = d.id;
        final name = (data['name'] ?? data['displayName'] ?? 'Unnamed') as String;
        final specialty = (data['specialty'] ?? data['department'] ?? '') as String;
        double rating = 0.0;
        final r = data['rating'];
        if (r is num) rating = r.toDouble();
        else if (r is String) rating = double.tryParse(r) ?? 0.0;
        final cnt = counts[id] ?? 0;
        stats.add(_DoctorStat(id: id, name: name, specialty: specialty, patients: cnt, rating: rating));
      }

      stats.sort((a, b) => b.patients.compareTo(a.patients));

      setState((){
        _patientsCount = patientsCount;
        _activeDoctorsCount = activeDoctorsCount;
        _revenueSum = revenue;
        _todaysAppointments = todaysAppointments;
        _topDoctors = stats.take(6).toList();
        _loadingKpis = false;
      });
    } catch (e, st) {
      setState(() {
        _kpiError = 'Failed to load data: $e';
        _loadingKpis = false;
      });
      debugPrint('KPILOAD ERROR: $e\n$st');
    }
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Widget _kpiCard(String label, Widget valueWidget, String hint,
      {IconData? icon, Color? iconBg}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardSurface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12.withOpacity(0.03), blurRadius: 8)],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label.toUpperCase(), style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              valueWidget,
              const SizedBox(height: 6),
              Text(hint, style: const TextStyle(fontSize: 11)),
            ]),
          ),
          const SizedBox(width: 12),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg ?? Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: _primaryTeal),
          )
        ],
      ),
    );
  }

  Widget _numericText(dynamic value, {String suffix = ''}) {
    String txt;
    if (value == null) txt = '—';
    else if (value is int) txt = value.toString();
    else if (value is double) txt = value.toStringAsFixed(2);
    else txt = value.toString();
    return Text(txt + suffix, style: const TextStyle(fontSize: 26, color: Colors.black87, fontWeight: FontWeight.w800));
  }

  TableRow _doctorRow(_DoctorStat doc) {
    return TableRow(children: [
      Padding(padding: const EdgeInsets.all(8.0), child: Row(children: [
        CircleAvatar(radius: 16, backgroundColor: _primaryTeal.withOpacity(0.08), child: Text(doc.name.isEmpty ? '?' : doc.name[0].toUpperCase(), style: const TextStyle(color: _primaryTeal)) ),
        const SizedBox(width: 8),
        Flexible(child: Text(doc.name, overflow: TextOverflow.ellipsis)),
      ])),
      Padding(padding: const EdgeInsets.all(8.0), child: Text(doc.specialty.isEmpty ? '-' : doc.specialty)),
      Padding(padding: const EdgeInsets.all(8.0), child: Text(doc.patients.toString())),
      Padding(padding: const EdgeInsets.all(8.0), child: Row(children: [const Icon(Icons.star, color: Colors.orange, size: 16), const SizedBox(width: 4), Text(doc.rating.toStringAsFixed(1))])),

    ]);
  }

  // ---------------------- Chart aggregation helpers ----------------------

  /// Aggregates snapshot docs into daily counts for last 7 days.
  /// Expects documents to have a Timestamp in the provided fieldName.
  Map<String, int> _aggregateLast7Days(List<QueryDocumentSnapshot> docs, String fieldName) {
    final Map<String, int> counts = {};
    final now = DateTime.now();
    for (int i = 0; i < 7; i++) {
      final d = now.subtract(Duration(days: 6 - i));
      final key = DateFormat('yyyy-MM-dd').format(d);
      counts[key] = 0;
    }
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final ts = data[fieldName];
      DateTime? dt;
      if (ts is Timestamp) dt = ts.toDate();
      else if (ts is DateTime) dt = ts;
      if (dt == null) continue;
      final key = DateFormat('yyyy-MM-dd').format(dt);
      if (counts.containsKey(key)) counts[key] = counts[key]! + 1;
    }
    return counts;
  }

  /// Aggregates snapshot docs into last 12 months counts (month keys 'YYYY-MM').
  Map<String, int> _aggregateLast12Months(List<QueryDocumentSnapshot> docs, String fieldName) {
    final Map<String, int> counts = {};
    final now = DateTime.now();
    for (int i = 0; i < 12; i++) {
      final d = DateTime(now.year, now.month - 11 + i, 1);
      final key = DateFormat('yyyy-MM').format(d);
      counts[key] = 0;
    }
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final ts = data[fieldName];
      DateTime? dt;
      if (ts is Timestamp) dt = ts.toDate();
      else if (ts is DateTime) dt = ts;
      if (dt == null) continue;
      final key = DateFormat('yyyy-MM').format(dt);
      if (counts.containsKey(key)) counts[key] = counts[key]! + 1;
    }
    return counts;
  }

  // Pie: robust department extraction (keeps canonical keys even if zero)
  Map<String, int> _aggregateDeptCounts(List<QueryDocumentSnapshot> docs) {
    // Start from canonical with zero so legend remains consistent
    final Map<String, int> map = { for (var d in _canonicalDepartments) d : 0 };

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;

      // Candidate keys to look for
      final candidates = <String>[
        'department',
        'dept',
        'departmentName',
        'specialty',
        'service',
        'department_name',
        'category',
        'type',
        'role',
      ];

      String? raw;
      for (final k in candidates) {
        if (data.containsKey(k) && data[k] != null) {
          final v = data[k];
          if (v is String && v.trim().isNotEmpty) {
            raw = v;
            break;
          } else if (v is Map && v.containsKey('name') && v['name'] is String) {
            raw = v['name'] as String;
            break;
          }
        }
      }

      final dept = _normalizeDepartment(raw);
      map[dept] = (map[dept] ?? 0) + 1;
    }

    return map;
  }

  // Normalizes department strings to a canonical display value
  String _normalizeDepartment(String? raw) {
    if (raw == null) return 'Other';
    final s = raw.trim().toLowerCase();

    if (s.isEmpty) return 'Other';

    final alias = <String, String>{
      // exact keys -> canonical labels
      'panchakarma': 'Panchakarma',
      'kayachikitsa': 'Kayachikitsa (General Medicine)',
      'kayachikisa': 'Kayachikitsa (General Medicine)',
      'shalya': 'Shalya Tantra (Surgery & Wound Care)',
      'shalya tantra': 'Shalya Tantra (Surgery & Wound Care)',
      'shalakya': 'Shalakya Tantra (Eye, ENT, Dental)',
      'prasuti': 'Prasuti & Stri Roga (Women’s Care)',
      'stri': 'Prasuti & Stri Roga (Women’s Care)',
      'kaumarbhritya': 'Kaumarbhritya (Pediatrics)',
      'kaumar bhritya': 'Kaumarbhritya (Pediatrics)',
      'physiotherapy': 'Ayurvedic Physiotherapy & Rehab',
      'rehab': 'Ayurvedic Physiotherapy & Rehab',
      'swasthavritta': 'Swasthavritta (Wellness & Lifestyle)',
      'wellness': 'Swasthavritta (Wellness & Lifestyle)',
      'general': 'Kayachikitsa (General Medicine)',
      'other': 'Other',
      'ayurveda': 'Panchakarma',
      'cardio': 'Kayachikitsa (General Medicine)', // if you want cardio mapped differently change here
    };

    // direct match
    if (alias.containsKey(s)) return alias[s]!;

    // substring matches (helps when user writes "Shalya - Surgery")
    for (final k in alias.keys) {
      if (s.contains(k)) return alias[k]!;
    }

    // fallback: try to title-case and return if matches canonical
    final fallback = s.split(RegExp(r'\s+')).map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
    for (final c in _canonicalDepartments) {
      if (c.toLowerCase() == fallback.toLowerCase()) return c;
    }
    return 'Other';
  }

  // color map for pie keys (includes all canonical departments)
  static Color _pieColorFor(String key) {
    final map = {
      'Panchakarma': Colors.green.shade700,
      'Kayachikitsa (General Medicine)': Colors.amber.shade700,
      'Shalya Tantra (Surgery & Wound Care)': Colors.blue.shade400,
      'Shalakya Tantra (Eye, ENT, Dental)': Colors.purple.shade300,
      'Prasuti & Stri Roga (Women’s Care)': Colors.pink.shade400,
      'Kaumarbhritya (Pediatrics)': Colors.teal.shade300,
      'Ayurvedic Physiotherapy & Rehab': Colors.cyan.shade400,
      'Swasthavritta (Wellness & Lifestyle)': Colors.lime.shade700,
      'Other': Colors.grey.shade400,
    };
    return map[key] ?? Colors.primaries[key.hashCode % Colors.primaries.length].shade400;
  }

  // ---------------------- UI ----------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBody,
      body: SafeArea(
        child: Row(
          children: [
            // Sidebar
            Container(
              width: _sidebarWidth,
              color: _sidebarBg,
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(children: [
                      Container(
                        decoration: BoxDecoration(color: _accentGold, borderRadius: BorderRadius.circular(8)),
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
                  _sidebarItem('Dashboard', Icons.dashboard, active: true, onTap: () {}),
                  _sidebarItem('Staffs', Icons.people, onTap: () { Navigator.of(context).pushNamed('/staffs'); }),
                  _sidebarItem('Doctors', Icons.medical_services, onTap: () { Navigator.of(context).pushNamed('/doctors'); }),
                  _sidebarItem('Billing & Patients', Icons.receipt_long, onTap: () { Navigator.of(context).pushNamed('/billing'); }),
                  const SizedBox(height: 18),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text('Reports', style: TextStyle(color: Colors.white.withOpacity(0.6), fontWeight: FontWeight.w700))),
                  const SizedBox(height: 8),
                 _sidebarItem(
  'Reports & Insights',
  Icons.bar_chart,
  onTap: () { Navigator.of(context).pushNamed('/reports'); },
),

                                  // spacer pushed down so bottom profile + logout sit at the bottom
                  const Spacer(),

                  // Bottom profile + logout
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=11'), radius: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text('Admin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                  SizedBox(height: 2),
                                  Text('Administrator', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 36,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white24,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                            ),
                            onPressed: () async {
                              
  // Try to sign out, but even if signOut throws we'll still navigate.
  try {
    await FirebaseAuth.instance.signOut();
  } catch (e) {
    debugPrint('Sign out error: $e');
    // optional: show a small error to the user
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error signing out — continuing to Welcome screen')),
      );
    }
  }

  // Navigate to WelcomeScreen and remove all previous routes
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const WelcomeScreen()),
    (route) => false,
  );
},

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

            // Main content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: _maxContentWidth),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      _buildTopHeaderWidget(),
                      const SizedBox(height: 18),
                      if (_loadingKpis)
                        const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                      else if (_kpiError != null)
                        Padding(padding: const EdgeInsets.all(12), child: Text(_kpiError!, style: const TextStyle(color: Colors.red)))
                      else
                        _buildKpiRow(),
                      const SizedBox(height: 18),
                      // Charts row (line + pie) with live streams
                      _buildChartGrid(),
                      const SizedBox(height: 18),
                      _buildBottomRow(),
                      const SizedBox(height: 18),
                      _recentInputsWidget(),
                      const SizedBox(height: 24),
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

  Widget _buildTopHeaderWidget() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(color: _bgBody, borderRadius: BorderRadius.circular(6)),
      child: Row(children: [
        Container(decoration: BoxDecoration(border: Border(left: BorderSide(color: _primaryTeal, width: 3))), padding: const EdgeInsets.only(left: 15), child: Text('Dashboard Overview', style: TextStyle(color: _primaryTeal, fontSize: 20, fontFamily: 'Merriweather', fontWeight: FontWeight.w700))),
        const Spacer(),
        Container(width: 340, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)), child: Row(children: [Icon(Icons.search, color: Colors.grey.shade400), const SizedBox(width: 8), Expanded(child: TextField(controller: _searchController, decoration: const InputDecoration.collapsed(hintText: 'Search...'))),])),
        const SizedBox(width: 12),
        IconButton(onPressed: () => _showSnack('No notifications'), icon: Icon(Icons.notifications_none, color: Colors.grey.shade700)),
        const SizedBox(width: 8),
        ElevatedButton(onPressed: () => _showSnack('Create new appointment'), style: ElevatedButton.styleFrom(backgroundColor: _accentGold, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('+ New Appointment')),
      ]),
    );
  }



  Widget _buildKpiRow() {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: _kpiCard('Total Patients', _numericText(_patientsCount), 'Count from patients collection', icon: Icons.people, iconBg: Colors.amber.shade50)),
      const SizedBox(width: 16),
      Expanded(child: _kpiCard('Active Doctors', _numericText(_activeDoctorsCount), 'Count from doctors collection', icon: Icons.medical_services, iconBg: Colors.teal.shade50)),
      const SizedBox(width: 16),
      Expanded(child: _kpiCard('Revenue (Mo)', _numericText(_revenueSum ?? 0.0, suffix: ''), 'Sum of billing amounts (collection: billings)', icon: Icons.monetization_on, iconBg: Colors.amber.shade50)),
      const SizedBox(width: 16),
      Expanded(child: _kpiCard('Appointments', _numericText(_todaysAppointments), "Today's Schedule", icon: Icons.calendar_today, iconBg: Colors.teal.shade50)),
    ]);
  }



  Widget _buildChartGrid() {
    final patientsStream = FirebaseFirestore.instance.collection('patients').orderBy('createdAt', descending: true).snapshots();
    final apptStream = FirebaseFirestore.instance.collection('appointments').orderBy('date', descending: true).snapshots();
    final doctorsStream = FirebaseFirestore.instance.collection('doctors').orderBy('createdAt', descending: true).snapshots();
    
    
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      
// line chart
      Expanded(
        flex: 2,
        child: Container(
          height: 350,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: _cardSurface, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black12.withOpacity(0.03), blurRadius: 8)]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Patient Traffic & Trends', style: TextStyle(color: _primaryTeal, fontFamily: 'Merriweather', fontSize: 18)),
              const Spacer(),
              DropdownButton<String>(
                value: _chartSource,
                items: const [
                  DropdownMenuItem(value: 'patients', child: Text('Patients')),
                  DropdownMenuItem(value: 'appointments', child: Text('Appointments')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _chartSource = v);
                },
                underline: const SizedBox(),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _chartFreq,
                items: const [
                  DropdownMenuItem(value: 'daily', child: Text('Daily')),
                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _chartFreq = v);
                },
                underline: const SizedBox(),
              ),
            ]),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _chartSource == 'patients' ? patientsStream : apptStream,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  final docs = snap.data?.docs ?? [];

                  if (_chartFreq == 'daily') {
                    final aggregated = _aggregateLast7Days(docs, _chartSource == 'patients' ? 'createdAt' : 'date');
                    final labels = aggregated.keys.toList();
                    final values = labels.map((k) => aggregated[k]!.toDouble()).toList();
                    final maxY = (values.isEmpty ? 1.0 : (values.reduce((a, b) => a > b ? a : b) + 2));
                    final spots = List.generate(values.length, (i) => FlSpot(i.toDouble(), values[i]));
                    return LineChart(LineChartData(
                      gridData: FlGridData(show: true, getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.shade200, strokeWidth: 1), drawVerticalLine: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx >= 0 && idx < labels.length) {
                            final d = DateFormat('MMMd').format(DateTime.parse(labels[idx]));
                            return Text(d, style: const TextStyle(color: Colors.black54, fontSize: 12));
                          }
                          return const SizedBox.shrink();
                        })),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      minX: 0,
                      maxX: (spots.isEmpty ? 6 : (spots.length - 1).toDouble()),
                      minY: 0,
                      maxY: maxY,
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: _primaryTeal,
                          barWidth: 3,
                          dotData: FlDotData(show: true),
                          belowBarData: BarAreaData(show: true, color: _primaryTeal.withOpacity(0.08)),
                        )
                      ],
                    ));
                  } else {
                    final aggregated = _aggregateLast12Months(docs, _chartSource == 'patients' ? 'createdAt' : 'date');
                    final labels = aggregated.keys.toList();
                    final values = labels.map((k) => aggregated[k]!.toDouble()).toList();
                    final maxY = (values.isEmpty ? 1.0 : (values.reduce((a, b) => a > b ? a : b) + 2));
                    final spots = List.generate(values.length, (i) => FlSpot(i.toDouble(), values[i]));
                    return LineChart(LineChartData(
                      gridData: FlGridData(show: true, getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.shade200, strokeWidth: 1), drawVerticalLine: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx >= 0 && idx < labels.length) {
                            final d = DateFormat.MMM().format(DateTime.parse(labels[idx] + '-01'));
                            return Text(d, style: const TextStyle(color: Colors.black54, fontSize: 12));
                          }
                          return const SizedBox.shrink();
                        })),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      minX: 0,
                      maxX: (spots.isEmpty ? 11 : (spots.length - 1).toDouble()),
                      minY: 0,
                      maxY: maxY,
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: _primaryTeal,
                          barWidth: 3,
                          dotData: FlDotData(show: true),
                          belowBarData: BarAreaData(show: true, color: _primaryTeal.withOpacity(0.08)),
                        )
                      ],
                    ));
                  }
                },
              ),
            ),
          ]),
        ),
      ),

      const SizedBox(width: 16),

      // Right: pie chart and legend (combine patients + doctors)
      Expanded(
        flex: 1,
        child: Container(
          height: 350,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: _cardSurface, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black12.withOpacity(0.03), blurRadius: 8)]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Dept. Distribution', style: TextStyle(color: _primaryTeal, fontFamily: 'Merriweather', fontSize: 18)),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: patientsStream,
                builder: (context, patientsSnap) {
                  if (patientsSnap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  final patientDocs = patientsSnap.data?.docs ?? [];

                  // Now listen to doctors stream as well (nest StreamBuilder)
                  return StreamBuilder<QuerySnapshot>(
                    stream: doctorsStream,
                    builder: (context, doctorsSnap) {
                      if (doctorsSnap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                      final doctorDocs = doctorsSnap.data?.docs ?? [];

                      // Convert both collections to a list of maps and aggregate together.
                      final List<Map<String, dynamic>> combinedMaps = [];
                      for (final d in patientDocs) {
                        combinedMaps.add(d.data() as Map<String, dynamic>);
                      }
                      for (final d in doctorDocs) {
                        final m = d.data() as Map<String, dynamic>;
                        final docMap = <String, dynamic>{};
                        docMap.addAll(m);
                        // ensure department field present using specialty/department
                        if (!docMap.containsKey('department') || (docMap['department'] == null || (docMap['department'] is String && (docMap['department'] as String).trim().isEmpty))) {
                          if (m.containsKey('specialty') && m['specialty'] is String) {
                            docMap['department'] = m['specialty'];
                          } else if (m.containsKey('department') && m['department'] is String) {
                            docMap['department'] = m['department'];
                          }
                        }
                        combinedMaps.add(docMap);
                      }

                      // Wrap maps into simple _MapDoc so aggregator can reuse logic
                      final fakeDocs = combinedMaps.map((m) => _MapDoc(m)).toList();
                      final counts = _aggregateDeptCountsFromMaps(fakeDocs);

                      if (counts.isEmpty) return const Center(child: Text('No department data'));

                      final total = counts.values.fold<int>(0, (p, n) => p + n);

                      // Keep canonical order and produce ordered entries
                      final List<MapEntry<String,int>> ordered = _canonicalDepartments.map((k) => MapEntry(k, counts[k] ?? 0)).toList();

                      // Create pie sections only for > 0 values
                      final sections = ordered.where((e) => e.value > 0).map((e) {
                        final pct = total == 0 ? 0 : (e.value / total) * 100;
                        final color = _pieColorFor(e.key);
                        return PieChartSectionData(
                          color: color,
                          value: e.value.toDouble(),
                          title: '${pct.round()}%',
                          radius: 46,
                          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        );
                      }).toList();

                      final showEmpty = sections.isEmpty;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Chart area (or empty message)
                          if (showEmpty)
                            Expanded(child: Center(child: Text('No department data yet', style: TextStyle(color: Colors.grey.shade600))))
                          else
                            SizedBox(height: 180, child: PieChart(PieChartData(sections: sections, sectionsSpace: 4, centerSpaceRadius: 22))),
                          const SizedBox(height: 10),
                          // Legend: make scrollable to avoid overflow
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: ordered.map((e) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                                    child: _PieLegendItem(color: _pieColorFor(e.key), label: e.key, value: e.value),
                                  );
                                }).toList(),
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
          ]),
        ),
      ),
    ]);
  }

  /// Aggregates department counts from a list of simple map-wrappers
  Map<String, int> _aggregateDeptCountsFromMaps(List<_MapDoc> mapDocs) {
    // initialize with canonical keys
    final Map<String, int> map = { for (var d in _canonicalDepartments) d : 0 };

    for (final doc in mapDocs) {
      final data = doc.data;
      // Candidate keys to look for
      final candidates = <String>[
        'department',
        'dept',
        'departmentName',
        'specialty',
        'service',
        'department_name',
        'category',
        'type',
        'role',
      ];

      String? raw;
      for (final k in candidates) {
        if (data.containsKey(k) && data[k] != null) {
          final v = data[k];
          if (v is String && v.trim().isNotEmpty) {
            raw = v;
            break;
          } else if (v is Map && v.containsKey('name') && v['name'] is String) {
            raw = v['name'] as String;
            break;
          }
        }
      }

      final dept = _normalizeDepartment(raw);
      map[dept] = (map[dept] ?? 0) + 1;
    }
    return map;
  }

  Widget _buildBottomRow() {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(flex: 2, child: Container(decoration: BoxDecoration(color: _cardSurface, borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.all(16), child: Column(children: [
        Row(children: [Text('Top Performing Doctors', style: TextStyle(fontFamily: 'Merriweather', color: _primaryTeal, fontSize: 18)), const Spacer(), TextButton(onPressed: () => Navigator.of(context).pushNamed('/admin/doctors'), child: Text('View All', style: TextStyle(color: _accentGold)))]),
        const SizedBox(height: 12),
        Table(columnWidths: const {0: FlexColumnWidth(2),1: FlexColumnWidth(1),2: FlexColumnWidth(1),3: FlexColumnWidth(1)}, children: [
          TableRow(children: [
            Padding(padding: EdgeInsets.all(8.0), child: Text('DOCTOR', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
            Padding(padding: EdgeInsets.all(8.0), child: Text('DEPT', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
            Padding(padding: EdgeInsets.all(8.0), child: Text('PATIENTS', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
            Padding(padding: EdgeInsets.all(8.0), child: Text('RATING', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
          ]),
          ..._topDoctors.map(_doctorRow),
        ]),
      ]))),
      const SizedBox(width: 16),
      Expanded(flex: 1, child: Container(decoration: BoxDecoration(color: _cardSurface, borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.all(16), child: Column(children: [
        Text('Quick Actions', style: TextStyle(fontFamily: 'Merriweather', color: Colors.black87, fontSize: 18)),
        const SizedBox(height: 12),
        GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 10, mainAxisSpacing: 10, children: [
          _quickActionButton(Icons.person_add, 'Add Staff', bgColor: Colors.white, onTap: () => Navigator.of(context).pushNamed('/admin/staff')),
          _quickActionButton(Icons.receipt_long, 'Billing', bgColor: Colors.white, onTap: () => Navigator.of(context).pushNamed('/admin/billing')),
          _quickActionButton(Icons.local_hospital, 'Doctors', bgColor: Colors.white, onTap: () => Navigator.of(context).pushNamed('/admin/doctors')),
          _quickActionButton(Icons.person_search, 'Find Patient', bgColor: Colors.white, onTap: () => _showSnack('Open patient search page')),
        ]),
      ]))),
    ]);
  }

  Widget _quickActionButton(IconData icon, String label, {Color? bgColor, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ?? () => _showSnack(label),
      child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: bgColor ?? Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade100)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 22, color: _primaryTeal), const SizedBox(height: 6), Text(label, style: const TextStyle(fontWeight: FontWeight.w600))])),
    );
  }

  Widget _recentInputsWidget() {
    Widget _buildStreamList(String title, Stream<QuerySnapshot> stream, String roleLabel) {
      return Card(elevation: 0, color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), child: Padding(padding: const EdgeInsets.all(12.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(stream: stream, builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Text('Loading...');
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return const Text('No recent inputs.');
          final items = docs.take(5).map((d) {
            final data = d.data() as Map<String, dynamic>? ?? <String, dynamic>{};
            final name = (data['name'] ?? data['title'] ?? 'Unnamed').toString();
            final sub = (data['specialty'] ?? data['assignedRole'] ?? data['role'] ?? '').toString();
            final timestamp = (data['createdAt'] as Timestamp?)?.toDate();
            final ts = timestamp != null ? timestamp.toLocal().toString().split(' ')[0] : '';
            return ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: CircleAvatar(backgroundColor: _primaryTeal.withOpacity(0.12), child: Text(name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(), style: TextStyle(color: _primaryTeal))), title: Text(name), subtitle: Text('${sub.isEmpty ? roleLabel : sub} ${ts.isNotEmpty ? '• $ts' : ''}'));
          }).toList();
          return Column(children: items);
        })
      ])));
    }

    final doctorsStream = FirebaseFirestore.instance.collection('doctors').orderBy('createdAt', descending: true).snapshots();
    final staffStream = FirebaseFirestore.instance.collection('staff').orderBy('createdAt', descending: true).snapshots();
    final adminsStream = FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'admin').orderBy('createdAt', descending: true).snapshots();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 6),
      const Text('Recent Inputs (Doctors / Staff / Admins)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      const SizedBox(height: 8),
      _buildStreamList('Recent Doctors', doctorsStream, 'Doctor'),
      const SizedBox(height: 8),
      _buildStreamList('Recent Staff', staffStream, 'Staff'),
      const SizedBox(height: 8),
      _buildStreamList('Recent Admins', adminsStream, 'Admin'),
      const SizedBox(height: 8),
    ]);
  }

  Widget _sidebarItem(String title, IconData icon, {bool active = false, VoidCallback? onTap}) {
    return InkWell(onTap: onTap, child: Container(margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: active ? Colors.white.withOpacity(0.08) : Colors.transparent, borderRadius: BorderRadius.circular(8), border: active ? Border(left: BorderSide(color: _accentGold, width: 4)) : null,), child: Row(children: [Icon(icon, color: Colors.white70, size: 18), const SizedBox(width: 10), Text(title, style: TextStyle(color: Colors.white.withOpacity(active ? 1 : 0.9), fontWeight: active ? FontWeight.w700 : FontWeight.w600)),],),),);
  }
}

class _PieLegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final int value;
  const _PieLegendItem({required this.color, required this.label, required this.value, Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Row(children: [Container(width: 12, height: 12, color: color), const SizedBox(width: 6), Text('$label ($value)')]);
  }
}

class _DoctorStat {
  final String id;
  final String name;
  final String specialty;
  final int patients;
  final double rating;
  _DoctorStat({required this.id, required this.name, required this.specialty, required this.patients, required this.rating});
}

/// Simple wrapper to mimic a doc that holds a Map<String,dynamic>
class _MapDoc {
  final Map<String, dynamic> data;
  _MapDoc(this.data);
}

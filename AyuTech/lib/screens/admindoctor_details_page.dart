// lib/screens/admindoctor_details_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class AdminDoctorDetailsPage extends StatefulWidget {
  final DocumentReference docRef;
  const AdminDoctorDetailsPage({Key? key, required this.docRef}) : super(key: key);

  @override
  State<AdminDoctorDetailsPage> createState() => _AdminDoctorDetailsPageState();
}

class _AdminDoctorDetailsPageState extends State<AdminDoctorDetailsPage> {
  // Palette (matches your screenshots)
  static const Color _brandDark = Color(0xFF1B4332);
  static const Color _brandGreen = Color(0xFF1F5F55);
  static const Color _pageBg = Color(0xFFF1EFE0);
  static const Color _sideGreen = Color(0xFF174B40);
  static const Color _accentGold = Color(0xFFD6A657);
  static const double _cardRadius = 14.0;

  int _analyticsSelected = 1; // 0-day,1-month,2-year

  String _fmt(dynamic v) {
    if (v == null) return '-';
    if (v is Timestamp) {
      final d = v.toDate();
      return '${d.day}/${d.month}/${d.year}';
    }
    return v.toString();
  }

  Widget _kpi(String label, String value, {IconData? trailing}) {
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 12, color: Colors.black45)),
        const SizedBox(height: 6),
        Row(children: [
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          if (trailing != null) ...[const SizedBox(width: 6), Icon(trailing, size: 18, color: Colors.amber)],
        ]),
      ]),
    );
  }

  Widget _infoCard({required String title, required Widget child}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardRadius)),
      color: Colors.white,
      elevation: 1,
      child: Padding(padding: const EdgeInsets.all(14.0), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _brandDark)),
        const SizedBox(height: 12),
        child,
      ])),
    );
  }

  Widget _rowPair(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(child: Text(label.toUpperCase(), style: const TextStyle(fontSize: 12, color: Colors.black45))),
        const SizedBox(width: 14),
        Expanded(flex: 2, child: Text(value.isNotEmpty ? value : '-', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
    );
  }

  Widget _buildSmallLineChart(List<double> values) {
    final spots = List.generate(values.length, (i) => FlSpot(i.toDouble(), values[i]));
    final maxY = values.isEmpty ? 40.0 : (values.reduce((a, b) => a > b ? a : b) * 1.25);
    return SizedBox(
      height: 160,
      child: LineChart(LineChartData(
        gridData: FlGridData(show: true, getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.shade200, strokeWidth: 1)),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: maxY <= 0 ? 40 : maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots.isNotEmpty ? spots : const [FlSpot(0, 0)],
            isCurved: true,
            color: _brandGreen,
            barWidth: 3,
            belowBarData: BarAreaData(show: true, color: _brandGreen.withOpacity(0.06)),
            dotData: FlDotData(show: false),
          ),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Always show the fixed sidebar (no drawer) as you requested.
    return FutureBuilder<DocumentSnapshot>(
      future: widget.docRef.get(),
      builder: (context, snap) {
        if (snap.hasError) return Scaffold(body: Center(child: Text('Error: ${snap.error}')));
        if (!snap.hasData || snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(backgroundColor: _pageBg, body: Center(child: CircularProgressIndicator()));
        }

        final data = (snap.data!.data() as Map<String, dynamic>? ?? {});
        final name = (data['name'] ?? data['fullName'] ?? 'Unnamed').toString();
        final specialty = (data['specialty'] ?? data['department'] ?? '-').toString();
        final experience = (data['experience'] ?? data['experienceYears'] ?? '').toString();
        final patients = (data['patientsCount'] ?? data['patients'] ?? 0).toString();
        final rating = (data['rating'] ?? '—').toString();
        final phone = (data['phone'] ?? data['contact'] ?? '').toString();
        final email = (data['email'] ?? '').toString();
        final address = (data['address'] ?? '').toString();
        final dob = _fmt(data['dob'] ?? data['dateOfBirth'] ?? '');
        final loginId = (data['loginId'] ?? data['doctorId'] ?? '').toString();
        final joined = _fmt(data['joinedAt'] ?? data['createdAt'] ?? '');
        final shift = (data['shift'] ?? '').toString();
        final qualifications = (data['qualifications'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? <String>[];
        final medicalLicense = (data['medicalLicense'] ?? '').toString();
        final licenseAuthority = (data['licenseAuthority'] ?? '').toString();
        final role = (data['role'] ?? 'Doctor').toString();
        final topConditions = (data['topConditions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
            <String>['Hypertension', 'High Cholesterol', 'Ischemic Heart Disease', 'Stress Management'];

        List<double> analyticsMonth = (data['analyticsMonth'] as List<dynamic>?)
                ?.map((e) => double.tryParse(e.toString()) ?? 0.0)
                .toList() ??
            [22.0, 26.0, 28.0, 27.0, 31.0];

        final chartValues = _analyticsSelected == 1 ? analyticsMonth : analyticsMonth;

        return Scaffold(
          backgroundColor: _pageBg,
          // drawer intentionally not used — sidebar always visible
          body: Row(children: [
            // Fixed sidebar (left)
            Container(
              width: 260,
              color: _sideGreen,
              child: SafeArea(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
                      ])),
                    ]),
                  ),
                  const SizedBox(height: 18),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text('MAIN', style: TextStyle(color: Colors.white.withOpacity(0.6), fontWeight: FontWeight.w700))),
                  const SizedBox(height: 8),
                  _sideItem(Icons.grid_view, 'Dashboard', active: false),
                  _sideItem(Icons.group, 'Staffs'),
                  _sideItem(Icons.local_hospital, 'Doctors', active: true),
                  _sideItem(Icons.receipt_long, 'Billing & Patients'),
                  const SizedBox(height: 18),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text('REPORTS', style: TextStyle(color: Colors.white.withOpacity(0.6), fontWeight: FontWeight.w700))),
                  const SizedBox(height: 8),
                  _sideItem(Icons.bar_chart, 'Reports & Insights'),
                  const Spacer(),
                  Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      Container(width: 42, height: 42, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
                      const SizedBox(width: 8),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                        Text('Dr. James Smith', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text('Chief Resident', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ])),
                    ]),
                  ),
                ]),
              ),
            ),

            // Main content (right)
            Expanded(
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 22.0),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          // Header row
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Row(children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('Doctors', style: TextStyle(color: _brandDark, fontSize: 28, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 6),
                                  Row(children: [
                                    IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.arrow_back), color: _brandDark),
                                    const SizedBox(width: 8),
                                    const Text('Back to list', style: TextStyle(color: Colors.black54)),
                                  ]),
                                ]),
                              ),
                              SizedBox(
                                width: 300,
                                child: TextField(decoration: InputDecoration(hintText: 'Search...', prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
                              ),
                              const SizedBox(width: 12),
                              Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)), child: IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none))),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.add), label: const Text('+ New Appointment'), style: ElevatedButton.styleFrom(backgroundColor: _accentGold, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
                            ]),
                          ),

                          const SizedBox(height: 18),

                          // Profile card
                          Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardRadius)),
                            elevation: 1,
                            child: Padding(
                              padding: const EdgeInsets.all(18.0),
                              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                                Container(
                                  width: 110,
                                  height: 110,
                                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.grey.shade200),
                                  child: Center(child: Text(name.isNotEmpty ? name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join() : '?', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: _brandGreen))),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Expanded(child: Text(name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: _brandGreen))),
                                      const SizedBox(width: 12),
                                      ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.edit, size: 18), label: const Text('Edit Profile'), style: ElevatedButton.styleFrom(backgroundColor: _brandGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
                                    ]),
                                    const SizedBox(height: 8),
                                    Wrap(spacing: 8, runSpacing: 6, children: [
                                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(999)), child: Text(role)),
                                      if (specialty != '-') Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(999)), child: Text(specialty)),
                                      if (loginId != '') Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(999)), child: Text('ID: $loginId')),
                                    ]),
                                    const SizedBox(height: 14),
                                    Row(children: [
                                      _kpi('Experience', experience.isEmpty || experience == '-' ? '—' : '$experience Years'),
                                      const SizedBox(width: 18),
                                      _kpi('Patients Treated', patients),
                                      const SizedBox(width: 18),
                                      _kpi('Avg Rating', rating, trailing: Icons.star),
                                    ]),
                                  ]),
                                ),
                              ]),
                            ),
                          ),

                          const SizedBox(height: 18),

                          // Two-column info area
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            // Left column
                            Expanded(
                              flex: 2,
                              child: Column(children: [
                                _infoCard(
                                  title: 'Personal Info',
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    _rowPair('Gender', (data['gender'] ?? '-').toString()),
                                    const Divider(),
                                    _rowPair('DOB', dob),
                                    const Divider(),
                                    _rowPair('Contact', phone),
                                    const SizedBox(height: 8),
                                    _rowPair('Email', email),
                                    if (address.isNotEmpty && address != '-') ...[const SizedBox(height: 12), _rowPair('Address', address)],
                                  ]),
                                ),
                                const SizedBox(height: 12),
                                _infoCard(
                                  title: 'Credentials',
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    _rowPair('Qualification', qualifications.isNotEmpty ? qualifications.join(', ') : (data['qualification'] ?? '-').toString()),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(color: Colors.yellow.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.yellow.shade100)),
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text('MEDICAL LICENSE', style: TextStyle(color: Colors.brown.shade700, fontWeight: FontWeight.w800)),
                                        const SizedBox(height: 8),
                                        Text(medicalLicense.isNotEmpty ? medicalLicense : '-', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 6),
                                        Text(licenseAuthority.isNotEmpty ? licenseAuthority : ''),
                                      ]),
                                    ),
                                  ]),
                                ),
                                const SizedBox(height: 12),
                              ]),
                            ),

                            const SizedBox(width: 16),

                            // Right column
                            Expanded(
                              flex: 3,
                              child: Column(children: [
                                _infoCard(
                                  title: 'Professional Details',
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    _rowPair('Doctor ID', loginId.isNotEmpty ? loginId : '-'),
                                    const Divider(),
                                    _rowPair('Date of Joining', joined),
                                    const Divider(),
                                    _rowPair('Shift Timing', shift.isNotEmpty ? shift : '-'),
                                    const SizedBox(height: 8),
                                    _rowPair('System Role', role),
                                  ]),
                                ),
                                const SizedBox(height: 12),
                                _infoCard(
                                  title: 'Account Access',
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    _rowPair('Username', (data['username'] ?? loginId).toString()),
                                    const Divider(),
                                    _rowPair('Password', '••••••••'),
                                  ]),
                                ),
                                const SizedBox(height: 12),
                                Card(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Row(children: [Text('Patient Analytics', style: TextStyle(fontWeight: FontWeight.w800, color: _brandGreen)), const Spacer(), ToggleButtons(isSelected: List.generate(3, (i) => i == _analyticsSelected), onPressed: (i) => setState(() => _analyticsSelected = i), children: const [Text('Day'), Text('Month'), Text('Year')])]),
                                      const SizedBox(height: 12),
                                      _buildSmallLineChart(chartValues),
                                      const SizedBox(height: 8),
                                      Wrap(spacing: 8, children: topConditions.map((c) => Chip(label: Text(c))).toList()),
                                    ]),
                                  ),
                                ),
                              ]),
                            ),
                          ]),

                          const SizedBox(height: 24),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }

  Widget _sideItem(IconData icon, String label, {bool active = false}) {
    return InkWell(
      onTap: () {},
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: active ? _sideGreen.withOpacity(0.85) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: active ? const Border(left: BorderSide(color: Color(0xFFD6A657), width: 4)) : null,
        ),
        child: Row(children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(color: Colors.white.withOpacity(active ? 1 : 0.9), fontWeight: active ? FontWeight.w700 : FontWeight.w600))),
          if (active) const Icon(Icons.chevron_right, color: Colors.white),
        ]),
      ),
    );
  }
}

// File: lib/screens/dashboard_screen.dart
// AyuTech Dashboard — Visual clone with working charts using fl_chart
// Functionality unchanged: Firestore, auth, navigation, and methods remain as before.

import 'package:flutter/material.dart';
import 'package:ayutech/models/patient.dart';
import 'package:ayutech/screens/patient_entry_screen.dart';
import 'package:ayutech/screens/patient_history_screen.dart';
import 'package:ayutech/screens/ongoing_patients_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ayutech/services/app_store.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'welcome_screen.dart';

// charts
import 'package:fl_chart/fl_chart.dart';

class AyuColors {
  static const Color teal = Color(0xFF2F5C56);
  static const Color cream = Color(0xFFFAFAF8);
  static const Color gold = Color(0xFFD6A657);
  static const Color text = Color(0xFF333333);
  static const Color amber = Color(0xFFFFF8E1);
  static const Color blue = Color(0xFFE3F2FD);
  static const Color green = Color(0xFFE8F5E9);
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Dummy values for now
  final String clinicName = "AyuTech Clinic";
  final String clinicAddress = "Velachery";
  final String clinicEmail = "doc@gmail.com";
  final String clinicPhone = "7646178180";

  final List<Patient> _patients = [];

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

  Future<void> _handleLogout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    await AppStore().setLoggedIn(value: false, username: "");
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  // Sidebar menu item builder
  Widget _SidebarItem(
      {required IconData icon,
      required String title,
      required bool active,
      VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: active ? AyuColors.teal.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: active ? AyuColors.teal : Colors.white70, size: 20),
            const SizedBox(width: 12),
            Text(title,
                style: TextStyle(
                    color: Colors.white.withOpacity(active ? 1.0 : 0.95),
                    fontFamily: 'Merriweather',
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _StatCard(
      {required String title,
      required String value,
      required String subtitle,
      required Color bg,
      required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: SizedBox(
        width: 220,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title.toUpperCase(),
                    style: const TextStyle(fontSize: 12, fontFamily: 'Lato', color: Colors.black54, fontWeight: FontWeight.w700)),
                Icon(icon, color: Colors.black38),
              ],
            ),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(fontSize: 28, fontFamily: 'Merriweather', fontWeight: FontWeight.w800, color: Color(0xFF2E2E2E))),
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(fontSize: 12, fontFamily: 'Lato', color: Colors.black45)),
          ],
        ),
      ),
    );
  }

  // --- Chart data (static sample data matching the screenshot look) ---
  // Line chart data (weekly)
  final List<double> mainSeries = [45, 50, 38, 66, 62, 42, 36]; // green solid
  final List<double> secondarySeries = [40, 48, 44, 46, 52, 46, 30]; // dashed gold

  // Pie chart segments (values)
  final List<double> pieValues = [40, 30, 30]; // sum 100

  // Convert to FlSpot list helper
  List<FlSpot> _toSpots(List<double> data) {
    return List.generate(data.length, (i) => FlSpot(i.toDouble(), data[i]));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final sidebarWidth = 260.0;

    return Scaffold(
      backgroundColor: AyuColors.cream,
      body: SafeArea(
        child: Row(
          children: [
            // LEFT SIDEBAR
            Container(
              width: sidebarWidth,
              color: AyuColors.teal,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo + Title
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(color: AyuColors.gold, shape: BoxShape.circle),
                        child: const Center(child: Icon(Icons.local_hospital, color: Colors.white)),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('AyuTech',
                              style: TextStyle(
                                  color: Colors.white, fontFamily: 'Merriweather', fontWeight: FontWeight.w800, fontSize: 18)),
                          SizedBox(height: 2),
                          Text('DOCTOR PORTAL', style: TextStyle(color: Colors.white70, fontFamily: 'Lato', fontSize: 11)),
                        ],
                      )
                    ],
                  ),

                  const SizedBox(height: 22),

                  // Menu
                  _SidebarItem(icon: Icons.dashboard, title: 'Dashboard', active: true, onTap: () {}),
                  _SidebarItem(
                      icon: Icons.person_add,
                      title: 'New Entry',
                      active: false,
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => PatientEntryScreen(onSave: _addPatient)));
                      }),
                  _SidebarItem(
                      icon: Icons.local_hospital,
                      title: 'Ongoing Patient',
                      active: false,
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => OngoingPatientsScreen(doctorUid: FirebaseAuth.instance.currentUser?.uid)));
                      }),
                  _SidebarItem(
                      icon: Icons.folder_open,
                      title: 'Records',
                      active: false,
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => PatientHistoryScreen(patients: _patients, uid: '')));
                      }),

                  const SizedBox(height: 20),

                  // Divider
                  Container(height: 1, color: Colors.white24),

                  const SizedBox(height: 14),

                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AyuColors.teal.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        CircleAvatar(backgroundColor: AyuColors.gold, child: Text('DR', style: TextStyle(color: AyuColors.teal, fontWeight: FontWeight.w800))),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Dr. Sharma', style: TextStyle(color: Colors.white, fontFamily: 'Merriweather', fontWeight: FontWeight.w700)),
                            SizedBox(height: 2),
                            Text('MD (Ayurveda)', style: TextStyle(color: Colors.white70, fontFamily: 'Lato', fontSize: 12)),
                          ],
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // RIGHT MAIN CONTENT
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top header row: title + date + New Appointment
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Dashboard Overview',
                            style: const TextStyle(
                                fontSize: 32, fontFamily: 'Merriweather', fontWeight: FontWeight.w800, color: AyuColors.teal)),
                        Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(DateTime.now().toLocal().toString().split(' ').first,
                                    style: const TextStyle(fontFamily: 'Lato', color: Colors.black54)),
                                const SizedBox(height: 4),
                              ],
                            ),
                            const SizedBox(width: 14),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => PatientEntryScreen(onSave: _addPatient)));
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('New Appointment', style: TextStyle(fontFamily: 'Lato')),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AyuColors.gold,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                            )
                          ],
                        )
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Stats cards row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _StatCard(title: 'Total Patients', value: '1,482', subtitle: '+12.5% vs last month', bg: Colors.white, icon: Icons.people),
                          const SizedBox(width: 12),
                          _StatCard(title: 'Waiting List', value: '1', subtitle: 'Queue normal', bg: AyuColors.amber, icon: Icons.calendar_today),
                          const SizedBox(width: 12),
                          _StatCard(title: 'In Consultation', value: '2', subtitle: 'Active sessions', bg: AyuColors.blue, icon: Icons.show_chart),
                          const SizedBox(width: 12),
                          _StatCard(title: 'Completed', value: '1', subtitle: "Today's closures", bg: AyuColors.green, icon: Icons.check_circle),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Charts area
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left large chart (Patient Traffic & Trends) - using LineChart
                          Expanded(
                            flex: 3,
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))]),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                    Text('Patient Traffic & Trends',
                                        style: const TextStyle(fontFamily: 'Merriweather', fontSize: 18, fontWeight: FontWeight.w700, color: AyuColors.teal)),
                                    DropdownButton<String>(
                                      value: 'Weekly',
                                      items: const [
                                        DropdownMenuItem(value: 'Weekly', child: Text('Weekly')),
                                        DropdownMenuItem(value: 'Monthly', child: Text('Monthly')),
                                      ],
                                      onChanged: (_) {},
                                    )
                                  ]),
                                  const SizedBox(height: 12),
                                  // Actual LineChart widget
                                  Expanded(
                                    child: LineChart(
                                      LineChartData(
                                        gridData: FlGridData(
                                          show: true,
                                          horizontalInterval: 20,
                                          getDrawingHorizontalLine: (value) => FlLine(color: const Color(0xFFE9E9E9), strokeWidth: 1),
                                          drawVerticalLine: false,
                                        ),
                                        titlesData: FlTitlesData(
                                          bottomTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: true,
                                              reservedSize: 30,
                                              getTitlesWidget: (value, meta) {
                                                const style = TextStyle(fontSize: 12, color: Colors.black54, fontFamily: 'Lato');
                                                switch (value.toInt()) {
                                                  case 0:
                                                    return const Text('Mon', style: style);
                                                  case 1:
                                                    return const Text('Tue', style: style);
                                                  case 2:
                                                    return const Text('Wed', style: style);
                                                  case 3:
                                                    return const Text('Thu', style: style);
                                                  case 4:
                                                    return const Text('Fri', style: style);
                                                  case 5:
                                                    return const Text('Sat', style: style);
                                                  case 6:
                                                    return const Text('Sun', style: style);
                                                }
                                                return const Text('');
                                              },
                                            ),
                                          ),
                                          leftTitles: AxisTitles(
                                            sideTitles: SideTitles(showTitles: false),
                                          ),
                                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                        ),
                                        minX: 0,
                                        maxX: 6,
                                        minY: 0,
                                        maxY: 80,
                                        lineBarsData: [
                                          // main (green solid with gradient area)
                                          LineChartBarData(
                                            spots: _toSpots(mainSeries),
                                            isCurved: true,
                                            barWidth: 4,
                                            color: AyuColors.teal,
                                            dotData: FlDotData(show: false),
                                            belowBarData: BarAreaData(
                                              show: true,
                                              gradient: LinearGradient(
                                                colors: [
                                                  AyuColors.teal.withOpacity(0.22),
                                                  AyuColors.teal.withOpacity(0.06),
                                                  Colors.white.withOpacity(0.0),
                                                ],
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                              ),
                                              cutOffY: 0,
                                            ),
                                            shadow: const Shadow(color: Colors.black26, blurRadius: 0),
                                          ),
                                          // secondary (gold dashed)
                                          LineChartBarData(
                                            spots: _toSpots(secondarySeries),
                                            isCurved: true,
                                            barWidth: 2.5,
                                            color: AyuColors.gold,
                                            dotData: FlDotData(show: false),
                                            dashArray: [6, 4],
                                            belowBarData: BarAreaData(show: false),
                                          ),
                                        ],
                                        borderData: FlBorderData(show: false),
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),

                          // Right smaller chart (Dept Distribution)
                          Expanded(
                            flex: 1,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))]),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Dept. Distribution',
                                      style: const TextStyle(fontFamily: 'Merriweather', fontSize: 18, fontWeight: FontWeight.w700, color: AyuColors.teal)),
                                  const SizedBox(height: 12),
                                  // Donut (PieChart) widget
                                  SizedBox(
                                    height: 180,
                                    child: PieChart(
                                      PieChartData(
                                        sectionsSpace: 6,
                                        centerSpaceRadius: 46,
                                        startDegreeOffset: -90,
                                        sections: List.generate(3, (i) {
                                          final value = pieValues[i];
                                          final color = (i == 0)
                                              ? AyuColors.teal
                                              : (i == 1)
                                                  ? const Color(0xFFD6A657)
                                                  : const Color(0xFF7FCF8F);
                                          return PieChartSectionData(
                                            value: value,
                                            color: color,
                                            radius: 44,
                                            showTitle: false,
                                          );
                                        }),
                                        // optional touch callback, not required
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  // Center text (placed below the chart to match screenshot; fl_chart center text requires extra painting — simpler layout)
                                  Center(
                                    child: Text('100%', style: const TextStyle(fontSize: 22, fontFamily: 'Merriweather', fontWeight: FontWeight.w800, color: AyuColors.teal)),
                                  ),
                                  const SizedBox(height: 12),
                                  // Legend
                                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                                    SizedBox(height: 6),
                                    Text('PANCHAKARMA', style: TextStyle(fontFamily: 'Lato', fontSize: 12, color: Colors.black54)),
                                    SizedBox(height: 4),
                                    Text('KAYACHIKITSA', style: TextStyle(fontFamily: 'Lato', fontSize: 12, color: Colors.black54)),
                                    SizedBox(height: 4),
                                    Text('SHALYA', style: TextStyle(fontFamily: 'Lato', fontSize: 12, color: Colors.black54)),
                                  ])
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Bottom area: keep Sign Out button (functions unchanged)
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: () => _handleLogout(context),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AyuColors.teal,
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
                        icon: const Icon(Icons.logout, color: Colors.white),
                        label: const Text('Sign Out', style: TextStyle(color: Colors.white, fontFamily: 'Lato')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  

}

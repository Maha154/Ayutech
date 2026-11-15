// lib/screens/patient_history_screen.dart
// Integrated UI design to match provided screenshots.
// NOTE: I only changed UI/visuals (colors, spacing, typography, buttons, badges, shadows).
// Functionality, streams and navigation remain the same as your original file.

import 'package:ayutech/screens/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ayutech/models/patient.dart';
import 'patient_report_screen.dart';
import 'package:ayutech/services/app_store.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class PatientHistoryScreen extends StatefulWidget {
  final String uid;
  final List<Patient> patients;

  const PatientHistoryScreen({
    super.key,
    required this.uid,
    required this.patients,
  });

  @override
  State<PatientHistoryScreen> createState() => _PatientHistoryScreenState();
}

class _PatientHistoryScreenState extends State<PatientHistoryScreen> {
  final TextEditingController _search = TextEditingController();
  String _statusFilter = 'All';

  late List<Patient> _all;
  late List<Patient> _visible;

  @override
  void initState() {
    super.initState();
    _all = List<Patient>.from(widget.patients);
    _visible = List<Patient>.from(widget.patients);
    _loadFromStore();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadFromStore() async {
    final stored = await AppStore().getPatients();
    if (!mounted) return;
    setState(() {
      _all = stored.isNotEmpty ? stored : _all;
      _applyFilters();
    });
  }

  Future<void> _deletePatient(String patientId) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      await FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .collection("patients")
          .doc(patientId)
          .delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Patient deleted successfully ✅")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete: $e")),
      );
    }
  }

  // Sidebar helper (method inside the state class)
  Widget _sidebarItem(IconData icon, String title, {bool selected = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2E6A58) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          leading: Icon(icon, color: Colors.white),
          title: Text(title, style: const TextStyle(color: Colors.white)),
          onTap: () {
            // visual-only by default; add navigation here if you want
          },
        ),
      ),
    );
  }

  Stream<List<Patient>> _patientsStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream<List<Patient>>.empty();

    return FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("patients")
        .orderBy("createdAt", descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Patient(
          id: doc.id,
          name: data["name"] ?? "",
          age: data["age"] ?? 0,
          gender: data["gender"] ?? "",
          region: data["region"] ?? "",
          phoneNumber: data["phoneNumber"] ?? "",
          diseases: data["disease"] is List
              ? List<String>.from(data["disease"])
              : (data["disease"] ?? "")
                  .toString()
                  .split(",")
                  .map((e) => e.trim())
                  .toList(),
          status: data["status"] ?? "Active",
          prescriber: data["prescriber"] ?? "",
          allergy: data["allergy"] ?? "",
          bowelMovement: data["bowelMovement"] ?? "",
          waterIntake: data["waterIntake"] ?? "",
          medicalHistory: data["medicalHistory"] ?? "",
          startDate:
              DateTime.tryParse(data["startDate"] ?? "") ?? DateTime.now(),
          physicalActivity: data["physicalActivity"] ?? "",
        );
      }).toList();
    });
  }

  void _applyFilters() {
    final q = _search.text.toLowerCase().trim();
    setState(() {
      _visible = _all.where((p) {
        final matchesQuery = q.isEmpty ||
            p.name.toLowerCase().contains(q) ||
            p.diseases.join(", ").toLowerCase().contains(q) ||
            p.region.toLowerCase().contains(q);

        final matchesStatus = _statusFilter.toLowerCase() == 'all'
            ? true
            : p.status.toLowerCase() == _statusFilter.toLowerCase();

        return matchesQuery && matchesStatus;
      }).toList();
    });
  }

  List<Patient> _filterLive(List<Patient> src) {
    final q = _search.text.toLowerCase().trim();
    final status = _statusFilter.toLowerCase();
    return src.where((p) {
      final matchesQuery = q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.diseases.join(", ").toLowerCase().contains(q) ||
          p.region.toLowerCase().contains(q);
      final matchesStatus =
          status == 'all' ? true : p.status.toLowerCase() == status;
      return matchesQuery && matchesStatus;
    }).toList();
  }

  String _fmtDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Widget _buildTableHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF7F6F2),
        borderRadius:
            BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
        border: Border(
          bottom: BorderSide(color: Color(0xFFEAE7DF), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          _buildHeaderCell('FULL NAME', flex: 2),
          _buildHeaderCell('ID', flex: 1),
          _buildHeaderCell('TOKEN', flex: 1),
          _buildHeaderCell('AGE', flex: 1),
          _buildHeaderCell('REGION', flex: 2),
          _buildHeaderCell('STATUS', flex: 1),
          _buildHeaderCell('DISEASE', flex: 2),
          _buildHeaderCell('START DATE', flex: 2),
          _buildHeaderCell('ACTIONS', flex: 1),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String title, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF374151),
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildTableRow(Patient patient) {
    // row background is white with subtle separator lines
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFEEF2F3), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Full Name
          Expanded(
            flex: 2,
            child: Text(
              patient.name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
          ),

          // ID placeholder
          Expanded(
            flex: 1,
            child: Text(
              patient.id != null && patient.id!.isNotEmpty
                  ? '#${patient.id!.substring(0, patient.id!.length.clamp(0, 6))}'
                  : '#REC',
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
          ),

          // TOKEN placeholder
          Expanded(
            flex: 1,
            child: Text(
              '#${(patient.age % 100).toString()}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
          ),

          // Age
          Expanded(
            flex: 1,
            child: Text(
              patient.age.toString(),
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
          ),

          // Region
          Expanded(
            flex: 2,
            child: Text(
              patient.region.isEmpty ? '—' : patient.region,
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
          ),

          // Status badge (smaller)
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildStatusBadge(patient.status),
            ),
          ),

          // Disease
          Expanded(
            flex: 2,
            child: Text(
              patient.diseases.isEmpty ? '—' : patient.diseases.join(', '),
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Start Date
          Expanded(
            flex: 2,
            child: Text(
              _fmtDate(patient.startDate),
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
          ),

          // Actions
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PatientReportScreen(
                            uid: patient.id ?? '',
                            name: patient.name,
                            age: patient.age.toString(),
                            gender: patient.gender,
                            initialConditions: patient.diseases,
                            previousHistory: patient.medicalHistory,
                            region: patient.region,
                            allergy: patient.allergy,
                            phoneNumber: patient.phoneNumber,
                            startDate: patient.startDate,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.insert_drive_file, size: 16),
                    label: const Text('Solution Chart',
                        style:
                            TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _deletePatient(patient.id ?? ''),
                  child: const Text('Delete',
                      style: TextStyle(
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final st = status.toLowerCase();
    Color bg = const Color(0xFFFEE2E2);
    Color text = const Color(0xFFDC2626);

    if (st.contains('ongoing') || st.contains('active')) {
      bg = const Color(0xFFFEF3F2); // subtle pink
      text = const Color(0xFFEF4444);
    } else if (st.contains('completed') || st.contains('ended')) {
      bg = const Color(0xFFF3F4F6);
      text = const Color(0xFF6B7280);
    } else if (st.contains('waiting')) {
      bg = const Color(0xFFFFF7ED);
      text = const Color(0xFFB45309);
    }









    // Smaller badge: reduced padding + smaller font
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: text),
        textAlign: TextAlign.center,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Define a fixed table width that matches the pixel spacing in your design.
    // Increase this if you add more columns or wider cells.
    const double tableWidth = 1240; // tweak if you want slightly wider

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Row(
        children: [
          // Sidebar (fixed width)
          Container(
            width: 260,
            color: const Color(0xFF155B4A),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: const [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Color(0xFFBEECD9),
                          child:
                              Icon(Icons.medical_services, color: Color(0xFF0F5132)),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'AyuTech\nDOCTOR PORTAL',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Nav items (visual)
                  _sidebarItem(Icons.dashboard, 'Dashboard', selected: false),
                  _sidebarItem(Icons.person_add, 'New Entry', selected: false),
                  _sidebarItem(Icons.access_time, 'Ongoing Patient', selected: false),
                  _sidebarItem(Icons.folder, 'Records', selected: true),

                  const Spacer(),

                  // Profile at bottom
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: const [
                        CircleAvatar(
                            radius: 22,
                            backgroundColor: Color(0xFF2B6B5A),
                            child: Text('DR', style: TextStyle(color: Colors.white))),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Dr. Sharma\nMD (Ayurveda)',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Main content area
          Expanded(
            child: StreamBuilder<List<Patient>>(
              stream: _patientsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text("Error loading patients"));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("No patients found"));
                }

                final patients = snapshot.data!;
                final filtered = _filterLive(patients);

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Page title + description
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const DashboardScreen()),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('Patient Records',
                                  style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A))),
                              SizedBox(height: 6),
                              Text('Find and manage patients',
                                  style: TextStyle(fontSize: 16, color: Color(0xFF6B7280))),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 22),

                      // Search + Filters row
                      Row(
                        children: [
                          // Name filter dropdown (visual only)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFECF0F2))),
                            child: Row(children: const [Icon(Icons.filter_list, size: 18), SizedBox(width: 8), Text('Name')]),
                          ),
                          const SizedBox(width: 12),

                          // Search field
                          Expanded(
                            child: TextField(
                              controller: _search,
                              decoration: InputDecoration(
                                hintText: 'Search by name...',
                                prefixIcon: const Icon(Icons.search),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Region dropdown visual
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFECF0F2))),
                            child: const Text('All Regions'),
                          ),
                          const SizedBox(width: 12),

                          // Start Date button visual
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFECF0F2))),
                            child: Row(children: const [Icon(Icons.calendar_today, size: 16), SizedBox(width: 8), Text('Start Date')]),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Table container (card) wrapped in horizontal scroll so columns keep exact widths
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Container(
                          width: tableWidth,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9F9),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 6)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildTableHeader(),
                              if (filtered.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(40),
                                  child: const Center(child: Text('No matching patients found.', style: TextStyle(color: Color(0xFF6B7280)))),
                                )
                              else
                                Column(children: filtered.map((p) => _buildTableRow(p)).toList()),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // footer spacing
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientQuickViewDialog extends StatelessWidget {
  final Patient patient;
  final String Function(DateTime) fmtDate;

  const _PatientQuickViewDialog({
    required this.patient,
    required this.fmtDate,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(patient.name),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Age: ${patient.age}, Gender: ${patient.gender}"),
            Text("Region: ${patient.region}"),
            Text("Contact: ${patient.phoneNumber}"),
            Text("Start Date: ${fmtDate(patient.startDate)}"),
            Text("Prescriber: ${patient.prescriber}"),
            Text("Allergies: ${patient.allergy}"),
            Text("Bowel: ${patient.bowelMovement}"),
            Text("Water Intake: ${patient.waterIntake}"),
            Text("Conditions: ${patient.diseases}"),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: const Text("Close"),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}

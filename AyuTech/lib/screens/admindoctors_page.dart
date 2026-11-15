// lib/screens/admindoctors_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart'; // used for a small analytics placeholder
import 'admindoctor_details_page.dart';

class DoctorsPage extends StatefulWidget {
  const DoctorsPage({super.key});

  @override
  State<DoctorsPage> createState() => _DoctorsPageState();
}

class _DoctorsPageState extends State<DoctorsPage> {
  final TextEditingController _searchCtl = TextEditingController();
  final CollectionReference _doctorColl = FirebaseFirestore.instance.collection('doctors');

  String _search = '';
  bool _loadingAction = false;

  static const List<String> _departments = [
    'Panchakarma',
    'Kayachikitsa (General Medicine)',
    'Shalya Tantra (Surgery & Wound Care)',
    'Shalakya Tantra (Eye, ENT, Dental)',
    'Prasuti & Stri Roga (Women’s Care)',
    'Kaumarbhritya (Pediatrics)',
    'Ayurvedic Physiotherapy & Rehab',
    'Swasthavritta (Wellness & Lifestyle)',
  ];

  // AyuTech unified palette (MATCHES WELCOME SCREEN)
static const Color ayuGreen = Color(0xFF2F5C56);
static const Color ayuGold  = Color(0xFFD6A657);
static const Color pageBg   = Color(0xFFFAFAF8);


  @override
  void initState() {
    super.initState();
    _searchCtl.addListener(() {
      setState(() => _search = _searchCtl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _toggleStatus(DocumentReference ref, String current) async {
    final next = current == 'active' ? 'inactive' : 'active';
    setState(() => _loadingAction = true);
    try {
      await ref.update({'status': next});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status changed to $next')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
    } finally {
      if (mounted) setState(() => _loadingAction = false);
    }
  }

  Future<void> _deleteDoctor(DocumentReference ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete doctor'),
        content: const Text('Are you sure you want to delete this doctor record? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _loadingAction = true);
    try {
      await ref.delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Doctor deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    } finally {
      if (mounted) setState(() => _loadingAction = false);
    }
  }

  Future<String> _generateDoctorIdFromDob(String dobIso) async {
    String normalizeDob(String iso) {
      try {
        final parts = iso.split('-');
        if (parts.length == 3) {
          final y = parts[0];
          final m = parts[1].padLeft(2, '0');
          final d = parts[2].padLeft(2, '0');
          return '$d$m$y';
        }
      } catch (_) {}
      return DateTime.now().millisecondsSinceEpoch.toString();
    }

    final base = 'doctor' + normalizeDob(dobIso);
    final coll = FirebaseFirestore.instance.collection('doctors');

    final check = (String candidate) async {
      final q = await coll.where('loginId', isEqualTo: candidate).limit(1).get();
      return q.docs.isEmpty;
    };

    if (await check(base)) return base;

    for (int i = 1; i <= 50; i++) {
      final cand = '${base}_$i';
      if (await check(cand)) return cand;
    }

    return '${base}_${DateTime.now().millisecondsSinceEpoch}';
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 8.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              Navigator.maybePop(context);
            },
          ),
          const SizedBox(width: 6),
          const Text('Doctors', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const Spacer(),
          ElevatedButton(
            onPressed: _loadingAction ? null : _showRegisterDoctorDialog,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD6A657)),
            child: const Text('Add New Doctor'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: ayuGreen.withOpacity(0.15)),),
        child: Row(
          children: [
            Icon(Icons.search, color: ayuGreen.withOpacity(0.6)),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchCtl,
                decoration: const InputDecoration.collapsed(hintText: 'Search doctors by name, email, dept or ID'),
              ),
            ),
            if (_search.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchCtl.clear();
                },
              )
          ],
        ),
      ),
    );
  }

  Widget _tableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: const [
          Expanded(flex: 3, child: Text('DOCTOR NAME', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          Expanded(flex: 2, child: Text('SPECIALTY', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          Expanded(flex: 1, child: Text('EXP', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          Expanded(flex: 2, child: Text('CONTACT', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          Expanded(flex: 2, child: Text('LOGIN ID', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          Expanded(flex: 1, child: Text('PATIENTS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          Expanded(
  flex: 1,
  child: Align(
    alignment: Alignment.centerRight,
    child: Text(
      'ACTIONS',
      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
    ),
  ),
),

        ],
      ),
    );
  }

  // ---------- UPDATED: tappable row that opens details ----------
  Widget _doctorRow(Map<String, dynamic> data, DocumentReference ref) {
    final name = (data['name'] ?? '').toString();
    final specialty = (data['specialty'] ?? '').toString();
    final experience = (data['experience'] ?? '').toString();
    final email = (data['email'] ?? '').toString();
    final patients = (data['patientsCount'] ?? 0).toString();
    final loginId = (data['loginId'] ?? '').toString();

    final initials = name.isNotEmpty ? name.trim().split(RegExp(r'\s+')).map((s) => s[0]).take(2).join().toUpperCase() : '?';

    void _openDetails() {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminDoctorDetailsPage(docRef: ref)));
      
    }

    return InkWell(
      onTap: _openDetails,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  CircleAvatar(
  radius: 20,
  backgroundColor: ayuGreen.withOpacity(0.12),
  child: Text(
    initials,
    style: const TextStyle(
      color: ayuGreen,
      fontWeight: FontWeight.bold,
    ),
  ),
),

                  const SizedBox(width: 12),
                  Flexible(child: Text(name.isNotEmpty ? name : 'Unnamed', style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
            Expanded(flex: 2, child: Text(specialty.isNotEmpty ? specialty : '-', style: const TextStyle(color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis)),
            Expanded(flex: 1, child: Text(experience.isNotEmpty ? "$experience Yrs" : '-', style: const TextStyle(color: Colors.black54))),
            Expanded(flex: 2, child: Text(email.isNotEmpty ? email : '-', style: const TextStyle(color: Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis)),
            Expanded(flex: 2, child: Text(loginId.isNotEmpty ? loginId : '-', style: const TextStyle(color: Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis)),
            Expanded(flex: 1, child: Text(patients, style: const TextStyle(fontWeight: FontWeight.w600))),
           SizedBox(
  width: 110,
  child: Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      
      IconButton(
        icon: const Icon(Icons.edit, size: 18),
        onPressed: () => _showEditDoctorDialog(ref),
        tooltip: 'Edit',
      ),
      IconButton(
        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
        onPressed: () => _confirmDeleteDoctor(ref),
        tooltip: 'Delete permanently',
      ),
    ],
  ),
),

          ],
        ),
      ),
    );
  }
  // ---------------------------------------------------------------
Future<void> _confirmDeleteDoctor(DocumentReference ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Delete Doctor'),
      content: const Text(
        'This doctor will be permanently deleted.\n\nThis action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  try {
    await ref.delete();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Doctor permanently deleted')),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Delete failed: $e')),
    );
  }
}

  void _openDoctorDetailsPage(DocumentReference ref) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DoctorProfilePage(docRef: ref)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Stream<QuerySnapshot> stream = _doctorColl.orderBy('createdAt', descending: true).snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAF8),
      body: SafeArea(
        child: Row(
          children: [
            // Sidebar
            Container(
              width: 260,
              color: ayuGreen,

              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.local_hospital, color: Color(0xFF1F5F55)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('AyuTech', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                              SizedBox(height: 4),
                              Text('MEDICAL ADMIN', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                            ],
                          ))
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text('Main', style: TextStyle(color: Colors.white.withOpacity(0.6), fontWeight: FontWeight.w700))),
                    const SizedBox(height: 8),
                    _sidebarItem('Dashboard', Icons.dashboard_outlined, active: false, onTap: () => Navigator.of(context).pushReplacementNamed('/admin/home')),
                    _sidebarItem('Staffs', Icons.group_outlined, onTap: () => Navigator.of(context).pushReplacementNamed('/staffs')),
                    _sidebarItem('Doctors', Icons.medical_services_outlined, active: true, onTap: () {}),
                    _sidebarItem('Billing & Patients', Icons.receipt_long_outlined, onTap: () => Navigator.of(context).pushReplacementNamed('/billing')),
                    const SizedBox(height: 18),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text('Reports', style: TextStyle(color: Colors.white.withOpacity(0.6), fontWeight: FontWeight.w700))),
                    const SizedBox(height: 8),
                    _sidebarItem('Reports & Insights', Icons.bar_chart, onTap: () => Navigator.of(context).pushReplacementNamed('/reports')),
                    const Spacer(),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0x15555555)))),
                      child: Row(
                        children: [
                          Container(width: 46, height: 46, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white24)), child: const CircleAvatar(radius: 22, backgroundColor: Colors.white, child: Icon(Icons.person, color: Color(0xFF1F5F55)))),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                            Text('Dr. James Smith', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                            SizedBox(height: 4),
                            Text('Chief Resident', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ])),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),

            // Main content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 8),
                    _buildSearchBar(),
                    const SizedBox(height: 12),
                    _tableHeader(),
                    const SizedBox(height: 8),
                    Expanded(
  child: Scrollbar(
    thumbVisibility: true,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 1200, // ✅ forces horizontal scroll when needed
        child: Column(
          children: [
           Expanded(
  child: SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: SizedBox(
      width: 1150, // 🔑 controls table width (adjust if needed)
      child: Column(
        children: [
          _tableHeader(),
          const SizedBox(height: 8),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: stream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data?.docs ?? [];
                final filtered = docs.where((d) {
                  final data = (d.data() as Map<String, dynamic>? ?? {});
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  final specialty = (data['specialty'] ?? '').toString().toLowerCase();
                  final loginId = (data['loginId'] ?? '').toString().toLowerCase();
                  final id = d.id.toLowerCase();

                  if (_search.isEmpty) return true;
                  return name.contains(_search) ||
                      email.contains(_search) ||
                      specialty.contains(_search) ||
                      loginId.contains(_search) ||
                      id.contains(_search);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No doctors found.'));
                }

                return Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        Divider(color: Colors.grey.shade200),
                    itemBuilder: (context, i) {
                      final doc = filtered[i];
                      final data =
                          (doc.data() as Map<String, dynamic>? ?? {});
                      return _doctorRow(data, doc.reference);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  ),
),

          ],
        ),
      ),
    ),
  ),
),

                    if (_loadingAction) const LinearProgressIndicator(minHeight: 3),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRegisterDoctorDialog() async {
    final _formKey = GlobalKey<FormState>();
    final _name = TextEditingController();
    final _experience = TextEditingController();
    final _phone = TextEditingController();
    final _email = TextEditingController();
    final _dobController = TextEditingController();
    final _department = ValueNotifier<String?>(null);
    final _adminPassword = TextEditingController();

    Future<void> _pickDob() async {
      final now = DateTime.now();
      final initial = DateTime(now.year - 30, now.month, now.day);
      final picked = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(1900), lastDate: DateTime.now());
      if (picked != null) {
        _dobController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      }
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Register New Doctor'),
            content: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Doctor name'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter name' : null,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _department.value,
                    items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    decoration: const InputDecoration(labelText: 'Department'),
                    onChanged: (v) => _department.value = v,
                    validator: (v) => (v == null || v.isEmpty) ? 'Select department' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _experience,
                    decoration: const InputDecoration(labelText: 'Experience (years)'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _phone,
                    decoration: const InputDecoration(labelText: 'Phone'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'Email ID'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter email';
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) return 'Enter valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _dobController,
                    readOnly: true,
                    decoration: InputDecoration(labelText: 'Date of birth', suffixIcon: IconButton(icon: const Icon(Icons.calendar_today), onPressed: _pickDob)),
                    onTap: _pickDob,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _adminPassword,
                    decoration: const InputDecoration(labelText: 'Temporary password (optional)'),
                    obscureText: true,
                  ),
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;

                  if (_department.value == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select department')));
                    return;
                  }
                  if (_dobController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please pick DOB (required for login id generation)')));
                    return;
                  }

                  setState(() => _loadingAction = true);

                  try {
                    final loginId = await _generateDoctorIdFromDob(_dobController.text.trim());

                    final payload = {
                      'name': _name.text.trim(),
                      'specialty': _department.value!.trim(),
                      'experience': _experience.text.trim(),
                      'phone': _phone.text.trim(),
                      'email': _email.text.trim(),
                      'dob': _dobController.text.trim(),
                      'status': 'active',
                      'loginId': loginId,
                      'patientsCount': 0,
                      'createdAt': FieldValue.serverTimestamp(),
                    };

                    if (_adminPassword.text.trim().isNotEmpty) {
                      payload['tempPassword'] = _adminPassword.text.trim();
                    }

                    final ref = await _doctorColl.add(payload);

                    if (!mounted) return;
                    Navigator.of(c).pop();

                    await showDialog(
                      context: context,
                      builder: (d) => AlertDialog(
                        title: const Text('Doctor Registered'),
                        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Doctor has been created successfully.'),
                          const SizedBox(height: 8),
                          SelectableText('Login ID: $loginId', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text('Document: ${ref.id}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                          const SizedBox(height: 8),
                          const Text('Note: create Auth user separately if you want this doctor to have a FirebaseAuth account.'),
                        ]),
                        actions: [TextButton(onPressed: () => Navigator.of(d).pop(), child: const Text('OK'))],
                      ),
                    );

                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Doctor created — Login ID: $loginId')));
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create doctor: $e')));
                  } finally {
                    if (mounted) setState(() => _loadingAction = false);
                  }
                },
                child: const Text('Create Doctor'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD6A657)),
              )
            ],
          );
        });
      },
    );
  }

  Future<void> _showEditDoctorDialog(DocumentReference ref) async {
    final docSnap = await ref.get();
    if (!docSnap.exists) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document no longer exists')));
      return;
    }

    final data = (docSnap.data() as Map<String, dynamic>? ?? {});
    final _formKey = GlobalKey<FormState>();
    final _name = TextEditingController(text: (data['name'] ?? '').toString());
    final _experience = TextEditingController(text: (data['experience'] ?? '').toString());
    final _phone = TextEditingController(text: (data['phone'] ?? '').toString());
    final _email = TextEditingController(text: (data['email'] ?? '').toString());
    final _dobController = TextEditingController(text: (data['dob'] ?? '').toString());
    final _loginId = TextEditingController(text: (data['loginId'] ?? '').toString());
    final _dept = ValueNotifier<String?>((data['specialty'] ?? '').toString().isEmpty ? null : (data['specialty'] ?? '').toString());
    String status = (data['status'] ?? 'active').toString();

    Future<void> _pickDob() async {
      final now = DateTime.now();
      DateTime initialDate = now.subtract(const Duration(days: 365 * 30));
      try {
        if (_dobController.text.isNotEmpty) {
          final parts = _dobController.text.split('-');
          if (parts.length == 3) {
            initialDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          }
        }
      } catch (_) {}
      final picked = await showDatePicker(context: context, initialDate: initialDate, firstDate: DateTime(1900), lastDate: DateTime.now());
      if (picked != null) {
        _dobController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      }
    }

    await showDialog(
      context: context,
      builder: (c) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Edit Doctor'),
            content: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Doctor name'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter name' : null),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _dept.value,
                    items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    decoration: const InputDecoration(labelText: 'Department'),
                    onChanged: (v) => _dept.value = v,
                    validator: (v) => (v == null || v.isEmpty) ? 'Select department' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(controller: _experience, decoration: const InputDecoration(labelText: 'Experience (years)'), keyboardType: TextInputType.number),
                  const SizedBox(height: 8),
                  TextFormField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.phone),
                  const SizedBox(height: 8),
                  TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'Email ID'), keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 8),
                  TextFormField(controller: _dobController, readOnly: true, decoration: InputDecoration(labelText: 'Date of birth', suffixIcon: IconButton(icon: const Icon(Icons.calendar_today), onPressed: _pickDob)), onTap: _pickDob),
                  const SizedBox(height: 8),
                  TextFormField(controller: _loginId, decoration: const InputDecoration(labelText: 'Login ID')),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: status,
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('active')),
                      DropdownMenuItem(value: 'inactive', child: Text('inactive')),
                      DropdownMenuItem(value: 'pending', child: Text('pending')),
                    ],
                    onChanged: (v) => setStateDialog(() => status = v ?? 'active'),
                    decoration: const InputDecoration(labelText: 'Status'),
                  ),
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;

                  setState(() => _loadingAction = true);

                  try {
                    final updatePayload = <String, dynamic>{
                      'name': _name.text.trim(),
                      'specialty': _dept.value ?? '',
                      'experience': _experience.text.trim(),
                      'phone': _phone.text.trim(),
                      'email': _email.text.trim(),
                      'dob': _dobController.text.trim(),
                      'loginId': _loginId.text.trim(),
                      'status': status,
                      'updatedAt': FieldValue.serverTimestamp(),
                    };

                    await ref.update(updatePayload);

                    if (!mounted) return;
                    Navigator.of(c).pop();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Doctor updated')));
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
                  } finally {
                    if (mounted) setState(() => _loadingAction = false);
                  }
                },
                child: const Text('Save'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F5F55)),
              ),
            ],
          );
        });
      },
    );
  }

  Widget _sidebarItem(String title, IconData icon, {bool active = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active ? Colors.white.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: active ? const Border(left: BorderSide(color: Color(0xFFD6A657), width: 4)) : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 18),
            const SizedBox(width: 10),
            Text(title, style: TextStyle(color: Colors.white.withOpacity(active ? 1 : 0.9), fontWeight: active ? FontWeight.w700 : FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// DoctorProfilePage
/// Full-screen, rich layout similar to the design screenshots.
/// Accepts a DocumentReference to the doctor doc.
class DoctorProfilePage extends StatelessWidget {
  final DocumentReference docRef;
  const DoctorProfilePage({super.key, required this.docRef});

  String _fmt(dynamic v) {
    if (v == null) return '-';
    return v.toString();
  }

  Widget _kpiCell(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _infoCard({required String title, required List<Widget> children}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1F5F55))), const Spacer()]),
          const SizedBox(height: 12),
          ...children,
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryTeal = Color(0xFF1F5F55);
    const Color accentGold = Color(0xFFD6A657);
    const bg = Color(0xFFFAF7F4);

    return FutureBuilder<DocumentSnapshot>(
      future: docRef.get(),
      builder: (context, snap) {
        if (snap.hasError) return Scaffold(body: Center(child: Text('Error: ${snap.error}')));
        if (!snap.hasData || snap.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));

        final data = (snap.data!.data() as Map<String, dynamic>? ?? {});
        final name = _fmt(data['name']).isNotEmpty ? _fmt(data['name']) : 'Unnamed';
        final specialty = _fmt(data['specialty']);
        final experience = _fmt(data['experience']);
        final phone = _fmt(data['phone']);
        final email = _fmt(data['email']);
        final loginId = _fmt(data['loginId']);
        final dob = _fmt(data['dob']);
        final patients = _fmt(data['patientsCount'] ?? data['patients'] ?? 0);
        final rating = _fmt(data['rating'] ?? '—');
        final address = _fmt(data['address'] ?? '');
        final qualifications = _fmt(data['qualifications'] ?? '');
        final license = _fmt(data['medicalLicense'] ?? '');

        return Scaffold(
          backgroundColor: bg,
          body: SafeArea(
            child: Row(
              children: [
                // left sidebar placeholder (keeps layout consistent)
                Container(width: 260, color: const Color(0xFF1F5F55)),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Page header
                        Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(border: Border(left: BorderSide(color: primaryTeal, width: 4))),
                              padding: const EdgeInsets.only(left: 14),
                              child: Text('Doctors', style: TextStyle(color: primaryTeal, fontSize: 22, fontWeight: FontWeight.w800)),
                            ),
                            const Spacer(),
                            SizedBox(
                              width: 250,
                              child: TextField(
                                decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Search...', filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none)),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.add),
                              label: const Text('+ New Appointment'),
                              style: ElevatedButton.styleFrom(backgroundColor: accentGold, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Header card with avatar, name, tags and KPI row
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                          child: Padding(
                            padding: const EdgeInsets.all(18.0),
                            child: Column(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // avatar
                                    Container(
                                      width: 110,
                                      height: 110,
                                      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(16)),
                                      child: Center(child: Text(name.isNotEmpty ? name.trim().split(' ').map((e) => e[0]).take(2).join() : '?', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: primaryTeal))),
                                    ),
                                    const SizedBox(width: 18),
                                    Expanded(
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Row(
                                          children: [
                                            Expanded(child: Text(name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: primaryTeal))),
                                            const SizedBox(width: 12),
                                            ElevatedButton.icon(
                                              onPressed: () {},
                                              icon: const Icon(Icons.edit, size: 18),
                                              label: const Text('Edit Profile'),
                                              style: ElevatedButton.styleFrom(backgroundColor: primaryTeal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(spacing: 8, children: [
                                          if (specialty != '-') Chip(backgroundColor: Colors.grey.shade100, label: Text(specialty)),
                                          Chip(backgroundColor: Colors.grey.shade100, label: Text('ID: $loginId')),
                                        ]),
                                      ]),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                // KPI row
                                Row(children: [
                                  _kpiCell('Experience', experience.isEmpty || experience == '-' ? '—' : '$experience Years'),
                                  const SizedBox(width: 16),
                                  _kpiCell('Patients Treated', patients),
                                  const SizedBox(width: 16),
                                  _kpiCell('Avg Rating', rating),
                                ]),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Two-column: left personal & credentials, right professional & account access + analytics
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          // left column
                          Expanded(
                            flex: 2,
                            child: Column(
                              children: [
                                _infoCard(
                                  title: 'Personal Info',
                                  children: [
                                    _rowPair('Gender', _fmt(data['gender'] ?? '-')),
                                    const Divider(),
                                    _rowPair('DOB', dob),
                                    const Divider(),
                                    _rowPair('Contact', phone),
                                    const Divider(),
                                    _rowPair('Email', email),
                                    const SizedBox(height: 8),
                                    if (address.isNotEmpty && address != '-') _rowPair('Address', address),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _infoCard(title: 'Credentials', children: [
                                  _rowPair('Qualification', qualifications),
                                  const SizedBox(height: 12),
                                  Row(children: [
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(color: Colors.yellow.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.yellow.shade100)),
                                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          Text('MEDICAL LICENSE', style: TextStyle(color: Colors.brown.shade700, fontWeight: FontWeight.w800)),
                                          const SizedBox(height: 8),
                                          Text(license, style: const TextStyle(fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 6),
                                          Text(_fmt(data['licenseAuthority'] ?? '')),
                                        ]),
                                      ),
                                    ),
                                  ]),
                                ]),
                                const SizedBox(height: 12),
                              ],
                            ),
                          ),

                          const SizedBox(width: 18),

                          // right column
                          Expanded(
                            flex: 3,
                            child: Column(
                              children: [
                                _infoCard(title: 'Professional Details', children: [
                                  _rowPair('Doctor ID', loginId),
                                  const Divider(),
                                  _rowPair('Date of Joining', _fmt(data['joinedAt'] ?? data['createdAt'] ?? '-')),
                                  const Divider(),
                                  _rowPair('Shift Timing', _fmt(data['shift'] ?? '-')),
                                  const Divider(),
                                  _rowPair('System Role', _fmt(data['role'] ?? 'Doctor')),
                                ]),
                                const SizedBox(height: 12),
                                _infoCard(title: 'Account Access', children: [
                                  _rowPair('Username', _fmt(data['username'] ?? loginId)),
                                  const Divider(),
                                  _rowPair('Password', '••••••••'),
                                ]),
                                const SizedBox(height: 12),
                                // Analytics card (small line chart)
                                Card(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Row(children: [Text('Patient Analytics', style: TextStyle(fontWeight: FontWeight.w800, color: primaryTeal)), const Spacer(), ToggleButtons(isSelected: const [true, false, false], children: const [Text('Day'), Text('Month'), Text('Year')], onPressed: (_) {})]),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        height: 140,
                                        child: LineChart(
                                          LineChartData(
                                            gridData: FlGridData(show: true, getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.shade200, strokeWidth: 1)),
                                            titlesData: FlTitlesData(show: false),
                                            borderData: FlBorderData(show: false),
                                            lineBarsData: [
                                              LineChartBarData(
                                                spots: const [
                                                  FlSpot(0, 22),
                                                  FlSpot(1, 26),
                                                  FlSpot(2, 28),
                                                  FlSpot(3, 27),
                                                  FlSpot(4, 31),
                                                ],
                                                isCurved: true,
                                                color: primaryTeal,
                                                barWidth: 3,
                                                belowBarData: BarAreaData(show: true, color: primaryTeal.withOpacity(0.06)),
                                                dotData: FlDotData(show: false),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(spacing: 8, children: const [
                                        Chip(label: Text('Hypertension')),
                                        Chip(label: Text('High Cholesterol')),
                                        Chip(label: Text('Ischemic Heart Disease')),
                                      ])
                                    ]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ]),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _rowPair(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w700))),
        const SizedBox(width: 14),
        Expanded(flex: 2, child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

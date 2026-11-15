// lib/screens/adminstaffs_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'adminstaff_detail_screen.dart';

class StaffsPage extends StatefulWidget {
  const StaffsPage({super.key});

  @override
  State<StaffsPage> createState() => _StaffsPageState();
}

class _StaffsPageState extends State<StaffsPage> {
  // Visual palette (keeps same look as the details screen)
// AyuTech unified palette (MATCHES LOGIN & DASHBOARD)
static const Color _ayuGreen = Color(0xFF2F5C56);
static const Color _ayuGold  = Color(0xFFD6A657);
static const Color _pageBg   = Color(0xFFFAFAF8);
static const Color _cardBg   = Colors.white;


  final TextEditingController _searchCtl = TextEditingController();
  final CollectionReference _staffColl = FirebaseFirestore.instance.collection('staff');

  String _search = '';
  bool _loadingAction = false;
  int _selectedNavIndex = 1;

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

  Future<void> _deleteStaff(DocumentReference ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete staff'),
        content: const Text('Are you sure you want to delete this staff record? This cannot be undone.'),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Staff deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    } finally {
      if (mounted) setState(() => _loadingAction = false);
    }
  }

  /// Generate loginId using staff + DOB (DDMMYYYY).
  /// If collision occurs append _1, _2... (keeps earlier behavior).
  Future<String> _generateStaffIdFromDob(String dobIso) async {
    String normalizeDob(String iso) {
      try {
        final parts = iso.split('-');
        if (parts.length == 3) {
          final y = parts[0];
          final m = parts[1].padLeft(2, '0');
          final d = parts[2].padLeft(2, '0');
          return '$d$m$y'; // DDMMYYYY
        }
      } catch (_) {}
      return DateTime.now().millisecondsSinceEpoch.toString();
    }

    final base = 'staff' + normalizeDob(dobIso); // e.g. staff15091990
    final coll = FirebaseFirestore.instance.collection('staff');

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
            icon: const Icon(Icons.arrow_back_outlined),
            onPressed: () => Navigator.maybePop(context),
          ),
          const SizedBox(width: 6),
          const Text('User Management', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const Spacer(),
          ElevatedButton(
            onPressed: _loadingAction ? null : _showRegisterStaffDialog,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD6A657)),
            child: const Text('Register New Staff'),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _loadingAction ? null : () async {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Auto-generate not implemented')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F5F55)),
            child: const Text('Auto-generate'),
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
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchCtl,
                decoration: const InputDecoration.collapsed(hintText: 'Search by name, email, role or ID'),
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

  // Table header row: only the requested columns
  Widget _tableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: const [
          Expanded(flex: 2, child: Text('NAME', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          Expanded(flex: 2, child: Text('ROLE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          Expanded(flex: 3, child: Text('EMAIL', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          Expanded(flex: 2, child: Text('LOGIN ID', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          Expanded(flex: 1, child: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          SizedBox(width: 90, child: Align(alignment: Alignment.centerRight, child: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)))),
        ],
      ),
    );
  }

  /// Row renderer: only shows name, role, email, loginId, status, and actions.
  Widget _staffRow(Map<String, dynamic> data, DocumentReference ref) {
    final name = (data['name'] ?? '').toString();
    final role = (data['assignedRole'] ?? data['role'] ?? 'Staff').toString();
    final email = (data['email'] ?? '').toString();
    final status = (data['status'] ?? 'active').toString();
    final loginId = (data['loginId'] ?? '').toString();

    final initials = name.isNotEmpty ? name.trim().split(RegExp(r'\s+')).map((s) => s[0]).take(2).join().toUpperCase() : '?';

    return InkWell(
      onTap: () {
        // open detail screen (shows all other info)
        Navigator.push(context, MaterialPageRoute(builder: (_) => StaffDetailScreen(docRef: ref)));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Row(
          children: [
            // name + avatar
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.green.shade50,
                    child: Text(initials, style: const TextStyle(color: Color(0xFF1F5F55), fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      name.isNotEmpty ? name : 'Unnamed',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // role
            Expanded(
              flex: 2,
              child: Text(
                role.isNotEmpty ? role : '-',
                style: const TextStyle(color: Colors.black87),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // email
            Expanded(
              flex: 3,
              child: Text(
                email.isNotEmpty ? email : '-',
                style: const TextStyle(color: Colors.black54),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // login id
            Expanded(
              flex: 2,
              child: Text(
                loginId.isNotEmpty ? loginId : '-',
                style: const TextStyle(color: Colors.black54),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // status
            Expanded(
              flex: 1,
              child: Row(
                children: [
                  Icon(status == 'active' ? Icons.visibility : Icons.visibility_off, color: status == 'active' ? Colors.green : Colors.orange, size: 18),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      status,
                      style: TextStyle(color: status == 'active' ? Colors.green : Colors.orange),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // actions (edit + menu)
            SizedBox(
              width: 90,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: () {
                      _showEditStaffDialog(ref);
                    },
                    tooltip: 'Edit',
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'toggle') _toggleStatus(ref, status);
                      else if (v == 'delete') _deleteStaff(ref);
                      else if (v == 'copy') {
                        Clipboard.setData(ClipboardData(text: ref.id));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document id copied')));
                      }
                    },
                    itemBuilder: (c) => [
                      PopupMenuItem(value: 'toggle', child: Text(status == 'active' ? 'Set inactive' : 'Set active')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                      const PopupMenuItem(value: 'copy', child: Text('Copy ID')),
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

  @override
  Widget build(BuildContext context) {
    final Stream<QuerySnapshot> stream = _staffColl.orderBy('createdAt', descending: true).snapshots();
    final bool wide = MediaQuery.of(context).size.width >= 1000;

    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        child: Row(
          children: [
            if (wide) _buildSideNav(context, wide),
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

                    // Stream list
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: stream,
                        builder: (context, snap) {
                          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
                          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                          final docs = snap.data?.docs ?? [];
                          // Apply client-side search filter
                          final filtered = docs.where((d) {
                            final data = (d.data() as Map<String, dynamic>? ?? {});
                            final name = (data['name'] ?? '').toString().toLowerCase();
                            final email = (data['email'] ?? '').toString().toLowerCase();
                            final role = (data['assignedRole'] ?? data['role'] ?? '').toString().toLowerCase();
                            final loginId = (data['loginId'] ?? '').toString().toLowerCase();
                            final id = d.id.toLowerCase();
                            if (_search.isEmpty) return true;
                            return name.contains(_search) || email.contains(_search) || role.contains(_search) || id.contains(_search) || loginId.contains(_search);
                          }).toList();

                          if (filtered.isEmpty) {
                            return const Center(child: Text('No staff records found.'));
                          }

                          return Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                            child: ListView.separated(
                              // add extra right padding so actions/popup doesn't overlap page edge
                              padding: const EdgeInsets.fromLTRB(12, 8, 48, 8),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => Divider(color: Colors.grey.shade100, height: 1),
                              itemBuilder: (context, i) {
                                final doc = filtered[i];
                                final data = (doc.data() as Map<String, dynamic>? ?? {});
                                return _staffRow(data, doc.reference);
                              },
                            ),
                          );
                        },
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
      // drawer for narrow screens
      drawer: MediaQuery.of(context).size.width < 1000 ? Drawer(child: _buildSideNavInner(context)) : null,
    );
  }

  // -------------------------
  // Register staff dialog (unchanged fields stored in Firestore)
  // (This still collects altContact, address, department, shift, qualifications, languages, etc.)
  // For brevity: full form code included (unchanged from previous version)
  // -------------------------
  Future<void> _showRegisterStaffDialog() async {
    final _formKey = GlobalKey<FormState>();
    final _name = TextEditingController();
    final _phone = TextEditingController();
    final _altContact = TextEditingController();
    final _email = TextEditingController();
    final _address = TextEditingController();
   
    final _assignedDoctor = TextEditingController();
    final _dobController = TextEditingController();
    final _adminPassword = TextEditingController(); // optional if you plan to create auth user
    String _shift = 'general'; // default
    // qualifications options based on Ayurveda
    final List<String> _qualOptions = ['BAMS', 'Panchakarma', 'Kayachikitsa', 'Shalyatantra', 'Shalakya', 'Rasashastra'];
    final Map<String, bool> _qualSelected = {for (var q in _qualOptions) q: false};
    final _languages = TextEditingController();

    Future<void> _pickDob() async {
      final now = DateTime.now();
      final initial = DateTime(now.year - 25, now.month, now.day);
      final picked = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(1900), lastDate: now);
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
            title: const Text('Register New Staff'),
            content: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Full name'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter name' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _phone,
                      decoration: const InputDecoration(labelText: 'Phone'),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _altContact,
                      decoration: const InputDecoration(labelText: 'Alt Contact (optional)'),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _email,
                      decoration: const InputDecoration(labelText: 'Contact Email (optional)'),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _address,
                      decoration: const InputDecoration(labelText: 'Address (optional)'),
                      minLines: 1,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 8),
                    
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _assignedDoctor,
                      decoration: const InputDecoration(labelText: 'Assigned Doctor (optional)'),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _dobController,
                      readOnly: true,
                      decoration: InputDecoration(labelText: 'DOB', suffixIcon: IconButton(icon: const Icon(Icons.calendar_today), onPressed: _pickDob)),
                      onTap: _pickDob,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _shift,
                      items: const [
                        DropdownMenuItem(value: 'general', child: Text('General (9:00am - 6:00pm)')),
                        DropdownMenuItem(value: 'night', child: Text('Night Doctor (8:00pm - 12:00am)')),
                      ],
                      onChanged: (v) => setStateDialog(() => _shift = v ?? 'general'),
                      decoration: const InputDecoration(labelText: 'Shift Timing'),
                    ),
                    const SizedBox(height: 8),
                    // qualifications as checkboxes
                    Align(alignment: Alignment.centerLeft, child: const Padding(padding: EdgeInsets.only(bottom: 6.0), child: Text('Qualifications (Ayurveda)'))),
                    Wrap(
                      spacing: 6,
                      children: _qualOptions.map((q) {
                        return FilterChip(
                          label: Text(q),
                          selected: _qualSelected[q] == true,
                          onSelected: (sel) => setStateDialog(() => _qualSelected[q] = sel),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _languages,
                      decoration: const InputDecoration(labelText: 'Languages (comma separated, e.g. English, Tamil)'),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _adminPassword,
                      decoration: const InputDecoration(labelText: 'Temporary password (optional)'),
                      obscureText: true,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;

                  // Ensure DOB is provided (we require DOB for loginId generation per your spec)
                  if (_dobController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please pick DOB (required for login id generation)')));
                    return;
                  }

                  setState(() => _loadingAction = true);

                  try {
                    // generate unique login id from DOB
                    final loginId = await _generateStaffIdFromDob(_dobController.text.trim());

                    // collect qualifications selected
                    final quals = _qualSelected.entries.where((e) => e.value).map((e) => e.key).toList();
                    final langs = _languages.text.trim().isEmpty
                        ? <String>[]
                        : _languages.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

                    // payload saved to Firestore
                    final payload = {
                      'name': _name.text.trim(),
                      'phone': _phone.text.trim(),
                      'altContact': _altContact.text.trim(),
                      'email': _email.text.trim(),
                      'address': _address.text.trim(),
                      
                      'assignedDoctor': _assignedDoctor.text.trim(),
                      'assignedRole': 'Staff',
                      'role': 'staff',
                      'dob': _dobController.text.trim(),
                      'shift': _shift,
                      'qualifications': quals,
                      'languages': langs,
                      'status': 'active',
                      'loginId': loginId,
                      'createdAt': FieldValue.serverTimestamp(),
                    };

                    // if temp password provided we store as tempPassword (note: NOT secure for production)
                    if (_adminPassword.text.trim().isNotEmpty) {
                      payload['tempPassword'] = _adminPassword.text.trim();
                    }

                    final ref = await _staffColl.add(payload);

                    if (!mounted) return;

                    // close the register dialog
                    Navigator.of(c).pop();

                    // show dialog with generated login id so admin can note it
                    await showDialog(
                      context: context,
                      builder: (d) => AlertDialog(
                        title: const Text('Staff Registered'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Staff has been created successfully.'),
                            const SizedBox(height: 8),
                            SelectableText('Login ID: $loginId', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text('Document: ${ref.id}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                            const SizedBox(height: 8),
                            const Text('Note: create Auth user separately if you want this staff to have a FirebaseAuth account.'),
                          ],
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(d).pop(), child: const Text('OK')),
                        ],
                      ),
                    );

                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Staff created — Login ID: $loginId')));
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create staff: $e')));
                  } finally {
                    if (mounted) setState(() => _loadingAction = false);
                  }
                },
                child: const Text('Register'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD6A657)),
              )
            ],
          );
        });
      },
    );
  }

  // -------------------------
  // Edit staff dialog — only edits backend doc fields; all extra fields remain in the detail screen
  // -------------------------
  Future<void> _showEditStaffDialog(DocumentReference ref) async {
    final docSnap = await ref.get();
    if (!docSnap.exists) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document no longer exists')));
      return;
    }

    final data = (docSnap.data() as Map<String, dynamic>? ?? {});
    final _formKey = GlobalKey<FormState>();
    final _name = TextEditingController(text: (data['name'] ?? '').toString());
    final _phone = TextEditingController(text: (data['phone'] ?? '').toString());
    final _altContact = TextEditingController(text: (data['altContact'] ?? '').toString());
    final _email = TextEditingController(text: (data['email'] ?? '').toString());
    final _address = TextEditingController(text: (data['address'] ?? '').toString());
  
    final _assignedDoctor = TextEditingController(text: (data['assignedDoctor'] ?? '').toString());
    final _dobController = TextEditingController(text: (data['dob'] ?? '').toString());
    final _loginId = TextEditingController(text: (data['loginId'] ?? '').toString());
    String _status = (data['status'] ?? 'active').toString();
    String _shift = (data['shift'] ?? 'general').toString();

    final List<String> _qualOptions = ['BAMS', 'Panchakarma', 'Kayachikitsa', 'Shalyatantra', 'Shalakya', 'Rasashastra'];
    final Map<String, bool> _qualSelected = {
      for (var q in _qualOptions) q: ((data['qualifications'] as List<dynamic>?)?.map((e) => e.toString()).contains(q) ?? false)
    };

    final _languages = TextEditingController(text: (data['languages'] as List<dynamic>?)?.join(', ') ?? '');

    Future<void> _pickDob() async {
      final now = DateTime.now();
      DateTime initialDate = now.subtract(const Duration(days: 365 * 25));
      try {
        if (_dobController.text.isNotEmpty) {
          final parts = _dobController.text.split('-');
          if (parts.length == 3) {
            initialDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          }
        }
      } catch (_) {}
      final picked = await showDatePicker(context: context, initialDate: initialDate, firstDate: DateTime(1900), lastDate: now);
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
            title: const Text('Edit Staff'),
            content: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Full name'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter name' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _phone,
                    decoration: const InputDecoration(labelText: 'Phone'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _altContact,
                    decoration: const InputDecoration(labelText: 'Alt Contact (optional)'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'Contact Email (optional)'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _address,
                    decoration: const InputDecoration(labelText: 'Address (optional)'),
                    minLines: 1,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    
                    
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _assignedDoctor,
                    decoration: const InputDecoration(labelText: 'Assigned Doctor (optional)'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _dobController,
                    readOnly: true,
                    decoration: InputDecoration(labelText: 'DOB', suffixIcon: IconButton(icon: const Icon(Icons.calendar_today), onPressed: () async => await _pickDob())),
                    onTap: _pickDob,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _loginId,
                    decoration: const InputDecoration(labelText: 'Login ID'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _status,
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('active')),
                      DropdownMenuItem(value: 'inactive', child: Text('inactive')),
                      DropdownMenuItem(value: 'pending', child: Text('pending')),
                    ],
                    onChanged: (v) => setStateDialog(() => _status = v ?? 'active'),
                    decoration: const InputDecoration(labelText: 'Status'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _shift,
                    items: const [
                      DropdownMenuItem(value: 'general', child: Text('General (9:00am - 6:00pm)')),
                      DropdownMenuItem(value: 'night', child: Text('Night Doctor (8:00pm - 12:00am)')),
                    ],
                    onChanged: (v) => setStateDialog(() => _shift = v ?? 'general'),
                    decoration: const InputDecoration(labelText: 'Shift Timing'),
                  ),
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerLeft, child: const Padding(padding: EdgeInsets.only(bottom: 6.0), child: Text('Qualifications (Ayurveda)'))),
                  Wrap(
                    spacing: 6,
                    children: _qualOptions.map((q) {
                      return FilterChip(
                        label: Text(q),
                        selected: _qualSelected[q] == true,
                        onSelected: (sel) => setStateDialog(() => _qualSelected[q] = sel),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _languages,
                    decoration: const InputDecoration(labelText: 'Languages (comma separated)'),
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
                      'phone': _phone.text.trim(),
                      'altContact': _altContact.text.trim(),
                      'email': _email.text.trim(),
                      'address': _address.text.trim(),
                      
                      'assignedDoctor': _assignedDoctor.text.trim(),
                      'dob': _dobController.text.trim(),
                      'loginId': _loginId.text.trim(),
                      'status': _status,
                      'shift': _shift,
                      'qualifications': _qualSelected.entries.where((e) => e.value).map((e) => e.key).toList(),
                      'languages': _languages.text.trim().isEmpty ? <String>[] : _languages.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
                      'updatedAt': FieldValue.serverTimestamp(),
                    };

                    // update doc
                    await ref.update(updatePayload);

                    if (!mounted) return;
                    Navigator.of(c).pop();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Staff updated')));
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

  // -------------------------
  // Side navigation (kept consistent with detail screen)
  // -------------------------
  Widget _buildSideNav(BuildContext context, bool wide) {
    return Container(width: 260, color: _ayuGreen,
child: _buildSideNavInner(context));
  }

  Widget _buildSideNavInner(BuildContext context) {
    Widget navItem(IconData icon, String label, int index) {
      final selected = _selectedNavIndex == index;
      return InkWell(
        onTap: () {
          setState(() => _selectedNavIndex = index);
          // TODO: perform actual navigation when needed
        },
        child: Container(
          color: selected ? _ayuGreen.withOpacity(0.85) : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
          child: Row(
            children: [
              CircleAvatar(backgroundColor: Colors.white24, child: Icon(icon, color: Colors.white, size: 18)),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
              if (selected) const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // logo + title
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                  child: const Icon(Icons.local_florist, color: _ayuGreen),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                    Text('AyuTech', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text('MEDICAL ADMIN', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('MAIN', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12)),
          ),
          const SizedBox(height: 8),
          navItem(Icons.grid_view, 'Dashboard', 0),
          navItem(Icons.group, 'Staffs', 1),
          navItem(Icons.local_hospital, 'Doctors', 2),
          navItem(Icons.receipt_long, 'Billing & Patients', 3),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('REPORTS', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12)),
          ),
          const SizedBox(height: 8),
          navItem(Icons.bar_chart, 'Reports & Insights', 4),
          const Spacer(),
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                Container(width: 42, height: 42, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                  Text('Dr. James Smith', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text('Chief Resident', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

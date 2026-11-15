// lib/screens/staff_detail_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class StaffDetailScreen extends StatefulWidget {
  final DocumentReference docRef;
  const StaffDetailScreen({super.key, required this.docRef});

  @override
  State<StaffDetailScreen> createState() => _StaffDetailScreenState();
}

class _StaffDetailScreenState extends State<StaffDetailScreen> {
  // Palette (match your screenshots)
  static const Color _brandDark = Color(0xFF1B4332);
  static const Color _brandGreen = Color(0xFF1F5F55);
  static const Color _pageBg = Color(0xFFF1EFE0);
  static const Color _sideGreen = Color(0xFF174B40);
  static const double _cardRadius = 14.0;

  int _selectedNavIndex = 1; // Staffs selected by default

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: widget.docRef.get(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (!snap.hasData || !snap.data!.exists) {
          return Scaffold(
            backgroundColor: _pageBg,
            // no appBar here either
            body: Center(
              child: Text('Staff record not found', style: TextStyle(color: _brandDark)),
            ),
          );
        }

        final Map<String, dynamic> data = (snap.data!.data() as Map<String, dynamic>?) ?? {};

        final name = (data['name'] ?? 'Unnamed') as String;
        final role = (data['assignedRole'] ?? data['role'] ?? 'Staff') as String;
        final assignedDoctor = (data['assignedDoctor'] ?? '') as String;
        final email = (data['email'] ?? '') as String;
        final phone = (data['phone'] ?? '') as String;
        final address = (data['address'] ?? '') as String;
        final dob = (data['dob'] ?? '') as String;
        final createdAt = data['createdAt'];
        final employeeId = (data['employeeId'] ?? '') as String;
        final dateOfJoining = (data['dateOfJoining'] ?? '') as String;
        
        final shift = (data['shift'] ?? '') as String;
        final workLocation = (data['workLocation'] ?? '') as String;
        final experienceYears = (data['experienceYears'] ?? '') as dynamic;
        final rating = (data['rating'] ?? '') as dynamic;
        final emergency = (data['emergencyContact'] ?? '') as String;
        final qualifications = (data['qualifications'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? <String>[];
        final languages = (data['languages'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? <String>[];

        String createdAtStr(dynamic ts) {
          try {
            if (ts is Timestamp) {
              final d = ts.toDate();
              return '${d.day}/${d.month}/${d.year}';
            } else if (ts is String && ts.isNotEmpty) return ts;
          } catch (_) {}
          return '';
        }

        final bool wide = MediaQuery.of(context).size.width >= 1000;

        return Scaffold(
          backgroundColor: _pageBg,
          // IMPORTANT: no appBar property here — top UI is built inside body
          body: Column(
            children: [
              // Thin dark stripe at top (customizable height/color)
              Container(height: 6, color: Colors.black87),

              // Main area: side nav + content
              Expanded(
                child: Row(
                  children: [
                    // Side navigation for wide screens
                    if (wide) _buildSideNav(context, wide),

                    // Main content
                    Expanded(
                      child: SafeArea(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              // Header area: large pale header with title + controls
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 1200),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // Left: page title + (optional) back control row
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'User Management',
                                              style: const TextStyle(
                                                fontSize: 28,
                                                fontWeight: FontWeight.w700,
                                                color: _brandDark,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                IconButton(
                                                  onPressed: () => Navigator.maybePop(context),
                                                  icon: const Icon(Icons.arrow_back),
                                                  color: _brandDark,
                                                ),
                                                const SizedBox(width: 6),
                                                const Text('Back', style: TextStyle(fontSize: 14, color: Colors.black54)),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Right: search, notifications, new appointment
                                      Row(
                                        children: [
                                          SizedBox(
                                            width: 300,
                                            child: TextField(
                                              decoration: InputDecoration(
                                                hintText: 'Search...',
                                                prefixIcon: const Icon(Icons.search),
                                                filled: true,
                                                fillColor: Colors.white,
                                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  borderSide: BorderSide.none,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Container(
                                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                                            child: IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none)),
                                          ),
                                          const SizedBox(width: 12),
                                          ElevatedButton.icon(
                                            onPressed: () {},
                                            icon: const Icon(Icons.add, size: 18),
                                            label: const Text('New Appointment'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFFD6A657),
                                              elevation: 0,
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              foregroundColor: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Centered content area
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 1200),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        // Profile card (with rounded corners and elevated white background)
                                        Card(
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardRadius)),
                                          elevation: 2,
                                          color: Colors.white,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 18.0),
                                            child: Row(
                                              children: [
                                                // avatar
                                                Container(
                                                  width: 110,
                                                  height: 110,
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(12),
                                                    color: Colors.green.shade50,
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                                                      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: _brandGreen),
                                                    ),
                                                  ),
                                                ),

                                                const SizedBox(width: 20),

                                                // Name, tags, metrics
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              name,
                                                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: _brandDark),
                                                            ),
                                                          ),
                                                          const SizedBox(width: 8),
                                                          Row(
                                                            children: [
                                                              IconButton(onPressed: () {}, icon: const Icon(Icons.chat_bubble_outline_outlined), color: _brandDark),
                                                              IconButton(onPressed: () {}, icon: const Icon(Icons.share_outlined), color: _brandDark),
                                                              const SizedBox(width: 6),
                                                              ElevatedButton.icon(
                                                                onPressed: () {},
                                                                icon: const Icon(Icons.edit, size: 18),
                                                                label: const Text('Edit Profile'),
                                                                style: ElevatedButton.styleFrom(
                                                                  backgroundColor: _brandGreen,
                                                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 10),
                                                      Wrap(
                                                        spacing: 8,
                                                        runSpacing: 6,
                                                        children: [
                                                          _smallTag(Icons.person_outline, role),
                                                          if (assignedDoctor.isNotEmpty) _smallTag(Icons.local_hospital, assignedDoctor),
                                                          if (workLocation.isNotEmpty) _smallTag(Icons.location_on_outlined, workLocation),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 18),
                                                      Row(
                                                        children: [
                                                          _metricItem('EXPERIENCE', experienceYears?.toString() ?? '-', large: true),
                                                          _verticalDivider(),
                                                          _metricItem('JOINED', dateOfJoining.isNotEmpty ? dateOfJoining : createdAtStr(createdAt), large: true),
                                                          _verticalDivider(),
                                                          _metricItem('RATING', rating != '' ? rating.toString() : '-', large: true, trailingIcon: Icons.star),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),

                                        const SizedBox(height: 18),

                                        // Two-column section: left = Contact & Personal, right = Work Info + others
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Left column
                                            Expanded(
                                              flex: 1,
                                              child: Column(
                                                children: [
                                                  _infoCard(
                                                    title: 'Contact Info',
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        _infoLine(Icons.phone_outlined, 'Mobile', phone),
                                                        const SizedBox(height: 12),
                                                        _infoLine(Icons.email_outlined, 'Email', email),
                                                        const SizedBox(height: 12),
                                                        if (address.isNotEmpty) _infoLine(Icons.location_on_outlined, 'Address', address),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  _infoCard(
                                                    title: 'Personal Details',
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        _twoColumn('Date of Birth', dob, 'Status', (data['status'] ?? 'active').toString()),
                                                        const SizedBox(height: 12),
                                                        _twoColumn('UID', (data['uid'] ?? widget.docRef.id).toString(), 'Created', createdAtStr(createdAt)),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  _accentCard(
                                                    title: 'Emergency',
                                                    accentColor: Colors.red.shade200,
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(emergency.isNotEmpty ? emergency : 'No emergency contact',
                                                            style: const TextStyle(fontWeight: FontWeight.w600)),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            const SizedBox(width: 14),

                                            // Right column
                                            Expanded(
                                              flex: 1,
                                              child: Column(
                                                children: [
                                                  _infoCard(
                                                    title: 'Work Information',
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        _twoColumn('Employee ID', employeeId.isNotEmpty ? employeeId : '-', 'Date of Joining',
                                                            dateOfJoining.isNotEmpty ? dateOfJoining : createdAtStr(createdAt)),
                                                        const SizedBox(height: 12),
                                                       
                                                        const SizedBox(height: 12),
                                                        _infoLine(Icons.schedule, 'Shift Timing', shift.isNotEmpty ? shift : '-'),
                                                        const SizedBox(height: 12),
                                                        _infoLine(Icons.place_outlined, 'Work Location', workLocation.isNotEmpty ? workLocation : '-'),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  _infoCard(
                                                    title: 'Qualifications',
                                                    child: Wrap(
                                                      spacing: 8,
                                                      children: qualifications.isNotEmpty ? qualifications.map((q) => _chipLabel(q)).toList() : [const Text('-')],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  _infoCard(
                                                    title: 'Languages',
                                                    child: Wrap(
                                                      spacing: 8,
                                                      children: languages.isNotEmpty ? languages.map((l) => _chipLabel(l)).toList() : [const Text('-')],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 24),
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
                  ],
                ),
              ),
            ],
          ),
          // Drawer for mobile / narrow layout
          drawer: wide ? null : Drawer(child: _buildSideNavInner(context)),
        );
      },
    );
  }

  // --- helpers / widgets ---

  Widget _buildSideNav(BuildContext context, bool wide) {
    return Container(
      width: 260,
      color: _sideGreen,
      child: _buildSideNavInner(context),
    );
  }

  Widget _buildSideNavInner(BuildContext context) {
    Widget navItem(IconData icon, String label, int index) {
      final selected = _selectedNavIndex == index;
      return InkWell(
        onTap: () {
          setState(() => _selectedNavIndex = index);
        },
        child: Container(
          color: selected ? _sideGreen.withOpacity(0.85) : Colors.transparent,
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                  child: const Icon(Icons.local_florist, color: _sideGreen),
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

  Widget _smallTag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.black12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: Colors.black54),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.black87)),
      ]),
    );
  }

  Widget _verticalDivider() {
    return Container(height: 48, margin: const EdgeInsets.symmetric(horizontal: 18), width: 1, color: Colors.grey.shade200);
  }

  Widget _metricItem(String title, String value, {bool large = false, IconData? trailingIcon}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: TextStyle(fontSize: 12, color: Colors.black45)),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(value, style: TextStyle(fontSize: large ? 18 : 14, fontWeight: FontWeight.bold, color: Colors.black87)),
              if (trailingIcon != null) ...[
                const SizedBox(width: 6),
                Icon(trailingIcon, size: 18, color: Colors.amber.shade700),
              ],
            ],
          ),
        ],
      ),
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

  Widget _accentCard({required String title, required Widget child, required Color accentColor}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardRadius)),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(_cardRadius), color: Colors.white),
        child: Row(children: [
          Container(width: 8, height: 120, decoration: BoxDecoration(color: accentColor, borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), bottomLeft: Radius.circular(14)))),
          Expanded(
            child: Padding(padding: const EdgeInsets.all(14.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: _brandDark)),
              const SizedBox(height: 8),
              child,
            ])),
          ),
        ]),
      ),
    );
  }

  Widget _infoLine(IconData icon, String label, String value) {
    return Row(children: [
      Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: Colors.black54, size: 18)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 12, color: Colors.black45)),
        const SizedBox(height: 6),
        Text(value.isNotEmpty ? value : '-', style: const TextStyle(fontSize: 14, color: Colors.black87)),
      ])),
    ]);
  }

  Widget _twoColumn(String aLabel, String aValue, String bLabel, String bValue) {
    return Row(children: [
      Expanded(child: _colLabelValue(aLabel, aValue)),
      const SizedBox(width: 12),
      Expanded(child: _colLabelValue(bLabel, bValue)),
    ]);
  }

  Widget _colLabelValue(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(), style: const TextStyle(fontSize: 12, color: Colors.black45)),
      const SizedBox(height: 6),
      Text(value.isNotEmpty ? value : '-', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
    ]);
  }

  Widget _chipLabel(String text) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(999)), child: Text(text, style: const TextStyle(color: _brandGreen, fontWeight: FontWeight.w600)));
  }
}

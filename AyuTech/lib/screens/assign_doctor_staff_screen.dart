import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AssignDoctorStaffScreen extends StatefulWidget {
  const AssignDoctorStaffScreen({Key? key}) : super(key: key);

  @override
  State<AssignDoctorStaffScreen> createState() =>
      _AssignDoctorStaffScreenState();
}

class _AssignDoctorStaffScreenState extends State<AssignDoctorStaffScreen> {
  String? selectedDoctorId;
  String? selectedStaffId;
  bool _loading = false;

  Future<void> assignStaffToDoctor() async {
    if (selectedDoctorId == null || selectedStaffId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select both doctor and staff')),
      );
      return;
    }

    setState(() => _loading = true);
    final firestore = FirebaseFirestore.instance;

    try {
      // Use a transaction for consistency
      await firestore.runTransaction((tx) async {
        final doctorRef = firestore.collection('doctors').doc(selectedDoctorId);
        final staffRef = firestore.collection('staff').doc(selectedStaffId);

        final doctorSnap = await tx.get(doctorRef);
        final staffSnap = await tx.get(staffRef);

        if (!doctorSnap.exists) throw Exception('Doctor not found');
        if (!staffSnap.exists) throw Exception('Staff not found');

        tx.update(doctorRef, {'assignedStaff': selectedStaffId});
        tx.update(staffRef, {'assignedDoctor': selectedDoctorId});
        tx.set(firestore.collection('assignments').doc(), {
          'doctorId': selectedDoctorId,
          'staffId': selectedStaffId,
          'adminId': FirebaseFirestore.instance.app.options.appId, // optional
          'assignedAt': FieldValue.serverTimestamp(),
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assignment successful')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assign Doctor ↔ Staff')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Doctors dropdown
            StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('doctors').snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }
                final docs = snap.data?.docs ?? [];
                return DropdownButtonFormField<String>(
                  value: selectedDoctorId,
                  decoration: const InputDecoration(labelText: 'Select Doctor'),
                  items: docs.map((d) {
                    final data = d.data() as Map<String, dynamic>;
                    return DropdownMenuItem(
                      value: d.id,
                      child: Text(data['name'] ?? 'Unnamed Doctor'),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => selectedDoctorId = v),
                );
              },
            ),
            const SizedBox(height: 16),
            // Staff dropdown
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('staff').snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }
                final staffDocs = snap.data?.docs ?? [];
                return DropdownButtonFormField<String>(
                  value: selectedStaffId,
                  decoration: const InputDecoration(labelText: 'Select Staff'),
                  items: staffDocs.map((d) {
                    final data = d.data() as Map<String, dynamic>;
                    return DropdownMenuItem(
                      value: d.id,
                      child: Text(data['name'] ?? 'Unnamed Staff'),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => selectedStaffId = v),
                );
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loading ? null : assignStaffToDoctor,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.link),
              label: const Text('Assign'),
            ),
            const SizedBox(height: 20),
            // Optional: quick view of current assignments
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance.collection('assignments').orderBy('assignedAt', descending: true).snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) return const SizedBox();
                  final items = snap.data!.docs;
                  if (items.isEmpty) return const Text('No assignments yet');
                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final d = items[i].data() as Map<String, dynamic>;
                      return ListTile(
                        title: Text('Doctor: ${d['doctorId']}  —  Staff: ${d['staffId']}'),
                        subtitle: d['assignedAt'] != null
                            ? Text(d['assignedAt'].toDate().toString())
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

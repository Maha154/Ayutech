// lib/screens/billing_details_screen.dart
// Desktop-ready BillingDetailsScreen with UI updated to match admin billing screenshot.
// Logic (Firestore, PDF export, upload) is unchanged; only layout / styling replaced.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

// PDF & printing packages
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

// FILE PICKER
import 'package:file_picker/file_picker.dart';

// Use the AyuColors palette you provided
import 'package:ayutech/screens/staff_home_screen.dart';
import 'package:ayutech/utils/pdf_generator.dart';
import 'package:url_launcher/url_launcher.dart';



class BillingDetailsScreen extends StatefulWidget {
  final String patientDocId;
  final String? globalPatientDocId;
  final Map<String, dynamic> patientData;

  const BillingDetailsScreen({
    Key? key,
    required this.patientDocId,
    required this.globalPatientDocId,
    required this.patientData,
  }) : super(key: key);


  @override
  State<BillingDetailsScreen> createState() => _BillingDetailsScreenState();
}

class _BillingDetailsScreenState extends State<BillingDetailsScreen> {
  final FirebaseFirestore _fire = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  String _status = 'Unpaid';
  final TextEditingController _amountCtl = TextEditingController();
  final TextEditingController _notesCtl = TextEditingController();
  bool _saving = false;
  bool _completing = false;

  final TextEditingController _particularCtl = TextEditingController();
  final TextEditingController _chargeCtl = TextEditingController();
  final TextEditingController _qtyCtl = TextEditingController(text: '1');

  final List<Map<String, dynamic>> _lineItems = [];
  final DateFormat _dateFmt = DateFormat('dd MMMM yyyy HH:mm');

  // Optional banner image path (desktop-only); set null to skip
  final String? bannerFilePath = null;

  @override
  void dispose() {
    _amountCtl.dispose();
    _notesCtl.dispose();
    _particularCtl.dispose();
    _chargeCtl.dispose();
    _qtyCtl.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> _billingStreamForStaff() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _fire
        .collection('users')
        .doc(uid)
        .collection('patients')
        .doc(widget.patientDocId)
        .collection('billing')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _loadParentPatientDoc() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not authenticated');
    final docRef = _fire.collection('users').doc(uid).collection('patients').doc(widget.patientDocId);
    final snap = await docRef.get();
    return snap as DocumentSnapshot<Map<String, dynamic>>;
  }

  // ---------- EDITED: insert new items at the start so they appear on top ----------
  void _addLineItem() {
    final part = _particularCtl.text.trim();
    final chargeText = _chargeCtl.text.trim();
    final qtyText = _qtyCtl.text.trim();
    if (part.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter particular')));
      return;
    }
    final charge = double.tryParse(chargeText) ?? 0.0;
    final qty = int.tryParse(qtyText) ?? 1;
    setState(() {
      // Insert at start so newest appears on top
      _lineItems.insert(0, {
        'particular': part,
        'charge': charge,
        'qty': qty,
        'amount': charge * qty,
      });
      _particularCtl.clear();
      _chargeCtl.clear();
      _qtyCtl.text = '1';
    });
  }

Future<void> _openDietPdf() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  String? pdfUrl;

  // 1️⃣ Try STAFF → GLOBAL patient doc
  if (widget.globalPatientDocId != null &&
      widget.globalPatientDocId!.isNotEmpty) {
    final staffGlobalSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('patients')
        .doc(widget.globalPatientDocId!)
        .get();

    pdfUrl = staffGlobalSnap.data()?['dietChartUrl'];
    debugPrint("STAFF (GLOBAL ID) dietChartUrl: $pdfUrl");
  }

  // 2️⃣ Fallback: STAFF → local patient doc
  if (pdfUrl == null || pdfUrl.isEmpty) {
    final staffLocalSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('patients')
        .doc(widget.patientDocId)
        .get();

    pdfUrl = staffLocalSnap.data()?['dietChartUrl'];
    debugPrint("STAFF (LOCAL ID) dietChartUrl: $pdfUrl");
  }

  // 3️⃣ Final fallback: GLOBAL patients collection
  if ((pdfUrl == null || pdfUrl.isEmpty) &&
      widget.globalPatientDocId != null &&
      widget.globalPatientDocId!.isNotEmpty) {
    final globalSnap = await FirebaseFirestore.instance
        .collection('patients')
        .doc(widget.globalPatientDocId!)
        .get();

    pdfUrl = globalSnap.data()?['dietChartUrl'];
    debugPrint("GLOBAL patients dietChartUrl: $pdfUrl");
  }

  // 4️⃣ Still missing
  if (pdfUrl == null || pdfUrl.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Diet PDF not uploaded yet')),
    );
    return;
  }

  // 5️⃣ Open PDF
  await launchUrl(
    Uri.parse(pdfUrl),
    mode: LaunchMode.externalApplication,
  );
}




  Future<void> _saveEntry() async {
    if (_lineItems.isEmpty && _amountCtl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add line items or amount before saving')));
      return;
    }
    setState(() => _saving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Not authenticated');

      final manualAmountText = _amountCtl.text.trim();
      final manualAmount = manualAmountText.isEmpty ? null : double.tryParse(manualAmountText);

      double linesTotal = 0;
      for (var it in _lineItems) {
        final a = (it['amount'] is num) ? (it['amount'] as num).toDouble() : double.tryParse(it['amount'].toString()) ?? 0.0;
        linesTotal += a;
      }
      final effectiveAmount = manualAmount ?? (linesTotal > 0 ? linesTotal : 0.0);

      final uidStaff = uid;
      final billingMap = {
        'status': _status.toLowerCase(),
        'amount': effectiveAmount,
        'notes': _notesCtl.text.trim(),
        'items': _lineItems,
        'createdAt': FieldValue.serverTimestamp(),
        'createdByUid': uidStaff,
      };

      final billingRef = await _fire
          .collection('users')
          .doc(uidStaff)
          .collection('patients')
          .doc(widget.patientDocId)
          .collection('billing')
          .add(billingMap);

      final parentRef = _fire.collection('users').doc(uidStaff).collection('patients').doc(widget.patientDocId);
      final parentUpdate = {
        'billingStatus': _status,
        'billingAmount': effectiveAmount,
        'billingNotes': _notesCtl.text.trim(),
        'billingUpdatedAt': FieldValue.serverTimestamp(),
        'lastBillingDocId': billingRef.id,
      };
      await parentRef.set(parentUpdate, SetOptions(merge: true));
      // --- ensure global patient doc also receives billing metadata (best-effort) ---
      try {
        final parentSnap2 = await parentRef.get();
        if (parentSnap2.exists) {
          final pdata = parentSnap2.data() as Map<String, dynamic>;

          // 1) Find (or confirm) global patient doc id
          String? globalId = pdata['globalPatientDocId'] ?? pdata['globalId'] ?? pdata['patientDocId'];
          if (globalId == null || globalId.toString().isEmpty) {
            // try to find a global doc with matching patientId field
            final pid = (pdata['patientId'] ?? pdata['patientIdString'] ?? pdata['patientId'])?.toString() ?? '';
            if (pid.isNotEmpty) {
              final q = await _fire.collection('patients').where('patientId', isEqualTo: pid).limit(1).get();
              if (q.docs.isNotEmpty) {
                globalId = q.docs.first.id;
                // write it back to staff doc so future calls can use it
                await parentRef.set({'globalPatientDocId': globalId}, SetOptions(merge: true));
              }
            }
          }

          // 2) If we have a globalId, update global patient doc with billing metadata
          if (globalId != null && globalId.toString().isNotEmpty) {
            final globalRef = _fire.collection('patients').doc(globalId.toString());
            final globalUpdate = {
              'billingStatus': _status,
              'billingAmount': effectiveAmount,
              'billingNotes': _notesCtl.text.trim(),
              'billingUpdatedAt': FieldValue.serverTimestamp(),
              'lastBillingDocId': billingRef.id,
            };
            await globalRef.set(globalUpdate, SetOptions(merge: true));
          }
        }
      } catch (e) {
        debugPrint('DEBUG: ensure global patient doc update failed: $e');
      }

      // Mirror to doctor's copy (best-effort)
      try {
        final parentSnap = await parentRef.get();
        if (parentSnap.exists) {
          final pdata = parentSnap.data() as Map<String, dynamic>;
          final assignedDoctorUid = pdata['assignedDoctorUid'] ?? pdata['doctorUid'];
          final doctorPatientDocId = pdata['doctorPatientDocId'] ?? pdata['staffPatientDocId'];
          if (assignedDoctorUid != null && doctorPatientDocId != null) {
            final doctorParentRef = _fire
                .collection('users')
                .doc(assignedDoctorUid.toString())
                .collection('patients')
                .doc(doctorPatientDocId.toString());

            await doctorParentRef.set(parentUpdate, SetOptions(merge: true));

            await _fire
                .collection('users')
                .doc(assignedDoctorUid.toString())
                .collection('patients')
                .doc(doctorPatientDocId.toString())
                .collection('billing')
                .add({...billingMap, 'mirroredFromStaffUid': uidStaff});
          }
        }
      } catch (e) {
        debugPrint('DEBUG: failed updating doctor copy: $e');
      }

      _amountCtl.clear();
      _notesCtl.clear();
      setState(() {
        _status = 'Unpaid';
        _lineItems.clear();
      });

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Billing saved')));
    } catch (e) {
      debugPrint('DEBUG: saveEntry error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---------- SIMPLE FONT LOADER ----------
  Future<pw.Font> _loadPdfFont() async {
    try {
      return pw.Font.helvetica();
    } catch (e, st) {
      debugPrint('DEBUG: unexpected font fallback error: $e\n$st');
      return pw.Font.helvetica();
    }
  }
  // -------------------------------------------------------

  Future<void> _exportPdf(String patientName, String assignedDoctorName, List<Map<String, dynamic>> items, double total) async {
    final pdfDoc = pw.Document();
    final pdfFont = await _loadPdfFont();

    pw.ImageProvider? bannerImage;
    try {
      if (bannerFilePath != null) {
        final f = File(bannerFilePath!);
        if (await f.exists()) {
          final bytes = await f.readAsBytes();
          bannerImage = pw.MemoryImage(bytes);
        }
      }
    } catch (e) {
      debugPrint('Banner load failed: $e');
    }

    final tableData = items.asMap().entries.map((e) {
      final idx = e.key + 1;
      final row = e.value;
      final part = row['particular'] ?? '';
      final qty = (row['qty'] ?? 1).toString();
      final rate = (row['charge'] is num) ? (row['charge'] as num).toStringAsFixed(2) : row['charge'].toString();
      final amt = (row['amount'] is num) ? (row['amount'] as num).toStringAsFixed(2) : row['amount'].toString();
      return [idx.toString(), part, qty, rate, amt];
    }).toList();

    pdfDoc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        build: (pw.Context context) {
          return [
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              width: double.infinity,
              decoration: pw.BoxDecoration(color: PdfColors.blue400),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Text('AyuTech Clinic',
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                              font: pdfFont,
                            )),
                        pw.SizedBox(height: 4),
                        pw.Text('Velachery', style: pw.TextStyle(color: PdfColors.white, font: pdfFont)),
                        pw.SizedBox(height: 2),
                        pw.Text('contact@ayutech.com | +91 70000 00000', style: pw.TextStyle(color: PdfColors.white, fontSize: 9, font: pdfFont)),
                      ],
                    ),
                  ),
                  if (bannerImage != null)
                    pw.Container(width: 120, height: 60, padding: const pw.EdgeInsets.only(left: 8), child: pw.Image(bannerImage, fit: pw.BoxFit.contain)),
                ],
              ),
            ),

            pw.SizedBox(height: 12),
            pw.Center(child: pw.Text('Hospital Bill', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, font: pdfFont))),
            pw.SizedBox(height: 6),
            pw.Center(child: pw.Text('[AYUTECH CLINIC ADDRESS HERE]', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700, font: pdfFont))),
            pw.SizedBox(height: 14),

            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text('Invoice Details', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: pdfFont)),
                      pw.Bullet(text: 'Invoice Number: ${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}', style: pw.TextStyle(font: pdfFont)),
                      pw.Bullet(text: 'Date of Issue: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}', style: pw.TextStyle(font: pdfFont)),
                      pw.Bullet(text: 'Service Date: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}', style: pw.TextStyle(font: pdfFont)),
                    ]),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text('Bill To', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: pdfFont)),
                      pw.Bullet(text: 'Name: $patientName', style: pw.TextStyle(font: pdfFont)),
                      pw.Bullet(text: 'Email: doc@example.com', style: pw.TextStyle(font: pdfFont)),
                      pw.Bullet(text: 'Phone: +91 70000 00000', style: pw.TextStyle(font: pdfFont)),
                    ]),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 18),
            pw.Text('Charges Summary', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, font: pdfFont)),
            pw.SizedBox(height: 8),

            pw.Table.fromTextArray(
              headers: ['#', 'Description', 'Qty', 'Rate', 'Amount'],
              data: tableData,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, font: pdfFont),
              cellStyle: pw.TextStyle(fontSize: 10, font: pdfFont),
              headerDecoration: pw.BoxDecoration(color: PdfColors.grey200),
              cellAlignment: pw.Alignment.centerLeft,
              columnWidths: {
                0: pw.FixedColumnWidth(30),
                1: pw.FlexColumnWidth(4),
                2: pw.FixedColumnWidth(40),
                3: pw.FixedColumnWidth(60),
                4: pw.FixedColumnWidth(80),
              },
              border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
              cellPadding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
            ),

            pw.SizedBox(height: 8),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text('Subtotal: ${total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11, font: pdfFont)),
                pw.SizedBox(height: 6),
                pw.Text('Total Amount Due: ${total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, font: pdfFont)),
              ]),
            ]),

            pw.SizedBox(height: 18),
            pw.Text('Notes:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: pdfFont)),
            pw.Text(_lineItems.isNotEmpty ? '' : '—', style: pw.TextStyle(font: pdfFont)),

            pw.Spacer(),
            pw.Divider(),
            pw.Center(child: pw.Text('Thank you for choosing AyuTech Clinic', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700, font: pdfFont))),
          ];
        },
      ),
    );

    // --- robust save + open block ---
    try {
      final Uint8List pdfBytes = await pdfDoc.save();
      debugPrint('DEBUG: PDF bytes length = ${pdfBytes.length}');

      // Optional: try printing preview (non-fatal)
      try {
        await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdfBytes);
      } catch (e) {
        debugPrint('DEBUG: Printing.layoutPdf failed (non-fatal): $e');
      }

      // Prefer Downloads if available
      String? downloadsPath;
      if (Platform.isWindows) {
        final up = Platform.environment['USERPROFILE'];
        if (up != null && up.isNotEmpty) downloadsPath = '$up${Platform.pathSeparator}Downloads';
      } else if (Platform.isMacOS || Platform.isLinux) {
        final home = Platform.environment['HOME'];
        if (home != null && home.isNotEmpty) downloadsPath = '${home}${Platform.pathSeparator}Downloads';
      }

      Directory saveDir;
      if (downloadsPath != null) {
        final d = Directory(downloadsPath);
        saveDir = await (await d.exists() ? Future.value(d) : getTemporaryDirectory());
      } else {
        saveDir = await getTemporaryDirectory();
      }

      final fileName = 'invoice_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = '${saveDir.path}${Platform.pathSeparator}$fileName';
      final file = File(filePath);

      await file.writeAsBytes(pdfBytes);
      debugPrint('DEBUG: wrote PDF to $filePath');

      final exists = await file.exists();
      debugPrint('DEBUG: file.exists = $exists');

      if (!exists) {
        throw Exception('File was not created: $filePath');
      }

      // Try opening the file using OS-specific commands.
      var opened = false;
      try {
        if (Platform.isWindows) {
          final result = await Process.run('cmd', ['/c', 'start', '""', file.path], runInShell: true);
          debugPrint('DEBUG: cmd start result: ${result.exitCode}, stdout: ${result.stdout}, stderr: ${result.stderr}');
          opened = result.exitCode == 0;
        } else if (Platform.isMacOS) {
          final result = await Process.run('open', [file.path]);
          debugPrint('DEBUG: open result: ${result.exitCode}, stdout: ${result.stdout}, stderr: ${result.stderr}');
          opened = result.exitCode == 0;
        } else if (Platform.isLinux) {
          final result = await Process.run('xdg-open', [file.path]);
          debugPrint('DEBUG: xdg-open result: ${result.exitCode}, stdout: ${result.stdout}, stderr: ${result.stderr}');
          opened = result.exitCode == 0;
        }
      } catch (e) {
        debugPrint('DEBUG: OS opener failed: $e');
        opened = false;
      }

      // If opening the file failed, try opening the containing folder
      if (!opened) {
        try {
          if (Platform.isWindows) {
            final result = await Process.run('explorer', ['/select,${file.path}'], runInShell: true);
            debugPrint('DEBUG: explorer select result: ${result.exitCode}, stdout: ${result.stdout}, stderr: ${result.stderr}');
          } else if (Platform.isMacOS) {
            final result = await Process.run('open', ['-R', file.path]);
            debugPrint('DEBUG: open -R result: ${result.exitCode}, stdout: ${result.stdout}, stderr: ${result.stderr}');
          } else if (Platform.isLinux) {
            final result = await Process.run('xdg-open', [saveDir.path]);
            debugPrint('DEBUG: xdg-open folder result: ${result.exitCode}, stdout: ${result.stdout}, stderr: ${result.stderr}');
          }
        } catch (e) {
          debugPrint('DEBUG: fallback folder-opener failed: $e');
        }
      }

      if (mounted) {
        final dest = saveDir.path.contains('Downloads') ? 'Downloads' : saveDir.path;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF saved to: $dest/$fileName')));
      }
    } catch (e, st) {
      debugPrint('Failed to save/open PDF: $e\n$st');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to export/open PDF: $e')));
    }
  } // end _exportPdf


  

  // ------------------ NEW: generate bytes & upload helpers ------------------

  /// Generates billing PDF bytes (re-usable for upload).
  Future<Uint8List> _generateBillingPdfBytes(
      String patientName, String assignedDoctorName, List<Map<String, dynamic>> items, double total) async {
    final pdf = pw.Document();
    final pdfFont = await _loadPdfFont();

    final tableData = items.asMap().entries.map((e) {
      final idx = e.key + 1;
      final row = e.value;
      final part = row['particular'] ?? '';
      final qty = (row['qty'] ?? 1).toString();
      final rate = (row['charge'] is num) ? (row['charge'] as num).toStringAsFixed(2) : row['charge'].toString();
      final amt = (row['amount'] is num) ? (row['amount'] as num).toStringAsFixed(2) : row['amount'].toString();
      return [idx.toString(), part, qty, rate, amt];
    }).toList();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      build: (pw.Context context) {
        return [
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            width: double.infinity,
            decoration: pw.BoxDecoration(color: PdfColors.blue400),
            child: pw.Row(children: [
              pw.Expanded(
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, mainAxisSize: pw.MainAxisSize.min, children: [
                  pw.Text('AyuTech Clinic', style: pw.TextStyle(color: PdfColors.white, fontSize: 20, fontWeight: pw.FontWeight.bold, font: pdfFont)),
                  pw.SizedBox(height: 4),
                  pw.Text('Velachery', style: pw.TextStyle(color: PdfColors.white, font: pdfFont)),
                  pw.SizedBox(height: 2),
                  pw.Text('contact@ayutech.com | +91 70000 00000', style: pw.TextStyle(color: PdfColors.white, fontSize: 9, font: pdfFont)),
                ]),
              ),
            ]),
          ),
          pw.SizedBox(height: 12),
          pw.Center(child: pw.Text('Hospital Bill', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, font: pdfFont))),
          pw.SizedBox(height: 6),
          pw.Center(child: pw.Text('[AYUTECH CLINIC ADDRESS HERE]', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700, font: pdfFont))),
          pw.SizedBox(height: 14),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
            child: pw.Row(children: [
              pw.Expanded(
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('Invoice Details', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: pdfFont)),
                  pw.Bullet(text: 'Invoice Number: ${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}', style: pw.TextStyle(font: pdfFont)),
                  pw.Bullet(text: 'Date of Issue: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}', style: pw.TextStyle(font: pdfFont)),
                ]),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('Bill To', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: pdfFont)),
                  pw.Bullet(text: 'Name: $patientName', style: pw.TextStyle(font: pdfFont)),
                  pw.Bullet(text: 'Phone: +91 70000 00000', style: pw.TextStyle(font: pdfFont)),
                ]),
              ),
            ]),
          ),
          pw.SizedBox(height: 18),
          pw.Text('Charges Summary', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, font: pdfFont)),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            headers: ['#', 'Description', 'Qty', 'Rate', 'Amount'],
            data: tableData,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, font: pdfFont),
            cellStyle: pw.TextStyle(fontSize: 10, font: pdfFont),
            headerDecoration: pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignment: pw.Alignment.centerLeft,
            columnWidths: {
              0: pw.FixedColumnWidth(30),
              1: pw.FlexColumnWidth(4),
              2: pw.FixedColumnWidth(40),
              3: pw.FixedColumnWidth(60),
              4: pw.FixedColumnWidth(80),
            },
            border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
            cellPadding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
          ),
          pw.SizedBox(height: 8),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('Subtotal: ${total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11, font: pdfFont)),
              pw.SizedBox(height: 6),
              pw.Text('Total Amount Due: ${total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, font: pdfFont)),
            ]),
          ]
          ),
          pw.SizedBox(height: 18),
          pw.Spacer(),
          pw.Divider(),
          pw.Center(child: pw.Text('Thank you for choosing AyuTech Clinic', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700, font: pdfFont))),
        ];
      },
    ));

    final bytes = await pdf.save();
    return bytes;
  }







  // ---------- COMPLETE patient handler (returns success instead of popping) ----------
  /// Marks patient as completed. Returns true on success.
  Future<bool> _completePatient(Map<String, dynamic> parentData) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    // Ask for confirmation here (keeps UI flow inside function)
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete patient'),
        content: const Text(
            'Mark this patient as completed and move to Existing Records? This will remove them from Ongoing list.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Confirm')),
        ],
      ),
    );

    if (confirmed != true) return false;

    try {
      final patientRef = _fire.collection('users').doc(uid).collection('patients').doc(widget.patientDocId);

      final update = {
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
        'isOngoing': false,
        'movedToRecords': true,
        'tokenNumber': null,
        'token': null,
      };

      await patientRef.set(update, SetOptions(merge: true));

      // Mirror to doctor's copy if exists (best-effort)
      try {
        final assignedDoctorUid = parentData['assignedDoctorUid'] ?? parentData['doctorUid'];
        final doctorPatientDocId = parentData['doctorPatientDocId'] ?? parentData['staffPatientDocId'];
        if (assignedDoctorUid != null && doctorPatientDocId != null) {
          final doctorRef = _fire
              .collection('users')
              .doc(assignedDoctorUid.toString())
              .collection('patients')
              .doc(doctorPatientDocId.toString());
          await doctorRef.set(update, SetOptions(merge: true));
        }
      } catch (e) {
        debugPrint('DEBUG: failed updating doctor copy on complete: $e');
      }

      // DON'T pop here. Return success and let the caller show upload dialog and then pop.
      return true;
    } catch (e) {
      debugPrint('DEBUG: completePatient error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to complete patient: $e')));
      return false;
    }
 

  }

  

  // ---------- END complete handler ----------

  String _fmtTs(Timestamp? ts) {
    if (ts == null) return '';
    return _dateFmt.format(ts.toDate());
  }

  Widget _buildHeaderCell(String title) {
    return Text(title, style: const TextStyle(fontWeight: FontWeight.w700));
  }

  @override
  Widget build(BuildContext context) {
    // Use AyuColors for consistent palette
    final headerGreen = AyuColors.teal;
    final tileBg = AyuColors.tileBg;
    final inputBg = AyuColors.tileBg.withOpacity(0.6);

    // Wrap Scaffold in a Theme override so all buttons use white text by default.
    return Theme(
      data: Theme.of(context).copyWith(
        // Elevated buttons (primary buttons)
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white, // text/icon color
            // keep background color usage from your call-sites (or set default here)
          ),
        ),
        // Outlined buttons
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white, // text/icon color
          ),
        ),
        // Text buttons
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
          ),
        ),
        // Dialog buttons (AlertDialog action buttons use TextButton by default,
        // so textButtonTheme above will already apply; this is optional)
       
      ),
      child: Scaffold(
        backgroundColor: AyuColors.bgBody,
        appBar: AppBar(
          backgroundColor: headerGreen,
          title: const Text('Billing & Invoicing'),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
          elevation: 0,
        ),
        body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: _loadParentPatientDoc(),
          builder: (context, parentSnap) {
            final parentData = parentSnap.data?.data() ?? <String, dynamic>{};
            final patientName = (parentData['name'] ?? parentData['fullName'] ?? '').toString();
            final patientToken = (parentData['tokenNumber'] ?? parentData['token'] ?? '--').toString();
            final patientId = (parentData['patientId'] ?? widget.patientDocId).toString();
            final assignedDoctorName = (parentData['assignedDoctorName'] ?? parentData['doctorName'] ?? '').toString();
            final startDateObj = parentData['startDate'];
            DateTime startDate = DateTime.now();
            if (startDateObj is Timestamp) startDate = (startDateObj as Timestamp).toDate();
            else if (startDateObj is String) startDate = DateTime.tryParse(startDateObj) ?? DateTime.now();

            // Layout center with max width like screenshot
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        // Top bar: title + optional total
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Billing & Invoicing', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AyuColors.teal)),
                              const SizedBox(height: 6),
                              Text('Generate and manage patient bills', style: TextStyle(color: Colors.black54)),
                            ]),

                          ],
                        ),
                        const SizedBox(height: 18),

                        // Main panels: left column (patient details + invoice settings), right column (billable items)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // LEFT COLUMN (fixed width)
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 360, minWidth: 300),
                              child: Column(
                                children: [
                                  // Patient Details card
                                  Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: AyuColors.cardSurface,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))],
                                      border: Border.all(color: Colors.black.withOpacity(0.02)),
                                    ),
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(radius: 28, backgroundColor: AyuColors.surfaceAlt, child: Text(patientName.isNotEmpty ? patientName[0].toUpperCase() : '?')),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                                Text(patientName.isNotEmpty ? patientName : 'John Doe', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                                const SizedBox(height: 4),
                                                Text(patientId, style: TextStyle(color: Colors.black54)),
                                              ]),
                                            )
                                          ],
                                        ),
                                        const Divider(height: 20),
                                        _InfoRow(label: 'Token ID', value: patientToken),
                                        const SizedBox(height: 8),
                                        _InfoRow(label: 'Admitted', value: DateFormat('dd/MM/yyyy').format(startDate)),
                                        const SizedBox(height: 8),
                                        _InfoRow(label: 'Region/Ward', value: (parentData['region'] ?? '—').toString()),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  // Invoice Settings card
                                  Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: AyuColors.cardSurface,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))],
                                      border: Border.all(color: Colors.black.withOpacity(0.02)),
                                    ),
                                    padding: const EdgeInsets.all(12),
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      const Text('Invoice Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 12),
                                      const Text('Payment Status', style: TextStyle(fontSize: 12)),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(8)),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: _status,
                                            isExpanded: true,
                                            style: const TextStyle(color: Colors.white), // selected value text color set here
                                            items: const [
                                              DropdownMenuItem(value: 'Unpaid', child: Text('Unpaid', style: TextStyle(color: Colors.black87))),
                                              DropdownMenuItem(value: 'Paid', child: Text('Paid', style: TextStyle(color: Colors.black87))),
                                            ],
                                            onChanged: (v) {
                                              if (v == null) return;
                                              setState(() => _status = v);
                                            },
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      const Text('Invoice Date', style: TextStyle(fontSize: 12)),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                        decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(8)),
                                        child: Row(
                                          children: [
                                            Expanded(child: Text(DateFormat('dd-MM-yyyy').format(DateTime.now()))),
                                            const Icon(Icons.calendar_today, size: 18, color: Colors.black54),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      const Text('Notes', style: TextStyle(fontSize: 12)),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        controller: _notesCtl,
                                        maxLines: 3,
                                        decoration: InputDecoration(hintText: 'Optional notes for the patient...', filled: true, fillColor: inputBg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                                      ),
                                      const SizedBox(height: 12),
                                 Row(
  children: [
    // ✅ Save Billing
    Expanded(
      child: ElevatedButton(
        onPressed: _saving ? null : _saveEntry,
        style: ElevatedButton.styleFrom(backgroundColor: AyuColors.teal),
        child: _saving
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text('Save Billing'),
      ),
    ),

    const SizedBox(width: 8),

    // 🟠 END PATIENT
    Expanded(
      child: ElevatedButton(
        onPressed: _completing
            ? null
            : () async {
                setState(() => _completing = true);

                final success = await _completePatient(parentData);

                setState(() => _completing = false);

                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Patient ended successfully')),
                  );

                  // Go back to records / ongoing screen
                  Navigator.pop(context);
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepOrange,
        ),
        child: _completing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text('End Patient'),
      ),
    ),
  ],
),



                                    ]),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 20),

                            // RIGHT COLUMN (expanded)
                            Expanded(
                              child: Column(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: AyuColors.cardSurface,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))],
                                      border: Border.all(color: Colors.black.withOpacity(0.02)),
                                    ),
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(child: Text('Billable Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AyuColors.teal))),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(color: AyuColors.tileBg, borderRadius: BorderRadius.circular(16)),
                                              child: const Text('2 Items', style: TextStyle(fontSize: 12)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),

                                        // Table header
                                        Container(
                                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                                          child: Row(
                                            children: [
                                              Expanded(flex: 1, child: Text('#', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700))),
                                              Expanded(flex: 6, child: Text('Particular / Service', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700))),
                                              Expanded(flex: 2, child: Text('Rate', textAlign: TextAlign.right, style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700))),
                                              const SizedBox(width: 12),
                                              SizedBox(width: 80, child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700))),
                                              const SizedBox(width: 12),
                                              SizedBox(width: 100, child: Text('Amount', textAlign: TextAlign.right, style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700))),
                                            ],
                                          ),
                                        ),
                                        const Divider(),

                                        // ---------- EDITED: show local _lineItems first, then persisted ----------
                                        StreamBuilder<QuerySnapshot>(
                                          stream: _billingStreamForStaff(),
                                          builder: (context, snap) {
                                            final docs = snap.data?.docs ?? [];

                                            // Build invoice items: local unsaved items first (so they appear at top),
                                            // then append persisted items from Firestore (older).
                                            final invoiceItems = <Map<String, dynamic>>[];

                                            // 1) Local unsaved items first
                                            for (var it in _lineItems) {
                                              invoiceItems.add(it);
                                            }

                                            // 2) Append persisted billing records (older entries)
                                            for (var d in docs.reversed) {
                                              final m = d.data() as Map<String, dynamic>;
                                              final items = (m['items'] ?? []) as List<dynamic>;
                                              if (items.isNotEmpty) {
                                                for (var it in items) {
                                                  if (it is Map) invoiceItems.add(Map<String, dynamic>.from(it as Map));
                                                }
                                              } else {
                                                final amt = (m['amount'] is num) ? (m['amount'] as num).toDouble() : double.tryParse((m['amount'] ?? '').toString()) ?? 0.0;
                                                invoiceItems.add({'particular': (m['notes'] ?? 'Billing'), 'qty': 1, 'charge': amt, 'amount': amt});
                                              }
                                            }

                                          


                                            double total = 0;
                                            for (var it in invoiceItems) {
                                              total += ((it['amount'] is num) ? (it['amount'] as num).toDouble() : double.tryParse((it['amount'] ?? '').toString()) ?? 0.0);
                                            }

                                           return SingleChildScrollView(
  child: Column(

      children: [
        if (invoiceItems.isEmpty)
  Padding(
    padding: const EdgeInsets.all(18),
    child: const Center(
      child: Text(
        'No billing items yet',
        style: TextStyle(color: Colors.black54),
      ),
    ),
  ),


                                                // Rows
                                                ...invoiceItems.asMap().entries.map((entry) {
                                                  final idx = entry.key + 1;
                                                  final it = entry.value;
                                                  final amt = (it['amount'] is num) ? (it['amount'] as num).toDouble() : double.tryParse((it['amount'] ?? '').toString()) ?? 0.0;
                                                  final rate = (it['charge'] is num) ? (it['charge'] as num).toDouble() : double.tryParse((it['charge'] ?? '').toString()) ?? 0.0;
                                                  final qty = it['qty'] ?? 1;
                                                  return Padding(
                                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                                    child: Row(
                                                      children: [
                                                        Expanded(flex: 1, child: Text(idx.toString())),
                                                        Expanded(flex: 6, child: Text(it['particular'] ?? 'Item')),
                                                        Expanded(flex: 2, child: Text('₹ ${rate.toStringAsFixed(2)}', textAlign: TextAlign.right)),
                                                        const SizedBox(width: 12),
                                                        SizedBox(width: 80, child: Text(qty.toString(), textAlign: TextAlign.center)),
                                                        const SizedBox(width: 12),
                                                        SizedBox(width: 100, child: Text('₹ ${amt.toStringAsFixed(2)}', textAlign: TextAlign.right)),
                                                      ],
                                                    ),
                                                  );
                                                }).toList(),

                                                const Divider(),
                                                // ADD NEW LINE ITEM row
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      flex: 5,
                                                      child: TextField(
                                                        controller: _particularCtl,
                                                        decoration: InputDecoration(hintText: 'Enter service or medicine name...', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    SizedBox(
                                                      width: 120,
                                                      child: TextField(
                                                        controller: _chargeCtl,
                                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                        decoration: InputDecoration(hintText: '₹ 0.00', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    SizedBox(
                                                      width: 80,
                                                      child: TextField(
                                                        controller: _qtyCtl,
                                                        keyboardType: TextInputType.number,
                                                        decoration: InputDecoration(hintText: '1', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    ElevatedButton.icon(
                                                      onPressed: _addLineItem,
                                                      icon: const Icon(Icons.add),
                                                      label: const Text('Add Item'),
                                                      style: ElevatedButton.styleFrom(backgroundColor: AyuColors.teal),
                                                    ),
                                                  ],
                                                ),

                                                const SizedBox(height: 18),

                                                // Totals block (right aligned)
                                                Row(
                                                  children: [
                                                    const Spacer(),
                                                    Container(
                                                      width: 320,
                                                      padding: const EdgeInsets.all(12),
                                                      decoration: BoxDecoration(color: tileBg, borderRadius: BorderRadius.circular(8)),
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                                        children: [
                                                          Row(
                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                            children: [const Text('Subtotal'), Text('₹ ${total.toStringAsFixed(2)}')],
                                                          ),
                                                          const SizedBox(height: 6),
                                                          Row(
                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                            children: [const Text('Tax (8%)'), Text('₹ ${(total * 0.08).toStringAsFixed(2)}')],
                                                          ),
                                                          const Divider(),
                                                          Row(
                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                            children: [
                                                              const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.w700)),
                                                              Text('₹ ${(total * 1.08).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.black87)),
                                                            ],
                                                          ),
                                                          const SizedBox(height: 12),

// ---------- ACTION BUTTONS ----------
Column(
  children: [
    // Row 1: Export buttons
    Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              final invoiceItems =
                  invoiceItemsFromDocsAndLocal(snap.data?.docs ?? []);
              await _exportPdf(
                patientName,
                assignedDoctorName,
                invoiceItems,
                total * 1.08,
              );
            },
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Export PDF'),
            style: OutlinedButton.styleFrom(
              backgroundColor: AyuColors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
 onPressed: () async {
  await _openDietPdf();
},

  icon: const Icon(Icons.restaurant_menu),
  label: const Text('Diet PDF'),
  style: OutlinedButton.styleFrom(
    backgroundColor: Colors.deepOrange,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 14),
  ),
),

        ),
      ],
    ),

    const SizedBox(height: 12),

    // Row 2: Generate invoice (full width)
    SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          final invoiceItems =
              invoiceItemsFromDocsAndLocal(snap.data?.docs ?? []);
          if (_lineItems.isNotEmpty) await _saveEntry();
          await _exportPdf(
            patientName,
            assignedDoctorName,
            invoiceItems,
            total * 1.08,
          );
        },
        icon: const Icon(Icons.check),
        label: const Text('Generate Invoice'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AyuColors.teal,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    ),
  ],
),


                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              ],
    )
  
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------- EDITED: invoiceItemsFromDocsAndLocal to place local items first ----------
  List<Map<String, dynamic>> invoiceItemsFromDocsAndLocal(List<QueryDocumentSnapshot> docs) {
    final items = <Map<String, dynamic>>[];

    // Local items first
    items.addAll(_lineItems);

    // Then persisted items (older)
    for (var d in docs.reversed) {
      final m = d.data() as Map<String, dynamic>;
      final list = (m['items'] ?? []) as List<dynamic>;
      if (list.isNotEmpty) {
        for (var it in list) {
          if (it is Map) items.add(Map<String, dynamic>.from(it as Map));
        }
      } else {
        final amt = (m['amount'] is num) ? (m['amount'] as num).toDouble() : double.tryParse((m['amount'] ?? '').toString()) ?? 0.0;
        items.add({'particular': (m['notes'] ?? 'Billing'), 'qty': 1, 'charge': amt, 'amount': amt});
      }
    }

    return items;
  }
}

// Small info row used in left column cards
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({Key? key, required this.label, required this.value}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(flex: 3, child: Text(label, style: const TextStyle(color: Colors.black54))),
        Expanded(flex: 5, child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
      ],
    );
  }
}

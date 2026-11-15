// lib/services/storage_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  StorageService._();
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseFirestore _fire = FirebaseFirestore.instance;

  /// Upload a PDF File (File) to dietCharts/{patientDocId}/{name} and update patients/{patientDocId}.
  static Future<String?> uploadDietChartPdf({
    required File pdfFile,
    required String patientDocId,
    String? fileName,
  }) async {
    final name = fileName ?? 'diet_chart_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final ref = _storage.ref().child('dietCharts').child(patientDocId).child(name);
    final metadata = SettableMetadata(contentType: 'application/pdf');

    final task = ref.putFile(pdfFile, metadata);
    final snapshot = await task.whenComplete(() {});
    final url = await snapshot.ref.getDownloadURL();

    await _fire.collection('patients').doc(patientDocId).set({
      'dietChartUrl': url,
      'dietChartName': name,
      'dietChartUploadedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return url;
  }

  /// Upload billing PDF and update patient doc with billingPdfUrl fields
  static Future<String?> uploadBillingPdf({
    required File pdfFile,
    required String patientDocId,
    String? fileName,
  }) async {
    final name = fileName ?? 'billing_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final ref = _storage.ref().child('billingPdfs').child(patientDocId).child(name);
    final metadata = SettableMetadata(contentType: 'application/pdf');
    final task = ref.putFile(pdfFile, metadata);
    final snapshot = await task.whenComplete(() {});
    final url = await snapshot.ref.getDownloadURL();

    await _fire.collection('patients').doc(patientDocId).set({
      'billingPdfUrl': url,
      'billingPdfName': name,
      'billingPdfUploadedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return url;
  }

  /// Optional: upload bytes if your PDF generator returns Uint8List
  static Future<String?> uploadBytesAsPdf({
    required Uint8List bytes,
    required String patientDocId,
    required String folder, // 'dietCharts' or 'billingPdfs'
    String? fileName,
  }) async {
    final name = fileName ?? 'file_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final ref = _storage.ref().child(folder).child(patientDocId).child(name);
    final metadata = SettableMetadata(contentType: 'application/pdf');
    final snapshot = await ref.putData(bytes, metadata);
    final url = await snapshot.ref.getDownloadURL();

    // update patients doc appropriately
    final updateMap = (folder == 'dietCharts')
        ? {
            'dietChartUrl': url,
            'dietChartName': name,
            'dietChartUploadedAt': FieldValue.serverTimestamp(),
          }
        : {
            'billingPdfUrl': url,
            'billingPdfName': name,
            'billingPdfUploadedAt': FieldValue.serverTimestamp(),
          };

    await _fire.collection('patients').doc(patientDocId).set(updateMap, SetOptions(merge: true));
    return url;
  }
}

// lib/services/token_allocator.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';


class TokenAllocator {
  static final FirebaseFirestore _fire = FirebaseFirestore.instance;

  /// Creates an ongoingPatients document and atomically allocates a unique
  /// tokenNumber (per clinicDate) using a counter doc:
  /// counters/ongoingPatients_<clinicDate>
  ///
  /// baseData: map of fields you would normally write to ongoingPatients (omit tokenNumber/token).
  /// Returns a Map containing:
  ///   'docRef' : DocumentReference to the newly created ongoingPatients doc
  ///   'token' : String token (e.g. T001)
  ///   'tokenNumber' : int numeric token (eg 1)
  ///   'clinicDate' : String clinic date key
  ///   'patientId' : optional patientId (if provided or generated)
 static Future<Map<String, dynamic>> createOngoingPatientWithAtomicToken(
    Map<String, dynamic> baseData) async {
  try {
    final clinicDate =
        (baseData['clinicDate'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now()))
            .toString();

    final counterRef =
        _fire.collection('counters').doc('ongoingPatients_$clinicDate');
    final newDocRef = _fire.collection('ongoingPatients').doc();

    // 🔹 Get counter safely
    final counterSnap = await counterRef.get();
    final last = (counterSnap.data()?['lastToken'] ?? 0) as int;
    final next = last + 1;

    final batch = _fire.batch();

    batch.set(
      counterRef,
      {'lastToken': next, 'clinicDate': clinicDate},
      SetOptions(merge: true),
    );

    final dataToWrite = Map<String, dynamic>.from(baseData)
      ..removeWhere((k, v) => v == null);

    dataToWrite.addAll({
      'tokenNumber': next,
      'token': next.toString(),
      'clinicDate': clinicDate,
      'status': dataToWrite['status'] ?? 'ongoing',
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.set(newDocRef, dataToWrite);

    await batch.commit();

    return {
      'docRef': newDocRef,
      'token': next.toString(),
      'tokenNumber': next,
      'clinicDate': clinicDate,
    };
  } catch (e) {
    debugPrint('TOKEN ALLOCATOR FAILED: $e');
    return {
      'docRef': null,
      'token': '',
      'tokenNumber': 0,
      'clinicDate': '',
    };
  }
}

}
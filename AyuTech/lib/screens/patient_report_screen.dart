// lib/screens/patient_report_screen.dart
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'dart:async';

import 'package:ayutech/services/diet_engine.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:ayutech/screens/patient_history_screen.dart';
import 'package:ayutech/services/diet_service.dart';
import 'package:ayutech/utils/pdf_generator.dart';
import 'package:ayutech/theme/app_theme.dart';
import 'package:ayutech/widgets/ui_helpers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ayutech/services/vikriti_dosha_calculator.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';



class PatientReportScreen extends StatefulWidget {
  // required patient identifier (keeps old name 'uid' used across your code)
  final String uid;

  // optional patient meta fields
  final String name;
  final String age;
  final String gender;
  final List<String> initialConditions;
  final String previousHistory;
  final String region;
  final String allergy;
  final String phoneNumber;

  // Make startDate nullable — provide fallback when displayed/used.
  final DateTime? startDate;

  // Optional prakriti label and optional flag for auto export
  final String? prakriti;
  final bool autoExport;
  
  

  // New optional field — focus specific report id when opening the screen
  final String? focusReportId;
  

  const PatientReportScreen({
    super.key,
    required this.uid,                       // keep this required
    this.name = '',
    this.age = '',
    this.gender = '',
    this.initialConditions = const [],
    this.previousHistory = '',
    this.region = '',
    this.allergy = '',
    this.phoneNumber = '',
    this.startDate,                          // nullable, default is null
    this.autoExport = false,
    this.prakriti,
    this.focusReportId,
  });

  @override
  State<PatientReportScreen> createState() => _PatientReportScreenState();
}

class _PatientReportScreenState extends State<PatientReportScreen> {


  // ------------------ DIET STATE ------------------

bool _loadingDiet = false;
bool exportStaff = true;
bool exportPatient = true;


// ------------------ DIET INPUT FIELDS ------------------
double height = 0;
double weight = 0;
double bmi = 0;

int sleepNumeric = 2;
int bowelNumeric = 2;
int stressNumeric = 2;
int activityNumeric = 2;
double waterLitres = 1.5;

String dietaryHabits = "";
String ageGroup = "";

  // ML RESULTS
  List<List<double>> prakritiResult = [];
  List<List<double>> doshaResult = [];
  List<List<double>> nutrientTargets = [];
  List<List<double>> mealRankings = [];
  String clinicName = "";
  String clinicAddress = "";
  String clinicEmail = "";
  String clinicPhone = "";
  String? _prakritiLabel;
  String? _cachedPrognosisText;

  String _patientStatus = "ongoing";


 

  

bool _loadingNutrients = false;
Map<String, dynamic>? _nutrients;






String? _latestDietReportId;
List<dynamic> _meals = [];
Map<String, dynamic>? _latestDietPlan;
List<dynamic> breakfast = [];
List<dynamic> lunch = [];
List<dynamic> evening = [];
List<dynamic> dinner = [];

  // --- VIKRITI (diagnosis) fields ---
  double _vikritiVata = 0.0;
  double _vikritiPitta = 0.0;
  double _vikritiKapha = 0.0;
  double? _nutritionScore;
  
  List<String> _vikritiSuggestions = [];
  String? _vikritiDominant;
  String? _vikritiTimestamp;

  



  late TextEditingController _conditionsController;
  late TextEditingController _historyController;

  late Map<String, dynamic> currentGuideline;
  List<Map<String, String>> _prescriptions = [];

  String get _rxStoreKey => 'rx:${widget.uid}';
  DateTime? _nextReviewDate;
  StreamSubscription<QuerySnapshot>? _vikritiSub;

  // NEW: finalizing flag for the Treated patient flow
  bool _finalizing = false;





  // ---------------------
  // Admin dashboard palette (applied to this screen)
  // ---------------------
  // These match the colors from your AdminHomePageAllInOne
  final Color _primaryTeal = const Color(0xFF2F5C56);
  final Color _accentGold = const Color(0xFFD6A657);
  final Color _bgBody = const Color(0xFFFAFAF8);
  final Color _cardSurface = Colors.white;
  final Color _sidebarBg = const Color(0xFF2F5C56);

  // lighter variants using hex alpha for small backgrounds
  final Color _lightPrimary = const Color(0x332F5C56); // 20% teal
  final Color _lightGold = const Color(0x33D6A657); // 20% gold
  final Color _shadow = const Color(0x11000000);

  @override
  void initState() {
    super.initState();
    _conditionsController =
        TextEditingController(text: widget.initialConditions.join(', '));
    _historyController = TextEditingController(text: widget.previousHistory);
    _prakritiLabel = widget.prakriti;

    _generateGuideline();
    _loadPrescriptions();
    _loadPatientFromFirestore();
    _loadClinicInfoLocal();


    
    

    // subscribe to latest vikriti report for this patient (auto-updates UI)
    _vikritiSub = FirebaseFirestore.instance
        .collection('patients')
        .doc(widget.uid)
        .collection('reports')
        .orderBy('created_at', descending: true)
        .limit(1)
        .snapshots()
        .listen((snap) {
      if (snap.docs.isEmpty) return;
      final raw = snap.docs.first.data() as Map<String, dynamic>? ?? {};
      final vikriti = (raw['vikriti'] ?? {}) as Map<String, dynamic>;


      





      double parseDouble(dynamic x) {
        if (x == null) return 0.0;
        if (x is double) return x;
        if (x is int) return x.toDouble();
        final s = x.toString();
        return double.tryParse(s) ?? 0.0;
      }

      final v = parseDouble(vikriti['vata']);
      final p = parseDouble(vikriti['pitta']);
      final k = parseDouble(vikriti['kapha']);
      final dominant = vikriti['dominant']?.toString();
      final suggestions = (vikriti['suggested_conditions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      String parseTs(dynamic ts) {
  if (ts == null) return "";
  if (ts is Timestamp) return ts.toDate().toIso8601String();
  return ts.toString();
}

final ts = parseTs(vikriti['engine_timestamp'] ?? raw['created_at']);


      if (!mounted) return;
      setState(() {
        _vikritiVata = v;
        _vikritiPitta = p;
        _vikritiKapha = k;
        _vikritiDominant = dominant;
        _vikritiSuggestions = suggestions;
        _vikritiTimestamp = ts;
        if (vikriti['prakriti'] != null) _prakritiLabel = vikriti['prakriti'].toString();
          _cachedHerbalText = _herbalTextForPrakriti(_prakritiLabel);
      });
    }, onError: (e) {
      debugPrint('vikriti stream error: $e');
    });
    // --- generate and store latest diet plan in-memory for immediate UI update ---






    // If opened with autoExport, wait for first frame then trigger export.
if (widget.autoExport) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _openPdfPreview();
  });
}


  }


Map<String, dynamic> _prepareDietInputs() {
  return {
    "prakriti": _prakritiLabel,        // ✅ predicted prakriti
    "disease": _conditionsController.text,
    "allergy": widget.allergy.isEmpty ? "none" : widget.allergy,
    "region": widget.region,
  };
}


Map<String, int> deriveVikritiScoresFromPatientData({
  required int bowelNumeric,        // 1=constipation, 2=normal, 3=loose
  required int stressNumeric,       // 1=low, 2=moderate, 3=high
  required int sleepNumeric,        // 1=poor, 2=average, 3=good
  required int activityNumeric,     // 1=low, 2=moderate, 3=high
  required double bmi,
  required String allergies,
}) {
  int vata = 0;
  int pitta = 0;
  int kapha = 0;

  // ---- Bowel movement (Mala)
  if (bowelNumeric == 1) {
    vata += 3; // constipation
  } else if (bowelNumeric == 3) {
    pitta += 2; // loose
  } else {
    kapha += 1; // regular
  }

  // ---- Stress
  if (stressNumeric == 3) {
    vata += 2;
    pitta += 1;
  } else if (stressNumeric == 2) {
    vata += 1;
    pitta += 1;
  }

  // ---- Sleep
  if (sleepNumeric == 1) {
    vata += 2; // poor sleep
  } else if (sleepNumeric == 3) {
    kapha += 2; // deep sleep
  }

  // ---- Physical activity
  if (activityNumeric == 3) {
    vata += 1; // excessive movement
  } else if (activityNumeric == 1) {
    kapha += 2; // sedentary
  }

  // ---- BMI
  if (bmi >= 30) {
    kapha += 4;
  } else if (bmi >= 25) {
    kapha += 2;
    pitta += 1;
  } else if (bmi < 18.5) {
    vata += 2;
  }

  // ---- Allergies
  if (allergies.toLowerCase().contains("food") ||
      allergies.toLowerCase().contains("skin")) {
    pitta += 2;
  }

  return {
    "vata": vata,
    "pitta": pitta,
    "kapha": kapha,
  };
}



Future<void> _fetchDietFromBackend() async {
  setState(() => _loadingDiet = true);

  try {
    final response = await http.post(
      Uri.parse("http://127.0.0.1:5050/predict-diet"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(_prepareDietInputs()),
    );

    if (response.statusCode != 200) {
      throw Exception("Diet API failed");
    }

  final Map<String, dynamic> decoded =
    Map<String, dynamic>.from(jsonDecode(response.body));

final meals = _convertDietResponseToMeals(decoded);


    debugPrint("DIET RESPONSE: ${response.body}");
    debugPrint("MEALS FOR UI: $meals");

    if (!mounted) return;
setState(() {
  _latestDietPlan = decoded;
  _meals = meals;
  _latestDietPlan = _buildFinalDietPlan();


 _cachedPrognosisText = decoded['prognosis']?.toString();



});



  } catch (e) {
  debugPrint("Diet API error: $e");
  // ❌ DO NOT clear meals here
}

finally {
  if (mounted) {
    setState(() => _loadingDiet = false);
  }
}

  
}



Future<void> _fetchNutrients() async {
  setState(() => _loadingNutrients = true);

  try {
    final response = await http.post(
      Uri.parse("http://127.0.0.1:5050/predict-nutrients"),
      headers: {"Content-Type": "application/json"},
body: jsonEncode({
  "age": int.tryParse(widget.age) ?? 30,
  "gender": widget.gender,
  "height": height,
  "weight": weight,
  "prakriti": _prakritiLabel,
  "disease": _conditionsController.text,
}),


    );

    if (response.statusCode != 200) {
      throw Exception("Nutrient API failed");
    }

final Map<String, dynamic> decoded =
    Map<String, dynamic>.from(jsonDecode(response.body));

// 🔑 ADD THE DUMMY HERE
final merged = {
  ..._dummyMicros, // dummy micros
  ...decoded,      // ML macros
};

setState(() {
  _nutrients = merged;
});



  } catch (e) {
    debugPrint("Nutrient error: $e");
  } finally {
    setState(() => _loadingNutrients = false);
  }
}


  Future<void> _loadClinicInfoLocal() async {
    final sp = await SharedPreferences.getInstance();
    setState(() {
      clinicName = sp.getString("clinicName") ?? "AyuTech Clinic";
      clinicAddress = sp.getString("clinicAddress") ?? "Velachery";
      clinicEmail = sp.getString("clinicEmail") ?? "doc@gmail.com";
      clinicPhone = sp.getString("clinicPhone") ?? "7646178180";
    });
  }

  Widget _divider() {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: _primaryTeal.withOpacity(0.5),
    );
  }
  

  Future<void> _saveClinicInfoLocal({
    required String name,
    required String address,
    required String email,
    required String phone,
  }) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString("clinicName", name);
    await sp.setString("clinicAddress", address);
    await sp.setString("clinicEmail", email);
    await sp.setString("clinicPhone", phone);

    setState(() {
      clinicName = name;
      clinicAddress = address;
      clinicEmail = email;
      clinicPhone = phone;
    });
  }

  Future<void> _loadPrescriptions() async {
    final sp = await SharedPreferences.getInstance();

    final raw = sp.getStringList(_rxStoreKey) ?? const <String>[];
    final items = <Map<String, String>>[];
    for (final s in raw) {
      try {
        final m = jsonDecode(s);
        if (m is Map) {
          items.add(m.map((k, v) => MapEntry(k.toString(), v.toString())));
        }
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _prescriptions = items;
      });
    }
  }

  // Add Prescription
  void _addPrescription() async {
    final medicineController = TextEditingController();
    final dosageController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Prescription"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: medicineController,
                decoration: const InputDecoration(labelText: "Medicine"),
              ),
              TextField(
                controller: dosageController,
                decoration: const InputDecoration(labelText: "Dosage"),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                setState(() {
                  _prescriptions.add({
                    "medicine": medicineController.text,
                    "dosage": dosageController.text,
                  });
                });

                final sp = await SharedPreferences.getInstance();
                await sp.setStringList(
                  _rxStoreKey,
                  _prescriptions.map((rx) => jsonEncode(rx)).toList(),
                );

                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  // Edit Prescription
  void _editPrescription(int index) async {
    final medicineController = TextEditingController(text: _prescriptions[index]["medicine"]);
    final dosageController = TextEditingController(text: _prescriptions[index]["dosage"]);

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Prescription"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: medicineController, decoration: const InputDecoration(labelText: "Medicine")),
              TextField(controller: dosageController, decoration: const InputDecoration(labelText: "Dosage")),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                setState(() {
                  _prescriptions[index] = {
                    "medicine": medicineController.text,
                    "dosage": dosageController.text,
                  };
                });

                final sp = await SharedPreferences.getInstance();
                await sp.setStringList(
                  _rxStoreKey,
                  _prescriptions.map((rx) => jsonEncode(rx)).toList(),
                );

                Navigator.pop(context);
              },
              child: const Text("Update"),
            ),
          ],
        );
      },
    );
  }


  

  // Delete Prescription
  void _deletePrescription(int index) async {
    setState(() {
      _prescriptions.removeAt(index);
    });

    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(
      _rxStoreKey,
      _prescriptions.map((rx) => jsonEncode(rx)).toList(),
    );
  }

Future<void> _loadPatientFromFirestore() async {
  try {
    // get the signed-in user first
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint('No authenticated user - skipping loadPatientFromFirestore');
      return;
    }
    final userId = currentUser.uid;

    // fetch the patient doc under the current user's patients collection
    final docSnap = await FirebaseFirestore.instance
        .collection("users")
        .doc(userId)
        .collection("patients")
        .doc(widget.uid)
        .get();

    if (!docSnap.exists) return;
    final data = docSnap.data()!;

    if (!mounted) return;

    // parse disease field (could be List or String)
    String diseaseText = "";
    try {
      final diseaseRaw = data["disease"];
      if (diseaseRaw is List) {
        diseaseText = diseaseRaw.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).join(", ");
      } else if (diseaseRaw is String) {
        diseaseText = diseaseRaw;
      }
    } catch (_) {
      diseaseText = "";
    }

    // helper to parse numbers robustly
    double tryParseNum(dynamic x) {
      if (x == null) return 0.0;
      if (x is double) return x;
      if (x is int) return x.toDouble();
      return double.tryParse(x.toString()) ?? 0.0;
    }

    // safe parsing for nested List<List<double>> fields
    List<List<double>> parseNestedDoubleList(dynamic raw) {
      if (raw is! List) return [];
      try {
        return (raw as List).map<List<double>>((outer) {
          if (outer is List) {
            return outer.map<double>((v) {
              if (v is num) return v.toDouble();
              return double.tryParse(v.toString()) ?? 0.0;
            }).toList();
          }
          return <double>[];
        }).toList();
      } catch (e) {
        debugPrint('Failed to parse nested double list: $e');
        return [];
      }
    }



_patientStatus = data['status'] ?? 'ongoing';


    // parse prakritiResult using your snippet
    List<List<double>> parsedPrakritiResult = [];
    if (data["prakritiResult"] is List) {
      try {
        parsedPrakritiResult = (data["prakritiResult"] as List)
            .map<List<double>>((outer) {
          if (outer is List) {
            return outer.map<double>((v) {
              if (v is num) return v.toDouble();
              return double.tryParse(v.toString()) ?? 0.0;
            }).toList();
          }
          return <double>[];
        }).toList();
      } catch (e) {
        debugPrint('Failed to parse prakritiResult: $e');
        parsedPrakritiResult = [];
      }
    }

    final parsedDoshaResult = parseNestedDoubleList(data["doshaResult"]);
    final parsedNutrientTargets = parseNestedDoubleList(data["nutrientTargets"]);
    final parsedMealRankings = parseNestedDoubleList(data["mealRankings"]);

    double? parsedNutritionScore;
    if (data['nutrition_score'] != null) parsedNutritionScore = tryParseNum(data['nutrition_score']);

    // meals (if backend saved them)
    final parsedMeals = data['meals'] ?? [];

    // update state once
    setState(() {

      height = (data["heightCm"] ?? 0).toDouble();
weight = (data["weightKg"] ?? 0).toDouble();
bmi = (data["bmi"] ?? 0).toDouble();

dietaryHabits = data["dietary_habits"] ?? "";

sleepNumeric = int.tryParse(data["sleep_pattern_numeric"]?.toString() ?? "2") ?? 2;
bowelNumeric = int.tryParse(data["bowel_movement_numeric"]?.toString() ?? "2") ?? 2;
stressNumeric = int.tryParse(data["stress_levels"]?.toString() ?? "2") ?? 2;
activityNumeric = int.tryParse(data["physical_activity_numeric"]?.toString() ?? "2") ?? 2;
waterLitres = double.tryParse(data["water_intake_l"]?.toString() ?? "1.5") ?? 1.5;

final ageNum = int.tryParse(widget.age) ?? 30;
ageGroup =
    ageNum < 18 ? "Child" :
    ageNum < 30 ? "Young Adult" :
    ageNum < 50 ? "Adult" : "Senior";

      _conditionsController.text = diseaseText;
      _historyController.text = data["medicalHistory"] ?? "";
      _nextReviewDate = (data["nextReviewDate"] != null)
          ? DateTime.tryParse(data["nextReviewDate"].toString())
          : _nextReviewDate;

  

  setState(() {
  _prakritiLabel = data['prakriti']?.toString() ?? widget.prakriti;
  _cachedHerbalText = _herbalTextForPrakriti(_prakritiLabel);
});

if (_prakritiLabel != null && _prakritiLabel!.isNotEmpty) {
  _fetchDietFromBackend();
  _fetchNutrients();
}


      prakritiResult = parsedPrakritiResult;
      doshaResult = parsedDoshaResult;
      nutrientTargets = parsedNutrientTargets;
      mealRankings = parsedMealRankings;

      _nutritionScore = parsedNutritionScore ?? _nutritionScore;



      // optionally store meals for UI
      // ensure you declared `List<dynamic> _meals = []` in state
        if (_meals.isEmpty && parsedMeals is List && parsedMeals.isNotEmpty) {
  _meals = parsedMeals;
}


      // ✅ call APIs AFTER state is committed





    });

    // 🔥 NOW inputs are ready → call APIs

  } catch (e, st) {
    debugPrint("Error loading patient: $e\n$st");
  }





}





  /// Loads the latest saved vikriti report from:
  /// patients/{patientId}/reports (ordered by created_at desc)
  Future<void> _loadLatestVikritiReport() async {
    try {
      final q = await FirebaseFirestore.instance
          .collection('patients')
          .doc(widget.uid)
          .collection('reports')
          .orderBy('created_at', descending: true)
          .limit(1)
          .get();

      if (q.docs.isEmpty) {
        return;
      }

      final doc = q.docs.first.data() as Map<String, dynamic>;
      final vikriti = (doc['vikriti'] ?? {}) as Map<String, dynamic>;

      double parseDouble(dynamic x) {
        if (x == null) return 0.0;
        if (x is double) return x;
        if (x is int) return x.toDouble();
        final s = x.toString();
        return double.tryParse(s) ?? 0.0;
      }

      final v = parseDouble(vikriti['vata']);
      final p = parseDouble(vikriti['pitta']);
      final k = parseDouble(vikriti['kapha']);
      final dominant = vikriti['dominant']?.toString();
      final suggestions = (vikriti['suggested_conditions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
      final ts = vikriti['engine_timestamp']?.toString() ?? doc['created_at']?.toString();

      if (!mounted) return;
      setState(() {
        _vikritiVata = v;
        _vikritiPitta = p;
        _vikritiKapha = k;
        _vikritiDominant = dominant;
        _vikritiSuggestions = suggestions;
        _vikritiTimestamp = ts;
        

               if (vikriti['prakriti'] != null) {
          _prakritiLabel = vikriti['prakriti'].toString();
        }
        // update cached herbal text for UI/pdf
        _cachedHerbalText = _herbalTextForPrakriti(_prakritiLabel);


        _cachedHerbalText = _herbalTextForPrakriti(_prakritiLabel);
      });
    } catch (e) {
      debugPrint('Error loading latest vikriti report: $e');
    }
  }


/// Load a specific report by its document ID (used when coming from DiagnosisScreen)
Future<void> _loadReportById(String reportId) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('patients')
        .doc(widget.uid)
        .collection('reports')

        .doc(reportId)
        .get();

    if (!doc.exists) return;

    final raw = doc.data() as Map<String, dynamic>? ?? {};
    final vikriti = (raw['vikriti'] ?? {}) as Map<String, dynamic>;

    double toDouble(dynamic x) {
      if (x == null) return 0.0;
      if (x is double) return x;
      if (x is int) return x.toDouble();
      return double.tryParse(x.toString()) ?? 0.0;
    }

    String parseTs(dynamic ts) {
      if (ts == null) return '';
      if (ts is Timestamp) {
        return ts.toDate().toIso8601String();
      }
      return ts.toString();
    }

    if (!mounted) return;
    setState(() {
      _vikritiVata = toDouble(vikriti['vata']);
      _vikritiPitta = toDouble(vikriti['pitta']);
      _vikritiKapha = toDouble(vikriti['kapha']);
      _vikritiDominant = vikriti['dominant']?.toString();
      _vikritiSuggestions =
          (vikriti['suggested_conditions'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList();
      _vikritiTimestamp =
          parseTs(vikriti['engine_timestamp'] ?? raw['created_at']);
    });
  } catch (e) {
    print("Error loading specific report: $e");
  }
}

  

  void _generateGuideline() {
    currentGuideline = {
      "nutrition": {"Protein": "130g", "Carbs": "230g", "Fat": "30g"},
      "safety": [],
      "dietChart": [],
      "explainability": "",
      "seasonalNotes": "",
      "regionalNotes": "",
    };
  }

  @override
  void dispose() {
    _conditionsController.dispose();
    _vikritiSub?.cancel();
    _historyController.dispose();
    super.dispose();
  }

Map<String, dynamic> _buildFinalDietPlan() {
  return {
    "generatedAt": DateTime.now().toIso8601String(),
    "diagnosis": _conditionsController.text,
    "prakriti": _prakritiLabel,
    "vikriti": {
      "vata": _vikritiVata,
      "pitta": _vikritiPitta,
      "kapha": _vikritiKapha,
      "dominant": _vikritiDominant,
    },
    "meals": _meals,
    "nutrients": _nutrients ?? {},
    "safetyCheck":
        _safetyCheckByDiagnosis[_conditionsController.text.toLowerCase()] ?? [],
    "herbalFormulation": _cachedHerbalText ?? "",
    "prognosis": _cachedPrognosisText ?? "",
    "doctor": {
      "clinicName": clinicName,
      "clinicPhone": clinicPhone,
      "clinicEmail": clinicEmail,
    },
  };
}

  // ----------------------------
  // NEW: finalize treatment flow
  // ----------------------------


  /// Extracted export code used by the button and for autoExport


  final Map<String, List<String>> _safetyCheckByDiagnosis = {
  "fever": [
    "Avoid cold water and refrigerated foods",
    "Do not skip meals; prefer light, warm foods",
    "Avoid excessive physical exertion",
  ],
  "asthma": [
    "Avoid cold air exposure and dust",
    "Do not consume cold drinks or ice creams",
    "Avoid smoking and passive smoke",
    "Limit exposure to strong perfumes or pollutants",
  ],
  "diabetes": [
    "Avoid high-sugar foods and sweetened drinks",
    "Do not skip meals",
    "Monitor blood sugar regularly",
  ],
};
Widget _safetyCheckSection() {
  final diagnosis = (_conditionsController.text)
      .toLowerCase()
      .trim();

  final safetyList = _safetyCheckByDiagnosis[diagnosis];

  if (safetyList == null || safetyList.isEmpty) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          "No specific safety precautions available.",
          style: TextStyle(color: Colors.black54),
        ),
      ],
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: safetyList.map((item) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("⚠️  "),
            Expanded(
              child: Text(
                item,
                style: const TextStyle(fontSize: 15),
              ),
            ),
          ],
        ),
      );
    }).toList(),
  );
}


  @override
  Widget build(BuildContext context) {
    // calculate displayStart at top of build (was previously incorrectly inside widget tree)
    final displayStart = widget.startDate ?? DateTime.now();

    final nutrition = <String, String>{};
    if (currentGuideline["nutrition"] is Map) {
      (currentGuideline["nutrition"] as Map).forEach((key, value) {
        nutrition[key.toString()] = value.toString();
      });
    }

    return Scaffold(
      backgroundColor: _bgBody,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Start Date + Buttons
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, size: 20, color: Colors.black),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PatientHistoryScreen(
                          uid: widget.uid,
                          patients: const [],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Text(
                  "Start Date: ${DateFormat('d MMMM yyyy').format(displayStart)}",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                _smallAction("Edit", onPressed: () {}),
                const SizedBox(width: 8),
                _smallAction("Export PDF", onPressed: _openPdfPreview)



               
                
              ],
            ),

            const SizedBox(height: 16),
            _topSummaryCard(),
            const SizedBox(height: 20),

            // rest of your UI unchanged...
            const SizedBox(height: 20),
            // Micro + Safety side by side
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _sectionContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Micro and Macro Nutrients", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontFamily: 'Merriweather', color: _primaryTeal)),
                        const SizedBox(height: 12),

                        
// ---------- NUTRIENTS SECTION (FIXED) ----------


                      


_sectionContainer(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      
      const SizedBox(height: 12),

      // ✅ CORRECT CONDITIONAL RENDERING
if (_loadingNutrients)
  const SizedBox(
    width: 18,
    height: 18,
    child: CircularProgressIndicator(strokeWidth: 2),
  )
else if (_nutrients == null)
  const Text("No nutrient data available.")
else
  _buildNutrientsUI(_nutrients!),

    ],
  ),
),


                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 20),
               Expanded(
  child: _sectionContainer(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Safety Check",
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(
                fontFamily: 'Merriweather',
                color: _primaryTeal,
              ),
        ),
        const SizedBox(height: 12),

        _safetyCheckSection(),
      ],
    ),
  ),
),

              ],
            ),
            const SizedBox(height: 20),

            const SizedBox(height: 20),

            _sectionContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "AI-Generated Ayurvedic Analysis",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontFamily: 'Merriweather', color: _primaryTeal),
                  ),

                  const SizedBox(height: 20),

                  // ---- Simple prakriti label card (shows immediately if passed or saved) ----
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _prakritiLabel == null ? Colors.grey.shade100 : Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: _shadow, blurRadius: 6, offset: Offset(0,3))],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.health_and_safety, color: Colors.orange),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Predicted Prakriti: ${_prakritiLabel ?? 'Not available'}",
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (_prakritiLabel != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(_prakritiLabel!, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // PRAKRITI RESULT
             
                 

                  // DOSHA IMBALANCE RESULT
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text("Dosha Imbalance (Vikriti)",
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red)),
                          const SizedBox(width: 8),
                          if (_vikritiTimestamp != null)
                            Text("• ${_vikritiTimestamp!.split('T').first}", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        ]),
                        const SizedBox(height: 8),

                        // Dominant label
  
Text(
  "Dominant: ${_vikritiDominant ?? "Not available"}",
  style: const TextStyle(
    fontWeight: FontWeight.w600,
    color: Colors.black,
  ),
),
const SizedBox(height: 8),

Text("Vata: ${_vikritiVata.toStringAsFixed(1)}%"),
Text("Pitta: ${_vikritiPitta.toStringAsFixed(1)}%"),
Text("Kapha: ${_vikritiKapha.toStringAsFixed(1)}%"),


                        const SizedBox(height: 12),

                        // Progress bars
                     

                        // Suggested conditions, if available
                      
                      ],
                    ),
                  ),

                 
               

                  const SizedBox(height: 20),

                  // MEAL RANKINGS

                ],
              ),
            ),


            

            // Diet Chart
            _dietChartSection(),
            const SizedBox(height: 20),

            _sectionContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Row with Add button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Prescription", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontFamily: 'Merriweather', color: _primaryTeal)),
                      _actionButton("Add", onPressed: _addPrescription), // Global Add Button
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Show prescriptions list
                  ..._prescriptions.asMap().entries.map((entry) {
                    final index = entry.key;
                    final rx = entry.value;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left side card (medicine + dosage)
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(255, 244, 244, 244),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "Medicine: ${rx["medicine"]}\nDosage: ${rx["dosage"]}",
                                style: const TextStyle(fontSize: 17),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Right side Edit + Delete buttons
                          Column(
                            children: [
                              _smallAction("Edit", onPressed: () => _editPrescription(index), filled: false),

                              const SizedBox(height: 6),
                              _actionButton("Delete", onPressed: () {
                                _deletePrescription(index);
                              }),
                            ],
                          )
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Herbal + Prognosis
            Row(
              children: [
               Expanded(
  child: _sectionContainer(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Herbal Formulation",
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(
                fontFamily: 'Merriweather',
                color: _primaryTeal,
              ),
        ),
        const SizedBox(height: 12),

        // ✅ SHOW HERBAL CONTENT
        if (_cachedHerbalText == null || _cachedHerbalText!.isEmpty)
          const Text(
            "No herbal formulation available",
            style: TextStyle(color: Colors.black54),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F7F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _cachedHerbalText!,
              style: const TextStyle(
                fontSize: 15,
                height: 1.6,
              ),
            ),
          ),
      ],
    ),
  ),
),

              ],
            ),
            const SizedBox(height: 20),
            // Seasonal Notes
            Row(
              children: [
                Expanded(
                  child: _sectionContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Seasonal Recommendations",
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Merriweather',
                                color: _primaryTeal,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _cardSurface,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: _shadow, blurRadius: 6, offset: Offset(0,3))],
                          ),
                          child: Text(
                            getSeasonalRecommendation(DateTime.now()), // auto pick season
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF2C4A2C),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              color: _primaryTeal,

              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Doctor / Clinic Info (dummy for now)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Dr.John",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Velachery",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "doc@gmail.com | 7646178180",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  // Next Review Date
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _nextReviewDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => _nextReviewDate = picked);

                        // Update in Firestore
                        await FirebaseFirestore.instance.collection("patients").doc(widget.uid).update({
                          "nextReviewDate": picked.toIso8601String(),
                        });
                      }
                    },
                    child: Text(
                      "Next Review Date: ${_nextReviewDate != null ? "${_nextReviewDate!.day}/${_nextReviewDate!.month}/${_nextReviewDate!.year}" : "Select"}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }





Future<void> _openPdfPreview() async {
  if (_finalizing) return;
  setState(() => _finalizing = true);

  try {
    final dietPlan = _buildFinalDietPlan();

    final pdfBytes = await generatePatientReport(
      name: widget.name,
      age: widget.age,
      gender: widget.gender,
      region: widget.region,
      allergy: widget.allergy,
      history: widget.previousHistory,
      disease: _conditionsController.text,
      prakriti: _prakritiLabel ?? "",
      dietChart: dietPlan["meals"] ?? [],
      nutrients: dietPlan["nutrients"] ?? {},
      safetyNotes:
          (dietPlan["safetyCheck"] as List<dynamic>? ?? []).cast<String>(),
      prevention: "",
      herbal: dietPlan["herbalFormulation"] ?? "",
      prognosis: dietPlan["prognosis"] ?? "",
      seasonalRecommendations:
          getSeasonalRecommendation(DateTime.now()),
      prescriptions: _prescriptions,
      doctorName: clinicName,
      clinicName: clinicName,
      clinicAddress: clinicAddress,
      clinicEmail: clinicEmail,
      clinicPhone: clinicPhone,
      nextReviewDate: _nextReviewDate,
    );

    final dir = await getTemporaryDirectory();
    final file = File(
      "${dir.path}/Diet_Report_${widget.name}.pdf",
    );

    await file.writeAsBytes(pdfBytes, flush: true);

    // ✅ THIS OPENS THE PDF FILE
    await OpenFile.open(file.path);
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("PDF open failed: $e")),
    );
  } finally {
    setState(() => _finalizing = false);
  }
}

static const Map<String, num> _dummyMicros = {
  "calcium_mg": 1000,
  "iron_mg": 18,
  "sodium_mg": 1500,
  "vitamin_c_mg": 75,
};


List<Map<String, dynamic>> _convertDietResponseToMeals(
    Map<String, dynamic> decoded) {

  final List<Map<String, dynamic>> meals = [];

  void addMeal(String title, String key) {
    if (!decoded.containsKey(key)) return;

    final raw = decoded[key];

    if (raw is! List) return;

    final options = raw
        .whereType<Map<String, dynamic>>()
        .toList();

    if (options.isEmpty) return;

    meals.add({
      "meal_name": title,
      "options": options,
    });
  }

  addMeal("Breakfast", "breakfast_options");
  addMeal("Lunch", "lunch_options");
  addMeal("Evening Snack", "evening_options");
  addMeal("Dinner", "dinner_options");

  return meals;
}




  Widget _buildNutrientsUI(Map<String, dynamic> data) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _macroPill("Protein", "${data['protein_g'] ?? '—'} g", _lightGold),
            _macroPill("Fats", "${data['fat_g'] ?? '—'} g", _lightGold),
            _macroPill("Carbs", "${data['carbs_g'] ?? '—'} g", _lightGold),
            _macroPill("Fiber", "${data['fiber_g'] ?? '—'} g", _lightGold),
            _macroPill("Calories", "${data['calories'] ?? '—'}", _lightGold),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _microRow("Calcium", "${data['calcium_mg'] ?? '—'} mg"),
      const SizedBox(height: 6),
      _microRow("Iron", "${data['iron_mg'] ?? '—'} mg"),
      const SizedBox(height: 6),
      _microRow("Sodium", "${data['sodium_mg'] ?? '—'} mg"),
      const SizedBox(height: 6),
      _microRow("Vitamin C", "${data['vitamin_c_mg'] ?? '—'} mg"),
    ],
  );
}

Widget _dietChartSection() {
  if (_loadingDiet) {
    return _sectionContainer(
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  if (_meals.isEmpty) {
    return _sectionContainer(
      child: const Text("Diet not generated yet"),
    );
  }

  return Column(
    children: _meals.map((meal) {
      return _sectionContainer(
        child: _dietBlock(
          meal["meal_name"],
          List<Map<String, dynamic>>.from(meal["options"]),
        ),
      );
    }).toList(),
  );
}



  // ----- Herbal formulations mapping by prakriti -----
  final Map<String, List<Map<String, String>>> _herbalFormulations = {
    "VATA–PITTA": [
      {
        "title": "Brahmi–Shatavari Kashayam",
        "ingredients": "Brahmi 5g, Shatavari 5g, Guduchi 3g",
        "preparation": "Add herbs to 300 ml water; boil until reduced to 150 ml; filter & drink warm",
        "use": "Calming + cooling"
      },
      {
        "title": "Jatamansi–Licorice Churna",
        "ingredients": "Jatamansi 50g, Licorice 50g",
        "preparation": "Dry herbs, powder finely, store airtight",
        "use": "Balances Vata (mind) and Pitta (heat)"
      },
      {
        "title": "Cooling Medhya Ghrita",
        "ingredients": "Ghee 100ml, Brahmi paste 20g, Shatavari paste 20g",
        "preparation": "Heat ghee, add herb pastes, slow boil, filter & store",
        "use": "Nervous system + digestion support"
      },
    ],

    "VATA–KAPHA": [
      {
        "title": "Dry Ginger–Tulsi Kashayam",
        "ingredients": "Dry ginger 5g, Tulsi 5g, Black pepper 2g",
        "preparation": "Boil in 300 ml water; reduce to 150 ml; filter",
        "use": "Clears Kapha + calms Vata"
      },
      {
        "title": "Trikatu–Ashwagandha Churna",
        "ingredients": "Trikatu 20g, Ashwagandha 40g",
        "preparation": "Mix into fine powder",
        "use": "Improves metabolism + strengthens Vata"
      },
      {
        "title": "Dashamoola Tailam",
        "ingredients": "Dashamoola decoction + sesame oil (1:1)",
        "preparation": "Combine, heat until water evaporates, filter",
        "use": "Massage oil to reduce stiffness + Kapha congestion"
      },
    ],

    "PITTA–KAPHA": [
      {
        "title": "Neem–Guduchi Kashayam",
        "ingredients": "Neem 5g, Guduchi 5g, Musta 3g",
        "preparation": "Boil, reduce, filter",
        "use": "Detoxifying + reduces heat + Kapha"
      },
      {
        "title": "Triphala–Musta Churna",
        "ingredients": "Triphala 50g, Musta 30g",
        "preparation": "Powder + mix",
        "use": "Digestion + metabolic balance"
      },
      {
        "title": "Cooling Coriander–Cumin Water",
        "ingredients": "Coriander seeds 1 tsp, Cumin seeds 1 tsp",
        "preparation": "Boil seeds in 500 ml water, cool and filter",
        "use": "Pacifies both Pitta and Kapha"
      },
    ],

    "PURE VATA": [
      {
        "title": "Dashamoola–Bala Kashayam",
        "ingredients": "Dashamoola 10g, Bala 5g",
        "preparation": "Boil → reduce → filter",
        "use": ""
      },
      {
        "title": "Ashwagandha–Shatavari Churna",
        "ingredients": "Ashwagandha 50g, Shatavari 50g",
        "preparation": "Powder and store",
        "use": ""
      },
      {
        "title": "Warm Medicated Sesame Oil",
        "ingredients": "Sesame oil + Bala decoction",
        "preparation": "Cook together till water evaporates",
        "use": ""
      },
    ],

    "PITTA": [
      {
        "title": "Amalaki–Guduchi Kashayam",
        "ingredients": "Amalaki 10g, Guduchi 5g",
        "preparation": "Boil → reduce → filter",
        "use": ""
      },
      {
        "title": "Yashtimadhu (Licorice) Churna",
        "ingredients": "Licorice root powder",
        "preparation": "Dry → powder → store",
        "use": ""
      },
      {
        "title": "Cooling Ghee Infusion",
        "ingredients": "Ghee + Brahmi paste",
        "preparation": "Heat gently → filter",
        "use": ""
      },
    ],

    "KAPHA": [
      {
        "title": "Trikatu–Tulsi Kashayam",
        "ingredients": "Trikatu 5g, Tulsi 5g",
        "preparation": "Boil → reduce → filter",
        "use": ""
      },
      {
        "title": "Triphala–Dry Ginger Churna",
        "ingredients": "Triphala 50g, Dry ginger 10g",
        "preparation": "Mix powders",
        "use": ""
      },
      {
        "title": "Mustard Tailam",
        "ingredients": "Mustard oil + Pippali",
        "preparation": "Heat oil with Pippali → filter",
        "use": ""
      },
    ],
  };

  /// Returns a formatted multi-line string for the given prakriti label.
  /// Normalizes label to known keys (case-insensitive).
  String _herbalTextForPrakriti(String? prakriti) {
    if (prakriti == null || prakriti.trim().isEmpty) return "";
    final key = prakriti.trim().toUpperCase();

    // try to find exact key, else search contains (handles variants)
    List<Map<String,String>>? list = _herbalFormulations[key];
    if (list == null) {
      // try fuzzy matching (e.g. "Vata-Pitta" or "Vata Pitta")
      _herbalFormulations.forEach((k, v) {
        final norm = k.replaceAll(RegExp(r'[^A-Z]'), '');
        final test = key.replaceAll(RegExp(r'[^A-Z]'), '');
        if (norm == test) list = v;
      });
    }
    if (list == null) return "";

    final sb = StringBuffer();
    for (final item in list!) {
      sb.writeln("• ${item['title']}");
      if ((item['ingredients'] ?? "").isNotEmpty) sb.writeln("  Ingredients: ${item['ingredients']}");
      if ((item['preparation'] ?? "").isNotEmpty) sb.writeln("  Preparation: ${item['preparation']}");
      if ((item['use'] ?? "").isNotEmpty) sb.writeln("  Use: ${item['use']}");
      sb.writeln();
    }
    return sb.toString().trim();
  }

  // cached last herbal text to avoid recomputing repeatedly in widgets
  String? _cachedHerbalText;


  Widget _dietBlock(String title, List<Map<String, dynamic>> options) {
    // Collect notes only once (from the first option that has them)
    String nutrientNote = "";
    String ayurvedaEffect = "";

    for (final opt in options) {
      if (nutrientNote.isEmpty && (opt["nutrient_note"]?.toString().isNotEmpty ?? false)) {
        nutrientNote = opt["nutrient_note"].toString();
      }
      if (ayurvedaEffect.isEmpty && (opt["ayurveda_effect"]?.toString().isNotEmpty ?? false)) {
        ayurvedaEffect = opt["ayurveda_effect"].toString();
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bgBody,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meal Title Bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: _primaryTeal,
            child: Text(
              title.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Option titles
          for (int i = 0; i < options.length; i++) ...[
            Text("Option ${i + 1}", style: TextStyle(color: _primaryTeal, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            _optionCard(options[i]),
            const SizedBox(height: 12),
          ],
          if (nutrientNote.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text("NUTRIENT NOTE", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _primaryTeal)),
                  const SizedBox(height: 6),
                  Text(nutrientNote, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
          if (ayurvedaEffect.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text("AYURVEDIC NOTE", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _primaryTeal)),
                  const SizedBox(height: 6),
                  Text(ayurvedaEffect, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
        ],
      ),
    );
  }

Widget _optionCard(Map option) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _cardSurface,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: _shadow, blurRadius: 6, offset: Offset(0, 3))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ✅ FOOD NAME
        Text(
          option["name"] ?? "Food",
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),

        const SizedBox(height: 8),

        // ✅ INGREDIENTS
        if (option["ingredients"] != null)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: option["ingredients"]
                .toString()
                .split(",")
                .map((e) => _chipBadge(e.trim()))
                .toList(),
          ),

        const SizedBox(height: 10),

        // ✅ PREPARATION
        if (option["prep"] != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7F7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              option["prep"],
              style: const TextStyle(fontSize: 14),
            ),
          ),

        const SizedBox(height: 10),

        // ✅ NUTRITION ROW
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            _nutriText("🔥 kcal", option["kcal"]),
            _nutriText("🥩 Protein", option["protein"]),
            _nutriText("🥖 Carbs", option["carbs"]),
            _nutriText("🧈 Fat", option["fat"]),
            _nutriText("🌾 Fiber", option["fiber"]),
          ],
        ),

        const SizedBox(height: 8),

        // ✅ AYURVEDIC INFO
        if (option["rasa"] != null || option["virya"] != null)
          Text(
            "Ayurveda: ${option["rasa"] ?? ""} | ${option["virya"] ?? ""}",
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
      ],
    ),
  );
}
Widget _nutriText(String label, dynamic value) {
  if (value == null) return const SizedBox.shrink();
  return Text("$label: $value", style: const TextStyle(fontSize: 12));
}


  Widget _nutritionList(String nutritionText) {
    final nutritionMap = {"P": "Protein", "F": "Fat", "C": "Carbohydrates", "Fib": "Fiber", "Na": "Sodium", "kcal": "Calories"};

    final items = nutritionText.split(';').map((s) => s.trim()).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        if (item.isEmpty) return const SizedBox.shrink();

        for (final key in nutritionMap.keys) {
          if (item.startsWith(key)) {
            final value = item.split(':').last.trim();
            return Text("• ${nutritionMap[key]}: $value", style: const TextStyle(fontSize: 14));
          }
        }

        // fallback if no match
        return Text("• $item", style: const TextStyle(fontSize: 14));
      }).toList(),
    );
  }

  Widget _chipBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _lightPrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _lightPrimary),
      ),
      child: Text(text, style: TextStyle(fontSize: 12, color: _primaryTeal, fontWeight: FontWeight.w600)),
    );
  }

  Widget _sectionContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _cardSurface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: _shadow, blurRadius: 8, offset: Offset(0,4))],
      ),
      child: child,
    );
  }

  Widget _infoBox(String text, {Color color = Colors.white, Color textColor = Colors.black}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: _shadow, blurRadius: 6, offset: Offset(0,3))],
      ),
      child: Text(text, style: TextStyle(color: textColor, fontSize: 15, height: 1.4)),
    );
  }

  Widget _pillBox(String text, {Color bg = Colors.white}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: _shadow, blurRadius: 6, offset: Offset(0,3))],
      ),
      child: Text(text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _primaryTeal)),
    );
  }

  // compact action buttons (filled or outline)
  Widget _smallAction(String label, {VoidCallback? onPressed, bool filled = false}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(88, 36),
        backgroundColor: filled ? _primaryTeal : Colors.white,
        foregroundColor: filled ? Colors.white : _primaryTeal,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: filled ? BorderSide.none : BorderSide(color: _primaryTeal),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(label, style: const TextStyle(fontSize: 14)),
    );
  }

  Widget _patientCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardSurface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: _shadow, blurRadius: 8, offset: Offset(0,4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 26, backgroundColor: _bgBody, child: Icon(Icons.person, color: _primaryTeal)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _primaryTeal, fontFamily: 'Merriweather')),
              const SizedBox(height: 4),
              Text("${widget.age} Years • ${widget.gender}", style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 6),
              Row(children: [const Icon(Icons.location_on, size: 14, color: Colors.grey), const SizedBox(width: 6), Text(widget.region, style: const TextStyle(color: Colors.black54))]),
              const SizedBox(height: 6),
              Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: _bgBody, borderRadius: BorderRadius.circular(8)), child: Text("ACTIVE", style: TextStyle(color: _primaryTeal, fontWeight: FontWeight.w600))),
                const SizedBox(width: 8),
                if (_prakritiLabel != null)
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)), child: Text(_prakritiLabel!, style: TextStyle(color: Colors.orange.shade700))),
              ]),
            ],
          ),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text("BMI", style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: _bgBody, borderRadius: BorderRadius.circular(12)),
              child: Column(children: [Text("27.5", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _primaryTeal)), const Text("84 kg • 175 cm", style: TextStyle(color: Colors.black54))]),
            ),
          ]),
        ],
      ),
    );
  }

  // Keep old calls working: alias to the new smallAction
  Widget _actionButton(String label, {VoidCallback? onPressed}) {
    return _smallAction(label, onPressed: onPressed, filled: true);
  }

  Widget _macroPill(String title, String value, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: _shadow, blurRadius: 6, offset: Offset(0,3))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title.toUpperCase(), style: const TextStyle(fontSize:12, color:Color(0xFF3A3A3A))),
        const SizedBox(height:6),
        Text(value, style: const TextStyle(fontSize:18, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _microRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.black87)),
        Container(padding: const EdgeInsets.symmetric(horizontal:12, vertical:6), decoration: BoxDecoration(color: _bgBody, borderRadius: BorderRadius.circular(10)), child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold))),
      ],
    );
  }

  Widget _vikritiRow(String label, double value) {
    // Ensure value within 0.0..1.0
    final v = (value.isFinite ? value : 0.0).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('${(v * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(value: v, minHeight: 8),
      ],
    );
  }

  Widget _dietBlockCard(String title, List<Map<String, dynamic>> options) {
    // show up to 2 options in the same card (like your reference design)
    final displayed = options.isEmpty ? <Map<String, dynamic>>[] : options.take(2).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0F0F0)),
        boxShadow: [BoxShadow(color: _shadow, blurRadius: 8, offset: Offset(0,4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _lightPrimary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.restaurant_menu, size: 18, color: _primaryTeal),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _primaryTeal, fontFamily: 'Merriweather'))),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: _bgBody, borderRadius: BorderRadius.circular(12)),
                child: Text("${options.length} options", style: const TextStyle(color: Colors.black54, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // First option (if exists)
          if (displayed.isNotEmpty) ...[
            _optionCard(displayed[0]),
            const SizedBox(height: 10),
          ] else
            Center(child: Text("No options", style: TextStyle(color: Colors.black54))),

          // If we have a second option, show 'OR' between them and show both cal rows
          if (displayed.length > 1) ...[
            // calories/macros for option 1
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: _lightGold, borderRadius: BorderRadius.circular(10)),
                  child: Text("${displayed[0]['calories'] ?? ''} kcal", style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                const Spacer(),
                Row(
                  children: [
                    if ((displayed[0]['protein'] ?? "").toString().isNotEmpty) Text("P:${displayed[0]['protein']}", style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 8),
                    if ((displayed[0]['carbs'] ?? "").toString().isNotEmpty) Text("C:${displayed[0]['carbs']}", style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 8),
                    if ((displayed[0]['fat'] ?? "").toString().isNotEmpty) Text("F:${displayed[0]['fat']}", style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 8),

            // OR pill
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _bgBody,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text("OR", style: TextStyle(color: _primaryTeal, fontWeight: FontWeight.w700)),
              ),
            ),

            const SizedBox(height: 10),

            // second option
            _optionCard(displayed[1]),
            const SizedBox(height: 10),

            // calories/macros for option 2
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: _lightGold, borderRadius: BorderRadius.circular(10)),
                  child: Text("${displayed[1]['calories'] ?? ''} kcal", style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                const Spacer(),
                Row(
                  children: [
                    if ((displayed[1]['protein'] ?? "").toString().isNotEmpty) Text("P:${displayed[1]['protein']}", style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 8),
                    if ((displayed[1]['carbs'] ?? "").toString().isNotEmpty) Text("C:${displayed[1]['carbs']}", style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 8),
                    if ((displayed[1]['fat'] ?? "").toString().isNotEmpty) Text("F:${displayed[1]['fat']}", style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
          ] else if (displayed.isNotEmpty) ...[
            // only one option → show its calories/macros and an OR button on the right
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: _lightGold, borderRadius: BorderRadius.circular(10)),
                  child: Text("${displayed[0]['calories'] ?? ''} kcal", style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                const Spacer(),
                Row(
                  children: [
                    if ((displayed[0]['protein'] ?? "").toString().isNotEmpty) Text("P:${displayed[0]['protein']}", style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 8),
                    if ((displayed[0]['carbs'] ?? "").toString().isNotEmpty) Text("C:${displayed[0]['carbs']}", style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 8),
                    if ((displayed[0]['fat'] ?? "").toString().isNotEmpty) Text("F:${displayed[0]['fat']}", style: const TextStyle(fontSize: 12)),
                  ],
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    backgroundColor: _bgBody,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  ),
                  child: Text("OR", style: TextStyle(color: _primaryTeal)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Unified top summary card: app name, patient details, diagnosis/status/prakriti, BMI + actions
Widget _topSummaryCard() {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---------------- LEFT : Patient ----------------
        Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: _lightPrimary,
              child: Icon(Icons.person, size: 28, color: _primaryTeal),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.name.isEmpty ? "Patient" : widget.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${widget.age} Years • ${widget.gender}",
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(widget.region, style: const TextStyle(color: Colors.black54)),
                  ],
                ),
                const SizedBox(height: 6),
                if (_prakritiLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _prakritiLabel!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),

        const Spacer(),

        // ---------------- CENTER : Diagnosis ----------------
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              "DIAGNOSIS",
              style: TextStyle(
                fontSize: 12,
                color: Colors.black54,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _conditionsController.text.isEmpty
                  ? "—"
                  : _conditionsController.text,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F2EF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
  _patientStatus.toUpperCase(),
  style: TextStyle(
    color: _patientStatus == "treated"
        ? Colors.green
        : _patientStatus == "ended"
            ? Colors.grey
            : _primaryTeal,
    fontWeight: FontWeight.bold,
    fontSize: 12,
  ),
)

            ),
          ],
        ),

        const Spacer(),

        // ---------------- RIGHT : BMI ----------------
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _bgBody,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              const Text(
                "BMI",
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 6),
              Text(
                bmi.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _primaryTeal,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "${weight.toInt()} kg • ${height.toInt()} cm",
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}


  Future<void> _callAyuBackend() async {
  try {
    final url = Uri.parse("http://127.0.0.1:5000/predict_all");

    final payload = {
      "age_group": "young_adult",
      "gender": widget.gender.toLowerCase(),
      "stress_levels": "moderate",
      "physical_activity_levels": "light",
      "bmi": 22.0,
      "water_intake_l": "moderate",
      "bowel_movement_numeric": "normal",
      "allergies_food_env": widget.allergy.isNotEmpty ? "food" : "none",
      "agni": "sama",
      "skin_type_encoded": "dry",
      "body_temperature_encoded": "neutral",
      "sleep_pattern_encoded": "deep_sleep",
      "symptoms": "heat acidity burning"
    };

    final resp = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );

    if (resp.statusCode != 200) {
      print("Backend error: ${resp.body}");
      return;
    }

    final data = jsonDecode(resp.body);
    print("AI RESPONSE: $data");

    setState(() {
      _prakritiLabel = data["prakriti"];
      _vikritiDominant = data["vikriti"];
      _nutritionScore = double.tryParse(data["nutrition_score"].toString());
    });

    // Save to Firestore (important)
    await FirebaseFirestore.instance
        .collection("patients")
        .doc(widget.uid)
        .set({
      "prakriti": _prakritiLabel,
      "nutrition_score": _nutritionScore,
    }, SetOptions(merge: true));
  } catch (e) {
    print("API ERROR: $e");
  }
}

}

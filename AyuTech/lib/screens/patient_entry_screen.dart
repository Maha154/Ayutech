// lib/screens/patient_entry_screen.dart
// Visual redesign only — integrates AyuTech dashboard look for New Patient Entry
// IMPORTANT: No logic changes — only layout/styles.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ayutech/models/patient.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ayutech/screens/patient_report_screen.dart';


import 'package:http/http.dart' as http;
import 'package:ayutech/services/vikriti_dosha_calculator.dart';





// already in your file earlier

class AyuColors {
  static const teal = Color(0xFF2F5C56);
  static const darkTeal = Color(0xFF466643);
  static const cream = Color(0xFFFAFAF8);
  static const surface = Color(0xFFFFFFFF);
  static const mutedFill = Color(0xFFF8F4F4);
  static const gold = Color(0xFFD6A657);
  static const accent = Color(0xFF5C7A5C);
}

class PatientEntryScreen extends StatefulWidget {
  final Function(Patient) onSave;
  final String? doctorUid;
  final String? patientDocId;
  final Map<String, dynamic>? prefill;

  const PatientEntryScreen({
    super.key,
    required this.onSave,
    this.doctorUid,
    this.patientDocId,
    this.prefill,
  });





  @override
  State<PatientEntryScreen> createState() => _PatientEntryScreenState();
}

class _PatientEntryScreenState extends State<PatientEntryScreen> {
  final _formKey = GlobalKey<FormState>();

  // Personal controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _diseaseController = TextEditingController();
  final TextEditingController _historyController = TextEditingController();
  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // doctor-only controllers (some already present in original file)
  final TextEditingController _allergyController = TextEditingController();
  final TextEditingController _prescriberController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();

  // Height / Weight / BMI controllers (single declaration)
  final TextEditingController _heightController = TextEditingController(); // Height (cm)
  final TextEditingController _weightController = TextEditingController(); // Weight (kg)
  final TextEditingController _bmiController = TextEditingController();

  // Meals integration (one place only)
  // Replace this line:
// final api_service = ApiService(baseUrl: 'http://127.0.0.1:5000'); // for desktop
// With this (single, consistent ApiService instance used throughout this file):
// make sure this field is declared at class scope (inside _PatientEntryScreenState)



final List<String> _regionOptions = [
  "South India",
  "North India",
  "East India",
  "West India",
  "Central India",
  "International / Non-Indian",
];

String? _getNormalizedRegion() {
  if (_regionController.text.isEmpty) return null;

  for (final r in _regionOptions) {
    if (r.toLowerCase() == _regionController.text.toLowerCase()) {
      return r;
    }
  }
  return null;
}






  // --- Skin analysis ---
  String? _skinAnalysis;
  final List<String> _skinOptions = const [
    "Dry / Dehydrated",
    "Rough / Uneven Texture",
    "Thin / Transparent Skin",
    "Cracked / Flaky",
    "Cold to touch",
    "Sensitive / Easily Irritated",
    "Reddish / Flushed",
    "Warm to touch",
    "Acne / Moles / Freckles",
    "Oily / Greasy",
    "Smooth / Soft",
    "Thick / Plump",
    "Pale / Cool",
    "Normal (Clear & Balanced)",
  ];

  // Symptom severity, diet, sleep numeric
  String? _symptomSeverity;
  final TextEditingController _dietController = TextEditingController();
 

  String? _gender;
  final List<String> _diseases = [];

  String? _bowel;
  String? _waterIntake;
  DateTime? _startDate;
  DateTime? _dob;
  String _status = "Active";
  String? _physicalActivity;

  // Prediction UI & state
  bool _predicting = false;
  String? _aiPrakriti;
  
  
  String? _sleepPattern;


  // DOCTOR-only fields (these were present already as controllers)
  final TextEditingController _bowelCtl = TextEditingController();
  final TextEditingController _activityCtl = TextEditingController();
  final TextEditingController _waterCtl = TextEditingController();
  final TextEditingController _allergyCtl = TextEditingController();
  final TextEditingController _historyCtl = TextEditingController();
  final TextEditingController _predictedCtl = TextEditingController();
  final TextEditingController _descCtl = TextEditingController();
  final TextEditingController _heightCtl = TextEditingController();
  final TextEditingController _weightCtl = TextEditingController();

  final RegExp _emailRe = RegExp(r'^[\w\.\-]+@[\w\-]+\.[\w\-\.]+$');
  final RegExp _phoneRe = RegExp(r'^[0-9]{10,13}$');

  int sleepNumeric = 0;
int stressNumeric = 0;
int activityNumeric = 0;
int bowelMovementNumeric = 0;


  // Doctor mode flags
  bool _isDoctorMode = false;
  bool _loadingDoctorData = false;
  bool _saving = false;
  double? _heightCm;
  double? _weightKg;
  double? _bmiValue;
  String _computedBmi = "";
  String? _stressLevel;
  String? _agni;

  @override
  void dispose() {
    // dispose all controllers once
    _nameController.dispose();
    _ageController.dispose();
    _dobController.dispose();
    _diseaseController.dispose();
    _historyController.dispose();
    _regionController.dispose();
    _phoneController.dispose();
    _allergyController.dispose();
    _prescriberController.dispose();
    _startDateController.dispose();

    // remove listeners & dispose height/weight
    _heightController.removeListener(_recalcBmi);
    _weightController.removeListener(_recalcBmi);
    _bmiController.dispose();
    _heightController.dispose();
    _weightController.dispose();

    _dietController.dispose();
  

    _bowelCtl.dispose();
    _activityCtl.dispose();
    _waterCtl.dispose();
    _allergyCtl.dispose();
    _historyCtl.dispose();
    _predictedCtl.dispose();
    _descCtl.dispose();

    _heightCtl.dispose();
    _weightCtl.dispose();

    super.dispose();
  }

  void _normalizeRegionController() {
  if (_regionController.text.isEmpty) return;

  for (final r in _regionOptions) {
    if (r.toLowerCase() == _regionController.text.toLowerCase()) {
      _regionController.text = r; // normalize case
      return;
    }
  }

  _regionController.clear();
}


  @override
  void initState() {
    super.initState();

    _heightController.addListener(_recalcBmi);
    _weightController.addListener(_recalcBmi);
    _normalizeRegionController();

    if (widget.doctorUid != null && widget.patientDocId != null) {
      _isDoctorMode = true;
      _loadDoctorPatient();
    } else if (widget.prefill != null) {
      _applyPrefill(widget.prefill!);
    }
  }

  void _recalcBmi() {
    final h = double.tryParse(_heightController.text.trim());
    final w = double.tryParse(_weightController.text.trim());
    if (h != null && h > 0 && w != null) {
      final bmi = w / ((h / 100) * (h / 100));
      setState(() {
        _bmiValue = bmi;
        _computedBmi = bmi.toStringAsFixed(2);
        _bmiController.text = _computedBmi;
      });
    } else {
      setState(() {
        _bmiValue = null;
        _computedBmi = "";
        _bmiController.text = "";
      });
    }
  }







Map<String, dynamic> _preparePrakritiInputs() {
  return {
    "Height (cm)": double.parse(_heightController.text),
    "Weight (kg)": double.parse(_weightController.text),
    "BMI": _bmiValue ?? 0,

    // ✅ SEND STRINGS — EXACTLY as selected
   "Sleep Pattern_Numeric": _mapSleepToNumeric(_sleepPattern),

    "Stress Levels": _stressLevel ?? "No stress",
    "Physical Activity Levels": _physicalActivity ?? "Moderately active",

    "Water Intake (L)": _mapWaterToNumeric(_waterIntake),
    "Bowel Movement_Numeric": _mapBowelToNumeric(_bowel),

    "Allergies (Food/Env)": _allergyCtl.text.trim().isEmpty
        ? "none"
        : _allergyCtl.text.trim().toLowerCase(),
  };
}

Map<String, int> deriveVikritiScoresFromPatientData() {
  int vata = 0;
  int pitta = 0;
  int kapha = 0;

  // --- Bowel movement
  final bowel = _bowel?.toLowerCase() ?? "";
  if (bowel.contains("constipation")) {
    vata += 3;
  } else if (bowel.contains("loose") || bowel.contains("diarrhoea")) {
    pitta += 2;
  } else {
    kapha += 1;
  }

  // --- Stress
  final stress = _stressLevel?.toLowerCase() ?? "";
  if (stress.contains("high") || stress.contains("severe")) {
    vata += 2;
    pitta += 1;
  } else if (stress.contains("moderate")) {
    vata += 1;
    pitta += 1;
  }

  // --- Sleep
  final sleep = _sleepPattern?.toLowerCase() ?? "";
  if (sleep.contains("poor") || sleep.contains("disturbed")) {
    vata += 2;
  } else if (sleep.contains("deep") || sleep.contains("excessive")) {
    kapha += 2;
  }

  // --- Physical activity
  final activity = _physicalActivity?.toLowerCase() ?? "";
  if (activity.contains("sedentary")) {
    kapha += 2;
  } else if (activity.contains("very active") || activity.contains("athlete")) {
    vata += 1;
  }

  // --- BMI
  final bmi = _bmiValue ?? 0;
  if (bmi >= 30) {
    kapha += 4;
  } else if (bmi >= 25) {
    kapha += 2;
    pitta += 1;
  } else if (bmi < 18.5) {
    vata += 2;
  }

  // --- Allergy
  final allergy = _allergyCtl.text.toLowerCase();
  if (allergy.contains("skin") || allergy.contains("food")) {
    pitta += 2;
  }

  return {
    "vata": vata,
    "pitta": pitta,
    "kapha": kapha,
  };
}


bool get _canPredictPrakriti {
  return _heightController.text.isNotEmpty &&
      _weightController.text.isNotEmpty &&
      _sleepPattern != null &&
      _stressLevel != null &&
      _physicalActivity != null;
}


int _mapSleepToNumeric(String? sleep) {
  switch (sleep) {
    case "Deep sleep":
      return 3;
    case "Normal sleep":
      return 2;
    case "Light, broken sleep":
      return 1;
    default:
      return 2;
  }
}



int _mapStressToNumeric(String? v) {
  if (v == null) return 2;
  final s = v.toLowerCase();

  if (s.contains("no")) return 0;
  if (s.contains("mild")) return 1;
  if (s.contains("moderate")) return 2;
  if (s.contains("high")) return 3;
  return 2;
}


int _mapActivityToNumeric(String? v) {
  if (v == null) return 2;
  final s = v.toLowerCase();

  if (s.contains("sedentary")) return 0;
  if (s.contains("light")) return 1;
  if (s.contains("moderate")) return 2;
  if (s.contains("very")) return 3;
  return 2;
}


double _mapWaterToNumeric(String? v) {
  if (v == null) return 1.5;
  if (v.contains("<1")) return 0.8;
  if (v.contains("1–2")) return 1.5;
  if (v.contains("2–3")) return 2.5;
  if (v.contains(">3")) return 3.5;
  return 1.5;
}

int _mapBowelToNumeric(String? v) {
  if (v == null) return 2;
  final s = v.toLowerCase();

  if (s.contains("constipation")) return 0;
  if (s.contains("irregular")) return 1;
  if (s.contains("normal")) return 2;
  if (s.contains("loose")) return 3;
  return 2;
}


  Future<void> _loadDoctorPatient() async {
    setState(() => _loadingDoctorData = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.doctorUid)
          .collection('patients')
          .doc(widget.patientDocId)
          .get();
      final data = doc.data() ?? {};

      _nameController.text = (data['name'] ?? '').toString();
      _ageController.text = (data['age']?.toString() ?? '');
      _gender = (data['gender'] ?? _gender)?.toString();
      _heightController.text = (data['heightCm']?.toString() ?? '');
      _weightController.text = (data['weightKg']?.toString() ?? '');
      _heightCm = double.tryParse(_heightController.text);
      _weightKg = double.tryParse(_weightController.text);
      _agni = (data['agni'] ?? data['Agni'])?.toString();
      _stressLevel = (data['stressLevel'] ?? data['stress'] ?? data['Stress Levels'])?.toString();
      _skinAnalysis = (data['skinAnalysis'] ?? data['skin_analysis'])?.toString();



      _recalcBmi();

      if (data['dob'] != null) {
        final parsed = _parseDateField(data['dob']);
        if (parsed != null) {
          _dob = parsed;
          _dobController.text = _fmtDate(_dob);
        }
      }
      _phoneController.text = (data['phone'] ?? data['phoneNumber'] ?? data['contact'] ?? '').toString();
      if (data['startDate'] != null) {
        final parsed = _parseDateField(data['startDate']);
        if (parsed != null) {
          _startDate = parsed;
          _startDateController.text = _fmtDate(_startDate);
        }
      }
      _regionController.text = (data['region'] ?? '').toString();
      _normalizeRegionController(); // 🔥 THIS IS CRITICAL

      final diseasesFromDoc = data['disease'] ?? data['diseases'];
      if (diseasesFromDoc is List) {
        _diseases.clear();
        for (var d in diseasesFromDoc) {
          _diseases.add(d.toString());
        }
      }

      _bowelCtl.text = (data['bowelMovement'] ?? '').toString();
      _activityCtl.text = (data['physicalActivity'] ?? '').toString();
      _waterCtl.text = (data['waterIntake'] ?? '').toString();
      _allergyCtl.text = (data['allergy'] ?? '').toString();
      _historyCtl.text = (data['medicalHistory'] ?? '').toString();
      _predictedCtl.text = (data['predictedDisease'] ?? '').toString();
      _descCtl.text = (data['description'] ?? '').toString();

      _symptomSeverity = (data['symptomSeverity'] ?? data['symptom_severity'])?.toString();
      _dietController.text = (data['diet'] ?? '').toString();
     
    } catch (e) {
      debugPrint('Failed to load doctor patient: $e');
    } finally {
      if (mounted) setState(() => _loadingDoctorData = false);
    }
  }

  void _applyPrefill(Map<String, dynamic> p) {
    try {
      if (p['name'] != null) _nameController.text = p['name'].toString();
      if (p['phone'] != null) _phoneController.text = p['phone'].toString();
      if (p['contact'] != null && (_phoneController.text.isEmpty)) _phoneController.text = p['contact'].toString();
      if (p['heightCm'] != null) {
        _heightController.text = p['heightCm'].toString();
        _heightCm = double.tryParse(_heightController.text);
      }
      if (p['weightKg'] != null) {
        _weightController.text = p['weightKg'].toString();
        _weightKg = double.tryParse(_weightController.text);
      }

      if (p['age'] != null) {
        _ageController.text = p['age'].toString();
      } else if (p['dob'] != null && _dob == null) {
        final parsed = _parseDateField(p['dob']);
        if (parsed != null) {
          final years = DateTime.now().year - parsed.year;
          if (years > 0 && years < 120) _ageController.text = years.toString();
        }
      }
      if (p['gender'] != null) _gender = p['gender'].toString();

      if (p['region'] != null) _regionController.text = p['region'].toString();
      _normalizeRegionController();


      final sd = p['startDate'];
      final parsedStart = _parseDateField(sd);
      if (parsedStart != null) {
        _startDate = parsedStart;
        _startDateController.text = _fmtDate(_startDate);
      } else if (sd is String && sd.isNotEmpty) {
        _startDateController.text = sd.toString();
      }

      final db = p['dob'];
      final parsedDob = _parseDateField(db);
      if (parsedDob != null) {
        _dob = parsedDob;
        _dobController.text = _fmtDate(_dob);
      } else if (db is String && db.isNotEmpty) {
        _dobController.text = db.toString();
      }

      final diseasesFromPrefill = p['disease'] ?? p['diseases'];
      if (diseasesFromPrefill is List) {
        _diseases.clear();
        for (var d in diseasesFromPrefill) {
          _diseases.add(d.toString());
        }
      } else if (diseasesFromPrefill is String && diseasesFromPrefill.isNotEmpty) {
        final parts = diseasesFromPrefill.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        _diseases.clear();
        _diseases.addAll(parts);
      }

      if (p['bowelMovement'] != null) {
        _bowelCtl.text = p['bowelMovement'].toString();
        _bowel = _bowelCtl.text;
      }
      if (p['physicalActivity'] != null) {
        _activityCtl.text = p['physicalActivity'].toString();
        _physicalActivity = _activityCtl.text;
      }
      if (p['waterIntake'] != null) {
        _waterCtl.text = p['waterIntake'].toString();
        _waterIntake = _waterCtl.text;
      }
      if (p['allergy'] != null) {
        _allergyCtl.text = p['allergy'].toString();
      }
      if (p['medicalHistory'] != null) {
        _historyCtl.text = p['medicalHistory'].toString();
      }
      if (p['predictedDisease'] != null) {
        _predictedCtl.text = p['predictedDisease'].toString();
      }
      if (p['description'] != null) {
        _descCtl.text = p['description'].toString();
      }

      if (p['diet'] != null) {
        _dietController.text = p['diet'].toString();
      }
      if (p['symptom_severity'] != null) {
        _symptomSeverity = p['symptom_severity'].toString();
      }
     
      if (p['patientId'] != null && _prescriberController.text.isEmpty) {
        _prescriberController.text = p['patientId'].toString();
      }
    } catch (e) {
      debugPrint('Prefill apply failed: $e');
    } finally {
      if (mounted) setState(() {});
    }

    if (p['skinAnalysis'] != null) _skinAnalysis = p['skinAnalysis'].toString();
    else if (p['skin_analysis'] != null) _skinAnalysis = p['skin_analysis'].toString();
  }

  DateTime? _parseDateField(dynamic field) {
    if (field == null) return null;
    try {
      if (field is Timestamp) return field.toDate();
      if (field is DateTime) return field;
      if (field is String) {
        final s = field.toString();
        try {
          return DateTime.parse(s);
        } catch (_) {
          return null;
        }
      }
    } catch (_) {}
    return null;
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return "";
    return "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";
  }

  void _addDisease() {
    final value = _diseaseController.text.trim();
    if (value.isNotEmpty && !_diseases.contains(value)) {
      setState(() => _diseases.add(value));
      _diseaseController.clear();
    }
  }

  void _removeDisease(String disease) {
    setState(() => _diseases.remove(disease));
  }




Future<String> _savePatientToFirestore(
  Patient patient, {
  String? prakriti,
  required VikritiResult vikritiResult,
}) async {


    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final docRef = FirebaseFirestore.instance.collection("users").doc(uid).collection("patients").doc();

      final parsedHeight = double.tryParse(_heightController.text.trim());
      final parsedWeight = double.tryParse(_weightController.text.trim());

      // 1️⃣ Derive Vikriti scores from existing patient fields

// ---------------- VIKRITI CALCULATION ----------------



// ================= VIKRITI CALCULATION =================

// 1️⃣ Derive scores from existing patient fields



// 3️⃣ Build Firestore-ready Vikriti map
final vikritiMap = {
  "label": vikritiResult.vikritiLabel,
  "doshas": vikritiResult.doshasString,
  "percentages": vikritiResult.percentages,
  "dominant": vikritiResult.vikritiLabel,
  "vata": vikritiResult.percentages["Vata"],
  "pitta": vikritiResult.percentages["Pitta"],
  "kapha": vikritiResult.percentages["Kapha"],
  "engine_timestamp": DateTime.now().toIso8601String(),
};




      final data = {
        "name": patient.name,
        "age": patient.age,
        "gender": patient.gender,
        "disease": patient.diseases,
        "medicalHistory": patient.medicalHistory,
        "prescriber": patient.prescriber,
        "region": patient.region,
        "phoneNumber": patient.phoneNumber,
        "allergy": patient.allergy,
        "bowelMovement": patient.bowelMovement,
        "waterIntake": patient.waterIntake,
        "startDate": patient.startDate.toIso8601String(),
        "status": patient.status,



        "updatedAt": FieldValue.serverTimestamp(),
        "physicalActivity": _physicalActivity ?? "Not specified",
        "heightCm": parsedHeight,
        "weightKg": parsedWeight,
        "bmi": _bmiValue,
        "symptomSeverity": _symptomSeverity,
        "dietary_habits": _dietController.text.trim(),

        "sleep_pattern_numeric": _sleepPattern,


        "stress_levels": _stressLevel,
    

  

        


"prakriti": _aiPrakriti,



        "skinAnalysis": _skinAnalysis,
        "agni": _agni,
        if (prakriti != null) "prakriti": prakriti,
        


        "medical_history": _historyCtl.text.trim().isEmpty
    ? "none"
    : _historyCtl.text.trim().toLowerCase(),

      };

      await docRef.set(data);

      final reportRef = FirebaseFirestore.instance
    .collection("patients")
    .doc(docRef.id)
    .collection("reports")
    .doc();

await reportRef.set({
  "created_at": FieldValue.serverTimestamp(),

  "vikriti": {
    "label": vikritiResult.vikritiLabel,
    "doshas": vikritiResult.doshasString,
    "percentages": vikritiResult.percentages,

    // dominant dosha ONLY
    "dominant": vikritiResult.dominantOrder.first.name,

    // duplicated for report screen UI
    "vata": vikritiResult.percentages["Vata"],
    "pitta": vikritiResult.percentages["Pitta"],
    "kapha": vikritiResult.percentages["Kapha"],

    "engine_timestamp": DateTime.now().toIso8601String(),
  }
});

      return docRef.id;
    } catch (e) {
      debugPrint("❌ Firestore save error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save to Firestore: $e")),
      );
      rethrow;
    }
  }

  // --- NEW: Helper to format data for Python ---



  

Future<void> _runPrakritiPrediction() async {
  setState(() => _predicting = true);

  try {
    final payload = _preparePrakritiInputs(); // ✅ HERE

    final response = await http.post(
      Uri.parse("http://127.0.0.1:5050/predict-prakriti"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception("Prakriti prediction failed");
    }

    final data = jsonDecode(response.body);

    setState(() {
      _aiPrakriti = data["prakriti"];
    });
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Prakriti prediction failed")),
    );
  } finally {
    setState(() => _predicting = false);
  }
}


  

 // 🔥 STEP 1: Derive scores







  // ⬇️ KEEP EVERYTHING ELSE BELOW THIS


Future<void> _savePatient() async {
  if (!_formKey.currentState!.validate()) return;

  // 1️⃣ Derive Vikriti scores
  final scores = deriveVikritiScoresFromPatientData();

  // 2️⃣ Calculate Vikriti
  final VikritiResult vikritiResult =
      VikritiDoshaCalculator.calculate(
    vataScore: scores["vata"]!,
    pittaScore: scores["pitta"]!,
    kaphaScore: scores["kapha"]!,
  );

  final newPatient = Patient(
    name: _nameController.text.trim(),
    age: int.tryParse(_ageController.text.trim()) ?? 0,
    gender: _gender ?? "Not specified",
    diseases: _diseases,
    medicalHistory: _historyCtl.text.trim(),
    prescriber: _prescriberController.text.trim(),
    region: _regionController.text.trim(),
    phoneNumber: _phoneController.text.trim(),
    allergy: _allergyCtl.text.trim(),
    bowelMovement: _bowel ?? "Normal",
    waterIntake: _waterIntake ?? "1–2L",
    startDate: _startDate ?? DateTime.now(),
    status: _status,
    physicalActivity: _physicalActivity ?? "Not specified",
  );

  final docId = await _savePatientToFirestore(
    newPatient,
    prakriti: _aiPrakriti,
    vikritiResult: vikritiResult,
  );

  if (!mounted) return;

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => PatientReportScreen(
        uid: docId,
        name: newPatient.name,
        age: newPatient.age.toString(),
        gender: newPatient.gender,
        initialConditions: newPatient.diseases,
        previousHistory: newPatient.medicalHistory,
        region: newPatient.region,
        allergy: newPatient.allergy,
        phoneNumber: newPatient.phoneNumber,
        startDate: newPatient.startDate,
        prakriti: _aiPrakriti,
         autoExport: false,
      ),
    ),
  );
}



  void _clearForm() {
    _formKey.currentState!.reset();
    _nameController.clear();
    _ageController.clear();
    _dobController.clear();
    _diseaseController.clear();
    _historyController.clear();
    _regionController.clear();
    _phoneController.clear();
    _allergyController.clear();
    _prescriberController.clear();
    _bowel = null;
    _waterIntake = null;
    _startDate = null;
    _dob = null;
    _status = "Active";
    _physicalActivity = null;

    _symptomSeverity = null;
    _dietController.clear();
    
    _aiPrakriti = null;
    _skinAnalysis = null;

    setState(() {
      _gender = null;
      _diseases.clear();
      _bowelCtl.clear();
      _activityCtl.clear();
      _waterCtl.clear();
      _allergyCtl.clear();
      _historyCtl.clear();
      _predictedCtl.clear();
      _descCtl.clear();
      _heightController.clear();
      _weightController.clear();
      _computedBmi = "";
      _bmiController.clear();
      _symptomSeverity = null;
      _dietController.clear();
      
      _aiPrakriti = null;
     
    });
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      setState(() {
        _startDate = DateTime(picked.year, picked.month, picked.day);
        _startDateController.text = _fmtDate(_startDate);
      });
    }
  }

  Future<void> _pickDOB() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 30),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _dob = DateTime(picked.year, picked.month, picked.day);
        _dobController.text = _fmtDate(_dob);
      });
    }
  }

  // ------- UI building helpers -------
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int? maxLines,
    VoidCallback? onTap,
    bool readOnly = false,
    Widget? suffixIcon,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines ?? 1,
      onTap: onTap,
      readOnly: readOnly,
      onChanged: onChanged,
      style: const TextStyle(
        fontSize: 16,
        color: Colors.black87,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AyuColors.mutedFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: const TextStyle(
          fontSize: 16,
          color: Colors.grey,
        ),
      ),
    );
  }




Widget _buildDropdown<T>({
  required String hintText,
  required T? value,
  required List<DropdownMenuItem<T>> items,
  required void Function(T?) onChanged,
  String? Function(T?)? validator,
}) {
  return DropdownButtonFormField<T>(
    isExpanded: true,

    value: value,
    items: items,

    // 🔥 THIS IS THE FIX
    selectedItemBuilder: (context) {
      return items.map((item) {
        return Align(
          alignment: Alignment.centerLeft,
          child: Text(
            item.value.toString(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis, // 🔥 PREVENTS OVERFLOW
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
        );
      }).toList();
    },

    onChanged: onChanged,
    validator: validator,

    decoration: InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: AyuColors.mutedFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
  );
}


  Widget _buildFormField(String label, Widget field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        field,
      ],
    );
  }


  

  Widget _sidebarItem(IconData icon, String label, {bool active = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
        decoration: BoxDecoration(
          color: active ? AyuColors.teal.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 20),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String clinicName = "AyuTech Clinic";
    String clinicAddress = "Velachery";
    String clinicEmail = "doc@gmail.com";
    String clinicPhone = "7646178180";

    final size = MediaQuery.of(context).size;
    final contentWidth = size.width - 260;

    return Scaffold(
      backgroundColor: AyuColors.cream,
      body: SafeArea(
        child: Row(
          children: [
            Container(
              width: 260,
              color: AyuColors.teal,
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(color: AyuColors.gold, shape: BoxShape.circle),
                        child: const Center(child: Icon(Icons.local_hospital, color: Colors.white)),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text("AyuTech", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                          SizedBox(height: 2),
                          Text("DOCTOR PORTAL", style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 28),
                  _sidebarItem(Icons.grid_view, "Dashboard", active: true, onTap: () => Navigator.pop(context)),
                  const SizedBox(height: 8),
                  _sidebarItem(Icons.person_add_alt_1, "New Entry", onTap: null),
                  const SizedBox(height: 8),
                  _sidebarItem(Icons.local_hospital, "Ongoing Patient", onTap: null),
                  const SizedBox(height: 8),
                  _sidebarItem(Icons.folder_open, "Records", onTap: null),
                  const Spacer(),
                  Row(
                    children: [
                      CircleAvatar(radius: 20, backgroundColor: AyuColors.gold, child: const Text("DR", style: TextStyle(color: Colors.white))),
                      const SizedBox(width: 12),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                        Text("Dr. Sharma", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text("MD (Ayurveda)", style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ])
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 20, 28, 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.black87),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 8),
                        const Text("New Patient Entry", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const SizedBox(width: 16),
                        const Text("Fill in the details below", style: TextStyle(fontSize: 14, color: Colors.black54)),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                      child: Center(
                        child: Container(
                          width: contentWidth > 900 ? 920.0 : contentWidth - 40,
                          decoration: BoxDecoration(
                            color: AyuColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 18, offset: const Offset(0, 8)),
                            ],
                          ),
                          padding: const EdgeInsets.all(22),
                          child: _loadingDoctorData
                              ? const SizedBox(height: 320, child: Center(child: CircularProgressIndicator()))
                              : Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 8.0),
                                        child: Text("PERSONAL INFORMATION", style: TextStyle(letterSpacing: 1.2, color: Colors.grey)),
                                      ),

                                      

                                      // First row: Name, Age, Gender
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildFormField(
                                              'Full Name',
                                              _buildTextField(
                                                controller: _nameController,
                                                hintText: "e.g. Vikram Malhotra",
                                                validator: (v) => (v == null || v.isEmpty) ? "Name is required" : null,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 20),
                                          Expanded(
                                            child: _buildFormField(
                                              'Age',
                                              _buildTextField(
                                                controller: _ageController,
                                                hintText: "e.g. 45",
                                                keyboardType: TextInputType.number,
                                                validator: (v) {
                                                  if (v == null || v.trim().isEmpty) {
                                                    return "Age is required";
                                                  }
                                                  final n = int.tryParse(v.trim());
                                                  if (n == null) return "Enter a valid number";
                                                  if (n <= 0 || n > 120) {
                                                    return "Enter a realistic age (1–120)";
                                                  }
                                                  return null;
                                                },
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 20),
                                          Expanded(
                                            child: _buildFormField(
                                              'Gender',
                                              _buildDropdown<String>(
                                                hintText: "Male / Female",
                                                value: _gender,
                                               items: ["Male", "Female", "Other / Prefer not to say"]
.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                                                onChanged: (v) => setState(() => _gender = v),
                                                validator: (v) => v == null ? "Gender is required" : null,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 18),

                                      // Second row: DOB, Phone, Start Date
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildFormField(
                                              'DOB',
                                              GestureDetector(
                                                onTap: _pickDOB,
                                                child: AbsorbPointer(
                                                  child: _buildTextField(
                                                    controller: _dobController,
                                                    hintText: "Select date of birth",
                                                    readOnly: true,
                                                    suffixIcon: const Icon(Icons.calendar_today),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 20),
                                          Expanded(
                                            child: _buildFormField(
                                              'Contact Number',
                                              _buildTextField(
                                                controller: _phoneController,
                                                hintText: "Mobile",
                                                validator: (v) {
                                                  final t = (v ?? "").trim();
                                                  if (t.isEmpty) return "Provide phone or email";
                                                  final isPhone = _phoneRe.hasMatch(t);
                                                  final isEmail = _emailRe.hasMatch(t);
                                                  if (!isPhone && !isEmail) {
                                                    return "Invalid phone/email";
                                                  }
                                                  return null;
                                                },
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 20),
                                          Expanded(
                                            child: _buildFormField(
                                              'Start Date',
                                              GestureDetector(
                                                onTap: _pickStartDate,
                                                child: AbsorbPointer(
                                                  child: _buildTextField(
                                                    controller: _startDateController,
                                                    hintText: "Select start date",
                                                    readOnly: true,
                                                    suffixIcon: const Icon(Icons.calendar_today),
                                                    validator: (_) => _startDate == null ? "Please select start date" : null,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 18),






                                      // Third row: Region, Bowel, Activity
                                      Row(
                                        children: [
                                          Expanded(
  child: _buildFormField(
    'Region',
    _buildDropdown<String>(
      hintText: "Select region",
      value: _regionController.text.isEmpty ? null : _regionController.text,
      items: _regionOptions
          .map((r) => DropdownMenuItem(value: r, child: Text(r)))
          .toList(),
      onChanged: (v) {
        setState(() {
          _regionController.text = v ?? '';
        });
      },
    ),
  ),
),

                                          const SizedBox(width: 20),
                                          Expanded(
                                            child: _buildFormField(
                                              'Bowel Movement',
                                              _buildDropdown<String>(
                                                hintText: "Select bowel movement",
                                                value: _bowel ?? (_bowelCtl.text.isNotEmpty ? _bowelCtl.text : null),
                                                items: const [
                                                  DropdownMenuItem(value: "Severe constipation", child: Text("Severe constipation")),
                                                  DropdownMenuItem(value: "Mild / occasional constipation", child: Text("Mild / occasional constipation")),
                                                  DropdownMenuItem(value: "Irregular / alternating constipation & loose", child: Text("Irregular / alternating constipation & loose")),
                                                  DropdownMenuItem(value: "Normal, once daily", child: Text("Normal, once daily")),
                                                  DropdownMenuItem(value: "Loose / frequent", child: Text("Loose / frequent")),
                                                  DropdownMenuItem(value: "Diarrhoea / very watery stool", child: Text("Diarrhoea / very watery stool")),
                                                  
                                                ],
                                                onChanged: (v) {
                                                  setState(() {
                                                    _bowel = v;
                                                    _bowelCtl.text = v ?? '';
                                                  });
                                                },
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 20),
                                          Expanded(
                                            child: _buildFormField(
                                              'Physical Activity',
                                              _buildDropdown<String>(
                                                hintText: "Select physical activity",
                                                value: _physicalActivity ?? (_activityCtl.text.isNotEmpty ? _activityCtl.text : null),
                                                items: const [
                                                  DropdownMenuItem(value: "Sedentary (very little movement)", child: Text("Sedentary (very little movement)")),
                                                  DropdownMenuItem(value: "Lightly active (walking/household work)", child: Text("Lightly active (walking/household work)")),
                                                  DropdownMenuItem(value: "Moderately active (exercise 3–4 days/week)", child: Text("Moderately active (exercise 3–4 days/week)")),
                                                  DropdownMenuItem(value: "Very active (manual labour / sports)", child: Text("Very active (manual labour / sports)")),
                                                  DropdownMenuItem(value: "Athlete level (intense daily training)", child: Text("Athlete level (intense daily training)")),
                                                ],
                                                onChanged: (v) {
                                                  setState(() {
                                                    _physicalActivity = v;
                                                    _activityCtl.text = v ?? '';
                                                  });
                                                },
                                                validator: (v) => v == null ? "Please select physical activity" : null,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 18),

                                      // Fourth row: Water Intake, Allergy, Medical History
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildFormField(
                                              'Water Intake',
                                              _buildDropdown<String>(
                                                hintText: "Select water intake",
                                                value: _waterIntake ?? (_waterCtl.text.isNotEmpty ? _waterCtl.text : null),
                                                items: const [
                                                  DropdownMenuItem(value: "<1L", child: Text("<1L/day")),
                                                  DropdownMenuItem(value: "1–2L", child: Text("1–2L/day")),
                                                  DropdownMenuItem(value: "2–3L", child: Text("2–3L/day")),
                                                  DropdownMenuItem(value: ">3L", child: Text(">3L/day")),
                                                ],
                                                onChanged: (v) {
                                                  setState(() {
                                                    _waterIntake = v;
                                                    _waterCtl.text = v ?? '';
                                                  });
                                                },
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 20),
                                          Expanded(
                                            child: _buildFormField(
                                              'Allergies',
                                              _buildTextField(
                                                controller: _allergyCtl,
                                                hintText: "e.g. Peanuts, Dust",
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 20),
                                          Expanded(
                                            child: _buildFormField(
                                              'Medical History',
                                              _buildTextField(
                                                controller: _historyCtl,
                                                hintText: "Enter medical history",
                                                maxLines: 3,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 18),

                                      // NEW: Height, Weight, BMI
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildFormField(
                                              'Height (cm)',
                                              _buildTextField(
                                                controller: _heightController,
                                                hintText: "Height (cm)",
                                                keyboardType: TextInputType.number,
                                                onChanged: (_) => _recalcBmi(),
                                                validator: (v) {
                                                  if (v == null || v.trim().isEmpty) return null;
                                                  final n = double.tryParse(v.trim());
                                                  if (n == null || n <= 0) return "Enter valid height";
                                                  return null;
                                                },
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 20),
                                          Expanded(
                                            child: _buildFormField(
                                              'Weight (kg)',
                                              _buildTextField(
                                                controller: _weightController,
                                                hintText: "Weight (kg)",
                                                keyboardType: TextInputType.number,
                                                onChanged: (_) => _recalcBmi(),
                                                validator: (v) {
                                                  if (v == null || v.trim().isEmpty) return null;
                                                  final n = double.tryParse(v.trim());
                                                  if (n == null || n <= 0) return "Enter valid weight";
                                                  return null;
                                                },
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 20),
                                          Expanded(
                                            child: _buildFormField(
                                              'BMI (calculated)',
                                              TextFormField(
                                                controller: _bmiController,
                                                readOnly: true,
                                                decoration: InputDecoration(
                                                  hintText: "BMI",
                                                  filled: true,
                                                  fillColor: AyuColors.mutedFill,
                                                  border: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                    borderSide: BorderSide.none,
                                                  ),
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 18),

                                      // --- NEW ROW: Agni & Stress ---
// --- NEW ROW: Agni & Stress ---
Row(
  children: [
    Expanded(
      child: _buildFormField(
        'Agni',
        _buildDropdown<String>(
          hintText: "Select Agni",
          value: _agni,
          items: const [
            DropdownMenuItem(value: "Vishama (Irregular)", child: Text("Vishama (Irregular)")),
            DropdownMenuItem(value: "Tikshna (Sharp)", child: Text("Tikshna (Sharp)")),
            DropdownMenuItem(value: "Manda (Dull)", child: Text("Manda (Dull)")),
            DropdownMenuItem(value: "Sama (Balanced)", child: Text("Sama (Balanced)")),
            DropdownMenuItem(value: "Mixed (Manda/Vishama)", child: Text("Mixed (Manda/Vishama)")),
            DropdownMenuItem(value: "Mixed (Tikshna/Manda)", child: Text("Mixed (Tikshna/Manda)")),
            DropdownMenuItem(value: "Mixed (Tikshna/Vishama)", child: Text("Mixed (Tikshna/Vishama)")),
          ],
          onChanged: (v) => setState(() => _agni = v),
          validator: (v) => v == null ? "Required for AI" : null,
        ),
      ),
    ),
    const SizedBox(width: 20),
    Expanded(
      child: _buildFormField(
        'Stress Level',
        _buildDropdown<String>(
          hintText: "Select Stress",
          value: _stressLevel,
       items: const [
  DropdownMenuItem(value: "No stress", child: Text("No stress")),
  DropdownMenuItem(value: "Mild stress", child: Text("Mild stress")),
  DropdownMenuItem(value: "Moderate stress", child: Text("Moderate stress")),
  DropdownMenuItem(value: "High stress", child: Text("High stress")),
  DropdownMenuItem(value: "Severe / chronic stress", child: Text("Severe / chronic stress")),
],

          onChanged: (v) => setState(() => _stressLevel = v),
          validator: (v) => v == null ? "Required for AI" : null,
        ),
      ),
    ),
  ],
),

const SizedBox(height: 18),

// Skin Analysis (single full-width field)
_buildFormField(
  'Skin Analysis',
  _buildDropdown<String>(
    hintText: "Select skin analysis",
    value: _skinAnalysis,
    items: _skinOptions.map((s) => DropdownMenuItem<String>(value: s, child: Text(s))).toList(),
    onChanged: (v) => setState(() => _skinAnalysis = v),
    validator: (v) => v == null ? "Please select skin analysis" : null,
  ),
),


                                      const SizedBox(height: 18),

                                      // Symptom severity, diet, sleep
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildFormField(
                                              'Symptom Severity',
                                              _buildDropdown<String>(
                                                hintText: "Select severity",
                                                value: _symptomSeverity,
                                                items: const [
                                                  DropdownMenuItem(value: "High", child: Text("High")),
                                                  DropdownMenuItem(value: "Medium", child: Text("Medium")),
                                                  DropdownMenuItem(value: "Low", child: Text("Low")),
                                                ],
                                                onChanged: (v) => setState(() => _symptomSeverity = v),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 20),
                                          Expanded(
                                            child: _buildDropdown<String>(
  hintText: "Select dietary habit",
  value: _dietController.text.isEmpty ? null : _dietController.text,
  items: const [
    DropdownMenuItem(value: "Vegetarian", child: Text("Vegetarian")),
    DropdownMenuItem(value: "Vegan", child: Text("Vegan")),
    DropdownMenuItem(value: "Eggetarian", child: Text("Eggetarian")),
    DropdownMenuItem(value: "Non-vegetarian (regular)", child: Text("Non-vegetarian (regular)")),
    DropdownMenuItem(value: "Non-vegetarian (occasional)", child: Text("Non-vegetarian (occasional)")),
    DropdownMenuItem(value: "Satvic / light", child: Text("Satvic / light")),
    DropdownMenuItem(value: "High spicy / oily", child: Text("High spicy / oily")),
    DropdownMenuItem(value: "High sugar / sweets", child: Text("High sugar / sweets")),
    DropdownMenuItem(value: "Skips meals frequently", child: Text("Skips meals frequently")),
  ],
  onChanged: (v) => setState(() => _dietController.text = v ?? ''),
),

                                          ),
                                          const SizedBox(width: 20),
                                          Expanded(
                                            child: _buildFormField(
  'Sleep Pattern',
  _buildDropdown<String>(
    hintText: "Select sleep pattern",
    value: _sleepPattern,
    items: const [
      DropdownMenuItem(value: "Very poor / disturbed sleep", child: Text("Very poor / disturbed sleep")),
      DropdownMenuItem(value: "Light, broken sleep", child: Text("Light, broken sleep")),
      DropdownMenuItem(value: "Normal sleep", child: Text("Normal sleep")),
      DropdownMenuItem(value: "Deep, restful sleep", child: Text("Deep, restful sleep")),
      DropdownMenuItem(value: "Excessive sleep / very drowsy", child: Text("Excessive sleep / very drowsy")),
    ],
onChanged: (value) {
  setState(() {
    _sleepPattern = value;
  });
},




  ),
),

                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 18),

                                      // Predicted diseases + description
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                _buildFormField(
                                                  'Disease',
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: _buildTextField(controller: _diseaseController, hintText: "Enter predicted disease"),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      ElevatedButton(
                                                        onPressed: _addDisease,
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: AyuColors.accent,
                                                          foregroundColor: Colors.white,
                                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                        ),
                                                        child: const Text("Add"),
                                                      )
                                                    ],
                                                  ),
                                                ),
                                                if (_diseases.isNotEmpty) ...[
                                                  const SizedBox(height: 8),
                                                  Wrap(
                                                    spacing: 8,
                                                    runSpacing: 8,
                                                    children: _diseases
                                                        .map(
                                                          (d) => Chip(
                                                            label: Text(d),
                                                            deleteIcon: const Icon(Icons.close, size: 18),
                                                            onDeleted: () => _removeDisease(d),
                                                            backgroundColor: const Color(0xFFD1FAE5),
                                                            labelStyle: const TextStyle(color: Color(0xFF065F46)),
                                                          ),
                                                        )
                                                        .toList(),
                                                  ),
                                                ]
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 20),
                                          Expanded(
                                            child: _buildFormField(
                                              'Symptoms',
                                              _buildTextField(controller: _prescriberController, hintText: "Enter symptoms / doctor", maxLines: 3),
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 30),

                                      // action buttons
                                      Center(
                                        child: Column(
                                          children: [
                                            // Predict area
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                              ElevatedButton.icon(
  icon: _predicting
      ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        )
      : const Icon(Icons.analytics, color: Color.fromARGB(255, 250, 249, 249)), // <-- make icon white

  label: Text(
    _predicting
        ? 'Predicting...'
        : (_aiPrakriti == null ? 'Predict Prakriti' : 'Predicted: $_aiPrakriti'),
    style: const TextStyle(
      color: Color.fromARGB(255, 255, 255, 255),   // <-- MAKE TEXT WHITE
      fontWeight: FontWeight.w600,
    ),
  ),

  style: ElevatedButton.styleFrom(
    backgroundColor: AyuColors.accent, // Your green color
    foregroundColor: Colors.white,     // <-- Ensures ripple + icon default color
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(30),
    ),
  ),

  onPressed: _predicting ? null : _runPrakritiPrediction,
),



 const SizedBox(height: 12),
if (_aiPrakriti != null) ...[
  Card(
    elevation: 4,
    color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("AI Predicted Prakriti", style: TextStyle(fontWeight: FontWeight.w600)),
              Text(_aiPrakriti!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
            ],
          ),
         
        
        ],
      ),
    ),
  ),
  const SizedBox(height: 12),





]
   



  ],
   ),
                                            const SizedBox(height: 12),

                                            // Save & Clear row (unchanged logic)
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                ElevatedButton(
                                                  onPressed: _saving ? null : _savePatient,
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: AyuColors.accent,
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                  child: _saving
                                                      ? const SizedBox(
                                                          width: 90,
                                                          height: 18,
                                                          child: Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                                                        )
                                                      : const Text("Save & Continue"),
                                                ),
                                                const SizedBox(width: 12),
                                                OutlinedButton(
                                                  onPressed: _clearForm,
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: AyuColors.accent,
                                                    side: BorderSide(color: AyuColors.accent),
                                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                  child: const Text("Clear Form"),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(height: 18),
                                    ],
                                  ),
                                ),
                        ),
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
    }


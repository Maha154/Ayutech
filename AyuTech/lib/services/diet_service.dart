


// lib/services/diet_service.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Toggle debug logging here
const bool _kDebug = true;

/// 🔹 Load diet plans from Firestore
Future<List<Map<String, dynamic>>> loadDietPlans({
  String? disease,
  String? region,
}) async {
  try {
    debugPrint("🔄 Fetching filtered diet plans from Firestore...");
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection("dietPlans");

    // ✅ Apply filters directly in Firestore
    if (disease != null && disease.isNotEmpty) {
      query = query.where("primary_disease", isEqualTo: disease.toLowerCase());
    }
    if (region != null && region.isNotEmpty) {
      query = query.where("patient_region", isEqualTo: region.toLowerCase());
    }

    final snapshot = await query.get();

    final allPlans = snapshot.docs.map((doc) {
      return Map<String, dynamic>.from(doc.data());
    }).toList();

    debugPrint("📦 Filtered diet plans fetched: ${allPlans.length}");
    return allPlans;
  } catch (e, st) {
    debugPrint("❌ Error loading diet plans: $e\n$st");
    return [];
  }
}


/// Normalize helper
String _norm(dynamic v) => v?.toString().toLowerCase().trim() ?? "";

/// 🔹 Filter plans based on patient details and build full diet chart rows
Map<String, dynamic> filterPlans(
  List<Map<String, dynamic>> allPlans, {
  required String disease,
  required int age,
  required String history,
  required String condition,
  required Set<String> allergens,
  required String region,
}) {
  final normDisease = disease.toLowerCase().trim();
  final normRegion = region.toLowerCase().trim();
  final normHistory = history.toLowerCase().trim();
  final lowerAllergens = allergens.map((e) => e.toLowerCase().trim()).toList();

  final rows = <Map<String, String>>[];
  final safetyNotes = <String>{};
  Map<String, dynamic>? matchedPlan; // ✅ store the first valid match

  for (final row in allPlans) {
    final rowPrimary = _norm(row["primary_disease"]);
    final rowStd = _norm(row["disease_name_standardized"]);
    final rowSymptoms = _norm(row["disease_symptoms"]);
    final rowRegion = _norm(row["patient_region"]);
    final rowAgeStr = row["patient_age"]?.toString() ?? "";
    final rowAgeCategory = _norm(row["age_category"]);
    final rowPrimaryAllergy = _norm(row["primary_allergy"]);
    final rowDiseaseAllergies = _norm(row["disease_allergies"]);
    final rowMedicalHistory =
        (_norm(row["medical_history"]) + " " + _norm(row["medical_intervention"])).trim();
    final safetyNote = row["safety_recommendations"]?.toString() ?? "";

    // --- Disease match
    bool diseaseMatch = normDisease.isEmpty;
    if (!diseaseMatch && normDisease.isNotEmpty) {
      final diseaseTokens = normDisease.split(RegExp(r'[\s,]+'));
      final rowText = "$rowPrimary $rowStd $rowSymptoms $rowMedicalHistory";
      diseaseMatch = diseaseTokens.any((t) => rowText.contains(t));
    }

    // --- Age match
    bool ageMatch = false;
    if (age == 0) {
      ageMatch = true;
    } else if (rowAgeStr.isNotEmpty) {
      final parsed = int.tryParse(rowAgeStr);
      if (parsed != null && parsed == age) ageMatch = true;
    }
    if (!ageMatch && rowAgeCategory.isNotEmpty) {
      final group = _ageGroup(age);
      ageMatch = rowAgeCategory.contains(group);
    }

    // --- History match
    bool historyMatch = true;
    if (normHistory.isNotEmpty && normHistory != "no history") {
      final historyTokens = normHistory.split(RegExp(r'[\s,]+'));
      historyMatch = historyTokens.any((t) => rowMedicalHistory.contains(t));
    }

    // --- Region match
    bool regionMatch = normRegion.isEmpty;
    if (!regionMatch) {
      final regionTokens = normRegion.split(RegExp(r'[\s,()]+'));
      regionMatch = regionTokens.any((t) => rowRegion.contains(t));
    }

    // --- Allergy safety
    bool allergenSafe = true;
    if (lowerAllergens.isNotEmpty) {
      final combinedAllergyFields =
          "$rowPrimaryAllergy $rowDiseaseAllergies $rowMedicalHistory";
      for (final allergen in lowerAllergens) {
        if (combinedAllergyFields.contains(allergen)) {
          allergenSafe = false;
          break;
        }
      }
    }

    // --- If all conditions match, collect
    if (diseaseMatch && ageMatch && historyMatch && regionMatch && allergenSafe) {
      matchedPlan ??= row; // ✅ store the first matching row

      if (safetyNote.isNotEmpty) safetyNotes.add(safetyNote);

      void addMeal(String mealLabel, dynamic option) {
        final opt = option?.toString();
        if (opt != null && opt.trim().isNotEmpty) {
          rows.add({
            "meal": mealLabel,
            "food_item": opt,
            "nutrient_note": row["nutrient_note"]?.toString() ?? "N/A",
            "ayurveda_effect": row["ayurveda_effect"]?.toString() ?? "N/A",
          });
        }
      }

      addMeal("Breakfast", row["breakfast_option1"]);
      addMeal("Breakfast", row["breakfast_option2"]);
      addMeal("Lunch", row["lunch_option1"]);
      addMeal("Lunch", row["lunch_option2"]);
      addMeal("Evening", row["evening_option1"]);
      addMeal("Evening", row["evening_option2"]);
      addMeal("Dinner", row["dinner_option1"]);
      addMeal("Dinner", row["dinner_option2"]);
    }
  }

  final plan = matchedPlan ?? {}; // fallback

  return {
    "dietChart": rows,
    "safetyNotes": safetyNotes.toList(),

    // ✅ Nutrients
    "calories": plan["total_calories"]?.toString() ?? "",
    "protein_g": plan["protein_g"]?.toString() ?? "",
    "fat_g": plan["fat_g"]?.toString() ?? "",
    "carbs_g": plan["carbs_g"]?.toString() ?? "",
    "fiber_g": plan["fiber_g"]?.toString() ?? "",
    "sodium_mg": plan["sodium_mg"]?.toString() ?? "",
    "calcium_mg": plan["calcium_mg"]?.toString() ?? "",
    "iron_mg": plan["iron_mg"]?.toString() ?? "",
    "vitamin_c_mg": plan["vitamin_c_mg"]?.toString() ?? "",

    // ✅ Extra mappings
    "prevention_measures": plan["prevention_measures"]?.toString() ?? "",
    "herbal_formulation": plan["herbal_formulation"]?.toString() ?? "",
    "prognosis": plan["prognosis"]?.toString() ?? "",
  };
}
String getSeasonalRecommendation(DateTime date) {
  final month = date.month;
  final day = date.day;

  if ((month == 1 && day >= 15) || month == 2 || (month == 3 && day < 15)) {
    return "❄️ Shishira (Late Winter): Favor warm, oily foods, sesame, jaggery, and ginger. Avoid excessive cold and dry foods.";
  } else if ((month == 3 && day >= 15) || month == 4 || (month == 5 && day < 15)) {
    return "🌸 Vasanta (Spring): Favor light, dry foods, barley, honey, and green vegetables. Avoid heavy, oily, and dairy-rich foods.";
  } else if ((month == 5 && day >= 15) || month == 6 || (month == 7 && day < 15)) {
    return "☀️ Grishma (Summer): Favor cooling foods like cucumber, watermelon, and buttermilk. Avoid spicy and salty foods.";
  } else if ((month == 7 && day >= 15) || month == 8 || (month == 9 && day < 15)) {
    return "🌧 Varsha (Rainy Season): Favor easily digestible warm foods like rice, ghee, and soups. Avoid raw salads and excessive oily foods.";
  } else if ((month == 9 && day >= 15) || month == 10 || (month == 11 && day < 15)) {
    return "🍂 Sharad (Autumn): Favor cooling foods like cucumber, pomegranate, and ghee in moderation. Avoid spicy, oily foods.";
  } else {
    return "❄️ Hemanta (Early Winter): Favor heavy, oily, and sweet foods like milk, ghee, and wheat. Avoid light and dry foods.";
  }
}







/// 🔹 Helper to classify age into groups (custom ranges)
String _ageGroup(int age) {
  if (age >= 1 && age <= 10) return "kid";
  if (age >= 11 && age <= 20) return "teen";
  if (age >= 21 && age <= 40) return "adult";
  if (age >= 41 && age <= 80) return "elderly";
  return "other"; // fallback if age is outside these ranges
}


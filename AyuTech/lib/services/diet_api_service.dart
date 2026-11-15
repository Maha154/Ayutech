import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/diet_response.dart';


class DietApiService {
static const String baseUrl = "http://127.0.0.1:5050";

  static Future<Map<String, List<MealOption>>> predictDiet() async {
    final response = await http.post(
      Uri.parse("$baseUrl/predict-diet"),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "primary_disease": "Diabetes",
        "Dietary Habits": "Vegetarian",
        "Age Group": "36–45 years",
        "Gender": "Male",
        "Height (cm)": 170,
        "Weight (kg)": 72,
        "BMI": 24.9,
        "Sleep Pattern_Numeric": 3,
        "Bowel Movement_Numeric": 4,
        "Stress Levels": 3,
        "Physical Activity Levels": 3,
        "Water Intake (L)": 2.5,
        "region": "South India"
      }),
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to fetch diet plan");
    }

    final data = jsonDecode(response.body);

    return {
      "breakfast": (data['breakfast_options'] as List)
          .map((e) => MealOption.fromJson(e))
          .toList(),
      "lunch": (data['lunch_options'] as List)
          .map((e) => MealOption.fromJson(e))
          .toList(),
      "dinner": (data['dinner_options'] as List)
          .map((e) => MealOption.fromJson(e))
          .toList(),
    };
  }
}

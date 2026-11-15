import 'package:flutter/material.dart';
import '../services/diet_api_service.dart';
import '../models/diet_response.dart';

class DietScreen extends StatefulWidget {
  const DietScreen({super.key});

  @override
  State<DietScreen> createState() => _DietScreenState();
}

class _DietScreenState extends State<DietScreen> {
  late Future<Map<String, List<MealOption>>> dietFuture;

  @override
  void initState() {
    super.initState();
    dietFuture = DietApiService.predictDiet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI Diet Chart")),
      body: FutureBuilder(
        future: dietFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }

          final meals = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              buildSection("Breakfast", meals['breakfast']!),
              buildSection("Lunch", meals['lunch']!),
              buildSection("Dinner", meals['dinner']!),
            ],
          );
        },
      ),
    );
  }

  Widget buildSection(String title, List<MealOption> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...items.map((meal) => Card(
              child: ListTile(
                title: Text(meal.name),
                subtitle: Text(
                    "${meal.kcal} kcal | P:${meal.protein} C:${meal.carbs} F:${meal.fat}"),
              ),
            )),
        const SizedBox(height: 16),
      ],
    );
  }
}

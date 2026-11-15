import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<List<int>> generatePatientReport({
  required String name,
  required String age,
  required String gender,
  required String region,
  required String allergy,
  required String history,

  String? disease,
  String? prakriti,

  required List<dynamic> dietChart,
  required Map<String, dynamic> nutrients,
  required List<String> safetyNotes,
  required String prevention,
  required String herbal,
  required String prognosis,
  required List prescriptions,
  required String seasonalRecommendations,
  required String doctorName,
  required String clinicName,
  required String clinicAddress,
  required String clinicEmail,
  required String clinicPhone,
  DateTime? nextReviewDate,
}) async {
  final pdf = pw.Document();

String cleanText(String text) {
  return text
      // remove common checkbox & symbols
      .replaceAll(RegExp(r'[☒☑☐✓✔✘]'), '')
      // remove ANY remaining non-ASCII characters
      .replaceAll(RegExp(r'[^\x00-\x7F]'), '')
      // clean spacing
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}



  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (context) => [

        // ================= HEADER =================
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              clinicName,
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green900,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(clinicAddress),
            pw.Text("$clinicEmail | $clinicPhone"),
            pw.Divider(thickness: 2),
          ],
        ),

        pw.SizedBox(height: 10),

        pw.Text(
          "Patient Report",
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),

        pw.SizedBox(height: 8),

        pw.Row(
          children: [
            pw.Text("Disease: ",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(disease?.isNotEmpty == true ? disease! : "Not specified"),
          ],
        ),

        pw.SizedBox(height: 4),

        pw.Row(
          children: [
            pw.Text(
              "Prakriti: ",
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.orange800,
              ),
            ),
            pw.Text(
              prakriti?.isNotEmpty == true ? prakriti! : "Not assessed",
              style: pw.TextStyle(color: PdfColors.orange800),
            ),
          ],
        ),

        pw.SizedBox(height: 10),

        pw.Table.fromTextArray(
          headers: ["Name", "Age", "Gender", "Region", "Allergy", "History"],
          data: [
            [
              name,
              age,
              gender,
              region,
              allergy,
              history.isNotEmpty ? history : "None"
            ]
          ],
        ),

        pw.SizedBox(height: 20),

        // ================= NUTRIENTS =================
        pw.Text(
          "Micro & Macro Nutrients",
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),

        pw.SizedBox(height: 8),

        if (nutrients.isEmpty)
          pw.Text("No nutrient data available")
        else
          pw.Wrap(
            spacing: 10,
            runSpacing: 8,
            children: nutrients.entries
                .map(
                  (e) => pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.green),
                    ),
                    child: pw.Text("${e.key}: ${e.value ?? ''}"),
                  ),
                )
                .toList(),
          ),

        pw.SizedBox(height: 24),

        // ================= DIET CHART =================
        pw.Text(
          "Diet Chart",
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),

        pw.SizedBox(height: 10),

        if (dietChart.isEmpty)
          pw.Text("No diet chart available.")
        else
          ...dietChart.map((meal) {
            final mealName = meal["meal_name"] ?? "Meal";
            final options = (meal["options"] as List?) ?? [];

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(8),
                  color: PdfColors.green100,
                  child: pw.Text(
                    mealName.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green900,
                    ),
                  ),
                ),

                pw.SizedBox(height: 8),

                ...options.asMap().entries.map((entry) {
                  final index = entry.key;
                  final opt = entry.value as Map<String, dynamic>;

                  return pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 12),
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [

                        // OPTION TITLE
                        pw.Text(
                          "Option ${index + 1}: ${opt['name'] ?? ''}",
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold),
                        ),

                        pw.SizedBox(height: 6),

                        // INGREDIENTS
                        if (opt['ingredients'] != null)
                          pw.Text(
                            "Ingredients: ${opt['ingredients']}",
                          ),

                        pw.SizedBox(height: 4),

                        // PREPARATION / STEPS
                        if (opt['prep'] != null)
                          pw.Text(
                            "Preparation: ${opt['prep']}",
                          ),

                        pw.SizedBox(height: 6),

                        // NUTRITION LINE
                        pw.Text(
                          "Nutrition: "
                          "Kcal ${opt['kcal'] ?? '-'}, "
                          "Protein ${opt['protein'] ?? '-'}, "
                          "Carbs ${opt['carbs'] ?? '-'}, "
                          "Fat ${opt['fat'] ?? '-'}, "
                          "Fiber ${opt['fiber'] ?? '-'}",
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  );
                }).toList(),



                pw.SizedBox(height: 14),
              ],
            );
          }).toList(),

        pw.SizedBox(height: 30),


        pw.SizedBox(height: 120),

// ================= HERBAL FORMULATION =================
pw.Text(
  "Herbal Formulation",
  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
),

pw.SizedBox(height: 10),

pw.Text(
  herbal.isNotEmpty
      ? cleanText(herbal)
      : "No herbal formulation prescribed.",
),



pw.SizedBox(height: 24),

// ================= PRESCRIPTION =================
pw.Text(
  "Prescription",
  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
),

pw.SizedBox(height: 8),

if (prescriptions.isEmpty)
  pw.Text("No medicines prescribed.")
else
  pw.Table.fromTextArray(
    headers: ["Medicine", "Dosage"],
    data: prescriptions
        .map(
          (rx) => [
            (rx["medicine"] ?? "").toString(),
            (rx["dosage"] ?? "").toString(),
          ],
        )
        .toList(),
  ),

 pw.SizedBox(height: 430),

        // ================= FOOTER =================
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(12),
          color: PdfColors.green,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("Doctor: $doctorName",
                  style: const pw.TextStyle(color: PdfColors.white)),
              pw.Text("$clinicEmail | $clinicPhone",
                  style: const pw.TextStyle(color: PdfColors.white)),
              pw.Text(
                "Next Review Date: ${nextReviewDate != null
                    ? "${nextReviewDate!.day}/${nextReviewDate!.month}/${nextReviewDate!.year}"
                    : "Not scheduled"}",
                style: const pw.TextStyle(color: PdfColors.white),
              ),
            ],
          ),
        ),
      ],
    ),
  );



  return pdf.save();
}

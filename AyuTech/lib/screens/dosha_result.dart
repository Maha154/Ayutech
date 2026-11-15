// lib/models/dosha_result.dart
class DoshaResult {
  final String dosha;              // server field: "dosha"
  final double? confidence;        // optional, server may not return
  final int? id;                   // optional id returned by server
  final Map<String, dynamic>? details;

  DoshaResult({
    required this.dosha,
    this.confidence,
    this.id,
    this.details,
  });

  factory DoshaResult.fromJson(Map<String, dynamic> json) {
    // primary text label
    final doshaValue = json['dosha'] ?? json['prakriti_class'] ?? json['result'] ?? 'unknown';

    // confidence may be missing
    double? conf;
    final confRaw = json['confidence'] ?? json['score'];
    if (confRaw is num) conf = confRaw.toDouble();
    else if (confRaw is String) conf = double.tryParse(confRaw);

    // optional id
    int? id;
    final idRaw = json['id'] ?? json['prediction_id'];
    if (idRaw is int) id = idRaw;
    else if (idRaw is String) id = int.tryParse(idRaw);

    final details = (json['details'] is Map) ? Map<String, dynamic>.from(json['details']) : null;

    return DoshaResult(
      dosha: doshaValue.toString(),
      confidence: conf,
      id: id,
      details: details,
    );
  }
}

// lib/services/diet_engine.dart
class DietEngine {
  static Map<String, dynamic> generateDietPlan(Map<String, dynamic> vikriti) {
    double v = _getNum(vikriti['vikriti_vata'] ?? vikriti['vata']);
    double p = _getNum(vikriti['vikriti_pitta'] ?? vikriti['pitta']);
    double k = _getNum(vikriti['vikriti_kapha'] ?? vikriti['kapha']);

    String dominant = vikriti['dominant']?.toString() ??
        (v >= p && v >= k ? 'Vata' : (p >= v && p >= k ? 'Pitta' : 'Kapha'));

    String strength(double s) {
      if (s >= 0.7) return 'High';
      if (s >= 0.4) return 'Moderate';
      return 'Low';
    }

    final foods = <String>[];
    final avoid = <String>[];
    final lifestyle = <String>[];

    if (dominant == 'Vata') {
      foods.addAll([
        'Warm cooked grains (rice, oats)',
        'Ghee, warm milk (if tolerated)',
        'Steamed root vegetables',
        'Soups, broths'
      ]);
      avoid.addAll(['Cold/raw salads at night', 'Excess coffee', 'Dry/light snacks']);
      lifestyle.addAll(['Gentle oil massage', 'Regular warm meals']);
      if (v >= 0.7) {
        foods.add('Grounding proteins (lentils, nuts in moderation)');
        lifestyle.add('Avoid late nights and excessive travel');
      }
    } else if (dominant == 'Pitta') {
      foods.addAll([
        'Cooling foods (cucumber, coconut water)',
        'Sweet and bitter vegetables',
        'Whole grains'
      ]);
      avoid.addAll(['Spicy foods', 'Alcohol', 'Excess fried foods']);
      lifestyle.addAll(['Avoid long sun exposure', 'Cooling breathwork']);
      if (p >= 0.7) {
        avoid.add('Tomato/acidic fruits in large amounts');
        foods.add('Moderate dairy if tolerated (cooling)');
      }
    } else {
      foods.addAll([
        'Light grains (millet, barley)',
        'Warm spices (ginger, black pepper)',
        'Bitter greens'
      ]);
      avoid.addAll(['Heavy dairy & sweets', 'Large late meals', 'Oily fried foods']);
      lifestyle.addAll(['Regular exercise', 'Light, frequent meals']);
      if (k >= 0.7) foods.add('Increase pungent spices & dry cooking');
    }

    final notes = <String>[];
    if (vikriti['suggested_conditions'] is List) {
      for (var s in vikriti['suggested_conditions']) notes.add(s.toString());
    }

    return {
      'dominant': dominant,
      'scores': {'vata': v, 'pitta': p, 'kapha': k},
      'strengths': {
        'vata': strength(v),
        'pitta': strength(p),
        'kapha': strength(k),
      },
      'foods': foods,
      'avoid': avoid,
      'lifestyle': lifestyle,
      'notes': notes,
    };
  }

  static double _getNum(dynamic x) {
    if (x == null) return 0.0;
    if (x is double) return x;
    if (x is int) return x.toDouble();
    return double.tryParse(x.toString()) ?? 0.0;
  }
}

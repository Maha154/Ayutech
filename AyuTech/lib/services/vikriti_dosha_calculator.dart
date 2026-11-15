// lib/services/vikriti_dosha_calculator.dart

/// Enum for internal dosha ordering
enum DoshaType { vata, pitta, kapha }

/// Result model returned by Vikriti calculator
class VikritiResult {
  /// Example:
  /// "Vata", "Pitta-Kapha", "Tridoshic (Vata-Pitta-Kapha)"
  final String vikritiLabel;

  /// Example:
  /// "Vata", "Pitta, Kapha", "Vata, Pitta, Kapha"
  /// (Store this directly in DB if needed)
  final String doshasString;

  /// Percentage split (0–100)
  /// Keys: Vata, Pitta, Kapha
  final Map<String, double> percentages;

  /// Dominance order (internal use)
  final List<DoshaType> dominantOrder;

  VikritiResult({
    required this.vikritiLabel,
    required this.doshasString,
    required this.percentages,
    required this.dominantOrder,
  });

  @override
  String toString() {
    return 'VikritiResult(label: $vikritiLabel, doshas: $doshasString, percentages: $percentages)';
  }
}

/// Main calculator class
class VikritiDoshaCalculator {
  /// Calculate Vikriti from questionnaire scores
  ///
  /// Pass the TOTAL scores for each dosha
  static VikritiResult calculate({
    required int vataScore,
    required int pittaScore,
    required int kaphaScore,
  }) {
    final int total = vataScore + pittaScore + kaphaScore;

    // Avoid division by zero
    final double vataPct =
        total == 0 ? 0 : (vataScore / total) * 100;
    final double pittaPct =
        total == 0 ? 0 : (pittaScore / total) * 100;
    final double kaphaPct =
        total == 0 ? 0 : (kaphaScore / total) * 100;

    final percentages = {
      'Vata': double.parse(vataPct.toStringAsFixed(1)),
      'Pitta': double.parse(pittaPct.toStringAsFixed(1)),
      'Kapha': double.parse(kaphaPct.toStringAsFixed(1)),
    };

    final scores = [
      _DoshaScore(DoshaType.vata, vataScore),
      _DoshaScore(DoshaType.pitta, pittaScore),
      _DoshaScore(DoshaType.kapha, kaphaScore),
    ];

    // Sort descending by score
    scores.sort((a, b) => b.score.compareTo(a.score));

    final top = scores[0];
    final second = scores[1];
    final third = scores[2];

    const int singleDominantThreshold = 5;
    const int tridoshicThreshold = 3;

    late String vikritiLabel;
    late String doshasString;
    late List<DoshaType> dominantOrder;

    final bool isTridoshic =
        (top.score - second.score < tridoshicThreshold) &&
        (second.score - third.score < tridoshicThreshold);

    if (isTridoshic) {
      vikritiLabel = 'Tridoshic (Vata-Pitta-Kapha)';
      doshasString = 'Vata, Pitta, Kapha';
      dominantOrder = [
        DoshaType.vata,
        DoshaType.pitta,
        DoshaType.kapha,
      ];
    } else if (top.score - second.score >= singleDominantThreshold) {
      vikritiLabel = _singleLabel(top.dosha);
      doshasString = _singleLabel(top.dosha);
      dominantOrder = [top.dosha, second.dosha, third.dosha];
    } else {
      vikritiLabel = _dualLabel(top.dosha, second.dosha);
      doshasString = _dualString(top.dosha, second.dosha);
      dominantOrder = [top.dosha, second.dosha, third.dosha];
    }

    return VikritiResult(
      vikritiLabel: vikritiLabel,
      doshasString: doshasString,
      percentages: percentages,
      dominantOrder: dominantOrder,
    );
  }

  // ---------- helpers ----------

  static String _singleLabel(DoshaType d) {
    switch (d) {
      case DoshaType.vata:
        return 'Vata';
      case DoshaType.pitta:
        return 'Pitta';
      case DoshaType.kapha:
        return 'Kapha';
    }
  }

  static String _dualLabel(DoshaType a, DoshaType b) {
    final ordered = _orderPair(a, b);
    return '${_singleLabel(ordered.$1)}-${_singleLabel(ordered.$2)}';
  }

  static String _dualString(DoshaType a, DoshaType b) {
    final ordered = _orderPair(a, b);
    return '${_singleLabel(ordered.$1)}, ${_singleLabel(ordered.$2)}';
  }

  /// Consistent ordering: Vata < Pitta < Kapha
  static (DoshaType, DoshaType) _orderPair(
      DoshaType a, DoshaType b) {
    const order = {
      DoshaType.vata: 0,
      DoshaType.pitta: 1,
      DoshaType.kapha: 2,
    };

    return order[a]! <= order[b]! ? (a, b) : (b, a);
  }
}

/// Internal helper
class _DoshaScore {
  final DoshaType dosha;
  final int score;

  _DoshaScore(this.dosha, this.score);
}

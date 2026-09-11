import 'dart:math';

import '../data/models/criteria.dart';
import '../data/models/ranking.dart';
import '../data/models/rating.dart';

/// Simple Additive Weighting (SAW) calculator.
/// - Menggunakan criteria_amount sebagai bobot.
/// - criteria_desc: jika diisi "cost" maka dinormalisasi dengan min/value, selain itu benefit (value/max).
class ProfileMatchingCalculator {
  List<Ranking> calculate({
    required List<Criteria> criteria,
    required List<Rating> ratings,
  }) {
    if (criteria.isEmpty || ratings.isEmpty) return [];

    // Siapkan bobot (dinormalisasi ke total 1).
    final weights = criteria.map((c) => c.amount.toDouble()).toList();
    final weightSum = weights.fold<double>(0, (a, b) => a + b);
    final normalizedWeights = weightSum == 0
        ? List.filled(weights.length, 1 / weights.length)
        : weights.map((w) => w / weightSum).toList();

    // Cari max/min tiap kriteria untuk normalisasi SAW.
    final maxValues = List<double>.filled(criteria.length, 0);
    final minValues = List<double>.filled(criteria.length, double.infinity);
    for (final rating in ratings) {
      for (var i = 0; i < criteria.length; i++) {
        final value = _valueByIndex(rating, i).toDouble();
        maxValues[i] = max(maxValues[i], value);
        minValues[i] = min(minValues[i], value);
      }
    }

    final results = <Ranking>[];
    for (final rating in ratings) {
      double total = 0.0;
      final normalizedPerCriteria =
          List<double>.filled(max(5, criteria.length), 0.0);

      for (var i = 0; i < criteria.length; i++) {
        final c = criteria[i];
        final value = _valueByIndex(rating, i).toDouble();
        final isCost = c.desc.toLowerCase() == 'cost';

        double normalized = 0;
        if (isCost) {
          // cost: lebih kecil lebih baik.
          normalized =
              minValues[i] == double.infinity || value == 0 ? 0 : minValues[i] / value;
        } else {
          // benefit: lebih besar lebih baik.
          normalized = maxValues[i] == 0 ? 0 : value / maxValues[i];
        }

        // Log detail normalisasi untuk debugging.
        print(
            '[SAW] ${rating.student.name} | ${c.id}-${c.name} (${isCost ? 'cost' : 'benefit'}) '
            'value=$value max=${maxValues[i]} min=${minValues[i]} '
            'normalized=${normalized.toStringAsFixed(4)} weight=${normalizedWeights[i].toStringAsFixed(4)}');

        total += normalized * normalizedWeights[i];
        normalizedPerCriteria[i] = normalized;
      }

      results.add(
        Ranking(
          studentName: rating.student.name,
          totalScore: double.parse(total.toStringAsFixed(3)),
          k1: normalizedPerCriteria[0],
          k2: normalizedPerCriteria.length > 1 ? normalizedPerCriteria[1] : 0,
          k3: normalizedPerCriteria.length > 2 ? normalizedPerCriteria[2] : 0,
          k4: normalizedPerCriteria.length > 3 ? normalizedPerCriteria[3] : 0,
          k5: normalizedPerCriteria.length > 4 ? normalizedPerCriteria[4] : 0,
        ),
      );
    }

    results.sort((a, b) => b.totalScore.compareTo(a.totalScore));
    return results;
  }

  int _valueByIndex(Rating rating, int index) {
    switch (index) {
      case 0:
        return rating.value.k1;
      case 1:
        return rating.value.k2;
      case 2:
        return rating.value.k3;
      case 3:
        return rating.value.k4;
      case 4:
        return rating.value.k5;
      default:
        return 0;
    }
  }
}

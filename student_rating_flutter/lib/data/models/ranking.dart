import 'rating_value.dart';

class Ranking {
  Ranking({
    required this.studentName,
    required this.totalScore,
    required this.k1,
    required this.k2,
    required this.k3,
    required this.k4,
    required this.k5,
  });

  final String studentName;
  final double totalScore;
  final double k1;
  final double k2;
  final double k3;
  final double k4;
  final double k5;

  RatingValue toRatingValue() => RatingValue(
        k1: k1.toInt(),
        k2: k2.toInt(),
        k3: k3.toInt(),
        k4: k4.toInt(),
        k5: k5.toInt(),
      );
}

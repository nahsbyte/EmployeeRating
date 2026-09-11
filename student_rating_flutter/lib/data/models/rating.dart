import 'dart:convert';

import 'student.dart';
import 'rating_value.dart';

class Rating {
  Rating({
    required this.ratingId,
    required this.student,
    required this.value,
    required this.value2,
  });

  final String ratingId;
  final Student student;
  final RatingValue value;
  final RatingValue value2;

  factory Rating.fromMap(Map<String, dynamic> map) {
    final ratingValueJson = map['rating_value'] ?? '{}';
    final ratingValue2Json = map['rating_value2'] ?? '{}';

    return Rating(
      ratingId: map['rating_id'] as String? ?? '',
      student: Student.fromMap(map),
      value: RatingValue.fromMap(_decode(ratingValueJson)),
      value2: RatingValue.fromMap(_decode(ratingValue2Json)),
    );
  }

  Map<String, dynamic> toMap() => {
        'rating_id': ratingId,
        ...student.toMap(),
        'rating_value': jsonEncode(value.toMap()),
        'rating_value2': jsonEncode(value2.toMap()),
      };

  static Map<String, dynamic> _decode(dynamic input) {
    if (input == null) return {};
    if (input is Map<String, dynamic>) return input;
    if (input is String && input.isNotEmpty) {
      return jsonDecode(input) as Map<String, dynamic>;
    }
    return {};
  }
}

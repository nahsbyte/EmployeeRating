import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/rating.dart';
import '../models/rating_value.dart';
import 'student_service.dart';

class RatingService {
  RatingService(this._client, this._studentService);

  final SupabaseClient _client;
  final StudentService _studentService;

  Future<List<Rating>> fetchRatingsWithStudents({
    String? classId,
    int? limit,
    int? offset,
  }) async {
    final students = limit == null || offset == null
        ? await _studentService.fetchStudents(classId: classId)
        : await _studentService.fetchStudentsPage(
            classId: classId,
            limit: limit,
            offset: offset,
          );
    if (students.isEmpty) return [];
    final orFilter = students.map((s) => 'student_id.eq.${s.id}').join(',');
    final ratingRows = await _client.from('rating').select().or(orFilter);

    final ratingByStudentId = {
      for (final row in ratingRows) row['student_id'] as String: row,
    };

    return students.map((student) {
      final row = ratingByStudentId[student.id];
      return Rating(
        ratingId: row?['rating_id'] as String? ?? student.id,
        student: student,
        value: RatingValue.fromMap(_decode(row?['rating_value'])),
        value2: RatingValue.fromMap(_decode(row?['rating_value2'])),
      );
    }).toList();
  }

  Future<void> upsertRating({
    required String ratingId,
    required String studentId,
    required RatingValue value,
    RatingValue? value2,
  }) async {
    await _client.from('rating').upsert({
      'rating_id': ratingId,
      'student_id': studentId,
      'rating_value': jsonEncode(value.toMap()),
      'rating_value2': jsonEncode((value2 ?? RatingValue()).toMap()),
    });
  }

  static Map<String, dynamic> _decode(dynamic input) {
    if (input == null) return {};
    if (input is Map<String, dynamic>) return input;
    if (input is String && input.isNotEmpty) {
      return jsonDecode(input) as Map<String, dynamic>;
    }
    return {};
  }
}

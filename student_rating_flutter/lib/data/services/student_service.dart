import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/student.dart';

class StudentService {
  StudentService(this._client);

  final SupabaseClient _client;
  static const Duration _cacheTtl = Duration(minutes: 3);
  static final Map<String, _StudentCacheEntry> _cache = {};

  Future<List<Student>> fetchStudents({
    String? classId,
    bool useCache = true,
  }) async {
    final key = (classId ?? '_all').trim().toLowerCase();
    final cached = _cache[key];
    if (useCache && cached != null && !cached.isExpired) {
      return cached.students;
    }
    var query = _client.from('student').select();
    if (classId != null && classId.trim().isNotEmpty) {
      final trimmed = classId.trim();
      query = query.or('class_id.eq.$trimmed,student_class.eq.$trimmed');
    }
    final response = await query.order('student_id');
    final students = (response as List<dynamic>)
        .map((e) => Student.fromMap(e as Map<String, dynamic>))
        .toList();
    _cache[key] = _StudentCacheEntry(students);
    return students;
  }

  Future<List<Student>> fetchStudentsPage({
    String? classId,
    required int limit,
    required int offset,
  }) async {
    var query = _client.from('student').select();
    if (classId != null && classId.trim().isNotEmpty) {
      final trimmed = classId.trim();
      query = query.or('class_id.eq.$trimmed,student_class.eq.$trimmed');
    }
    final response =
        await query.order('student_id').range(offset, offset + limit - 1);
    return (response as List<dynamic>)
        .map((e) => Student.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<Student?> fetchStudentById(String studentId) async {
    final response =
        await _client.from('student').select().eq('student_id', studentId).maybeSingle();
    if (response == null) return null;
    return Student.fromMap(response);
  }

  String _generateId() =>
      'S${DateTime.now().millisecondsSinceEpoch.toString().padLeft(13, '0')}';

  Future<void> upsertStudent(Student student) async {
    await _client.from('student').upsert(student.toMap());
    _cache.clear();
  }

  Future<void> upsertStudentsBulk(List<Student> students) async {
    if (students.isEmpty) return;
    final payload = students.map((s) => s.toMap()).toList();
    await _client.from('student').upsert(payload);
    _cache.clear();
  }

  Future<Student> createStudent({
    required String name,
    required String className,
    required String address,
    required String phone,
  }) async {
    final id = _generateId();
    final student = Student(
      id: id,
      name: name,
      className: className,
      classId: className,
      address: address,
      phone: phone,
    );
    await upsertStudent(student);
    _cache.clear();
    return student;
  }
}

class _StudentCacheEntry {
  _StudentCacheEntry(this.students) : createdAt = DateTime.now();

  final List<Student> students;
  final DateTime createdAt;

  bool get isExpired => DateTime.now().difference(createdAt) > StudentService._cacheTtl;
}

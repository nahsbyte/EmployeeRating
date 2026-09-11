import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/class_info.dart';
import '../models/user_option.dart';

class ClassService {
  ClassService(this._client);

  final SupabaseClient _client;
  static const Duration _cacheTtl = Duration(minutes: 5);
  static List<ClassInfo>? _classesCache;
  static DateTime? _classesCacheAt;
  static List<ClassInfo>? _classOptionsCache;
  static DateTime? _classOptionsCacheAt;

  bool _isCacheValid(DateTime? timestamp) {
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) <= _cacheTtl;
  }

  Future<List<ClassInfo>> fetchClasses() async {
    if (_classesCache != null && _isCacheValid(_classesCacheAt)) {
      return _classesCache!;
    }
    final response = await _client
        .from('class')
        .select('class_id, class_name, wali_user_id, profiles(full_name)')
        .order('class_id');
    final classes = (response as List<dynamic>).map((row) {
      final map = row as Map<String, dynamic>;
      String? waliName;
      final profiles = map['profiles'];
      if (profiles is Map<String, dynamic>) {
        waliName = profiles['full_name'] as String?;
      } else if (profiles is List && profiles.isNotEmpty) {
        final first = profiles.first;
        if (first is Map<String, dynamic>) {
          waliName = first['full_name'] as String?;
        }
      }
      return ClassInfo(
        id: map['class_id'] as String,
        name: map['class_name'] as String?,
        waliUserId: map['wali_user_id'] as String?,
        waliName: waliName,
      );
    }).toList();
    _classesCache = classes;
    _classesCacheAt = DateTime.now();
    return classes;
  }

  Future<List<UserOption>> fetchWaliOptions() async {
    final response = await _client
        .from('profiles')
        .select('user_id, full_name')
        .ilike('role', '%wali%')
        .order('full_name');
    final options = (response as List<dynamic>)
        .map((row) => UserOption(
              id: row['user_id'] as String,
              name: row['full_name'] as String? ?? '-',
            ))
        .toList();
    final deduped = <String, UserOption>{};
    for (final option in options) {
      deduped[option.id] = option;
    }
    return deduped.values.toList();
  }

  Future<List<ClassInfo>> fetchClassOptions() async {
    if (_classOptionsCache != null && _isCacheValid(_classOptionsCacheAt)) {
      return _classOptionsCache!;
    }
    final response = await _client
        .from('class')
        .select('class_id, class_name')
        .order('class_id');
    final options = (response as List<dynamic>)
        .map((row) => ClassInfo(
              id: row['class_id'] as String,
              name: row['class_name'] as String?,
            ))
        .toList();
    _classOptionsCache = options;
    _classOptionsCacheAt = DateTime.now();
    return options;
  }

  Future<ClassInfo?> fetchClassInfo(String classId) async {
    final classRow = await _client
        .from('class')
        .select('class_id, class_name, wali_user_id')
        .eq('class_id', classId)
        .maybeSingle();
    if (classRow == null) return null;

    String? waliName;
    final waliUserId = classRow['wali_user_id'] as String?;
    if (waliUserId != null && waliUserId.isNotEmpty) {
      final waliRow = await _client
          .from('profiles')
          .select('full_name')
          .eq('user_id', waliUserId)
          .maybeSingle();
      waliName = waliRow?['full_name'] as String?;
    }

    return ClassInfo(
      id: classRow['class_id'] as String,
      name: classRow['class_name'] as String?,
      waliUserId: waliUserId,
      waliName: waliName,
    );
  }

  Future<void> upsertClass({
    required String classId,
    String? className,
    String? waliUserId,
  }) async {
    await _client.from('class').upsert({
      'class_id': classId,
      'class_name': className,
      'wali_user_id': waliUserId,
    });
    _classesCache = null;
    _classOptionsCache = null;
    _classesCacheAt = null;
    _classOptionsCacheAt = null;
  }

  Future<void> upsertClassesBulk(List<ClassInfo> classes) async {
    if (classes.isEmpty) return;
    final payload = classes
        .map((c) => {
              'class_id': c.id.trim(),
              'class_name': c.name?.trim().isNotEmpty == true ? c.name!.trim() : null,
            })
        .toList();
    await _client.from('class').upsert(payload);
    _classesCache = null;
    _classOptionsCache = null;
    _classesCacheAt = null;
    _classOptionsCacheAt = null;
  }

  Future<void> deleteClass(String classId) async {
    await _client.from('class').delete().eq('class_id', classId);
    _classesCache = null;
    _classOptionsCache = null;
    _classesCacheAt = null;
    _classOptionsCacheAt = null;
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/criteria.dart';

class CriteriaService {
  CriteriaService(this._client);

  final SupabaseClient _client;

  Future<List<Criteria>> fetchCriteria() async {
    final response =
        await _client.from('criteria').select().order('criteria_id');
    return (response as List<dynamic>)
        .map((e) => Criteria.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> upsertCriteria(Criteria criteria) async {
    await _client.from('criteria').upsert(criteria.toMap());
  }

  Future<void> deleteCriteria(String id) async {
    await _client.from('criteria').delete().eq('criteria_id', id);
  }
}

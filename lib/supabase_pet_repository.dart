import 'package:supabase_flutter/supabase_flutter.dart';

class SupabasePetRepository {
  SupabasePetRepository(this.client);
  final SupabaseClient client;

  Future<T> _request<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (error) {
      if (error.code == '23503') {
        throw Exception('연결된 기록이 있어 삭제할 수 없습니다.');
      }
      throw Exception('반려동물 정보를 저장하거나 불러오지 못했습니다. 다시 시도해 주세요.');
    } catch (_) {
      throw Exception('반려동물 서버에 연결하지 못했습니다. 다시 시도해 주세요.');
    }
  }

  Future<String> ensureProfile(String owner, String name) => _request(() async {
    var profile = await client
        .from('profiles')
        .select('id,name')
        .eq('id', owner)
        .maybeSingle();
    if (profile != null) return profile['name'] as String;
    final displayName = name.trim().isEmpty
        ? '보호자'
        : name.trim().substring(0, name.trim().length.clamp(0, 30));
    try {
      await client.from('profiles').insert({'id': owner, 'name': displayName});
    } on PostgrestException catch (error) {
      // Two devices can create the same guardian profile concurrently.
      if (error.code != '23505') rethrow;
      profile = await client
          .from('profiles')
          .select('id,name')
          .eq('id', owner)
          .maybeSingle();
      if (profile == null) rethrow;
      return profile['name'] as String;
    }
    return displayName;
  });

  static Map<String, dynamic> decode(Map<String, dynamic> row) => {
    'id': row['id'],
    'owner': row['owner_id'],
    'name': row['name'],
    'breed': row['breed'],
    'birthday': row['birthday'],
    'photo': row['avatar_id'] == null
        ? row['photo']
        : 'petsns-avatar:${row['owner_id']}/${row['avatar_id']}',
    'memoryOriginType': row['memory_origin_type'],
    'memoryOriginDate': row['memory_origin_date'],
  };

  Future<List<Map<String, dynamic>>> list(String owner) => _request(() async {
    final rows = await client
        .from('pets')
        .select()
        .eq('owner_id', owner)
        .order('id');
    return rows.map(decode).toList();
  });

  Future<Map<String, dynamic>> save(String owner, Map<String, dynamic> pet) =>
      _request(() async {
        const fields = {
          'name': 'name',
          'breed': 'breed',
          'birthday': 'birthday',
          'photo': 'photo',
          'memoryOriginType': 'memory_origin_type',
          'memoryOriginDate': 'memory_origin_date',
        };
        final values = {
          for (final field in fields.entries)
            if (pet.containsKey(field.key)) field.value: pet[field.key],
        };
        final row = pet['id'] == null
            ? await client
                  .from('pets')
                  .insert({...values, 'owner_id': owner})
                  .select()
                  .single()
            : await client
                  .from('pets')
                  .update(values)
                  .eq('id', pet['id'])
                  .eq('owner_id', owner)
                  .select()
                  .single();
        return decode(row);
      });

  Future<void> delete(String owner, String id) => _request(() async {
    final rows = await client
        .from('pets')
        .delete()
        .eq('id', id)
        .eq('owner_id', owner)
        .select('id');
    if (rows.length != 1) throw StateError('Missing or inaccessible pet.');
  });
}

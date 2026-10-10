import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseMemoryRepository {
  SupabaseMemoryRepository(this.client);
  final SupabaseClient client;

  Future<T> _request<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (_) {
      throw Exception('하루 기록을 저장하거나 불러오지 못했습니다. 연결을 확인하고 다시 시도해 주세요.');
    }
  }

  Map<String, dynamic> _day(Map<String, dynamic> row) => {
    'owner': row['owner_id'],
    'petId': row['pet_id'],
    'date': row['record_date'],
    'title': row['title'],
    'note': row['note'],
    'anniversary': row['anniversary'],
  };

  Future<List<Map<String, dynamic>>> list(String owner) => _request(() async {
    final days = <Map<String, dynamic>>[];
    const pageSize = 500;
    for (var offset = 0; ; offset += pageSize) {
      final rows = await client
          .from('memory_days')
          .select()
          .eq('owner_id', owner)
          .order('record_date')
          .order('pet_id')
          .range(offset, offset + pageSize - 1);
      days.addAll(rows.map(_day));
      if (rows.length < pageSize) return days;
    }
  });

  Future<Map<String, dynamic>> save(
    String petId,
    String date,
    String title,
    String note,
    bool anniversary,
  ) => _request(() async {
    final row = await client
        .rpc(
          'save_memory_day',
          params: {
            'p_pet_id': petId,
            'p_date': date,
            'p_title': title,
            'p_note': note,
            'p_anniversary': anniversary,
          },
        )
        .single();
    return _day(row);
  });

  Future<void> delete(String owner, String petId, String date) =>
      _request(() async {
        await client
            .from('memory_days')
            .delete()
            .eq('owner_id', owner)
            .eq('pet_id', petId)
            .eq('record_date', date);
      });
}

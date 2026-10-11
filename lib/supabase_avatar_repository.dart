import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_photo_repository.dart';
import 'supabase_pet_repository.dart';

class SupabaseAvatarRepository {
  SupabaseAvatarRepository(this.client);
  final SupabaseClient client;
  static const bucket = 'pet-avatars';
  void _session(String owner) {
    if (client.auth.currentUser?.id != owner) {
      throw Exception('로그인 상태가 변경되었습니다. 다시 로그인해 주세요.');
    }
  }

  Future<Map<String, dynamic>?> _pet(String owner, String id) async {
    _session(owner);
    return client
        .from('pets')
        .select()
        .eq('owner_id', owner)
        .eq('id', id)
        .maybeSingle();
  }

  bool _matches(
    Map<String, dynamic>? row,
    String? avatar,
    Map<String, dynamic> values,
  ) =>
      row != null &&
      row['avatar_id'] == avatar &&
      values.entries.every((e) => row[e.key] == e.value);

  Future<Map<String, dynamic>> save(
    String owner,
    Map<String, dynamic> changes, {
    PhotoUpload? upload,
  }) async {
    _session(owner);
    final create = changes['id'] == null;
    final petId = changes['id'] as String? ?? newPhotoId();
    final avatar = upload == null ? null : newPhotoId();
    final values = <String, dynamic>{
      for (final field in ['name', 'breed', 'birthday', 'photo'])
        if (changes.containsKey(field)) field: changes[field],
    };
    if (upload != null) values.remove('photo');
    Map<String, dynamic>? result;
    try {
      if (avatar != null) {
        await client.from('pet_avatars').insert({'id': avatar});
        _session(owner);
        await client.storage
            .from(bucket)
            .uploadBinary(
              '$owner/$avatar',
              upload!.bytes,
              fileOptions: FileOptions(
                contentType: upload.mime,
                upsert: false,
                cacheControl: '0',
              ),
            );
      }
      _session(owner);
      result = await client
          .rpc(
            'save_pet_with_avatar',
            params: {
              'p_pet_id': petId,
              'p_create': create,
              'p_values': values,
              'p_avatar': avatar,
            },
          )
          .single();
    } catch (_) {
      if (client.auth.currentUser?.id == owner) {
        try {
          final settled = await _pet(owner, petId);
          if (_matches(settled, avatar, values)) result = settled;
          if (result == null && avatar != null) {
            await client
                .from('pet_avatars')
                .update({'state': 'deleting'})
                .eq('owner_id', owner)
                .eq('id', avatar)
                .eq('state', 'pending');
            final after = await _pet(owner, petId);
            if (_matches(after, avatar, values)) result = after;
          }
        } catch (_) {
          // Unknown outcomes retain a reservation for later cleanup.
        }
      }
      if (result == null) {
        throw Exception('프로필과 사진을 저장하지 못했습니다. 기존 정보는 유지됩니다. 다시 시도해 주세요.');
      }
    } finally {
      if (client.auth.currentUser?.id == owner) await cleanup(owner);
    }
    _session(owner);
    return SupabasePetRepository.decode(result);
  }

  Future<bool> cleanup(String owner) async {
    try {
      _session(owner);
      await client.rpc('claim_avatar_cleanup');
      var complete = true;
      // Remove each page before reading the next so deletes do not shift offsets.
      while (true) {
        _session(owner);
        final rows = await client
            .from('pet_avatars')
            .select()
            .eq('owner_id', owner)
            .eq('state', 'deleting')
            .order('id')
            .limit(500);
        if (rows.isEmpty) return complete;
        for (final row in rows) {
          try {
            _session(owner);
            await client.storage.from(bucket).remove([
              row['object_path'] as String,
            ]);
            _session(owner);
            await client
                .from('pet_avatars')
                .delete()
                .eq('owner_id', owner)
                .eq('id', row['id'])
                .eq('state', 'deleting');
          } catch (_) {
            complete = false;
          }
        }
        if (!complete || rows.length < 500) return complete;
      }
    } catch (_) {
      return false;
    }
  }
}

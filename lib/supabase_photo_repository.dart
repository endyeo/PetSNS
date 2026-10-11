import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

const privatePhotoPrefix = 'petsns-photo:';
const privateAvatarPrefix = 'petsns-avatar:';
bool isPrivatePhotoSource(String? source) =>
    source?.startsWith(privatePhotoPrefix) == true ||
    source?.startsWith(privateAvatarPrefix) == true;

String newPhotoId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class PhotoUpload {
  PhotoUpload(this.bytes, this.mime);
  final Uint8List bytes;
  final String mime;

  static PhotoUpload parse(String source) {
    final match = RegExp(
      r'^data:(image/(?:jpeg|png|webp|gif));base64,(.+)$',
    ).firstMatch(source);
    if (match == null) throw Exception('JPEG·PNG·WebP·GIF 사진을 선택해 주세요.');
    Uint8List bytes;
    try {
      bytes = base64Decode(match[2]!);
    } catch (_) {
      throw Exception('사진 파일을 읽지 못했습니다. 다시 선택해 주세요.');
    }
    if (bytes.isEmpty || bytes.length > 3 * 1024 * 1024) {
      throw Exception('사진은 한 장당 3MB 이하로 선택해 주세요.');
    }
    return PhotoUpload(bytes, match[1]!);
  }
}

class SupabasePhotoRepository {
  SupabasePhotoRepository(this.client);
  final SupabaseClient client;
  static const bucket = 'memory-photos';

  void _session(String owner) {
    if (client.auth.currentUser?.id != owner) {
      throw Exception('로그인 상태가 변경되었습니다. 다시 로그인해 주세요.');
    }
  }

  Future<List<Map<String, dynamic>>> _rows(String owner) async {
    _session(owner);
    final rows = <Map<String, dynamic>>[];
    for (var offset = 0; ; offset += 500) {
      final page = await client
          .from('memory_photos')
          .select()
          .eq('owner_id', owner)
          .order('record_date')
          .order('id')
          .range(offset, offset + 499);
      rows.addAll(page);
      if (page.length < 500) return rows;
    }
  }

  Future<List<Map<String, dynamic>>> list(String owner) async {
    try {
      return (await _rows(owner))
          .where((r) => r['state'] == 'ready')
          .map(
            (r) => <String, dynamic>{
              'id': r['id'],
              'owner': r['owner_id'],
              'petId': r['pet_id'],
              'date': r['record_date'],
              'photo': '$privatePhotoPrefix${r['object_path']}',
            },
          )
          .toList();
    } catch (_) {
      throw Exception('사진 목록을 불러오지 못했습니다. 연결을 확인하고 다시 시도해 주세요.');
    }
  }

  Future<Uint8List> download(String owner, String source) async {
    _session(owner);
    final avatar = source.startsWith(privateAvatarPrefix);
    final prefix = avatar ? privateAvatarPrefix : privatePhotoPrefix;
    if (!source.startsWith('$prefix$owner/')) {
      throw Exception('사진 접근 권한이 없습니다.');
    }
    try {
      final bytes = await client.storage
          .from(avatar ? 'pet-avatars' : bucket)
          .download(
            source.substring(prefix.length),
            cacheNonce: DateTime.now().microsecondsSinceEpoch.toString(),
          );
      _session(owner);
      return bytes;
    } catch (_) {
      throw Exception('사진을 불러오지 못했습니다. 다시 시도해 주세요.');
    }
  }

  Future<void> save(
    String owner,
    String pet,
    String date,
    List<PhotoUpload> photos, {
    String? replace,
  }) async {
    _session(owner);
    if (photos.isEmpty || (replace != null && photos.length != 1)) {
      throw Exception('사진을 선택해 주세요. 교체할 사진은 한 장만 선택할 수 있습니다.');
    }
    final ids = photos.map((_) => newPhotoId()).toList();
    var committed = false;
    try {
      await client.from('memory_photos').insert([
        for (final id in ids) {'id': id, 'pet_id': pet, 'record_date': date},
      ]);
      for (var i = 0; i < ids.length; i++) {
        _session(owner);
        await client.storage
            .from(bucket)
            .uploadBinary(
              '$owner/${ids[i]}',
              photos[i].bytes,
              fileOptions: FileOptions(
                contentType: photos[i].mime,
                upsert: false,
                cacheControl: '0',
              ),
            );
      }
      _session(owner);
      await client.rpc(
        'finish_memory_photos',
        params: {'p_ids': ids, 'p_replace': replace},
      );
      committed = true;
    } catch (_) {
      // A lost success response must not delete a completed upload.
      if (client.auth.currentUser?.id == owner) {
        try {
          final rows = (await _rows(
            owner,
          )).where((r) => ids.contains(r['id'])).toList();
          committed =
              rows.length == ids.length &&
              rows.every((r) => r['state'] == 'ready');
          if (!committed) {
            await client
                .from('memory_photos')
                .update({'state': 'deleting'})
                .eq('owner_id', owner)
                .inFilter('id', ids)
                .eq('state', 'pending');
            final settled = (await _rows(
              owner,
            )).where((r) => ids.contains(r['id'])).toList();
            committed =
                settled.length == ids.length &&
                settled.every((r) => r['state'] == 'ready');
          }
        } catch (_) {
          // Reservations remain recoverable after the 24-hour upload window.
        }
      }
      if (!committed) throw Exception('사진을 저장하지 못했습니다. 연결을 확인하고 다시 시도해 주세요.');
    } finally {
      if (client.auth.currentUser?.id == owner) await cleanup(owner);
    }
    _session(owner);
  }

  Future<void> edit(String owner, String id, String pet, String date) async {
    try {
      _session(owner);
      await client
          .from('memory_photos')
          .update({'pet_id': pet, 'record_date': date})
          .eq('owner_id', owner)
          .eq('id', id)
          .eq('state', 'ready')
          .select('id')
          .single();
    } catch (_) {
      throw Exception('사진 정보를 수정하지 못했습니다. 다시 시도해 주세요.');
    }
  }

  Future<void> delete(String owner, String id) async {
    try {
      _session(owner);
      await client
          .from('memory_photos')
          .update({'state': 'deleting'})
          .eq('owner_id', owner)
          .eq('id', id)
          .select('id')
          .single();
      if (!await cleanup(owner)) throw Exception('cleanup pending');
    } catch (_) {
      throw Exception('사진 삭제를 완료하지 못했습니다. 다시 시도하면 남은 파일을 정리합니다.');
    }
  }

  Future<bool> cleanup(String owner) async {
    try {
      _session(owner);
      await client.rpc('claim_memory_photo_cleanup');
      final rows = await _rows(owner);
      var complete = true;
      for (final row in rows.where((r) => r['state'] == 'deleting')) {
        try {
          _session(owner);
          await client.storage.from(bucket).remove([
            row['object_path'] as String,
          ]);
          _session(owner);
          await client
              .from('memory_photos')
              .delete()
              .eq('owner_id', owner)
              .eq('id', row['id'])
              .eq('state', 'deleting');
        } catch (_) {
          complete = false;
        }
      }
      return complete;
    } catch (_) {
      return false;
    }
  }
}

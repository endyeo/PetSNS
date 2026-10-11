import 'dart:convert';
import 'dart:math';
import 'meeting_location.dart';
import 'supabase_auth_service.dart';
import 'supabase_pet_repository.dart';
import 'supabase_memory_repository.dart';
import 'supabase_photo_repository.dart';
import 'supabase_avatar_repository.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef RecordData = Map<String, dynamic>;
DateTime korea(DateTime time) => time.toUtc().add(const Duration(hours: 9));
DateTime chatClose(DateTime appointment) {
  final k = korea(appointment);
  return DateTime.utc(
    k.year,
    k.month,
    k.day + 2,
  ).subtract(const Duration(hours: 9));
}

String stamp(DateTime d) {
  final k = korea(d);
  return '${k.month}.${k.day} ${k.hour.toString().padLeft(2, '0')}:${k.minute.toString().padLeft(2, '0')}';
}

DateTime meetingDeadline(DateTime at) =>
    at.toUtc().subtract(const Duration(hours: 6));

String dayKey(DateTime date) => date.toIso8601String().substring(0, 10);
int daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

const dogPhoto =
    'https://images.unsplash.com/photo-1552053831-71594a27632d?w=1200&auto=format&fit=crop&q=85';
const catPhoto =
    'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=900&auto=format&fit=crop&q=85';

const petCategories = ['강아지', '고양이', '기타'];

class PetStore extends ChangeNotifier {
  PetStore(
    this.prefs, {
    DateTime Function()? clock,
    this.auth,
    this.petRepository,
    this.memoryRepository,
    this.photoRepository,
    this.avatarRepository,
  }) : assert(
         memoryRepository == null || (petRepository != null && auth != null),
       ),
       assert(
         photoRepository == null || (petRepository != null && auth != null),
       ),
       clock = clock ?? DateTime.now {
    assert(avatarRepository == null || (petRepository != null && auth != null));
    auth?.addListener(_authChanged);
  }
  final SharedPreferences prefs;
  final SupabaseAuthService? auth;
  final SupabasePetRepository? petRepository;
  final SupabaseMemoryRepository? memoryRepository;
  final SupabasePhotoRepository? photoRepository;
  final SupabaseAvatarRepository? avatarRepository;
  bool avatarCleanupPending = false;
  List<RecordData> _serverPets = [];
  List<RecordData> _serverDays = [];
  List<RecordData> _serverPhotos = [];
  bool photoCleanupPending = false;
  String? _petOwner;
  String? _profileName;
  bool _disposed = false;
  bool _loaded = false;
  void _authChanged() {
    if (auth?.account?['id'] != _petOwner) {
      _serverPets = [];
      _serverDays = [];
      _serverPhotos = [];
      photoCleanupPending = false;
      avatarCleanupPending = false;
      _petOwner = null;
      _profileName = null;
    }
    notifyListeners();
  }

  bool get usesSupabase => auth != null;
  final DateTime Function() clock;
  RecordData data = {};
  bool busy = false;
  static const key = 'petsns.v1';
  List<RecordData> rows(String key) {
    if (_loaded) {
      if (key == 'pets' && petRepository != null) return _serverPets;
      if (key == 'memoryDays' && memoryRepository != null) return _serverDays;
      if (key == 'memories' && photoRepository != null) return _serverPhotos;
    }
    return (data[key] as List).cast<RecordData>();
  }

  String? get user => account?['id'] as String?;
  RecordData? get account {
    if (auth != null) {
      final account = auth!.account;
      if (petRepository != null && account?['id'] != _petOwner) return null;
      if (petRepository != null && account != null) {
        return {...account, 'name': _profileName};
      }
      return account;
    }
    final session = data['session'];
    if (session is! String) return null;
    for (final row in (data['accounts'] as List? ?? const [])) {
      if (row['id'] == session) return row as RecordData;
    }
    return null;
  }

  String id() =>
      '${clock().microsecondsSinceEpoch}-${Random.secure().nextInt(0x7fffffff)}';
  Future<void> load() async {
    final raw = prefs.getString(key);
    if (raw != null) {
      data = jsonDecode(raw) as RecordData;
      if (data['version'] != 1) {
        throw Exception('지원하지 않는 저장 데이터입니다.');
      }
    } else {
      final now = clock().toUtc();
      data = {
        'version': 1,
        'session': null,
        'accounts': <RecordData>[],
        'pets': <RecordData>[],
        'memories': <RecordData>[],
        'messages': <RecordData>[],
        'meetings': <RecordData>[
          {
            'id': 'walk',
            'title': '꼬리 흔들며, 한강 산책',
            'place': '서울 · 반포한강공원',
            'note': '서로의 속도에 맞춰 천천히 걸어요. 리드줄과 물을 챙겨 주세요.',
            'at': now.add(const Duration(days: 2)).toIso8601String(),
            'deadline': now.add(const Duration(days: 1)).toIso8601String(),
            'capacity': 6,
            'photo': dogPhoto,
            'canceled': false,
            'members': {
              'host': {'since': now.toIso8601String(), 'companions': 0},
            },
          },
          {
            'id': 'picnic',
            'title': '햇살 아래 댕댕 피크닉',
            'place': '서울 · 서울숲',
            'note': '돗자리 위에서 나누는 소소한 반려 생활 이야기.',
            'at': now.add(const Duration(days: 4)).toIso8601String(),
            'deadline': now.add(const Duration(days: 3)).toIso8601String(),
            'capacity': 4,
            'photo': catPhoto,
            'canceled': false,
            'members': {
              'neighbor': {'since': now.toIso8601String(), 'companions': 1},
            },
          },
        ],
      };
      await prefs.setString(key, jsonEncode(data));
    }
    final beforeMigration = jsonEncode(data);
    data.putIfAbsent('groupMessages', () => <RecordData>[]);
    data.putIfAbsent(
      'posts',
      () => <RecordData>[
        for (final example in [
          (
            'post-walk',
            '오늘 산책에서 만난 작은 행복',
            '강아지',
            '공원에서 모카와 천천히 걸었어요. 여러분은 오늘 어디를 걸었나요?',
          ),
          (
            'post-cat',
            '우리 집 고양이의 낮잠 자리',
            '고양이',
            '햇살이 들어오는 창가를 제일 좋아해요. 집사님들의 일상도 들려주세요.',
          ),
          (
            'post-family',
            '작은 가족을 소개해 주세요',
            '기타',
            '함께 사는 반려동물과의 평범하고 소중한 이야기를 나눠요.',
          ),
        ])
          {
            'id': example.$1,
            'title': example.$2,
            'category': example.$3,
            'body': example.$4,
            'owner': null,
            'name': 'PetSNS · 예시',
            'at': clock().toUtc().toIso8601String(),
          },
      ],
    );
    data.putIfAbsent(
      'groups',
      () => <RecordData>[
        for (final example in [
          ('dog-walkers', '동네 산책 친구', '강아지', '서울', '산책 사진을 나누고 함께 걸을 친구를 만나요.'),
          ('cat-friends', '고양이 집사 모임', '고양이', '전국', '고양이의 일상과 집사들의 이야기를 나눠요.'),
          ('pet-family', '작은 가족 사랑방', '기타', '전국', '다양한 반려동물과 함께하는 일상을 나눠요.'),
        ])
          {
            'id': example.$1,
            'kind': 'group',
            'title': example.$2,
            'category': example.$3,
            'place': example.$4,
            'note': example.$5,
            'members': <String, dynamic>{},
            'canceled': false,
          },
      ],
    );
    ensureDemoCompanion();
    migrateMemoryDays();
    for (final item in [
      ('walk', 'host', '보리', dogPhoto),
      ('picnic', 'neighbor', '나비', catPhoto),
    ]) {
      final examples = rows('meetings').where((m) => m['id'] == item.$1);
      if (examples.isEmpty) continue;
      final participant = members(examples.first)[item.$2];
      if (participant is Map && participant['petIds'] == null) {
        participant.putIfAbsent(
          'petProfiles',
          () => [
            {'id': 'demo-${item.$2}', 'name': item.$3, 'photo': item.$4},
          ],
        );
      }
    }
    for (final meeting in rows('meetings')) {
      meeting.putIfAbsent(
        'category',
        () => ['walk', 'picnic'].contains(meeting['id']) ? '강아지' : '기타',
      );
      meeting['deadline'] = meetingDeadline(
        DateTime.parse(meeting['at']),
      ).toIso8601String();
      final example = meeting['id'] == 'walk'
          ? meetingPlaceExamples.first
          : meeting['id'] == 'picnic'
          ? meetingPlaceExamples.last
          : null;
      if (example != null) {
        meeting.putIfAbsent('latitude', () => example.latitude);
        meeting.putIfAbsent('longitude', () => example.longitude);
      }
    }
    final migrated = jsonEncode(data);
    if (migrated != beforeMigration && !await prefs.setString(key, migrated)) {
      throw Exception('기존 추억을 저장하지 못했습니다. 저장 공간을 확인해 주세요.');
    }
    _loaded = true;
    if (petRepository != null && auth?.account != null) await _loadServerPets();
    notifyListeners();
  }

  Future<void> _loadServerPets() async {
    if (_disposed) throw Exception('화면이 닫혔습니다. 다시 실행해 주세요.');
    final account = auth!.account!;
    final owner = account['id'] as String;
    _petOwner = null;
    _serverPets = [];
    _serverDays = [];
    _serverPhotos = [];
    notifyListeners();
    final name = await petRepository!.ensureProfile(
      owner,
      account['name'] as String,
    );
    final pets = await petRepository!.list(owner);
    final days = await memoryRepository?.list(owner) ?? <RecordData>[];
    final clean = await photoRepository?.cleanup(owner) ?? true;
    final avatarsClean = await avatarRepository?.cleanup(owner) ?? true;
    final photos = await photoRepository?.list(owner) ?? <RecordData>[];
    if (_disposed || auth!.account?['id'] != owner) {
      throw Exception('로그인 상태가 변경되었습니다. 다시 로그인해 주세요.');
    }
    _serverPets = pets;
    _serverDays = days;
    _serverPhotos = photos;
    photoCleanupPending = !clean;
    avatarCleanupPending = !avatarsClean;
    _petOwner = owner;
    _profileName = name;
    notifyListeners();
  }

  Future<void> _changeServerPet(
    Future<void> Function(String owner) action,
  ) async {
    requireUser();
    if (busy) throw Exception('저장 중입니다. 잠시 후 다시 시도해 주세요.');
    final owner = user!;
    busy = true;
    try {
      await action(owner);
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _checkPetSession(String owner) {
    if (_disposed || user != owner) {
      throw Exception('로그인 상태가 변경되었습니다. 다시 로그인해 주세요.');
    }
  }

  Future<void> _saveServerPet(RecordData row) => _changeServerPet((
    owner,
  ) async {
    final matches = _serverPets.where((pet) => pet['id'] == row['id']);
    if (row['id'] != null && matches.isEmpty) throw Exception('수정 권한이 없습니다.');
    final saved = {...?matches.firstOrNull, ...row};
    saved['name'] = (saved['name'] as String? ?? '').trim();
    if ((saved['name'] as String).isEmpty ||
        (saved['name'] as String).length > 60 ||
        (saved['breed'] as String? ?? '').length > 80) {
      throw Exception('이름(1~60자)과 품종(80자 이하)을 확인해 주세요.');
    }
    final birthday = saved['birthday'];
    if (birthday != null) validateMemoryDate(DateTime.parse(birthday));
    final photo = saved['photo'] as String?;
    final upload =
        photo?.startsWith('data:') == true && avatarRepository != null
        ? PhotoUpload.parse(photo!)
        : null;
    final sameAvatar =
        photo?.startsWith(privateAvatarPrefix) == true &&
        matches.firstOrNull?['photo'] == photo;
    if (photo != null &&
        photo.isNotEmpty &&
        upload == null &&
        !sameAvatar &&
        !['https', 'http'].contains(Uri.tryParse(photo)?.scheme)) {
      throw Exception('프로필 사진 업로드는 준비 중입니다.');
    }
    if (photo == '') saved['photo'] = null;
    final changes = {...row};
    if (row.containsKey('name')) changes['name'] = saved['name'];
    if (row.containsKey('photo')) changes['photo'] = saved['photo'];
    if (sameAvatar) changes.remove('photo');
    late RecordData result;
    try {
      result = avatarRepository != null && changes.containsKey('photo')
          ? await avatarRepository!.save(owner, changes, upload: upload)
          : await petRepository!.save(owner, changes);
    } finally {
      if (avatarRepository != null && !_disposed && user == owner) {
        final clean = await avatarRepository!.cleanup(owner);
        if (!_disposed && user == owner) avatarCleanupPending = !clean;
      }
    }
    _checkPetSession(owner);
    final index = _serverPets.indexWhere((pet) => pet['id'] == result['id']);
    if (index < 0) {
      _serverPets.add(result);
      _serverPets.sort(
        (a, b) => (a['id'] as String).compareTo(b['id'] as String),
      );
    } else {
      _serverPets[index] = result;
    }
  });

  void migrateMemoryDays() {
    data.putIfAbsent('memoryDays', () => <RecordData>[]);
    String? firstPetFor(String owner) {
      final pets = rows('pets').where((pet) => pet['owner'] == owner);
      return pets.isEmpty ? null : pets.first['id'] as String;
    }

    for (final record in [...rows('memories'), ...rows('memoryDays')]) {
      record.putIfAbsent('petId', () => firstPetFor(record['owner'] as String));
      if (record['petId'] == null) {
        record['petId'] = firstPetFor(record['owner'] as String);
      }
    }
    for (final account in rows('accounts')) {
      if (account['memoryOriginType'] == null) continue;
      final pets = rows('pets').where((pet) => pet['owner'] == account['id']);
      if (pets.isEmpty) continue;
      pets.first.putIfAbsent(
        'memoryOriginType',
        () => account['memoryOriginType'],
      );
      pets.first.putIfAbsent(
        'memoryOriginDate',
        () => account['memoryOriginDate'],
      );
      account.remove('memoryOriginType');
      account.remove('memoryOriginDate');
    }
    for (final photo in rows('memories')) {
      if (!photo.containsKey('title') && !photo.containsKey('note')) continue;
      final matches = rows('memoryDays').where(
        (day) =>
            day['owner'] == photo['owner'] &&
            day['petId'] == photo['petId'] &&
            day['date'] == photo['date'],
      );
      final day = matches.isEmpty
          ? <String, dynamic>{
              'owner': photo['owner'],
              'petId': photo['petId'],
              'date': photo['date'],
              'title': '',
              'note': '',
              'anniversary': false,
            }
          : matches.first;
      if (matches.isEmpty) rows('memoryDays').add(day);
      for (final field in ['title', 'note']) {
        final value = (photo[field] as String? ?? '').trim();
        final previous = day[field] as String? ?? '';
        if (value.isNotEmpty && !previous.split('\n\n').contains(value)) {
          day[field] = previous.isEmpty ? value : '$previous\n\n$value';
        }
        photo.remove(field);
      }
      day['anniversary'] =
          day['anniversary'] == true || photo['anniversary'] == true;
      photo.remove('anniversary');
    }
  }

  String? get defaultPetId {
    final pets = rows('pets').where((pet) => pet['owner'] == user);
    return pets.isEmpty ? null : pets.first['id'] as String;
  }

  RecordData memoryProfile({String? petId}) {
    requireUser();
    final target = petId ?? defaultPetId;
    final pets = rows(
      'pets',
    ).where((pet) => pet['owner'] == user && pet['id'] == target);
    if (pets.isEmpty) throw Exception('추억을 기록할 반려동물을 먼저 등록해 주세요.');
    return pets.first;
  }

  RecordData memoryDay(String date, {String? petId}) {
    petId ??= defaultPetId;
    final days = rows('memoryDays').where(
      (day) =>
          day['owner'] == user && day['petId'] == petId && day['date'] == date,
    );
    if (days.isNotEmpty) return days.first;
    return {
      'owner': user,
      'petId': petId,
      'date': date,
      'title': '',
      'note': '',
      'anniversary': false,
    };
  }

  DateTime? get firstPhotoDate => firstPhotoDateFor(defaultPetId);
  DateTime? firstPhotoDateFor(String? petId) {
    final dates =
        rows('memories')
            .where((photo) => photo['owner'] == user && photo['petId'] == petId)
            .map((photo) => DateTime.parse(photo['date']))
            .toList()
          ..sort();
    return dates.isEmpty ? null : dates.first;
  }

  DateTime? get memoryOrigin => memoryOriginFor(defaultPetId);
  DateTime? memoryOriginFor(String? petId) {
    if (user == null || petId == null) return null;
    return DateTime.tryParse(
      memoryProfile(petId: petId)['memoryOriginDate'] ?? '',
    );
  }

  void validateMemoryDate(DateTime date) {
    final today = korea(clock());
    if (date.isBefore(DateTime(1990)) || daysBetween(date, today) < 0) {
      throw Exception('날짜는 1990년부터 오늘 사이로 선택해 주세요.');
    }
  }

  Future<void> setMemoryOrigin(
    String type,
    DateTime date, {
    String? petId,
  }) async {
    if (petRepository != null) {
      final profile = memoryProfile(petId: petId);
      if (!['firstMeeting', 'firstPhoto'].contains(type)) {
        throw Exception('시작 기준을 선택해 주세요.');
      }
      final firstPhoto = firstPhotoDateFor(profile['id']);
      if (type == 'firstPhoto') date = firstPhoto ?? date;
      validateMemoryDate(date);
      if (firstPhoto != null && date.isAfter(firstPhoto)) {
        throw Exception('시작일은 가장 오래된 사진 날짜보다 늦을 수 없어요.');
      }
      await _saveServerPet({
        'id': profile['id'],
        'memoryOriginType': type,
        'memoryOriginDate': dayKey(date),
      });
      return;
    }
    await change(() {
      final profile = memoryProfile(petId: petId);
      final firstPhoto = firstPhotoDateFor(profile['id']);
      if (!['firstMeeting', 'firstPhoto'].contains(type)) {
        throw Exception('시작 기준을 선택해 주세요.');
      }
      if (type == 'firstPhoto') date = firstPhoto ?? date;
      validateMemoryDate(date);
      if (firstPhoto != null && date.isAfter(firstPhoto)) {
        throw Exception('시작일은 가장 오래된 사진 날짜보다 늦을 수 없어요.');
      }
      profile['memoryOriginType'] = type;
      profile['memoryOriginDate'] = dayKey(date);
    });
  }

  Future<void> saveMemoryDay(
    String date,
    String title,
    String note,
    bool anniversary, {
    String? petId,
  }) async {
    if (memoryRepository != null) {
      await _changeServerPet((owner) async {
        final profile = memoryProfile(petId: petId);
        final parsed = DateTime.tryParse(date);
        if (parsed == null || dayKey(parsed) != date) {
          throw Exception('올바른 날짜를 선택해 주세요.');
        }
        validateMemoryDate(parsed);
        final result = await memoryRepository!.save(
          profile['id'],
          date,
          title.trim(),
          note.trim(),
          anniversary,
        );
        _checkPetSession(owner);
        _serverDays.removeWhere(
          (day) =>
              day['petId'] == result['petId'] && day['date'] == result['date'],
        );
        _serverDays.add(result);
      });
      return;
    }
    await change(() {
      final profile = memoryProfile(petId: petId);
      validateMemoryDate(DateTime.parse(date));
      rows('memoryDays').removeWhere(
        (day) =>
            day['owner'] == user &&
            day['petId'] == profile['id'] &&
            day['date'] == date,
      );
      rows('memoryDays').add({
        'owner': user,
        'petId': profile['id'],
        'date': date,
        'title': title.trim(),
        'note': note.trim(),
        'anniversary': anniversary,
      });
    });
  }

  Future<void> deleteMemoryDay(String date, {String? petId}) async {
    if (memoryRepository == null) throw Exception('온라인 하루 기록에만 사용할 수 있습니다.');
    await _changeServerPet((owner) async {
      final profile = memoryProfile(petId: petId);
      await memoryRepository!.delete(owner, profile['id'], date);
      _checkPetSession(owner);
      _serverDays.removeWhere(
        (day) => day['petId'] == profile['id'] && day['date'] == date,
      );
    });
  }

  Future<void> saveMemoryPhotos(
    String date,
    List<String> photos, {
    String? existingId,
    String? petId,
  }) async {
    if (photoRepository != null) {
      await _changeServerPet((owner) async {
        final existing = existingId == null
            ? null
            : rows(
                'memories',
              ).firstWhere((p) => p['id'] == existingId && p['owner'] == owner);
        final profile = memoryProfile(petId: petId ?? existing?['petId']);
        final parsed = DateTime.tryParse(date);
        if (parsed == null || dayKey(parsed) != date) {
          throw Exception('올바른 날짜를 선택해 주세요.');
        }
        validateMemoryDate(parsed);
        if (photos.isEmpty || (existing != null && photos.length != 1)) {
          throw Exception('사진을 선택해 주세요.');
        }
        if (profile['memoryOriginType'] == 'firstMeeting' &&
            parsed.isBefore(DateTime.parse(profile['memoryOriginDate']))) {
          throw Exception('첫 만남 이전 사진이에요. Day 0 시작일을 먼저 확인해 주세요.');
        }
        final uploads = existing != null && photos.single == existing['photo']
            ? null
            : photos.map(PhotoUpload.parse).toList();
        try {
          if (uploads == null) {
            await photoRepository!.edit(
              owner,
              existingId!,
              profile['id'],
              date,
            );
          } else {
            await photoRepository!.save(
              owner,
              profile['id'],
              date,
              uploads,
              replace: existingId,
            );
          }
        } catch (_) {
          if (!_disposed && user == owner) {
            final clean = await photoRepository!.cleanup(owner);
            if (!_disposed && user == owner) {
              photoCleanupPending = !clean;
            }
          }
          rethrow;
        }
        await _refreshServerPhotos(owner);
      });
      return;
    }
    await change(() {
      requireUser();
      RecordData? existing;
      if (existingId != null) {
        existing = rows(
          'memories',
        ).firstWhere((photo) => photo['id'] == existingId);
        if (existing['owner'] != user) throw Exception('수정 권한이 없습니다.');
        petId ??= existing['petId'];
      }
      final profile = memoryProfile(petId: petId);
      final origin = memoryOriginFor(profile['id']);
      validateMemoryDate(DateTime.parse(date));
      if (profile['memoryOriginType'] == 'firstMeeting' &&
          origin != null &&
          DateTime.parse(date).isBefore(origin)) {
        throw Exception('첫 만남 이전 사진이에요. Day 0 시작일을 먼저 확인해 주세요.');
      }
      if (photos.isEmpty || photos.any((photo) => photo.isEmpty)) {
        throw Exception('사진을 선택해 주세요.');
      }
      if (existing != null) {
        if (photos.length != 1) throw Exception('수정할 사진 한 장을 선택해 주세요.');
        existing['photo'] = photos.single;
        existing['date'] = date;
        existing['petId'] = profile['id'];
      } else {
        for (final photo in photos) {
          rows('memories').add({
            'id': id(),
            'owner': user,
            'petId': profile['id'],
            'date': date,
            'photo': photo,
          });
        }
      }
      if (profile['memoryOriginType'] == 'firstPhoto' &&
          origin != null &&
          DateTime.parse(date).isBefore(origin)) {
        profile['memoryOriginDate'] = date;
      }
    });
  }

  Future<void> _refreshServerPhotos(String owner) async {
    _checkPetSession(owner);
    final photos = await photoRepository!.list(owner);
    final pets = await petRepository!.list(owner);
    final clean = await photoRepository!.cleanup(owner);
    _checkPetSession(owner);
    _serverPhotos = photos;
    _serverPets = pets;
    photoCleanupPending = !clean;
  }

  Future<void> retryPhotoCleanup() => _changeServerPet(_refreshServerPhotos);
  Future<void> retryAvatarCleanup() => _changeServerPet((owner) async {
    final clean = await avatarRepository!.cleanup(owner);
    _checkPetSession(owner);
    avatarCleanupPending = !clean;
  });

  void ensureDemoCompanion() {
    final accounts = rows(
      'accounts',
    ).where((account) => account['id'] == 'test');
    if (accounts.isEmpty || accounts.first['multiPetDemoV1'] == true) return;
    if (rows('pets').where((pet) => pet['owner'] == 'test').length < 2) {
      final petId = id();
      rows('pets').add({
        'id': petId,
        'owner': 'test',
        'name': '루나',
        'breed': '코리안 쇼트헤어',
        'birthday': '2023-05-20',
        'photo': catPhoto,
      });
      rows('memories').add({
        'id': id(),
        'owner': 'test',
        'petId': petId,
        'title': '루나와 느긋한 오후',
        'note': '창가에서 햇볕을 쬐며 함께 쉬었어요.',
        'date': dayKey(korea(clock())),
        'photo': catPhoto,
        'anniversary': false,
      });
    }
    accounts.first['multiPetDemoV1'] = true;
  }

  Future<void> change(void Function() action) async {
    if (busy) {
      throw Exception('저장 중입니다. 잠시 후 다시 시도해 주세요.');
    }
    busy = true;
    final backup = jsonEncode(data);
    final petBackup = jsonEncode(_serverPets);
    final dayBackup = jsonEncode(_serverDays);
    final photoBackup = jsonEncode(_serverPhotos);
    final owner = _petOwner;
    try {
      action();
      if (petRepository != null) {
        if (jsonEncode(_serverPets) != petBackup ||
            jsonEncode(_serverDays) != dayBackup ||
            jsonEncode(_serverPhotos) != photoBackup) {
          throw Exception(
            memoryRepository == null ? '추억 저장은 준비 중입니다.' : '사진 저장은 준비 중입니다.',
          );
        }
        final previous = jsonDecode(backup) as RecordData;
        // Local child records cannot enforce server pet deletion across devices.
        for (final collection in [
          'pets',
          'memories',
          'memoryDays',
          'meetings',
          'groups',
        ]) {
          if (jsonEncode(data[collection]) !=
              jsonEncode(previous[collection])) {
            throw Exception(
              memoryRepository == null
                  ? '추억과 모임 저장은 준비 중입니다. 반려동물 프로필만 저장할 수 있습니다.'
                  : '사진과 모임 저장은 준비 중입니다.',
            );
          }
        }
      }
      if (!await prefs.setString(key, jsonEncode(data))) {
        throw Exception('저장 공간이 부족합니다.');
      }
    } catch (_) {
      data = jsonDecode(backup) as RecordData;
      if (_petOwner == owner) {
        _serverPets = (jsonDecode(petBackup) as List).cast<RecordData>();
        _serverDays = (jsonDecode(dayBackup) as List).cast<RecordData>();
        _serverPhotos = (jsonDecode(photoBackup) as List).cast<RecordData>();
      }
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  String hash(String password, String salt) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();
  Future<void> login(String email, String password, {String? name}) async {
    if (auth != null) {
      email = email.trim().toLowerCase();
      if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
        throw Exception('이메일 주소를 확인해 주세요.');
      }
      if (password.length < 8) {
        throw Exception('비밀번호는 8자 이상 입력해 주세요.');
      }
      if (name != null) throw Exception('온라인 회원가입은 아직 지원하지 않습니다.');
      if (petRepository == null) {
        await auth!.login(email, password);
      } else {
        if (busy) throw Exception('처리 중입니다. 잠시 후 다시 시도해 주세요.');
        busy = true;
        try {
          await auth!.login(email, password);
          await _loadServerPets();
        } finally {
          busy = false;
          if (!_disposed) notifyListeners();
        }
      }
      return;
    }
    await change(() {
      email = email.trim().toLowerCase();
      if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
        throw Exception('이메일 주소를 확인해 주세요.');
      }
      if (password.length < 8) {
        throw Exception('비밀번호는 8자 이상 입력해 주세요.');
      }
      final matches = rows('accounts').where((r) => r['email'] == email);
      if (name != null) {
        if (name.trim().isEmpty) {
          throw Exception('이름을 입력해 주세요.');
        }
        if (matches.isNotEmpty) {
          throw Exception('이미 가입한 이메일입니다.');
        }
        final salt = id();
        final uid = id();
        rows('accounts').add({
          'id': uid,
          'email': email,
          'name': name.trim(),
          'salt': salt,
          'hash': hash(password, salt),
        });
        data['session'] = uid;
      } else {
        if (matches.isEmpty ||
            matches.first['hash'] != hash(password, matches.first['salt'])) {
          throw Exception('이메일 또는 비밀번호가 올바르지 않습니다.');
        }
        data['session'] = matches.first['id'];
      }
    });
  }

  Future<void> testLogin() {
    if (auth != null) throw Exception('등록된 계정으로 로그인해 주세요.');
    return change(() {
      if (!rows('accounts').any((r) => r['id'] == 'test')) {
        rows('accounts').add({'id': 'test', 'name': '지우', 'email': '테스트 계정'});
        rows('pets').add({
          'id': id(),
          'owner': 'test',
          'name': '모카',
          'breed': '골든 리트리버',
          'birthday': '2022-04-12',
          'photo': dogPhoto,
        });
        rows('memories').add({
          'id': id(),
          'owner': 'test',
          'title': '너와 함께라서 좋은 하루',
          'note': '오랜만에 공원에서 실컷 뛰어놀았다. 이런 평범한 날들이 오래 기억되길.',
          'date': dayKey(korea(clock())),
          'photo': dogPhoto,
          'anniversary': false,
        });
      }
      data['session'] = 'test';
      ensureDemoCompanion();
      migrateMemoryDays();
    });
  }

  Future<void> logout() =>
      auth != null ? auth!.logout() : change(() => data['session'] = null);

  @override
  void dispose() {
    _disposed = true;
    auth?.removeListener(_authChanged);
    super.dispose();
  }

  void requireUser() {
    if (user == null) {
      throw Exception('로그인이 필요합니다.');
    }
  }

  RecordData meeting(String id) =>
      rows('meetings').firstWhere((r) => r['id'] == id);
  RecordData room(String id, {bool group = false}) =>
      rows(group ? 'groups' : 'meetings').firstWhere((r) => r['id'] == id);

  Future<void> joinGroup(String id) => change(() {
    requireUser();
    final g = room(id, group: true);
    if (g['canceled'] == true) throw Exception('가입할 수 없는 모임입니다.');
    if (joined(g)) throw Exception('이미 가입한 모임입니다.');
    members(g)[user!] = {
      'petIds': participatingPetIds(null),
      'since': clock().toUtc().toIso8601String(),
      'after': rows('groupMessages').length,
    };
  });

  Future<void> createPost(String title, String body, String category) =>
      change(() {
        requireUser();
        if (title.trim().isEmpty ||
            title.trim().length > 60 ||
            body.trim().isEmpty ||
            body.trim().length > 2000 ||
            !petCategories.contains(category)) {
          throw Exception('카테고리와 제목(1~60자), 내용(1~2,000자)을 확인해 주세요.');
        }
        rows('posts').insert(0, {
          'id': id(),
          'owner': user,
          'name': account!['name'],
          'title': title.trim(),
          'body': body.trim(),
          'category': category,
          'at': clock().toUtc().toIso8601String(),
        });
      });
  Map<String, dynamic> members(RecordData m) =>
      m['members'] as Map<String, dynamic>;
  bool joined(RecordData m) => user != null && members(m).containsKey(user);
  String status(RecordData m) {
    if (m['canceled'] == true) {
      return '취소됨';
    }
    if (!clock().toUtc().isBefore(chatClose(DateTime.parse(m['at'])))) {
      return '종료됨';
    }
    if (!clock().toUtc().isBefore(meetingDeadline(DateTime.parse(m['at'])))) {
      return '모집 마감';
    }
    if (members(m).length >= m['capacity']) {
      return '정원 마감';
    }
    return '모집 중';
  }

  List<String> participatingPetIds(List<String>? requested) {
    final ids = requested ?? [?defaultPetId];
    final unique = ids.toSet().toList();
    for (final id in unique) {
      if (!rows('pets').any((p) => p['id'] == id && p['owner'] == user)) {
        throw Exception('내 반려동물만 선택할 수 있어요.');
      }
    }
    return unique;
  }

  List<RecordData> meetingPets(RecordData meeting) {
    final result = <RecordData>[];
    for (final entry in members(meeting).entries) {
      final member = entry.value as Map;
      final ids = member['petIds'] as List?;
      final registered = rows('pets').where((pet) => pet['owner'] == entry.key);
      if (ids != null) {
        result.addAll(registered.where((pet) => ids.contains(pet['id'])));
      } else if (registered.isNotEmpty) {
        result.add(registered.first);
      } else {
        result.addAll(
          (member['petProfiles'] as List? ?? []).map(
            (p) => Map<String, dynamic>.from(p as Map),
          ),
        );
      }
    }
    return result;
  }

  Future<void> join(String mid, {List<String>? petIds}) => change(() {
    requireUser();
    final m = meeting(mid);
    if (joined(m)) {
      throw Exception('이미 참여한 약속입니다.');
    }
    if (status(m) != '모집 중') {
      throw Exception('지금은 참여할 수 없습니다.');
    }
    final selectedPets = participatingPetIds(petIds);
    members(m)[user!] = {
      'petIds': selectedPets,
      'since': clock().toUtc().toIso8601String(),
      'after': rows('messages').length,
    };
  });
  Future<void> leave(String mid, {bool group = false}) => change(() {
    requireUser();
    final m = room(mid, group: group);
    if (!joined(m)) {
      throw Exception(group ? '가입한 모임이 아닙니다.' : '참여 중인 약속이 아닙니다.');
    }
    members(m).remove(user);
  });
  bool canChat(RecordData m) =>
      joined(m) &&
      m['canceled'] != true &&
      (m['kind'] == 'group' ||
          clock().toUtc().isBefore(chatClose(DateTime.parse(m['at']))));
  List<RecordData> messages(String mid, {bool group = false}) {
    final m = room(mid, group: group);
    if (!canChat(m)) {
      return [];
    }
    final membership = members(m)[user];
    return rows(group ? 'groupMessages' : 'messages')
        .asMap()
        .entries
        .where(
          (e) =>
              e.key >= (membership['after'] ?? 0) &&
              e.value['meeting'] == mid &&
              !DateTime.parse(
                e.value['at'],
              ).isBefore(DateTime.parse(membership['since'])),
        )
        .map((e) => e.value)
        .toList();
  }

  // Media uses exactly the same membership boundary as the conversation.
  List<RecordData> chatPhotos(String mid, {bool group = false}) =>
      messages(mid, group: group)
          .where(
            (message) =>
                message['photo'] is String &&
                (message['photo'] as String).isNotEmpty,
          )
          .toList();

  List<RecordData> chatMembers(String mid, {bool group = false}) {
    final m = room(mid, group: group);
    if (!canChat(m)) return [];
    return members(m).entries.map((entry) {
      final accounts = rows('accounts').where((a) => a['id'] == entry.key);
      final pets = meetingPets({
        ...m,
        'members': {entry.key: entry.value},
      });
      return <String, dynamic>{
        'id': entry.key,
        'name': accounts.isNotEmpty
            ? accounts.first['name']
            : pets.isNotEmpty
            ? '${pets.first['name']} 보호자'
            : '참여 보호자',
        'pets': pets,
      };
    }).toList();
  }

  Future<void> send(
    String mid,
    String body, {
    String? photo,
    bool group = false,
  }) => change(() {
    requireUser();
    if (!canChat(room(mid, group: group))) {
      throw Exception('채팅 접근 권한이 없거나 채팅이 종료되었습니다.');
    }
    if ((body.trim().isEmpty && photo == null) || body.trim().length > 1000) {
      throw Exception('메시지는 1~1000자로 입력해 주세요.');
    }
    if (photo != null) {
      final match = RegExp(
        r'^data:image/(jpeg|png|gif|webp);base64,(.+)$',
      ).firstMatch(photo);
      if (match == null) throw Exception('지원하는 사진 파일을 선택해 주세요.');
      final bytes = base64Decode(match.group(2)!);
      if (bytes.isEmpty || bytes.length > 3 * 1024 * 1024) {
        throw Exception('사진 한 장은 3MB 이하로 선택해 주세요.');
      }
    }
    rows(group ? 'groupMessages' : 'messages').add({
      'id': id(),
      'meeting': mid,
      'owner': user,
      'name': account!['name'],
      'body': body.trim(),
      'photo': ?photo,
      'at': clock().toUtc().toIso8601String(),
    });
  });
  Future<void> createMeeting(
    String title,
    MeetingLocation place,
    String note,
    DateTime at,
    int capacity, {
    List<String>? petIds,
    String category = '강아지',
  }) => change(() {
    requireUser();
    if (!petCategories.contains(category)) throw Exception('약속 카테고리를 선택해 주세요.');
    if (title.trim().isEmpty || !place.isValid) {
      throw Exception('약속 이름과 지도에서 선택한 장소를 확인해 주세요.');
    }
    final deadline = meetingDeadline(at);
    if (!deadline.isAfter(clock().toUtc())) {
      throw Exception('약속은 시작까지 6시간 넘게 남은 시간으로 설정해 주세요.');
    }
    if (capacity < 2 || capacity > 50) {
      throw Exception('정원은 2~50명입니다.');
    }
    final selectedPets = participatingPetIds(petIds);
    rows('meetings').add({
      'id': id(),
      'title': title.trim(),
      'category': category,
      'place': place.name.trim(),
      'latitude': place.latitude,
      'longitude': place.longitude,
      'note': note.trim(),
      'at': at.toUtc().toIso8601String(),
      'deadline': deadline.toUtc().toIso8601String(),
      'capacity': capacity,
      'photo': switch (category) {
        '강아지' => dogPhoto,
        '고양이' => catPhoto,
        _ => null,
      },
      'canceled': false,
      'members': {
        user!: {
          'petIds': selectedPets,
          'since': clock().toUtc().toIso8601String(),
          'after': rows('messages').length,
        },
      },
    });
  });
  Future<void> saveOwned(String collection, RecordData row) async {
    if (petRepository != null && collection == 'pets') {
      await _saveServerPet(row);
      return;
    }
    await change(() {
      requireUser();
      if (!['pets', 'memories'].contains(collection)) {
        throw Exception('잘못된 요청입니다.');
      }
      final existing = rows(collection).where((r) => r['id'] == row['id']);
      if (existing.isNotEmpty && existing.first['owner'] != user) {
        throw Exception('수정 권한이 없습니다.');
      }
      if ((row[collection == 'pets' ? 'name' : 'title'] as String? ?? '')
          .trim()
          .isEmpty) {
        throw Exception('이름 또는 제목을 입력해 주세요.');
      }
      final entries = rows(collection);
      final index = entries.indexWhere((entry) => entry['id'] == row['id']);
      final saved = <String, dynamic>{
        if (index >= 0) ...entries[index],
        ...row,
        'id': row['id'] ?? id(),
        'owner': user,
      };
      if (index >= 0) {
        entries[index] = saved;
      } else {
        entries.add(saved);
      }
      migrateMemoryDays();
    });
  }

  Future<void> deleteOwned(String collection, String rid) async {
    if (photoRepository != null && collection == 'memories') {
      await _changeServerPet((owner) async {
        // Retry also works after an earlier delete hid the photo but left its file.
        try {
          await photoRepository!.delete(owner, rid);
        } finally {
          if (!_disposed && user == owner) await _refreshServerPhotos(owner);
        }
      });
      return;
    }
    if (petRepository != null && collection == 'pets') {
      await _changeServerPet((owner) async {
        memoryProfile(petId: rid);
        final memories = [...rows('memories'), ...rows('memoryDays')];
        final rooms = [...rows('meetings'), ...rows('groups')];
        if (memories.any(
              (row) => row['owner'] == owner && row['petId'] == rid,
            ) ||
            rooms.any(
              (room) => (members(room)[owner]?['petIds'] as List? ?? [])
                  .contains(rid),
            )) {
          throw Exception('연결된 기록이 있어 삭제할 수 없습니다.');
        }
        await petRepository!.delete(owner, rid);
        _checkPetSession(owner);
        _serverPets.removeWhere((pet) => pet['id'] == rid);
        if (avatarRepository != null) {
          final clean = await avatarRepository!.cleanup(owner);
          _checkPetSession(owner);
          avatarCleanupPending = !clean;
        }
      });
      return;
    }
    await change(() {
      requireUser();
      if (!['pets', 'memories'].contains(collection)) {
        throw Exception('잘못된 요청입니다.');
      }
      final row = rows(collection).firstWhere((r) => r['id'] == rid);
      if (row['owner'] != user) {
        throw Exception('삭제 권한이 없습니다.');
      }
      rows(collection).remove(row);
    });
  }
}

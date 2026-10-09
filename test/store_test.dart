import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pet_sns/store.dart';
import 'package:pet_sns/meeting_location.dart';

void main() {
  late PetStore s;
  late DateTime now;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    now = DateTime.utc(2026, 10, 1, 3);
    s = PetStore(await SharedPreferences.getInstance(), clock: () => now);
    await s.load();
    await s.testLogin();
  });
  test(
    'test session, pet and memory persist through reload and logout',
    () async {
      await s.logout();
      await s.testLogin();
      expect(s.rows('pets').length, 2);
      final restored = PetStore(s.prefs, clock: () => now);
      await restored.load();
      expect(restored.user, 'test');
      expect(restored.rows('memories').length, 2);
    },
  );
  test(
    'meeting pets follow membership, selection, ownership and persistence',
    () async {
      final dog = s.rows('pets').firstWhere((pet) => pet['name'] == '모카');
      final cat = s.rows('pets').firstWhere((pet) => pet['name'] == '루나');
      expect(s.meetingPets(s.meeting('walk')).map((pet) => pet['name']), [
        '보리',
      ]);
      await s.join('walk', petIds: [cat['id'], cat['id']]);
      expect(s.members(s.meeting('walk'))['test']['petIds'], [cat['id']]);
      expect(s.meetingPets(s.meeting('walk')).map((pet) => pet['name']), [
        '보리',
        '루나',
      ]);
      final restored = PetStore(s.prefs, clock: () => now);
      await restored.load();
      expect(
        restored.meetingPets(restored.meeting('walk')).last['id'],
        cat['id'],
      );
      await restored.leave('walk');
      expect(
        restored
            .meetingPets(restored.meeting('walk'))
            .map((pet) => pet['name']),
        ['보리'],
      );
      await restored.createMeeting(
        '가족 산책',
        const MeetingLocation('공원', 37.54, 127.04),
        '',
        now.add(const Duration(days: 2)),
        6,
        petIds: [dog['id'], cat['id']],
      );
      expect(
        restored
            .meetingPets(restored.rows('meetings').last)
            .map((pet) => pet['name']),
        ['모카', '루나'],
      );
      await restored.login('other@example.com', 'password1', name: '다른 보호자');
      await expectLater(
        restored.join('walk', petIds: [dog['id']]),
        throwsException,
      );
      expect(restored.joined(restored.meeting('walk')), false);
      await restored.join('walk', petIds: []);
      expect(
        restored
            .meetingPets(restored.meeting('walk'))
            .map((pet) => pet['name']),
        ['보리'],
      );
    },
  );
  test(
    'signup normalizes email and rejects duplicate and incorrect credentials',
    () async {
      await s.login(' A@example.com ', 'password1', name: 'A');
      await s.logout();
      await expectLater(s.login('a@example.com', 'wrongpass'), throwsException);
      await s.login('a@example.com', 'password1');
      await expectLater(
        s.login('a@example.com', 'password1', name: 'A'),
        throwsException,
      );
    },
  );
  test('organizer auto joins and has same leave/rejoin behavior', () async {
    await s.createMeeting(
      '산책',
      const MeetingLocation('공원', 37.54, 127.04),
      '',
      now.add(const Duration(days: 2)),
      2,
    );
    final m = s.rows('meetings').last;
    expect(s.members(m).length, 1);
    expect(s.members(m)['test'].containsKey('companions'), false);
    await s.leave(m['id']);
    expect(s.joined(s.meeting(m['id'])), false);
    await s.join(m['id']);
    expect(s.joined(s.meeting(m['id'])), true);
  });
  test('capacity counts accounts, rejects duplicate and over quota', () async {
    final m = s.meeting('walk');
    m['capacity'] = 2;
    await s.join('walk');
    expect(s.members(m).length, 2);
    await expectLater(s.join('walk'), throwsException);
    await s.login('b@example.com', 'password1', name: 'B');
    await expectLater(s.join('walk'), throwsException);
    expect(s.members(s.meeting('walk')).length, 2);
  });
  test('six-hour cutoff overrides legacy deadlines and is exclusive', () async {
    final m = s.meeting('walk');
    final cutoff = meetingDeadline(DateTime.parse(m['at']));
    m['deadline'] = DateTime.parse(m['at']).toIso8601String();
    now = cutoff.subtract(const Duration(microseconds: 1));
    await s.join('walk');
    await s.leave('walk');
    now = cutoff;
    expect(s.status(s.meeting('walk')), '모집 마감');
    await expectLater(s.join('walk'), throwsException);
    await s.prefs.setString(PetStore.key, jsonEncode(s.data));
    final restored = PetStore(s.prefs, clock: () => now);
    await restored.load();
    expect(DateTime.parse(restored.meeting('walk')['deadline']), cutoff);
  });
  test(
    'map location and cutoff persist; invalid or already closed creation is rejected',
    () async {
      final at = now.add(const Duration(hours: 7));
      await s.createMeeting(
        '공원 산책',
        const MeetingLocation('공원 정문', 37.54, 127.04),
        '',
        at,
        6,
      );
      final m = s.rows('meetings').last;
      expect(DateTime.parse(m['deadline']), now.add(const Duration(hours: 1)));
      final restored = PetStore(s.prefs, clock: () => now);
      await restored.load();
      final place = MeetingLocation.fromRecord(restored.rows('meetings').last)!;
      expect(place.latitude, 37.54);
      expect(place.longitude, 127.04);
      expect(place.name, '공원 정문');
      final count = s.rows('meetings').length;
      await expectLater(
        s.createMeeting(
          '마감',
          meetingPlaceExamples.first,
          '',
          now.add(const Duration(hours: 6)),
          6,
        ),
        throwsException,
      );
      await expectLater(
        s.createMeeting(
          '위치 오류',
          const MeetingLocation('공원', 91, 127),
          '',
          at,
          6,
        ),
        throwsException,
      );
      await expectLater(
        s.createMeeting('정원 오류', meetingPlaceExamples.first, '', at, 1),
        throwsException,
      );
      expect(s.rows('meetings').length, count);
    },
  );
  test('deadline is exclusive and applies to rejoin and test user', () async {
    await s.join('walk');
    await s.leave('walk');
    now = DateTime.parse(s.meeting('walk')['deadline']);
    await expectLater(s.join('walk'), throwsException);
  });
  test(
    'leave hides chat; rejoin excludes earlier messages; reconnect keeps timestamp',
    () async {
      await s.join('walk');
      await s.send('walk', 'old');
      final since = s.members(s.meeting('walk'))['test']['since'];
      await s.logout();
      await s.testLogin();
      expect(s.members(s.meeting('walk'))['test']['since'], since);
      expect(s.messages('walk').length, 1);
      await s.leave('walk');
      expect(s.messages('walk'), isEmpty);
      await expectLater(s.send('walk', 'forbidden'), throwsException);
      await s.join('walk');
      expect(s.messages('walk'), isEmpty);
      await s.send('walk', 'new');
      expect(s.messages('walk').single['body'], 'new');
    },
  );
  test('first participation excludes prior participant messages', () async {
    await s.join('walk');
    await s.send('walk', 'old');
    await s.login('b@example.com', 'password1', name: 'B');
    await s.join('walk');
    expect(s.messages('walk'), isEmpty);
    await s.send('walk', 'hello');
    expect(s.messages('walk').length, 1);
  });
  test(
    'KST closure is midnight after following day including year boundary',
    () {
      expect(
        chatClose(DateTime.utc(2026, 12, 31, 14)),
        DateTime.utc(2027, 1, 1, 15),
      );
      expect(
        chatClose(DateTime.utc(2026, 12, 31, 15)),
        DateTime.utc(2027, 1, 2, 15),
      );
    },
  );
  test('chat stays open after deadline and closes exactly at cutoff', () async {
    await s.join('walk');
    final close = chatClose(DateTime.parse(s.meeting('walk')['at']));
    now = close.subtract(const Duration(microseconds: 1));
    await s.send('walk', 'last');
    expect(s.canChat(s.meeting('walk')), true);
    now = close;
    expect(s.canChat(s.meeting('walk')), false);
    expect(s.messages('walk'), isEmpty);
    await expectLater(s.send('walk', 'late'), throwsException);
  });
  test('canceled meetings block both chat and new registrations', () async {
    await s.join('walk');
    s.meeting('walk')['canceled'] = true;
    expect(s.messages('walk'), isEmpty);
    await expectLater(s.send('walk', 'no'), throwsException);
    await s.leave('walk');
    await expectLater(s.join('walk'), throwsException);
  });
  test(
    'invalid counts, blank messages and dates fail without mutation',
    () async {
      await expectLater(
        s.createMeeting('x', const MeetingLocation('p', 37.5, 127), '', now, 2),
        throwsException,
      );
      await s.join('walk');
      await expectLater(s.send('walk', '  '), throwsException);
      await expectLater(s.send('walk', 'a' * 1001), throwsException);
      expect(s.rows('messages'), isEmpty);
    },
  );
  test('owned records reject another account editing or deleting', () async {
    final pet = Map<String, dynamic>.from(s.rows('pets').first);
    await s.login('b@example.com', 'password1', name: 'B');
    await expectLater(
      s.saveOwned('pets', {...pet, 'name': 'stolen'}),
      throwsException,
    );
    await expectLater(s.deleteOwned('pets', pet['id']), throwsException);
    expect(s.rows('pets').first['name'], '모카');
  });
  test('simultaneous join calls cannot overbook', () async {
    s.meeting('walk')['capacity'] = 2;
    final results = await Future.wait([
      s.join('walk').then((_) => true).catchError((_) => false),
      s.join('walk').then((_) => true).catchError((_) => false),
    ]);
    expect(results.where((v) => v).length, 1);
    expect(s.members(s.meeting('walk')).length, 2);
  });
  test(
    'legacy photo text migrates once to an owner-specific daily journal',
    () async {
      s.data['memoryDays'] = <RecordData>[];
      s.data['memories'] = <RecordData>[
        {
          'id': 'a',
          'owner': 'test',
          'date': '2026-09-30',
          'photo': 'a',
          'title': '산책',
          'note': '공원',
          'anniversary': false,
        },
        {
          'id': 'b',
          'owner': 'test',
          'date': '2026-09-30',
          'photo': 'b',
          'title': '생일',
          'note': '케이크',
          'anniversary': true,
        },
        {
          'id': 'c',
          'owner': 'other',
          'date': '2026-09-30',
          'photo': 'c',
          'title': '다른 계정',
          'note': '비공개',
        },
      ];
      await s.prefs.setString(PetStore.key, jsonEncode(s.data));
      final restored = PetStore(s.prefs, clock: () => now);
      await restored.load();
      expect(restored.memoryDay('2026-09-30')['title'], '산책\n\n생일');
      expect(restored.memoryDay('2026-09-30')['note'], '공원\n\n케이크');
      expect(restored.memoryDay('2026-09-30')['anniversary'], true);
      expect(restored.rows('memoryDays').length, 2);
      expect(
        restored
            .rows('memories')
            .every(
              (photo) =>
                  !photo.containsKey('title') && !photo.containsKey('note'),
            ),
        true,
      );
      await restored.load();
      expect(restored.memoryDay('2026-09-30')['title'], '산책\n\n생일');
      expect(restored.rows('memories').length, 3);
    },
  );
  test(
    'one daily journal survives photo addition, movement and last-photo deletion',
    () async {
      await s.saveMemoryDay('2026-09-30', '하루', '메모', true);
      await s.saveMemoryDay('2026-09-30', '수정된 하루', '수정된 메모', false);
      await s.saveMemoryPhotos('2026-09-30', ['one', 'two', 'three']);
      expect(
        s.rows('memoryDays').where((day) => day['date'] == '2026-09-30').length,
        1,
      );
      final photos = s
          .rows('memories')
          .where((photo) => photo['date'] == '2026-09-30')
          .toList();
      await s.saveMemoryPhotos('2026-10-01', [
        'one',
      ], existingId: photos.first['id']);
      for (final photo in photos.skip(1)) {
        await s.deleteOwned('memories', photo['id']);
      }
      expect(s.memoryDay('2026-09-30')['title'], '수정된 하루');
      expect(s.memoryDay('2026-09-30')['note'], '수정된 메모');
      final restored = PetStore(s.prefs, clock: () => now);
      await restored.load();
      expect(restored.memoryDay('2026-09-30')['title'], '수정된 하루');
    },
  );
  test('Day 0 is explicit, inclusive, persisted and validated', () async {
    expect(s.memoryOrigin, isNull);
    await s.setMemoryOrigin('firstMeeting', DateTime(2026, 9, 1));
    expect(daysBetween(s.memoryOrigin!, DateTime(2026, 9, 1)), 0);
    expect(daysBetween(s.memoryOrigin!, DateTime(2026, 10, 1)), 30);
    await expectLater(
      s.setMemoryOrigin('firstMeeting', DateTime(2026, 10, 2)),
      throwsException,
    );
    await expectLater(
      s.saveMemoryPhotos('2026-08-31', ['photo']),
      throwsException,
    );
    final restored = PetStore(s.prefs, clock: () => now);
    await restored.load();
    expect(restored.memoryOrigin, DateTime(2026, 9, 1));
    expect(restored.memoryProfile()['memoryOriginType'], 'firstMeeting');
  });
  test(
    'first-photo Day 0 moves earlier on backfill and survives deleting that photo',
    () async {
      await s.setMemoryOrigin('firstPhoto', DateTime(2026, 1, 1));
      expect(s.memoryOrigin, DateTime(2026, 10, 1));
      await s.saveMemoryPhotos('2026-09-15', ['earlier']);
      expect(s.memoryOrigin, DateTime(2026, 9, 15));
      await s.deleteOwned('memories', s.rows('memories').last['id']);
      expect(s.memoryOrigin, DateTime(2026, 9, 15));
      await s.login('new@example.com', 'password1', name: '새 계정');
      expect(s.memoryOrigin, isNull);
      expect(s.memoryDay('2026-10-01')['title'], '');
    },
  );
  test(
    'photo edits enforce ownership and reject empty or future uploads atomically',
    () async {
      final photo = Map<String, dynamic>.from(s.rows('memories').first);
      await expectLater(
        s.saveMemoryPhotos('2026-10-02', ['future']),
        throwsException,
      );
      await expectLater(s.saveMemoryPhotos('2026-10-01', []), throwsException);
      await s.login('new@example.com', 'password1', name: '새 계정');
      await expectLater(
        s.saveMemoryPhotos('2026-10-01', [
          'replacement',
        ], existingId: photo['id']),
        throwsException,
      );
      expect(s.rows('memories').first['photo'], photo['photo']);
    },
  );
  test(
    'pets keep separate photos, Day journals and Day 0 after reload',
    () async {
      final first = s.rows('pets').first;
      final second = s.rows('pets').last;
      await s.setMemoryOrigin(
        'firstMeeting',
        DateTime(2026, 9, 1),
        petId: first['id'],
      );
      await s.setMemoryOrigin(
        'firstPhoto',
        DateTime(2026, 10, 1),
        petId: second['id'],
      );
      await s.saveMemoryDay(
        '2026-10-01',
        '모카의 하루',
        '산책',
        false,
        petId: first['id'],
      );
      await s.saveMemoryDay(
        '2026-10-01',
        '루나의 하루',
        '낮잠',
        false,
        petId: second['id'],
      );
      await s.saveMemoryPhotos('2026-09-20', [
        'cat-photo',
      ], petId: second['id']);
      expect(s.memoryOriginFor(first['id']), DateTime(2026, 9, 1));
      expect(s.memoryOriginFor(second['id']), DateTime(2026, 9, 20));
      expect(s.memoryDay('2026-10-01', petId: first['id'])['note'], '산책');
      expect(s.memoryDay('2026-10-01', petId: second['id'])['note'], '낮잠');
      expect(s.rows('memories').last['petId'], second['id']);
      final restored = PetStore(s.prefs, clock: () => now);
      await restored.load();
      expect(
        restored.memoryDay('2026-10-01', petId: first['id'])['title'],
        '모카의 하루',
      );
      expect(
        restored.memoryDay('2026-10-01', petId: second['id'])['title'],
        '루나의 하루',
      );
      expect(restored.memoryOriginFor(first['id']), DateTime(2026, 9, 1));
      await restored.login('other@example.com', 'password1', name: '다른 보호자');
      await expectLater(
        restored.saveMemoryPhotos('2026-10-01', ['photo'], petId: first['id']),
        throwsException,
      );
      await expectLater(
        restored.saveMemoryDay(
          '2026-10-01',
          '잘못된 수정',
          '',
          false,
          petId: first['id'],
        ),
        throwsException,
      );
    },
  );
  test(
    'profile edits preserve carousel order and the pet Day 0 settings',
    () async {
      final pet = s.rows('pets').first;
      final order = s.rows('pets').map((pet) => pet['id']).toList();
      await s.setMemoryOrigin(
        'firstMeeting',
        DateTime(2026, 9, 1),
        petId: pet['id'],
      );
      await s.saveOwned('pets', {
        'id': pet['id'],
        'name': '모카 새 이름',
        'breed': pet['breed'],
        'birthday': pet['birthday'],
        'photo': pet['photo'],
      });
      expect(s.rows('pets').map((pet) => pet['id']).toList(), order);
      expect(s.memoryOriginFor(pet['id']), DateTime(2026, 9, 1));
    },
  );
  test(
    'existing one-pet demo is upgraded once without changing its memories',
    () async {
      final original = s.rows('pets').first['id'];
      s.rows('pets').removeWhere((pet) => pet['id'] != original);
      s.rows('memories').removeWhere((photo) => photo['petId'] != original);
      s.rows('memoryDays').removeWhere((day) => day['petId'] != original);
      s.account.remove('multiPetDemoV1');
      s.account['memoryOriginType'] = 'firstMeeting';
      s.account['memoryOriginDate'] = '2026-09-01';
      final oldPhoto = s.rows('memories').first;
      oldPhoto.remove('petId');
      s.rows('memoryDays').first.remove('petId');
      await s.prefs.setString(PetStore.key, jsonEncode(s.data));
      final restored = PetStore(s.prefs, clock: () => now);
      await restored.load();
      expect(restored.rows('pets').length, 2);
      expect(restored.rows('memories').first['petId'], original);
      expect(restored.memoryOriginFor(original), DateTime(2026, 9, 1));
      expect(
        restored.memoryDay('2026-10-01', petId: original)['title'],
        '너와 함께라서 좋은 하루',
      );
      await restored.load();
      await restored.testLogin();
      expect(restored.rows('pets').length, 2);
      expect(restored.rows('memories').length, 2);
    },
  );
}

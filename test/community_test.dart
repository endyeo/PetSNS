import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pet_sns/main.dart';
import 'package:pet_sns/store.dart';
import 'package:pet_sns/meeting_location.dart';
import 'package:pet_sns/meeting_map.dart';

const testPhoto =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=';

void main() {
  late PetStore store;
  late DateTime now;
  setUp(() async {
    now = DateTime.utc(2026, 10, 1, 3);
    SharedPreferences.setMockInitialValues({});
    store = PetStore(await SharedPreferences.getInstance(), clock: () => now);
    await store.load();
    await store.testLogin();
  });

  test(
    'legacy migration preserves records and adds categories, posts and groups once',
    () async {
      final snapshot = jsonDecode(jsonEncode(store.data)) as RecordData;
      snapshot.remove('groups');
      snapshot.remove('groupMessages');
      snapshot.remove('posts');
      for (final meeting in snapshot['meetings']) {
        meeting.remove('category');
      }
      await store.prefs.setString(PetStore.key, jsonEncode(snapshot));
      final restored = PetStore(store.prefs, clock: () => now);
      await restored.load();
      expect(restored.rows('meetings').map((m) => m['category']), [
        '강아지',
        '강아지',
      ]);
      expect(restored.rows('groups').length, 3);
      expect(restored.rows('posts').length, 3);
      expect(restored.rows('memories').length, store.rows('memories').length);
      await restored.joinGroup('cat-friends');
      await restored.createPost('고양이 이야기', '창가에서 쉬었어요.', '고양이');
      await restored.load();
      expect(
        restored.joined(restored.room('cat-friends', group: true)),
        isTrue,
      );
      expect(restored.rows('posts').length, 4);
      expect(restored.rows('groups').length, 3);
    },
  );

  test(
    'meeting categories persist and invalid categories do not create records',
    () async {
      for (final category in petCategories) {
        await store.createMeeting(
          category,
          const MeetingLocation('공원', 37.54, 127.04),
          '',
          now.add(const Duration(days: 2)),
          6,
          category: category,
        );
        expect(store.rows('meetings').last['category'], category);
      }
      final count = store.rows('meetings').length;
      await expectLater(
        store.createMeeting(
          '잘못된 분류',
          const MeetingLocation('공원', 37.54, 127.04),
          '',
          now.add(const Duration(days: 2)),
          6,
          category: '잘못된 분류',
        ),
        throwsException,
      );
      expect(store.rows('meetings').length, count);
      final restored = PetStore(store.prefs, clock: () => now);
      await restored.load();
      expect(restored.rows('meetings').last['category'], '기타');
    },
  );

  test(
    'groups isolate membership, chat and photos from appointments and other groups',
    () async {
      await expectLater(
        store.send('cat-friends', '안녕', group: true),
        throwsException,
      );
      expect(store.messages('cat-friends', group: true), isEmpty);
      await store.joinGroup('cat-friends');
      await store.join('walk');
      await store.send('walk', '약속 대화');
      await store.send('cat-friends', '모임 사진', photo: testPhoto, group: true);
      expect(store.messages('walk').single['body'], '약속 대화');
      expect(
        store.chatPhotos('cat-friends', group: true).single['body'],
        '모임 사진',
      );
      expect(
        store.chatMembers('cat-friends', group: true).single['name'],
        '지우',
      );
      await store.login('other@example.com', 'password1', name: '다른 집사');
      await store.joinGroup('cat-friends');
      expect(store.chatPhotos('cat-friends', group: true), isEmpty);
      await store.send('cat-friends', '새 대화', group: true);
      await store.joinGroup('dog-walkers');
      expect(store.messages('dog-walkers', group: true), isEmpty);
      await store.leave('cat-friends', group: true);
      expect(store.chatMembers('cat-friends', group: true), isEmpty);
      await store.joinGroup('cat-friends');
      expect(store.messages('cat-friends', group: true), isEmpty);
      expect(store.joined(store.meeting('walk')), isFalse);
      now = now.add(const Duration(days: 30));
      await store.send('cat-friends', '계속 이어지는 모임', group: true);
      expect(
        store.messages('cat-friends', group: true).single['body'],
        '계속 이어지는 모임',
      );
    },
  );

  test('post creation validates, attributes and persists', () async {
    final count = store.rows('posts').length;
    await expectLater(store.createPost('', '내용', '강아지'), throwsException);
    await expectLater(store.createPost('제목', '', '강아지'), throwsException);
    expect(store.rows('posts').length, count);
    await store.createPost('  오늘의 산책  ', '  행복한 하루  ', '강아지');
    final restored = PetStore(store.prefs, clock: () => now);
    await restored.load();
    expect(restored.rows('posts').first['title'], '오늘의 산책');
    expect(restored.rows('posts').first['body'], '행복한 하루');
    expect(restored.rows('posts').first['owner'], 'test');
    await store.logout();
    await expectLater(store.createPost('제목', '내용', '기타'), throwsException);
  });

  for (final width in [320.0, 390.0, 1440.0]) {
    Future<void> openHome(WidgetTester tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ko'),
          supportedLocales: const [Locale('ko')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: ListenableBuilder(
            listenable: store,
            builder: (_, _) => Home(store: store),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> navigate(WidgetTester tester, String label) async {
      if (width < 950) {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(label),
          ),
        );
      } else {
        await tester.tap(find.text(label == '약속' ? '함께하는 약속' : label).first);
      }
      await tester.pumpAndSettle();
    }

    testWidgets(
      'P controls stay centered above navigation while scrolling at $width',
      (tester) async {
        for (var i = 0; i < 12; i++) {
          store.rows('meetings').add({
            ...store.meeting('walk'),
            'id': 'long-list-$i',
          });
        }
        await openHome(tester);
        await navigate(tester, '약속');
        final toggle = find.byKey(const ValueKey('meeting-view-switch'));
        final fab = find.byKey(const ValueKey('meeting-create-fab'));
        final bottom = width < 950
            ? tester.getTopLeft(find.byType(NavigationBar)).dy
            : 1000.0;
        final centerX = width < 950 ? width / 2 : (width + 226) / 2;
        final original = tester.getCenter(toggle);
        final originalFabSize = tester.getSize(fab);
        expect(original.dx, closeTo(centerX, 0.1));
        expect(tester.getBottomLeft(toggle).dy, lessThan(bottom));
        expect(tester.getBottomLeft(toggle).dy, greaterThan(bottom - 90));
        expect(tester.getCenter(fab).dy, closeTo(original.dy, 0.1));
        expect(tester.getTopRight(fab).dx, closeTo(width - 16, 0.1));
        expect(
          tester.getTopLeft(fab).dx,
          greaterThan(tester.getTopRight(toggle).dx),
        );
        expect(find.text('LOCAL DEMO'), findsOneWidget);
        expect(find.text('PetSNS'), findsOneWidget);
        expect(find.byTooltip('로그아웃'), findsOneWidget);
        expect(find.text('가벼운 산책부터 즐거운 만남까지.'), findsNothing);
        expect(
          tester
              .getTopLeft(find.byKey(const ValueKey('meeting-categories')))
              .dy,
          inExclusiveRange(
            tester.getBottomLeft(find.byKey(const ValueKey('app-header'))).dy,
            tester.getBottomLeft(find.byKey(const ValueKey('app-header'))).dy +
                45,
          ),
        );
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -600),
        );
        await tester.pumpAndSettle();
        expect(tester.getCenter(toggle), original);
        await tester.tap(find.text('지도'));
        await tester.pumpAndSettle();
        expect(fab, findsNothing);
        expect(tester.getCenter(toggle), original);
        await tester.tap(find.text('목록'));
        await tester.pump();
        expect(tester.getCenter(toggle), original);
        expect(tester.getSize(fab), originalFabSize);
        await tester.pumpAndSettle();
        expect(tester.getCenter(toggle), original);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'P category filters list and map; create plus only in list at $width',
      (tester) async {
        await store.createMeeting(
          '고양이 만남',
          const MeetingLocation('공원', 37.54, 127.04),
          '',
          now.add(const Duration(days: 2)),
          6,
          category: '고양이',
        );
        await openHome(tester);
        await navigate(tester, '약속');
        final fab = find.byKey(const ValueKey('meeting-create-fab'));
        expect(fab, findsOneWidget);
        expect(
          tester.widget<FloatingActionButton>(fab).shape,
          isA<CircleBorder>(),
        );
        expect(find.text('약속 만들기'), findsNothing);
        expect(find.text('꼬리 흔들며, 한강 산책'), findsOneWidget);
        expect(find.text('고양이 만남'), findsOneWidget);
        expect(
          tester
              .widget<SegmentedButton<String>>(
                find.byKey(const ValueKey('meeting-categories')),
              )
              .selected,
          {'전체'},
        );
        await tester.tap(find.text('고양이'));
        await tester.pumpAndSettle();
        expect(find.text('고양이 만남'), findsOneWidget);
        expect(find.text('꼬리 흔들며, 한강 산책'), findsNothing);
        await tester.tap(find.text('지도'));
        await tester.pumpAndSettle();
        expect(fab, findsNothing);
        expect(
          tester
              .widget<PetMeetingMap>(
                find.byKey(const ValueKey('meetings-map-view')),
              )
              .locations
              .length,
          1,
        );
        await tester.tap(find.text('목록'));
        await tester.pumpAndSettle();
        await tester.tap(fab);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<DropdownButtonFormField<String>>(
                find.byKey(const ValueKey('meeting-category-input')),
              )
              .initialValue,
          '고양이',
        );
        await tester.tap(find.text('취소'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets('C plain tabs, group join and joined rooms first at $width', (
      tester,
    ) async {
      await openHome(tester);
      await navigate(tester, '채팅');
      expect(find.byKey(const ValueKey('app-header')), findsOneWidget);
      expect(find.text('PetSNS'), findsOneWidget);
      expect(find.byTooltip('로그아웃'), findsOneWidget);
      final tabs = tester.widget<TabBar>(
        find.byKey(const ValueKey('chat-room-tabs')),
      );
      expect(tabs.tabs.map((t) => (t as Tab).text), ['게시글', '모임방', '약속방']);
      expect(find.text('우리끼리 나누는 이야기'), findsNothing);
      expect(find.byKey(const ValueKey('post-card-post-walk')), findsOneWidget);
      await tester.tap(find.text('모임방'));
      await tester.pumpAndSettle();
      expect(find.text('함께할 모임을 찾아보세요'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('group-card-cat-friends')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('가입하고 모임방 열기'));
      await tester.pumpAndSettle();
      expect(store.joined(store.room('cat-friends', group: true)), isTrue);
      expect(find.textContaining('채팅 종료 예정'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('chat-input')),
        '새 모임 인사',
      );
      await tester.tap(find.byTooltip('메시지 보내기'));
      await tester.pumpAndSettle();
      expect(find.text('새 모임 인사'), findsOneWidget);
      await tester.tap(find.byTooltip('채팅방 메뉴'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('멤버'));
      await tester.pumpAndSettle();
      expect(find.text('지우 · 나'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(ChatScreen), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('가입한 모임'), findsOneWidget);
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('group-card-cat-friends')))
            .dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const ValueKey('group-card-dog-walkers')))
              .dy,
        ),
      );
      await tester.tap(find.text('약속방'));
      await tester.pumpAndSettle();
      expect(find.text('아직 참여한 채팅이 없어요'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('posts can be written and opened at $width', (tester) async {
      await openHome(tester);
      await navigate(tester, '채팅');
      await tester.tap(find.byKey(const ValueKey('post-create')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('post-title-input')),
        '새 게시글 제목',
      );
      await tester.enterText(
        find.byKey(const ValueKey('post-body-input')),
        '오늘의 일상을 나눠요.',
      );
      await tester.tap(find.text('게시하기'));
      await tester.pumpAndSettle();
      expect(find.text('새 게시글 제목'), findsOneWidget);
      await tester.tap(find.text('새 게시글 제목'));
      await tester.pumpAndSettle();
      expect(find.byType(SelectableText), findsOneWidget);
      await tester.tap(find.text('닫기'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

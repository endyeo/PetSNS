import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pet_sns/main.dart';
import 'package:pet_sns/store.dart';
import 'package:pet_sns/meeting_map.dart';

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets(
      'P map switch stays above navigation and marker opens the same meeting at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final store = PetStore(
          await SharedPreferences.getInstance(),
          clock: () => DateTime.utc(2026, 10, 1, 3),
        );
        await store.load();
        await store.testLogin();
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
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('약속'),
          ),
        );
        await tester.pumpAndSettle();
        final toggle = find.byKey(const ValueKey('meeting-view-switch'));
        expect(
          tester.getBottomLeft(toggle).dy,
          lessThan(tester.getTopLeft(find.byType(NavigationBar)).dy),
        );
        expect(find.text('꼬리 흔들며, 한강 산책'), findsOneWidget);
        await tester.tap(find.text('지도'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('meetings-map-view')), findsOneWidget);
        expect(
          tester
              .widget<PetMeetingMap>(
                find.byKey(const ValueKey('meetings-map-view')),
              )
              .locations
              .length,
          2,
        );
        await tester.tap(find.byKey(const ValueKey('meeting-map-marker-0')));
        await tester.pumpAndSettle();
        expect(find.text('꼬리 흔들며, 한강 산책'), findsOneWidget);
        expect(find.text('동반 인원 (본인 제외)'), findsNothing);
        await tester.tap(find.text('닫기'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('목록'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('meeting-card-walk')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  for (final width in [320.0, 390.0]) {
    testWidgets('P shows participating pets and four information rows at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final store = PetStore(
        await SharedPreferences.getInstance(),
        clock: () => DateTime.utc(2026, 10, 1, 3),
      );
      await store.load();
      await store.testLogin();
      store.meeting('walk')['distanceMeters'] = 1800;
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
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('약속'),
        ),
      );
      await tester.pumpAndSettle();
      final first = find.byKey(const ValueKey('meeting-card-walk'));
      final second = find.byKey(const ValueKey('meeting-card-picnic'));
      expect(
        tester.getTopLeft(second).dy,
        greaterThan(tester.getBottomLeft(first).dy),
      );
      expect(find.text(' / 1.8km'), findsOneWidget);
      expect(find.text(' / 거리 미확인'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('meeting-pet-profile-demo-host')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          ValueKey(
            "meeting-pet-profile-${store.rows('pets').firstWhere((p) => p['name'] == '모카')['id']}",
          ),
        ),
        findsNothing,
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('meeting-pets-walk'))).dx,
        lessThan(
          tester
              .getTopLeft(find.byKey(const ValueKey('meeting-title-walk')))
              .dx,
        ),
      );
      final rowKeys = ['title', 'place', 'time', 'status'];
      for (var i = 1; i < rowKeys.length; i++) {
        expect(
          tester
              .getTopLeft(find.byKey(ValueKey('meeting-${rowKeys[i]}-walk')))
              .dy,
          greaterThan(
            tester
                .getTopLeft(
                  find.byKey(ValueKey('meeting-${rowKeys[i - 1]}-walk')),
                )
                .dy,
          ),
        );
      }
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('meeting-status-walk')),
          matching: find.text('1 / 6'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('꼬리 흔들며, 한강 산책'));
      await tester.pumpAndSettle();
      final dog = store.rows('pets').firstWhere((pet) => pet['name'] == '모카');
      final cat = store.rows('pets').firstWhere((pet) => pet['name'] == '루나');
      await tester.tap(find.byKey(ValueKey("meeting-pet-choice-${dog['id']}")));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey("meeting-pet-choice-${cat['id']}")));
      await tester.pumpAndSettle();
      await tester.tap(find.text('참여하기'));
      await tester.pumpAndSettle();
      expect(store.members(store.meeting('walk'))['test']['petIds'], [
        cat['id'],
      ]);
      expect(
        find.byKey(ValueKey("meeting-pet-profile-${cat['id']}")),
        findsOneWidget,
      );
      expect(
        find.byKey(
          ValueKey(
            "meeting-pet-profile-${store.rows('pets').firstWhere((p) => p['name'] == '모카')['id']}",
          ),
        ),
        findsNothing,
      );
      expect(find.text('모집 중 · 참여 중'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('meeting-status-walk')),
          matching: find.text('2 / 6'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  for (final width in [320.0, 390.0, 1440.0]) {
    testWidgets(
      'H pet slides, connected family footer and weekly memories at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final store = PetStore(
          await SharedPreferences.getInstance(),
          clock: () => DateTime.utc(2026, 10, 1, 3),
        );
        await store.load();
        await store.testLogin();
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
        expect(find.text('함께라서 더 좋은 하루 🐾'), findsOneWidget);
        expect(find.text('추억 기록'), findsOneWidget);
        expect(
          tester.widget<Text>(find.byKey(const ValueKey('home-pet-name'))).data,
          '모카',
        );
        expect(find.text('너와 나의 보통 날, 가장 특별한 순간.'), findsNothing);
        expect(find.text('우리의 추억 한 조각'), findsNothing);
        expect(find.text('산책 친구를 만나볼까요?'), findsNothing);
        expect(find.text('EVERY PAW LEAVES A LITTLE LOVE.'), findsNothing);
        final family = find.byKey(const ValueKey('home-family'));
        final banner = find.byKey(const ValueKey('home-pet-banner'));
        expect(tester.getTopLeft(family).dy, tester.getBottomLeft(banner).dy);
        expect(tester.getSize(family).width, tester.getSize(banner).width);
        expect(find.text('가족 1 / 2 마리'), findsNothing);
        expect(find.textContaining('생일'), findsNothing);
        expect(find.text('좌우로 넘겨 보세요'), findsNothing);
        expect(find.byKey(const ValueKey('home-pet-indicators')), findsOneWidget);
        expect(find.text('1 / 2'), findsNothing);
        expect(
          find.byKey(const ValueKey('home-week-calendar')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('home-day-photo-0')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('home-memory-collage')),
          findsOneWidget,
        );
        expect(find.text('오늘의 추억을 기록하기'), findsNothing);
        final collage = find.byKey(const ValueKey('home-memory-collage'));
        final dayTitle = find.byKey(const ValueKey('home-memory-title'));
        expect(tester.getSize(collage), const Size(80, 80));
        expect(
          tester.getTopLeft(dayTitle).dx,
          greaterThan(tester.getTopRight(collage).dx),
        );
        expect(find.text('약속 없이, 우리만의 느긋한 하루'), findsOneWidget);
        final pages = find.byKey(const ValueKey('home-pet-pages'));
        final recordButton = find.byKey(const ValueKey('home-record-memory'));
        final buttonPosition = tester.getTopLeft(recordButton);
        final buttonElement = tester.element(recordButton);
        expect(
          find.descendant(of: pages, matching: find.byType(FilledButton)),
          findsNothing,
        );
        expect(
          find.descendant(
            of: pages,
            matching: find.byKey(const ValueKey('home-pet-name')),
          ),
          findsNothing,
        );
        expect(find.byTooltip('다음 반려동물'), findsNothing);
        await tester.drag(pages, Offset(-tester.getSize(pages).width * .8, 0));
        await tester.pumpAndSettle();
        expect(find.text('추억 기록'), findsOneWidget);
        expect(
          tester.widget<Text>(find.byKey(const ValueKey('home-pet-name'))).data,
          '루나',
        );
        expect(find.text('가족 2 / 2 마리'), findsNothing);
        expect(find.text('2 / 2'), findsNothing);
        expect(tester.getTopLeft(recordButton), buttonPosition);
        expect(tester.element(recordButton), same(buttonElement));
        await tester.tap(find.byKey(const ValueKey('home-record-memory')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('memory-editor-pet')))
              .data,
          '루나의 추억',
        );
        await tester.tap(find.text('닫기'));
        await tester.pumpAndSettle();
        expect(find.text('루나와 느긋한 오후'), findsOneWidget);
        expect(find.text('너와 함께라서 좋은 하루'), findsNothing);
        final cat = store.rows('pets').firstWhere((pet) => pet['name'] == '루나');
        await tester.tap(
          find.byKey(ValueKey("memory-pet-selector-${cat['id']}")),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('모카').last);
        await tester.pumpAndSettle();
        expect(find.text('너와 함께라서 좋은 하루'), findsOneWidget);
        expect(find.text('루나와 느긋한 오후'), findsNothing);
        if (width < 950) {
          await tester.tap(find.text('하루'));
        } else {
          await tester.tap(find.text('우리의 하루'));
        }
        await tester.pumpAndSettle();
        expect(find.text('추억 기록'), findsOneWidget);
        expect(
          tester.widget<Text>(find.byKey(const ValueKey('home-pet-name'))).data,
          '모카',
        );
        await tester.tap(family);
        await tester.pumpAndSettle();
        expect(find.text('우리 집 작은 가족'), findsOneWidget);
        expect(find.text('모카'), findsOneWidget);
        expect(find.text('루나'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets(
    'H selected date shows a merged photo title row and joined appointment profiles',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final store = PetStore(
        await SharedPreferences.getInstance(),
        clock: () => DateTime.utc(2026, 10, 1, 3),
      );
      await store.load();
      await store.testLogin();
      final dog = store
          .rows('pets')
          .firstWhere((p) => p['owner'] == store.user && p['name'] == '모카');
      final cat = store
          .rows('pets')
          .firstWhere((p) => p['owner'] == store.user && p['name'] == '루나');
      store.data['memories'] = <RecordData>[];
      const image =
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=';
      await store.saveMemoryPhotos('2026-10-01', [
        image,
        image,
        image,
        image,
      ], petId: dog['id']);
      await store.saveMemoryPhotos('2026-09-30', [image], petId: cat['id']);
      await store.saveMemoryDay(
        '2026-10-01',
        '함께 걸은 가을',
        '',
        false,
        petId: dog['id'],
      );
      await store.setMemoryOrigin(
        'firstMeeting',
        DateTime(2026, 9, 1),
        petId: dog['id'],
      );
      await store.setMemoryOrigin(
        'firstMeeting',
        DateTime(2026, 9, 30),
        petId: cat['id'],
      );
      await store.join('walk', petIds: [dog['id']]);
      store.meeting('walk')['at'] = DateTime.utc(
        2026,
        10,
        1,
        16,
      ).toIso8601String();
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
      expect(find.text('Day 30'), findsNothing);
      expect(find.textContaining('Day '), findsNothing);
      expect(find.text('D+31'), findsOneWidget);
      Color? dateColor(String date) =>
          (tester
                      .widget<Container>(
                        find.byKey(ValueKey('home-date-$date')),
                      )
                      .decoration
                  as BoxDecoration)
              .color;
      expect(dateColor('2026-10-02'), const Color(0xFFFFE59B));
      final photos = store
          .rows('memories')
          .where((m) => m['petId'] == dog['id'])
          .toList();
      for (final memory in photos.take(3)) {
        expect(
          find.byKey(ValueKey("home-memory-${memory['id']}")),
          findsOneWidget,
        );
      }
      expect(
        find.byKey(ValueKey("home-memory-${photos.last['id']}")),
        findsNothing,
      );
      expect(find.text('함께 걸은 가을'), findsOneWidget);
      expect(find.text('약속 없이, 우리만의 느긋한 하루'), findsOneWidget);
      final collage = find.byKey(const ValueKey('home-memory-collage'));
      for (final memory in photos.take(3)) {
        final tile = find.byKey(ValueKey("home-memory-${memory['id']}"));
        expect(
          tester.getRect(collage).contains(tester.getCenter(tile)),
          isTrue,
        );
      }
      await tester.tap(find.byKey(const ValueKey('home-date-2026-10-02')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-dashboard')), findsOneWidget);
      expect(find.text('함께 걸은 가을'), findsNothing);
      expect(find.byKey(const ValueKey('home-meeting-walk')), findsOneWidget);
      expect(find.byKey(const ValueKey('home-meetings-empty')), findsNothing);
      for (final pet in store.meetingPets(store.meeting('walk'))) {
        final profile = find.byKey(
          ValueKey("meeting-pet-profile-${pet['id']}"),
        );
        expect(profile, findsOneWidget);
        expect(
          tester.getTopLeft(profile).dx,
          lessThan(
            tester.getTopLeft(find.text(store.meeting('walk')['title'])).dx,
          ),
        );
      }
      expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
      expect(find.text('이날의 추억이 기다리고 있어요'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('home-date-2026-10-01')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home-day-photo-0')));
      await tester.pumpAndSettle();
      expect(find.byType(MemoryView), findsOneWidget);
      expect(find.byKey(const ValueKey('memory-editor-pet')), findsNothing);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('다음 주'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-today-day')), findsNothing);
      expect(dateColor('2026-10-05'), isNot(const Color(0xFFFFE59B)));
      await tester.tap(find.text('오늘'));
      await tester.pumpAndSettle();
      store.meeting('walk')['canceled'] = true;
      await store.change(() {});
      await tester.pumpAndSettle();
      expect(dateColor('2026-10-02'), isNot(const Color(0xFFFFE59B)));
      await tester.drag(
        find.byKey(const ValueKey('home-pet-pages')),
        const Offset(-300, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('Day 1'), findsNothing);
      expect(find.text('D+2'), findsOneWidget);
      expect(find.text('오늘의 추억을 기록하기'), findsOneWidget);
      expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
      for (final memory in store.rows('memories')) {
        expect(
          find.byKey(ValueKey("home-memory-${memory['id']}")),
          findsNothing,
        );
      }
      await tester.tap(find.text('오늘의 추억을 기록하기'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('memory-editor-pet')))
            .data,
        '루나의 추억',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('Day 0 setup explicitly selects the first-photo basis', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = PetStore(
      await SharedPreferences.getInstance(),
      clock: () => DateTime.utc(2026, 10, 1, 3),
    );
    await store.load();
    await store.testLogin();
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
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('추억'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('시작 기준 설정'), findsOneWidget);
    expect(find.byKey(const ValueKey('memory-weeks')), findsNothing);
    await tester.tap(find.text('시작 기준 설정'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('memory-origin-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('첫 사진').last);
    await tester.pumpAndSettle();
    expect(find.text('저장된 가장 오래된 사진 날짜를 사용해요.'), findsOneWidget);
    await tester.tap(find.text('설정 완료'));
    await tester.pumpAndSettle();
    expect(store.memoryProfile()['memoryOriginType'], 'firstPhoto');
    expect(find.text('Day 0 · 첫 사진\n2026-10-01'), findsOneWidget);
    expect(find.text('Day 0'), findsOneWidget);
    expect(find.byKey(const ValueKey('memory-weeks')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final width in [390.0, 1440.0]) {
    testWidgets(
      'mobile-first photo gallery, daily journal and Day 0 at width $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final store = PetStore(
          await SharedPreferences.getInstance(),
          clock: () => DateTime.utc(2026, 10, 1, 3),
        );
        await store.load();
        await store.testLogin();
        store.data['memories'] = <RecordData>[];
        store.data['memoryDays'] = <RecordData>[];
        const image =
            'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=';
        await store.saveMemoryPhotos('2026-10-01', [
          image,
          image,
          image,
          image,
        ]);
        await store.saveMemoryPhotos('2026-09-30', [image, image]);
        await store.saveMemoryPhotos('2026-09-23', [image]);
        await store.saveMemoryDay(
          '2026-10-01',
          '함께한 하루',
          'Day에 하나만 있는 메모',
          false,
        );
        await store.setMemoryOrigin('firstMeeting', DateTime(2026, 9, 1));
        final todayPhotos = store
            .rows('memories')
            .where((m) => m['date'] == '2026-10-01')
            .toList();
        final foreign = {
          'id': 'foreign-photo',
          'owner': 'someone-else',
          'date': '2026-10-01',
          'photo': image,
        };
        store.rows('memories').add(foreign);
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
        await tester.tap(
          width < 950
              ? find.descendant(
                  of: find.byType(NavigationBar),
                  matching: find.text('추억'),
                )
              : find.text('추억 보관함').first,
        );
        await tester.pumpAndSettle();
        expect(find.text('추억 캘린더'), findsNothing);
        expect(find.text('Day 0 · 첫 만남\n2026-09-01'), findsOneWidget);
        expect(find.text('Day 30'), findsOneWidget);
        expect(find.text('함께한 하루'), findsOneWidget);
        expect(find.text('Day에 하나만 있는 메모'), findsOneWidget);
        expect(find.text('사진 4장'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('memory-photo-foreign-photo')),
          findsNothing,
        );
        final photoFinder = find.byKey(
          ValueKey('memory-photo-${todayPhotos.first['id']}'),
        );
        final gridFinder = find.byKey(const ValueKey('memory-photo-grid'));
        final grid = tester.widget<GridView>(gridFinder);
        expect(
          (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
              .crossAxisCount,
          3,
        );
        // Verify physical layout, rather than only the grid delegate setting.
        final tiles = todayPhotos
            .map((m) => find.byKey(ValueKey("memory-photo-${m['id']}")))
            .toList();
        expect(tester.getTopLeft(tiles[0]).dy, tester.getTopLeft(tiles[2]).dy);
        expect(
          tester.getTopLeft(tiles[3]).dy,
          greaterThan(tester.getTopLeft(tiles[0]).dy),
        );
        expect(
          find.descendant(of: gridFinder, matching: find.byType(Text)),
          findsNothing,
        );
        final journal = find.byKey(const ValueKey('memory-day-journal'));
        final gallery = find.byKey(const ValueKey('memory-gallery'));
        if (width < 720) {
          expect(
            tester.getBottomLeft(journal).dy,
            lessThan(tester.getTopLeft(gallery).dy),
          );
        } else {
          expect(
            tester.getTopLeft(journal).dx,
            lessThan(tester.getTopLeft(gallery).dx),
          );
        }
        await tester.ensureVisible(photoFinder);
        await tester.tap(photoFinder);
        await tester.pumpAndSettle();
        expect(find.text('추억 보기'), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        expect(
          tester
              .widget<Image>(
                find.descendant(
                  of: find.byKey(const ValueKey('memory-full-photo')),
                  matching: find.byType(Image),
                ),
              )
              .fit,
          BoxFit.contain,
        );
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('수정'));
        await tester.tap(find.text('수정'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(photoFinder);
        await tester.tap(photoFinder);
        await tester.pumpAndSettle();
        expect(find.text('사진 수정'), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        expect(
          tester.widget<Image>(find.byType(Image).last).fit,
          BoxFit.contain,
        );
        await tester.tap(find.text('닫기'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('글 수정'));
        await tester.tap(find.text('글 수정'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, '수정한 하루 제목');
        await tester.enterText(find.byType(TextField).last, '하루 메모 수정');
        await tester.tap(find.text('저장'));
        await tester.pumpAndSettle();
        expect(find.text('수정한 하루 제목'), findsOneWidget);
        expect(find.text('하루 메모 수정'), findsOneWidget);
        expect(
          store.rows('memories').where((m) => m['owner'] == 'test').length,
          7,
        );
        await tester.ensureVisible(find.text('완료'));
        await tester.tap(find.text('완료'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('memory-day-2026-09-30')));
        await tester.pumpAndSettle();
        expect(find.text('Day 29'), findsOneWidget);
        expect(find.text('사진 2장'), findsOneWidget);
        await tester.drag(
          find.byKey(const ValueKey('memory-weeks')),
          const Offset(280, 0),
        );
        await tester.pumpAndSettle();
        expect(find.text('Day 22'), findsOneWidget);
        expect(find.text('사진 1장'), findsOneWidget);
        await tester.tap(find.text('오늘'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('memory-day-2026-09-29')));
        await tester.pumpAndSettle();
        expect(find.text('Day 28'), findsOneWidget);
        expect(find.text('사진 0장'), findsOneWidget);
        final emptyDayText = find.descendant(
          of: find.byKey(const ValueKey('memory-day-2026-09-29')),
          matching: find.text('28'),
        );
        final photoDayText = find.descendant(
          of: find.byKey(const ValueKey('memory-day-2026-09-30')),
          matching: find.text('29'),
        );
        expect(
          tester.widget<Text>(emptyDayText).style!.color!.a,
          lessThan(0.5),
        );
        expect(tester.widget<Text>(photoDayText).style!.color, ink);
        await tester.tap(find.byKey(const ValueKey('memory-day-2026-10-02')));
        await tester.pumpAndSettle();
        expect(
          find.text('Day 28'),
          findsOneWidget,
        ); // Future Days remain disabled.
        await tester.tap(find.text('오늘'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('추억 기록'));
        await tester.pumpAndSettle();
        expect(find.text('날짜  2026-10-01'), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        await tester.tap(find.text('닫기'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  for (final width in [390.0, 1440.0]) {
    testWidgets('test login and navigation at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const PetApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('테스트로 이용하기'));
      await tester.pumpAndSettle();
      expect(find.text('함께라서 더 좋은 하루 🐾'), findsOneWidget);

      if (width < 950) {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('약속'),
          ),
        );
      } else {
        await tester.tap(find.text('함께하는 약속').first);
      }
      await tester.pumpAndSettle();
      expect(find.byTooltip('약속 만들기'), findsOneWidget);

      await tester.tap(find.byTooltip('약속 만들기'));
      await tester.pumpAndSettle();
      expect(find.text('새로운 약속 만들기'), findsOneWidget);

      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('로그아웃'));
      await tester.pumpAndSettle();
      expect(find.text('테스트로 이용하기'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('create appointment, send a message and leave through UI', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const PetApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('테스트로 이용하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('함께하는 약속').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('약속 만들기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '모카의 새 산책');
    expect(find.text('동반 인원 (본인 제외)'), findsNothing);
    expect(find.text('참여 마감 · 한국 시간'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('meeting-place-picker')));
    await tester.pumpAndSettle();
    expect(find.text('지도에서 장소 선택'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('meeting-map-marker-0')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('meeting-place-name')),
      '동네 공원',
    );
    await tester.tap(find.text('이 장소로 선택'));
    await tester.pumpAndSettle();
    expect(find.text('동네 공원'), findsOneWidget);
    await tester.tap(find.text('약속 만들기').last);
    await tester.pumpAndSettle();
    expect(find.text('모카의 새 산책'), findsOneWidget);
    await tester.tap(find.text('모카의 새 산책'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('채팅 열기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '함께 걸어요!');
    await tester.tap(find.byTooltip('메시지 보내기'));
    await tester.pumpAndSettle();
    expect(find.text('함께 걸어요!'), findsOneWidget);
    await tester.tap(find.byTooltip('채팅방 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('나가기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('나가기').last);
    await tester.pumpAndSettle();
    expect(find.text('참여가 취소되었습니다'), findsOneWidget);
    expect(find.text('함께 걸어요!'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

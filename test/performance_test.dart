import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pet_sns/main.dart';
import 'package:pet_sns/store.dart';
import 'package:pet_sns/meeting_location.dart';
import 'package:pet_sns/design_system.dart';

const image =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a/1sAAAAASUVORK5CYII=';

Future<PetStore> makeStore({DateTime Function()? clock}) async {
  SharedPreferences.setMockInitialValues({});
  final store = PetStore(
    await SharedPreferences.getInstance(),
    clock: clock ?? () => DateTime.utc(2026, 10, 1, 3),
  );
  await store.load();
  await store.testLogin();
  return store;
}

Widget host(Widget screen) => MaterialApp(
  theme: petTheme,
  locale: const Locale('ko'),
  supportedLocales: const [Locale('ko')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: screen,
);

Future<void> expectIdle(WidgetTester tester) async {
  final previous = debugOnRebuildDirtyWidget;
  final rebuilt = <String>[];
  debugOnRebuildDirtyWidget = (element, builtOnce) {
    if (builtOnce) rebuilt.add(element.widget.runtimeType.toString());
  };
  try {
    for (var second = 0; second < 5; second++) {
      await tester.pump(const Duration(seconds: 1));
      expect(
        rebuilt,
        isEmpty,
        reason: 'Idle second ${second + 1} rebuilt $rebuilt',
      );
    }
  } finally {
    debugOnRebuildDirtyWidget = previous;
  }
}

void main() {
  testWidgets('home photo form saves after navigating to the memory tab', (
    tester,
  ) async {
    final folder = Directory.systemTemp.createTempSync('petsns-memory-test-');
    final file = File('${folder.path}/photo.png')
      ..writeAsBytesSync(base64Decode(image.split(',').last));
    addTearDown(() => folder.deleteSync(recursive: true));
    const channel = MethodChannel('plugins.flutter.io/image_picker');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      expect(call.method, 'pickMultiImage');
      return [file.path];
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final store = await makeStore();
    await tester.pumpWidget(host(Home(store: store)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('추억 기록'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('추억 기록'));
    await tester.pumpAndSettle();
    final preview = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('사진 1장'),
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('사진 선택'));
      for (var attempt = 0; attempt < 100; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
        if (preview.evaluate().isNotEmpty) break;
      }
    });
    await tester.pumpAndSettle();
    expect(preview, findsOneWidget);
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(store.rows('memories').length, 3);
    final restored = PetStore(store.prefs);
    await restored.load();
    expect(
      base64Decode(
        (restored.rows('memories').last['photo'] as String).split(',').last,
      ),
      base64Decode(image.split(',').last),
    );
    expect(restored.rows('memories').last['date'], '2026-10-01');
    expect(restored.rows('memories').last['petId'], store.defaultPetId);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final width in [320.0, 1440.0]) {
    testWidgets('all five tabs build zero times each idle second at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = await makeStore();
      // Use local images so network loading cannot mask the timer regression.
      for (final collection in ['pets', 'memories']) {
        for (final row in store.rows(collection)) {
          row['photo'] = image;
        }
      }
      await tester.pumpWidget(host(Home(store: store)));
      await tester.pumpAndSettle();
      final labels = width < 950
          ? ['하루', '추억', '약속', '채팅', '반려동물']
          : ['우리의 하루', '추억 보관함', '함께하는 약속', '채팅', '반려동물'];
      for (var index = 0; index < labels.length; index++) {
        final target = width < 950
            ? find.descendant(
                of: find.byType(NavigationBar),
                matching: find.text(labels[index]),
              )
            : find.widgetWithText(ListTile, labels[index]);
        await tester.tap(target);
        await tester.pumpAndSettle();
        await expectIdle(tester);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('chat and room details do not rebuild while idle', (
    tester,
  ) async {
    final store = await makeStore();
    await store.join('walk');
    for (final screen in [
      ChatScreen(store: store, mid: 'walk'),
      ChatRoomDetails(store: store, mid: 'walk', mode: 'members'),
      ChatRoomDetails(store: store, mid: 'walk', mode: 'photos'),
    ]) {
      await tester.pumpWidget(host(screen));
      await tester.pumpAndSettle();
      await expectIdle(tester);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('data photo reuses decoded bytes until the source changes', (
    tester,
  ) async {
    await tester.pumpWidget(host(photo(image, width: 50, height: 50)));
    await tester.pumpAndSettle();
    final original =
        (tester.widget<Image>(find.byType(Image)).image as MemoryImage).bytes;
    await tester.pumpWidget(host(photo(image, width: 80, fit: BoxFit.contain)));
    await tester.pumpAndSettle();
    expect(
      (tester.widget<Image>(find.byType(Image)).image as MemoryImage).bytes,
      same(original),
    );
    expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.contain);
    await tester.pumpWidget(host(photo('data:image/png;base64,invalid!')));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.pets_rounded), findsOneWidget);
    await tester.pumpWidget(host(photo(image)));
    await tester.pumpAndSettle();
    final replacement =
        (tester.widget<Image>(find.byType(Image)).image as MemoryImage).bytes;
    expect(replacement, isNot(same(original)));
    expect(replacement, original);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recruitment closes exactly at its scheduled boundary', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 10, 1, 3);
    final store = await makeStore(clock: () => now);
    await store.createMeeting(
      '경계 약속',
      const MeetingLocation('공원', 37.54, 127.04),
      '',
      now.add(const Duration(hours: 6, seconds: 3)),
      6,
    );
    await tester.pumpWidget(host(Home(store: store)));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('약속'),
      ),
    );
    await tester.pumpAndSettle();
    final meeting = store.rows('meetings').last;
    final status = find
        .descendant(
          of: find.byKey(ValueKey("meeting-status-${meeting['id']}")),
          matching: find.byType(Text),
        )
        .first;
    expect(tester.widget<Text>(status).data, '모집 중 · 참여 중');
    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.widget<Text>(status).data, '모집 중 · 참여 중');
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.widget<Text>(status).data, '모집 마감 · 참여 중');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('orphaned stored session opens login and preserves records', (
    tester,
  ) async {
    final store = await makeStore();
    store.data['session'] = 'deleted-account';
    await store.prefs.setString(PetStore.key, jsonEncode(store.data));
    await tester.pumpWidget(const PetApp());
    await tester.pumpAndSettle();
    expect(find.text('테스트로 이용하기'), findsOneWidget);
    final restored = PetStore(store.prefs);
    await restored.load();
    expect(restored.user, isNull);
    expect(restored.account, isNull);
    expect(restored.rows('pets').length, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('open meetup detail refreshes at the recruitment cutoff', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 10, 1, 3);
    final store = await makeStore(clock: () => now);
    await store.createMeeting(
      '상세 경계 약속',
      const MeetingLocation('공원', 37.54, 127.04),
      '',
      now.add(const Duration(hours: 6, seconds: 5)),
      6,
    );
    await tester.pumpWidget(host(Home(store: store)));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('약속'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('상세 경계 약속'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('모집 중'),
      ),
      findsOneWidget,
    );
    now = now.add(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 5));
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('모집 마감'),
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('resuming a chat rechecks closure after suspended time', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 10, 1, 3);
    final store = await makeStore(clock: () => now);
    await store.join('walk');
    await tester.pumpWidget(host(ChatScreen(store: store, mid: 'walk')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chat-input')), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = chatClose(DateTime.parse(store.meeting('walk')['at']));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byKey(const ValueKey('chat-input')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('all theme text styles are at least 13px and use Pretendard', () {
    final theme = petTheme.textTheme;
    for (final style in [
      theme.displayLarge,
      theme.displayMedium,
      theme.displaySmall,
      theme.headlineLarge,
      theme.headlineMedium,
      theme.headlineSmall,
      theme.titleLarge,
      theme.titleMedium,
      theme.titleSmall,
      theme.bodyLarge,
      theme.bodyMedium,
      theme.bodySmall,
      theme.labelLarge,
      theme.labelMedium,
      theme.labelSmall,
    ]) {
      expect(style!.fontSize, greaterThanOrEqualTo(13));
      expect(style.fontFamily, 'Pretendard');
    }
  });
}

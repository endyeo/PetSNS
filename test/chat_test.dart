import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pet_sns/main.dart';
import 'package:pet_sns/store.dart';

const image =
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
    await store.join('walk');
  });

  test(
    'photos respect first join, same-time rejoin, room, reload and closure',
    () async {
      await store.send('walk', '', photo: image);
      await store.login('other@example.com', 'password1', name: '다른 보호자');
      await store.join('walk');
      expect(store.chatPhotos('walk'), isEmpty);
      await store.send('walk', '새 사진', photo: image);
      await store.join('picnic');
      await store.send('picnic', '', photo: image);
      expect(store.chatPhotos('walk').single['body'], '새 사진');
      final restored = PetStore(store.prefs, clock: () => now);
      await restored.load();
      expect(restored.chatPhotos('walk').single['photo'], image);
      await store.leave('walk');
      expect(store.chatPhotos('walk'), isEmpty);
      await expectLater(store.send('walk', '', photo: image), throwsException);
      await store.join('walk');
      expect(store.chatPhotos('walk'), isEmpty);
      await store.send('walk', '', photo: image);
      expect(store.chatPhotos('walk').length, 1);
      store.meeting('walk')['canceled'] = true;
      expect(store.chatPhotos('walk'), isEmpty);
      expect(store.chatMembers('walk'), isEmpty);
      await expectLater(store.send('walk', '', photo: image), throwsException);
      store.meeting('walk')['canceled'] = false;
      now = chatClose(DateTime.parse(store.meeting('walk')['at']));
      expect(store.chatPhotos('walk'), isEmpty);
      expect(store.chatMembers('walk'), isEmpty);
      await expectLater(store.send('walk', '', photo: image), throwsException);
    },
  );

  test('invalid media fails without adding a message', () async {
    for (final source in [
      '',
      'https://example.com/photo.png',
      'data:image/png;base64,',
      'data:image/svg+xml;base64,PHN2Zz4=',
    ]) {
      await expectLater(store.send('walk', '', photo: source), throwsException);
    }
    await expectLater(
      store.send('walk', 'a' * 1001, photo: image),
      throwsException,
    );
    expect(store.messages('walk'), isEmpty);
    await store.send('walk', '  산책 사진  ', photo: image);
    expect(store.messages('walk').single['body'], '산책 사진');
  });

  test(
    'members include current guardians and participating pets only',
    () async {
      expect(store.chatMembers('walk').map((m) => m['name']), ['보리 보호자', '지우']);
      expect(
        (store.chatMembers('walk').last['pets'] as List).single['name'],
        '모카',
      );
      await store.leave('walk');
      expect(store.chatMembers('walk'), isEmpty);
      await store.logout();
      expect(store.chatPhotos('walk'), isEmpty);
    },
  );

  testWidgets('plus previews, removes and sends a photo without text', (
    tester,
  ) async {
    final folder = Directory.systemTemp.createTempSync('petsns-chat-');
    final file = File('${folder.path}/photo.png')
      ..writeAsBytesSync(base64Decode(image.split(',').last));
    addTearDown(() => folder.deleteSync(recursive: true));
    const channel = MethodChannel('plugins.flutter.io/image_picker');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      expect(call.method, 'pickImage');
      return file.path;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen(store: store, mid: 'walk'),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> choose() async {
      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('사진 추가'));
        for (var i = 0; i < 100; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await tester.pump();
          if (find.text('전송할 사진').evaluate().isNotEmpty) break;
        }
      });
      await tester.pumpAndSettle();
      expect(find.text('전송할 사진'), findsOneWidget);
    }

    await choose();
    expect(store.messages('walk'), isEmpty);
    await tester.tap(find.byTooltip('첨부 사진 제거'));
    await tester.pumpAndSettle();
    expect(find.text('전송할 사진'), findsNothing);
    await choose();
    await tester.tap(find.byTooltip('메시지 보내기'));
    await tester.pumpAndSettle();
    expect(store.chatPhotos('walk').single['photo'], image);
    expect(store.messages('walk').single['body'], '');
    expect(find.text('전송할 사진'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final width in [320.0, 390.0, 1440.0]) {
    testWidgets('C shares P information without distance at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      store.meeting('walk')['distanceMeters'] = 1800;
      await tester.pumpWidget(MaterialApp(home: Home(store: store)));
      await tester.pumpAndSettle();
      if (width < 950) {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('채팅'),
          ),
        );
      } else {
        await tester.tap(find.text('채팅').first);
      }
      await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey('chat-card-walk'));
      await tester.tap(find.text('약속방'));
      await tester.pumpAndSettle();
      expect(card, findsOneWidget);
      for (final text in [
        '꼬리 흔들며, 한강 산책',
        '서울 · 반포한강공원',
        '모집 중 · 참여 중',
        '2 / 6',
      ]) {
        expect(
          find.descendant(of: card, matching: find.text(text)),
          findsOneWidget,
        );
      }
      expect(
        find.byKey(const ValueKey('meeting-pet-profile-demo-host')),
        findsOneWidget,
      );
      expect(find.textContaining('km'), findsNothing);
      expect(find.textContaining('거리'), findsNothing);
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byTooltip('채팅방 메뉴'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
      'compact bubbles, members and visible photo gallery at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await store.send('walk', '안녕');
        final id = store.messages('walk').single['id'];
        await store.send('walk', '', photo: image);
        final photoId = store.chatPhotos('walk').single['id'];
        await tester.pumpWidget(
          MaterialApp(
            home: ChatScreen(store: store, mid: 'walk'),
          ),
        );
        await tester.pumpAndSettle();
        final bubble = find.byKey(ValueKey('chat-bubble-$id'));
        final sender = find.byKey(ValueKey('chat-sender-$id'));
        expect(
          find.descendant(of: bubble, matching: find.text('지우')),
          findsNothing,
        );
        expect(
          tester.getBottomLeft(sender).dy,
          lessThan(tester.getTopLeft(bubble).dy),
        );
        expect(tester.getSize(bubble).height, lessThan(70));
        expect(tester.getSize(bubble).width, lessThan(150));
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('chat-input')))
              .decoration!
              .fillColor,
          Colors.white,
        );
        expect(find.byTooltip('사진 추가'), findsOneWidget);
        await tester.tap(find.byTooltip('채팅방 메뉴'));
        await tester.pumpAndSettle();
        for (final text in ['멤버', '사진', '나가기']) {
          expect(find.text(text), findsOneWidget);
        }
        await tester.tap(find.text('멤버'));
        await tester.pumpAndSettle();
        expect(find.text('보리 보호자'), findsOneWidget);
        expect(find.text('지우 · 나'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('채팅방 메뉴'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('사진'));
        await tester.pumpAndSettle();
        final thumbnail = find.byKey(ValueKey('chat-gallery-$photoId'));
        expect(thumbnail, findsOneWidget);
        await tester.tap(thumbnail);
        await tester.pumpAndSettle();
        expect(find.byType(InteractiveViewer), findsOneWidget);
        final remaining = chatClose(
          DateTime.parse(store.meeting('walk')['at']),
        ).difference(now);
        now = now.add(remaining);
        await tester.pump(remaining);
        expect(find.byType(InteractiveViewer), findsNothing);
        expect(find.text('채팅방 접근이 차단되었습니다'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

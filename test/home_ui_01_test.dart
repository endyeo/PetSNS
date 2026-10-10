import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_sns/design_system.dart';
import 'package:pet_sns/screens/home_screen.dart';
import 'package:pet_sns/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final width in [360.0, 1024.0]) {
    testWidgets('HOME-UI-01 acceptance criteria verification at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final store = PetStore(
        await SharedPreferences.getInstance(),
        clock: () => DateTime.utc(2026, 10, 1, 3), // 2026-10-01 KST
      );
      await store.load();
      await store.testLogin();

      final dog = store.rows('pets').firstWhere((p) => p['name'] == '모카');
      final cat = store.rows('pets').firstWhere((p) => p['name'] == '루나');

      // Set origin dates for Day 1 calculation
      // 모카: 2026-09-01 -> 30 days diff + 1 = D+31
      await store.setMemoryOrigin(
        'firstMeeting',
        DateTime(2026, 9, 1),
        petId: dog['id'],
      );
      // 루나: 2026-09-30 -> 1 day diff + 1 = D+2
      await store.setMemoryOrigin(
        'firstMeeting',
        DateTime(2026, 9, 30),
        petId: cat['id'],
      );

      // Join a meeting on 2026-10-02 to verify appointment highlighting
      await store.join('walk', petIds: [dog['id']]);
      store.meeting('walk')['at'] = DateTime.utc(2026, 10, 2, 6).toIso8601String();

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ko'),
          supportedLocales: const [Locale('ko')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: petTheme,
          home: ListenableBuilder(
            listenable: store,
            builder: (_, _) => Home(store: store),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final banner = find.byKey(const ValueKey('home-pet-banner'));
      final bannerRect = tester.getRect(banner);

      // 1. H-03 추억 기록 버튼이 사진의 우측 하단에 배치
      final recordButton = find.byKey(const ValueKey('home-record-memory'));
      expect(recordButton, findsOneWidget);
      final buttonRect = tester.getRect(recordButton);
      expect(buttonRect.bottom, lessThanOrEqualTo(bannerRect.bottom));
      expect(buttonRect.right, lessThanOrEqualTo(bannerRect.right));
      expect(buttonRect.center.dx, greaterThan(bannerRect.center.dx)); // On right side

      // 2. '가족 1 / 2 마리' 문구가 제거된다
      expect(find.text('가족 1 / 2 마리'), findsNothing);
      expect(find.text('1 / 2'), findsNothing);

      // 3. H-05가 안내 문구 없이 표시된다
      expect(find.text('좌우로 넘겨 보세요'), findsNothing);
      expect(find.byKey(const ValueKey('home-pet-indicators')), findsOneWidget);

      // 4. 생일 정보는 화면에서만 제거된다 (데이터는 유지)
      expect(find.textContaining('생일'), findsNothing);
      expect(dog['birthday'], '2022-04-12'); // Data is kept intact

      // 5. 사진 우측 상단에 D+숫자가 표시된다
      final dayBadge = find.byKey(const ValueKey('home-pet-day'));
      expect(dayBadge, findsOneWidget);
      final dayBadgeRect = tester.getRect(dayBadge);
      expect(dayBadgeRect.top, greaterThanOrEqualTo(bannerRect.top));
      expect(dayBadgeRect.right, lessThanOrEqualTo(bannerRect.right));
      expect(dayBadgeRect.center.dx, greaterThan(bannerRect.center.dx)); // On right side
      expect(find.text('D+31'), findsOneWidget); // 1-based Day counter

      // 6. 글자 색상은 검정색이다
      final dayTextWidget = tester.widget<Text>(find.descendant(of: dayBadge, matching: find.byType(Text)));
      expect(dayTextWidget.style?.color, Colors.black);

      // 7. 배경색은 앱 전체 배경색과 동일하다
      final dayMaterial = tester.widget<Material>(find.ancestor(of: dayBadge, matching: find.byType(Material)).first);
      expect(dayMaterial.color, AppColors.canvas);

      // 8. 사진, 버튼, 텍스트가 모바일과 웹에서 겹치지 않는다
      final nameFinder = find.byKey(const ValueKey('home-pet-name'));
      final nameRect = tester.getRect(nameFinder);
      expect(nameRect.right, lessThan(buttonRect.left));

      // 9. H-04의 작은 Day 문구가 제거된다
      expect(find.byKey(const ValueKey('home-today-day')), findsNothing);
      expect(find.text('Day 30'), findsNothing);
      expect(find.text('Day 31'), findsNothing);

      // 10. 주간 달력의 날짜 선택과 약속 강조가 정상 동작한다
      final appointmentDateKey = ValueKey('home-date-2026-10-02');
      final dateContainer = tester.widget<Container>(find.byKey(appointmentDateKey));
      final decoration = dateContainer.decoration as BoxDecoration;
      expect(decoration.color, AppColors.anniversary); // Meeting highlighted yellow

      await tester.tap(find.byKey(appointmentDateKey));
      await tester.pumpAndSettle();
      expect(find.text('꼬리 흔들며, 한강 산책'), findsOneWidget); // Meeting preview updated

      // 11. 사진 좌우 제스처로 반려동물을 변경할 수 있다
      final pages = find.byKey(const ValueKey('home-pet-pages'));
      await tester.drag(pages, Offset(-tester.getSize(pages).width * 0.8, 0));
      await tester.pumpAndSettle();

      // 12. 반려동물 변경 시 이름, 종, D+숫자가 갱신된다
      expect(tester.widget<Text>(find.byKey(const ValueKey('home-pet-name'))).data, '루나');
      expect(find.text('코리안 쇼트헤어'), findsOneWidget);
      expect(find.text('D+2'), findsOneWidget); // 루나: 2026-09-30 -> D+2
      expect(find.text('가족 2 / 2 마리'), findsNothing);

      // 13. 추억 기록 버튼의 기존 기능이 유지된다
      await tester.tap(recordButton);
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('memory-editor-pet'))).data,
        '루나의 추억',
      );
    });
  }
}

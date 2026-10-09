# PetSNS 시작 안내

반려동물 추억, 약속, 게시글, 모임·약속 채팅을 체험하는 Flutter 앱입니다. 모바일을 우선으로 만들고 웹·Android를 지원합니다. [English README](../../README.md).

## 실행

`C:\Projects\PetSNS`에서 실행합니다.

```powershell
flutter pub get
flutter run -d chrome --web-port 8080
```

기록을 유지하려면 같은 호스트·8080 포트를 사용하세요. 이미 서버가 실행 중인 포트에는 중복 실행하지 않습니다. 연결된 Android 기기는 메시지가 표시될 때 USB 디버깅을 허용한 뒤 `flutter run -d SM-S908N`(또는 해당 기기 ID)으로 실행합니다.

### Supabase 연결 설정

`config/supabase.example.json`을 `config/supabase.local.json`(Git 제외 대상)으로 복사한 뒤, Project URL과 `sb_publishable_...` 키를 입력합니다. 빌드 시 아래와 같이 주입합니다:

```powershell
flutter run -d chrome --web-port 8080 --dart-define-from-file=config/supabase.local.json
flutter build web --release --dart-define-from-file=config/supabase.local.json
flutter build apk --debug --dart-define-from-file=config/supabase.local.json
flutter test test/supabase_live_test.dart --dart-define-from-file=config/supabase.local.json
```

개별 `--dart-define=SUPABASE_URL=...` 및 `--dart-define=SUPABASE_PUBLISHABLE_KEY=...` 인자도 사용할 수 있습니다. 해당 설정은 클라이언트 빌드에 포함되므로 공개 가능한 Publishable Key만 사용해야 하며, Secret Key, service_role 키, DB 비밀번호는 절대 사용하지 마세요. Flutter assets에는 설정을 추가하지 않습니다.

앱 시작 시 SDK를 초기화한 후 `apikey` 헤더와 10초 타임아웃으로 읽기 전용 `GET /auth/v1/settings`를 요청합니다. Auth 설정 응답과 함께 HTTP 200을 반환해야 연결된 것으로 간주합니다. 콘솔의 `[PetSNS Supabase]` 진단 로그는 키 값이나 응답 본문을 출력하지 않고 누락/잘못된 설정, 초기화 실패, HTTP 오류, 네트워크 장애를 보고합니다. `lib/main.dart`의 `supabaseConnection`은 `initialized`와 `connected` 플래그를 별도로 제공합니다.
연결에 실패해도 기존 로컬 앱은 정상 이용할 수 있습니다. 이 과정은 프로젝트 게이트웨이 및 Auth 접근 가능 여부만 검증하며, 데이터베이스 권한, 동기화, 사용자 로그인까지 처리하지는 않습니다. 이번 단계에서는 Supabase 세션 유지 및 URL 세션 감지 기능이 비활성화되어 있습니다.

## 지금 가능한 것

로그인 화면에서 테스트 이용을 선택하면 가입 없이 체험할 수 있습니다. 새로고침해도 기록·세션이 유지되고, 테스트 이용은 기록을 초기화하지 않습니다. 데이터는 기기에 `petsns.v1` JSON으로 저장됩니다.

한 기기·한 활성 앱에서 사용하는 데모입니다. 서버, 실제 이메일 인증, 비밀번호 찾기, 여러 기기 동기화는 없습니다. 운영용 인증으로 사용할 수 없습니다. 저장소 삭제·앱 제거 시 기록이 사라질 수 있고, 예시 사진·지도는 인터넷 연결이 필요합니다.

## 알아두면 좋은 규칙

- 약속 정원은 자동 참여하는 작성자를 포함한 보호자 2~50명입니다. 시작 6시간 전에 참여가 마감되며 마감 정각에는 참여할 수 없습니다. 새 약속은 시작까지 6시간 넘게 남아야 합니다.
- 약속 채팅은 약속 날짜 기준 이틀 뒤 00:00 한국 시간(KST)에 종료됩니다(예: 10월 1일 약속 → 10월 3일 00:00 종료). 모임방에는 약속 날짜에 따른 자동 종료가 없습니다.
- 나가면 접근이 차단되고, 재참여하면 새 참여 시점(`since` 및 `after`) 이후의 대화·사진만 보입니다. 약속방 나가기는 해당 약속 참여, 모임방 나가기는 해당 모임 가입만 취소합니다.
- 추억·하루 글·Day 0는 반려동물별로 관리합니다. 사진을 삭제해도 하루 글은 남습니다. 선택한 사진은 장당 3MB(`3 * 1024 * 1024` 바이트) 이하입니다.

## 코드 위치와 변경 확인

`lib/main.dart`에서 앱이 시작됩니다. 5개 탭 화면, 로그인, 채팅, 뷰어는 `lib/screens/`에 있고 팝업 폼은 `lib/forms/`, 공용 위젯은 `lib/widgets/`에 있습니다. 저장소 및 비즈니스 규칙은 `lib/store.dart`에 위치합니다. 색상, 텍스트 스타일(최소 13px), 테마는 `lib/design_system.dart`에 정의되어 있습니다. 번들된 [Pretendard v1.3.9](https://github.com/orioncactus/pretendard/tree/v1.3.9) 폰트와 OFL 라이선스는 `assets/fonts/`에 있습니다.

저장소는 `C:\Projects\PetSNS`와 같이 OneDrive 외부 경로에 보관하세요. `build/`와 `.dart_tool/`은 Git 제외 대상입니다. Flutter는 Windows 사용자 PATH의 `C:\flutter\bin`을 통해 이용할 수 있습니다. 커밋하기 전에 [커밋 규칙](../../.agents/rules/commits.md)을 확인하세요.

코드를 바꿀 때는 `flutter analyze`와 관련 `flutter test`로 확인합니다. 플랫폼 변경이 필요한 경우 `flutter build web --release` 또는 `flutter build apk --debug`로 빌드합니다. 이번 문서 정리는 앱 테스트·빌드를 새로 실행한 작업이 아닙니다.

## 시각 자료와 기획 참고

- [서비스 기획서](service-plan.html): 서비스의 전체 흐름.
- [기능별 완료 기준](feature-prd.html): 기능 PRD의 한글 보기와 완료·실패 방지·오류 조건.
- [화면 가이드](ui-guide.html): 화면·요소를 찾아 수정할 곳을 지정하고 메모하기.
- [기존 화면 캡처](screenshots/mobile-preview.jpg): 같은 폴더에 다른 화면 캡처도 있습니다.

예: “홈의 추억 기록 버튼을 더 크게 해줘. 위치와 색상은 유지하고 모바일에서도 글자가 잘리지 않게 해줘.” 문서나 코드 이름까지 지정할 필요는 없습니다.

화면 가이드의 메모는 브라우저에 저장됩니다. 주소가 달라져 메모가 보이지 않으면 이전 가이드에서 JSON을 내려받아 새 가이드에 가져오세요.

## 새 채팅에서 이어가기

프로젝트를 연결하고 원하는 화면·동작을 설명하면 됩니다. AI는 루트 `AGENTS.md`에서 시작해 관련 코드와 테스트를 확인합니다.

# T28 Supabase 로그인과 세션 복원

작성일: 2026년 10월 10일. 상태: 구현 및 인증 검증 완료. 공개 웹 배포와 배포 도메인에서의 브라우저 검증은 미실행.

## 목표와 범위

실제 Supabase 계정으로 로그인하고, 재실행 때 서버에서 확인한 세션으로 홈을 복원한다. 기존 로컬 계정·반려동물·추억·참여 기록은 보존한다. 선행 작업은 [T27 DB·권한 구축](t27-supabase-profiles-and-pets.md)이다.

이번 작업은 기존 계정의 이메일 로그인, 현재 기기의 로그아웃, SDK 세션 저장·복원·갱신, 오류 처리 및 앱 연결이다. 사용자 프로필·반려동물 DB 연결은 후속 [T29](t29-supabase-pet-integration.md)에서 완료했다. 회원가입·인증메일·비밀번호 재설정과 로컬 기록 이전은 남은 범위다. 공개 서비스 준비 완료로 처리하지 않는다.

## 확정한 동작

- 앱 진입점은 Supabase 설정이 하나라도 있거나 release 빌드이면 온라인 인증을 사용한다. 설정이 누락·잘못되면 오류와 재시도를 표시하며 로컬 인증으로 통과하지 않는다. 설정 없는 debug 실행만 기존 로컬 데모를 사용한다.
- 온라인 로그인에는 기존과 같은 이메일 정규화·형식 검사 및 비밀번호 8자 이상 검사를 적용한다. 버튼은 처리 중에만 비활성화하며, 빈 입력은 제출 후 검증한다. D2의 별도 버튼 변경은 이번 범위에 없다.
- 온라인 화면에서는 로컬 회원가입·테스트 이용 버튼을 숨긴다. 해당 저장소 메서드를 직접 호출해도 온라인 모드에서는 거부한다. 서버 비밀번호 검증 실패 시 로컬 비밀번호를 검사하지 않는다.
- 온라인 사용자 ID는 Auth가 반환한 ID다. 로컬 이메일이 같아도 소유자를 연결하거나 기록을 이전하지 않는다. 화면 표시 이름만 사용자 메타데이터를 사용하며, 인증·소유권 판정에 사용하지 않는다.
- SDK 세션 저장과 자동 토큰 갱신을 활성화했다. 기존 `petsns.v1`의 로컬 세션은 온라인 인증 근거로 쓰지 않는다. 재시작 시 `getUser()`로 확인하며, 만료된 세션은 먼저 갱신한다.
- 무효 세션은 지우고 로그인으로 돌아간다. 복원 중 네트워크 실패는 홈 진입을 막고 재시도를 제공한다. 인증 스트림 오류도 처리하며, 만료된 토큰은 저장소의 사용자 판정에서 거부한다.
- 로그아웃은 `SignOutScope.local`로 현재 기기의 갱신 세션을 해제한다. 다른 기기의 로그인은 유지한다. SDK는 로컬 세션을 먼저 제거하므로 서버 요청 실패 시에도 이 기기의 로그인 상태는 해제된다. 이미 발급된 JWT는 만료 전까지 서버에서 유효할 수 있다.
- 인증 정보는 SDK 전용 저장소에 저장한다. 온라인 로그인·로그아웃으로 기존 로컬 JSON·비밀번호 해시·기록을 다시 쓰지 않는다. 토큰·비밀번호·서버 응답 본문은 오류 안내에 포함하지 않는다.

## 완료 기준과 증거

1. **실제 인증:** 개발 계정 A·B의 올바른 비밀번호로 독립된 Auth ID를 얻고, 잘못된 비밀번호는 거부한다. 실제 계정 검사에서 통과했다.
2. **세션 복원:** SDK 저장소에 세션이 남고, SDK를 종료·재초기화한 뒤 서버 확인으로 동일 사용자 ID를 복원한다. 실제 갱신 토큰 요청도 통과했다. 실제 배포 도메인의 브라우저 새로고침 검증과는 구분한다.
3. **로그아웃:** SDK 메모리·저장소의 세션이 없어지고 재초기화 후에도 로그인 상태가 되지 않는다. 실제 계정 검사에서 통과했다.
4. **차단:** 로컬 세션·일치하는 로컬 비밀번호·테스트 버튼으로 온라인 인증을 우회할 수 없다. 설정 누락, 잘못된 JWT, 만료, 네트워크 장애 및 중복 요청은 자동 검사로 검증했다.
5. **보존:** 기존 로컬 데이터 문자열이 인증 전·후와 재초기화 후 동일하다. 실제 계정 검사와 저장소 회귀 검사에서 확인했다.
6. **배포 산출물:** 설정을 포함한 `flutter build web --release`가 성공한다. 생성된 `build/web`을 공개 호스팅에 올린 결과는 아직 검증하지 않았다.

## 수행한 작업과 결과

- [인증 서비스](../../lib/supabase_auth_service.dart)를 추가하고, [앱 진입점](../../lib/main.dart), [저장소](../../lib/store.dart), [로그인 화면](../../lib/screens/login_screen.dart), [SDK 초기화](../../lib/supabase_connection.dart)를 연결했다.
- [자동 인증 검사](../../test/supabase_auth_test.dart) 7개 통과. 인증 실패·복원·만료·현재 세션 로그아웃·우회 금지·버튼 처리 중 상태·설정 실패를 검사한다.
- [실제 계정 검사](../../test/supabase_auth_live_test.dart)에서 19개 조건 통과. 원격 Supabase Auth를 사용하고 Flutter 테스트용 로컬 저장소에 기존 기록을 준비했다. 실제 사용자의 브라우저 저장소를 수정하지 않았다.
- 전체 Flutter 테스트 **93개 통과, 선택 실행 3개 건너뜀**. 이 중 실제 인증 검사는 위 명령으로 별도 실행했으며, 다른 선택 실행 검사를 이번 단계에서 실행한 것으로 기록하지 않는다.
- 웹 release 빌드 및 최종 `flutter analyze` 통과, 오류·경고 없음. 인증 로그는 Git 제외된 `build/db-verification/auth-live-results.log`, 전체 회귀 로그는 `auth-regression-results.log`에 저장했다.
- DB 구조·RLS·개발 계정 비밀번호는 변경하지 않았다. T27의 유출 비밀번호 차단 비활성화 경고는 남아 있다. 이 기능은 [Pro 요금제 이상에서 제공](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection)된다. 현재 요금제와 실제 서비스 가입 전 설정은 후속 확인 대상이며 유료 요금제로 변경하지 않았다.

## 재현

저장소 루트에서 실행한다. 개발 프로젝트 URL·Publishable Key는 `config/supabase.local.json`, 전용 계정 A·B는 Git 제외된 `config/supabase.test.local.json`을 사용한다. 계정 파일은 앱 빌드 설정이나 자산에 넣지 않는다.

```powershell
flutter test
flutter analyze
flutter build web --release --dart-define-from-file=config/supabase.local.json
$env:PET_SNS_RUN_AUTH_LIVE = '1'
try {
  flutter test test/supabase_auth_live_test.dart --dart-define-from-file=config/supabase.local.json --reporter expanded
} finally {
  Remove-Item Env:PET_SNS_RUN_AUTH_LIVE
}
```

성공 출력은 `PASS: 19 assertions; two real users, refresh, SDK restart, logout, local records preserved.`이다. 테스트는 현재 실행에서 만든 로그인 세션을 로그아웃하며 Auth 사용자와 DB 기록은 삭제하지 않는다.

## 다음 구현

본인 사용자 프로필 초기화·조회와 반려동물 CRUD·Day 0 연결은 [T29](t29-supabase-pet-integration.md)에서 진행했다. 배포 실행은 사용자의 요청에 따라 별도 단계로 남긴다. 최신 실행 모드와 검증 결과도 T29를 기준으로 한다. 로컬 기록 이전은 소유 확인·동의·실패 복구 규칙을 정한 뒤 별도 구현하며 같은 이메일이라는 이유만으로 이전하지 않는다.

## 근거

- [Supabase Flutter 이메일 로그인](https://supabase.com/docs/reference/dart/auth-signinwithpassword), [인증 이벤트](https://supabase.com/docs/reference/dart/auth-onauthstatechange), [로그아웃](https://supabase.com/docs/reference/dart/auth-signout).

# T27 Supabase 사용자 반려동물 DB와 접근 권한 구축

작성일: 2026년 10월 10일. 상태: 개발 Supabase DB 적용 및 실제 A·B 계정 검증 완료. 후속 인증 연결은 [T28](t28-supabase-login-and-session.md), 앱 데이터 연동은 미완료.

## 목표와 범위

사용자 프로필과 반려동물을 Supabase PostgreSQL에 저장할 기반을 만들고, 로그인한 사용자가 본인 데이터만 접근하도록 보장한다.

이번 작업은 DB 스키마, 마이그레이션 SQL, RLS, 자동 검증 및 결과 기록까지다. Flutter 로그인 화면과 `PetStore` 데이터 연결, 로컬 기록 이전, 사진 파일 업로드, 게시글·약속·채팅 DB는 후속 작업이다. 기존 `petsns.v1` 데이터는 수정하지 않는다.

## 확인한 현재 상태

- 앱은 Supabase SDK 초기화와 Auth 설정 접근만 확인한다. 앱 로그인과 데이터 저장은 여전히 SharedPreferences를 사용한다.
- 적용 전 개발 프로젝트 `PetSNS` (`inbsusvyxxvmthdavbha`)의 public 테이블·마이그레이션과 Auth 사용자는 모두 0개였다. 앱 설정 URL과 대상 프로젝트가 같음을 확인하고 적용했다.
- Docker 엔진은 실행되지 않는다. 로컬 SQL 검증은 PGlite를 사용하며, Supabase CLI 2.120.0은 Git 제외된 `build/db-verification`에 설치했다.

## 확정한 삭제 정책

사용자가 2026년 10월 10일 **연결 기록이 있으면 삭제 차단**을 선택했다. 자동 연쇄 삭제는 사용하지 않는다.

반려동물이 있는 사용자 프로필은 삭제할 수 없다. 프로필이 남아 있는 Auth 사용자도 DB 외래키로 삭제를 막는다. 계정 삭제 화면·API는 이번 범위에 없다.

이번 스키마에는 사진·일기·참여 테이블이 없으므로 해당 참조에 대한 차단까지 구현되었다고 주장하지 않는다. 향후 연결 테이블은 반려동물을 참조하는 `ON DELETE RESTRICT` 외래키를 추가한 뒤 삭제 기능을 연결한다. 참조가 없는 검증용 반려동물은 본인이 삭제할 수 있다.

## 데이터 모델과 규칙

- `profiles`: Auth 사용자 ID와 같은 UUID `id`, 필수 `name`. 비밀번호·이메일은 복제하지 않는다. 이름은 앞뒤 공백 없이 1~30자로 제한한다.
- `pets`: 기존 로컬 ID 이전이 가능하도록 문자열 `id`, 필수 `owner_id`, 필수 이름 1~60자, 선택 품종 최대 80자, 선택 생일·사진·Day 0 기준과 날짜. 소유자는 존재하는 사용자 프로필이어야 한다.
- 이름·품종 제한은 기존 UI의 30/60/80을 DB에도 적용한다. PostgreSQL의 `char_length` 기준이며 Flutter의 복합 문자 길이와 차이가 있을 수 있다. 앱 연결 단계에서 같은 입력 검증을 맞춘다.
- 생일과 Day 0 날짜는 1990년 1월 1일 이상이다. Day 0 기준은 `firstMeeting` 또는 `firstPhoto`이며 기준·날짜는 함께 입력하거나 모두 비워 둔다.
- 오늘 이후 날짜와 가장 오래된 사진을 기준으로 하는 Day 0 검사는 시간·사진 연동 단계에서 추가한다. 기존 앱 검사는 유지한다.
- `photo`는 기존 모델의 사진 참조 문자열을 위한 필드다. 파일 접근 권한·장당 3,145,728바이트 제한·파일 형식 검증은 사진 저장소 단계에서 구현한다.

## 접근 규칙

두 테이블 모두 RLS를 켜고 권한을 명시적으로 부여한다. 로그인 사용자는 본인 행만 조회·생성·수정·삭제할 수 있다. 비로그인 역할에는 테이블 권한을 부여하지 않는다.

타인 명의 생성과 타인 기록 조회·수정·삭제를 차단한다. 로그인 사용자는 프로필 ID, 반려동물 ID와 소유자 ID를 변경할 수 없다. 사용자 프로필은 이름만, 반려동물은 내용 필드만 수정할 수 있다.

## 완료 기준과 재현 방식

1. **DB 생성:** 기존 테이블이 없는 별도 검증 DB에 마이그레이션을 적용하고 테이블·제약조건·인덱스·RLS·권한을 검사한다. 새 DB에서 동일 검증을 두 번 수행한다.
2. **정상 CRUD:** 서로 다른 A·B 계정으로 각각 본인 프로필·반려동물을 생성·조회·수정·삭제하고, 재조회한 값과 삭제 결과를 확인한다.
3. **권한 차단:** 상대방 ID 직접 조회, 수정, 삭제, 타인 명의 생성, ID·소유자 변경, 비로그인 CRUD를 검사한다. 성공 HTTP 응답이더라도 결과 0건 및 소유자 재조회 결과로 차단을 판정한다.
4. **무결성·삭제:** 필수값·길이·Day 0 조합·외래키 위반을 거부한다. 반려동물이 남아 있는 프로필과 프로필이 남아 있는 Auth 사용자 삭제가 실패해야 한다.
5. **실제 Supabase:** 앱용 Publishable Key와 독립된 A·B Auth 세션으로 REST API를 호출한다. 관리자 키를 사용자 권한 검증에 쓰지 않는다.
6. **기록 보존:** 기존 Flutter 저장소 테스트와 연결 전후 보존 테스트로 로컬 기록이 유지됨을 확인한다.

SQL 역할 테스트는 DB 권한·제약조건의 증거이며 실제 Auth 토큰·게이트웨이·원격 설정 검증을 대신하지 않는다. 미실행·건너뛴 검증은 PASS로 기록하지 않는다.

## 작업 결과와 남은 작업

- **원격 적용 완료:** [사용자·반려동물 스키마](../../supabase/migrations/20261010063830_profiles_and_pets.sql), [기존 RLS 도우미 실행 권한 제한](../../supabase/migrations/20261010064515_restrict_rls_auto_enable_execute.sql). 원격 이력과 파일 버전을 맞췄다. 테이블 2개 RLS 활성화, 작업별 정책 8개를 확인했다.
- **검증 코드:** [SQL 검사](../../supabase/tests/profiles_and_pets.sql), [반복 실행 스크립트](../../scripts/verify-db.mjs), [실제 계정 API 검사](../../test/supabase_db_live_test.dart), [Auth 부모 삭제 제한 검사](../../supabase/tests/auth_delete_restrict.sql).
- **PASS:** PGlite 0.3.14의 새 PostgreSQL DB 두 곳에서 각각 69개 검사 통과. Auth 스키마·역할·사용자 ID 및 기본 DDL 도우미는 테스트용 구성이다. 실제 Supabase 인증 결과와 구분한다. 각 실행 후 Auth 테스트 데이터 롤백을 확인했고, 상세 결과는 Git 제외된 `build/db-verification/results.json`에 저장한다.
- **PASS:** `test/store_test.dart`, `test/supabase_connection_test.dart` 합계 36개 테스트 통과.
- **PASS:** 실제 `test/supabase_live_test.dart` 1개 통과. Auth 설정 HTTP 200, 잘못된 키 거부, 초기화 전후 테스트용 로컬 기록 보존을 확인했다. 사용자별 DB 권한 증거는 아니다.
- **PASS:** `flutter analyze` 오류 없음.
- **PASS:** 실제 Supabase Auth 비밀번호 로그인으로 A·B의 독립된 일반 사용자 토큰을 발급받아 76개 API 검사 통과. 본인 CRUD, 양방향 타인 접근 차단, ID·소유자 변경 금지, 비로그인 차단, 입력 제한, 반려동물이 남은 프로필 삭제 차단 및 정리를 확인했다. Publishable Key를 사용했으며 관리자 키로 권한 검사를 하지 않았다. 최종 출력은 Git 제외된 `build/db-verification/live-api-results.log`에 저장한다.
- **PASS:** 원격 DB에서 프로필이 있는 Auth 사용자 삭제가 외래키 위반으로 실패함을 별도 트랜잭션으로 확인하고 롤백했다. 최종 조회 결과 `profiles=0`, `pets=0`, 전용 Auth 계정 2개다.
- **계정 준비:** 사용자 승인으로 개발용 계정 A·B를 관리 SQL로 생성했다. 역할은 `authenticated`, 관리자 권한은 없으며, 이메일 확인 상태는 테스트 준비 단계에서 설정했다. 실제 이메일 발송·가입·메일 소유 확인을 검증한 결과는 아니다. 비밀번호는 Git 제외된 `config/supabase.test.local.json`에만 저장했다.
- **점검:** 기존 `rls_auto_enable()`의 클라이언트 실행 권한 경고 2건을 해소했다. 해당 이벤트 트리거는 활성화 상태를 유지한다. 최종 성능 Advisor 알림은 0건이다. Auth의 **유출 비밀번호 차단 비활성화** 경고 1건은 남아 있으며, 실제 가입·로그인 연결 전 [설정 지원 범위와 활성화](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection)를 확인한다.
- **T27 단계의 보존:** `lib/` 앱 코드는 변경하지 않았고 사용자 로컬 저장소를 수정하지 않았다. 이후 T28에서 앱 인증을 연결했다. 기존 AGENTS·README·한국어 가이드의 작업 중 변경은 보존했다.

## 재실행 및 원격 적용

저장소 루트에서 검증용 의존성을 Git 제외된 `build` 아래에 설치하고 SQL 검사를 실행한다. Flutter 앱 의존성은 추가하지 않는다.

```powershell
npm.cmd install --prefix build/db-verification --no-audit --no-fund --ignore-scripts @electric-sql/pglite@0.3.14
node scripts/verify-db.mjs
flutter test test/store_test.dart test/supabase_connection_test.dart
flutter analyze
```

이번 개발 프로젝트에는 두 마이그레이션이 이미 적용되었다. 다른 대상에 적용할 때 프로젝트·기존 테이블·정책·마이그레이션 이력을 먼저 확인한다. 이미 적용한 파일을 다시 실행하지 않으며, 기존 테이블을 덮어쓰거나 운영 DB를 초기화하지 않는다.

SQL 검사는 별도 개발 DB에서 관리자 세션으로 테스트 Auth 사용자만 준비한 뒤, 실제 DML 권한 검사를 `authenticated`·`anon` 역할로 수행한다. 전체 테스트는 롤백된다. `psql --set ON_ERROR_STOP=1 --file supabase/tests/profiles_and_pets.sql`로 실행할 수 있으며, 이 파일은 pgTAP 형식이 아니다.

실제 Supabase 검증에는 **프로필 행이 없는 전용 개발 계정 A·B**를 사용한다. 기존 프로필이 있으면 덮어쓰지 않고 테스트를 중단한다. 이메일·비밀번호는 Git 제외된 `config/supabase.test.local.json`에서 테스트 실행 중 읽는다. 같은 이름의 환경변수로 대체할 수도 있다. 이 파일을 `--dart-define-from-file`이나 앱 자산으로 포함하면 안 된다.

다른 개발 환경에서는 `config/supabase.test.example.json`을 `config/supabase.test.local.json`으로 복사하고 준비한 전용 계정의 값을 입력한다. 이번 작업 환경에는 계정 값이 이미 저장되어 있다.

```powershell
$env:PET_SNS_RUN_DB_LIVE = '1'
try {
  flutter test test/supabase_db_live_test.dart --dart-define-from-file=config/supabase.local.json --reporter expanded
} finally {
  Remove-Item Env:PET_SNS_RUN_DB_LIVE
}
```

성공 출력은 `PASS: 76 API assertions with two Auth sessions; fixture cleanup completed.`이다. 테스트는 이번 실행에서 만든 프로필·반려동물만 정리하고 Auth 계정은 삭제하지 않는다. 정리 실패도 테스트 실패로 처리한다. 원격 Auth 삭제 제한은 개발 DB의 관리자 SQL 세션에서 `supabase/tests/auth_delete_restrict.sql`을 실행하면 재현할 수 있다. 오류 없이 롤백되어야 한다.

Supabase Auth 로그인·로그아웃·세션 복원은 후속 T28에서 연결했다. 다음 구현은 본인 프로필·반려동물 CRUD의 앱 연동이다. 기존 로컬 기록 이전 규칙을 정하고 데이터 보존 검증을 통과한 뒤 연결한다. 온라인 배포 완료는 아직 주장하지 않는다.

## 근거

- [프로필 T06](t06-create-or-edit-a-pet-profile.md), [삭제 T07](t07-delete-a-pet-profile.md), [Day 0 T09](t09-set-a-pet-s-day-0.md).
- [현재 저장소](../../lib/store.dart), [프로필 폼](../../lib/forms/profile_form.dart), [로그인 화면](../../lib/screens/login_screen.dart).
- [Supabase RLS 공식 설명](https://supabase.com/docs/guides/database/postgres/row-level-security).

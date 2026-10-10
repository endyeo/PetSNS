# T30 추억의 하루 기록 DB 연결

작성일: 2026년 10월 10일. 상태: 구현·원격 API·release 산출물 검증 완료. 웹 배포는 실행하지 않았다.

온라인 사진의 후속 구현은 [T31](t31-supabase-memory-photos.md)에 기록한다. 아래 사진 차단 설명과 수치는 T30 완료 시점의 이력이다.

## 목표와 범위

반려동물의 날짜별 제목·메모·기념일을 Supabase에 저장하고 같은 계정의 다른 실행 환경에서 조회한다. 선행 작업은 T27~T29다. 사진 업로드·사진 메타데이터 DB, 모임·채팅 DB, 로컬 데이터 이전은 별도 단계다.

## 확정한 동작

- 기존 T13의 반려동물·날짜당 일기 1개, 빈 제목·메모 허용, 사진 없는 날짜 저장, 기념일 표시는 유지한다. 새 글자 수 제한은 도입하지 않는다.
- 날짜는 1990년 1월 1일부터 KST 오늘까지다. 앱과 DB에서 모두 검사한다. 기념일은 매년 알림을 만드는 기능이 아니다.
- 기존 일기를 반복 저장하면 동일 행을 갱신한다. 저장은 DB의 한 트랜잭션으로 실행하며 작성자 ID는 현재 Auth에서 결정한다. 동시 같은 날짜 저장은 마지막 서버 저장이 적용된다.
- 본인 반려동물의 일기만 작성·조회·수정·삭제한다. 일기 소유자와 반려동물 소유자가 일치해야 한다. API를 직접 호출해도 다른 사람의 동물에 일기를 연결할 수 없다.
- 일기가 있는 반려동물 삭제는 서버 FK로 차단한다. 다른 기기의 오래된 목록에서 삭제를 시도해도 차단한다. 일기를 명시적으로 삭제한 후 연결 기록이 없으면 반려동물을 삭제할 수 있다. 빈 일기도 기록으로 취급한다.
- 로그인·복원 시 일기까지 서버에서 조회한 뒤 홈에 진입한다. 서버 실패를 로컬 일기로 대체하지 않는다. 성공 응답 뒤 화면을 갱신하고 실패·중복 요청·계정 변경 시 다른 계정에 응답을 적용하지 않는다.
- 일기는 500행씩 끝까지 읽어 API의 기본 반환 개수 때문에 오래된 기록이 잘리지 않도록 한다. 재로그인·재실행 시 다시 조회하며 실시간 동기화는 이번 범위가 아니다.
- 온라인 일기는 로컬 JSON에 저장하지 않고 기존 로컬 계정·일기·사진을 이전하지 않는다. 온라인 모드에서는 사진·모임 작성 제한을 유지한다.
- 온라인 하루 기록 편집에 삭제 버튼과 확인 창을 추가한다. 삭제는 해당 반려동물·날짜의 글과 기념일 표시만 지운다. 로컬 데모의 기존 저장 동작은 유지한다.

## 완료 기준과 증명

1. A의 앱에서 저장·수정한 제목·메모·기념일을 독립 클라이언트와 새 앱 저장소에서 읽는다. 반복 저장·동시 저장 후 한 행만 존재해야 한다.
2. 반려동물과 날짜가 다른 일기는 분리한다. 빈 일기·긴 메모·1990년 경계는 허용하며 미래 날짜·1990년 이전·무효 날짜는 거부한다.
3. B의 직접 API 읽기·수정·삭제·소유자 위조와 A의 동물에 B의 일기를 만드는 요청은 거부한다. 미인증 조회와 저장도 거부한다.
4. 일기 저장 전에 조회했던 다른 클라이언트에서도 반려동물 삭제가 실패해야 한다. 일기를 삭제한 뒤 삭제할 수 있어야 한다.
5. 서버 실패·중복 저장·계정 전환 시 캐시를 잘못 변경하지 않는다. 기존 로컬 JSON이 유지되고 로컬 기능 회귀 검사, 정적 분석, release 빌드가 통과해야 한다.
6. 한국어 PRD에 실행한 명령·실제 결과·남은 범위를 기록한다. 실제 배포 도메인 E2E는 공개 호스팅 이후 별도 수행한다.

## 수행 기록

- 변경 전에 원격 `public` 표는 `profiles`, `pets`이고 각각 0행인 것을 확인했다. 기존 표를 교체하거나 운영 기록을 삭제하지 않았다.
- [마이그레이션](../../supabase/migrations/20261010080713_memory_days.sql)을 CLI로 생성한 후 로컬 SQL 검증을 거쳐 개발 Supabase에 적용했다. 로컬 파일 버전은 실제 원격 마이그레이션 이력과 일치한다.
- `memory_days`의 복합 PK `(pet_id, record_date)`와 반려동물·소유자의 복합 FK를 추가했다. FK는 `ON DELETE/UPDATE RESTRICT`다. 본인만 허용하는 CRUD RLS와 명시적 권한을 설정하고 소유자·반려동물·날짜는 수정 권한에서 제외했다.
- `save_memory_day` RPC는 **SECURITY INVOKER**로 호출자 권한을 사용하며 Auth의 사용자 ID로 작성자를 정한다. 빈 검색 경로와 함수별 실행 권한을 설정했고 미인증 호출은 금지했다. 관리자 키를 클라이언트에 추가하지 않았다.
- [일기 REST 저장소](../../lib/supabase_memory_repository.dart), 앱 시작·계정별 캐시·저장소·편집 화면을 연결했다. 일기는 성공 응답 뒤 화면에 반영하며 로컬 JSON에 쓰지 않는다.
- [로컬 SQL 검사](../../supabase/tests/memory_days.sql)를 기존 DB 검사와 함께 PGlite 0.3.14의 새 DB 두 개에서 실행해 **93개 조건씩 통과**했다. 이는 기존 사용자·반려동물 검사와 이번 일기 검사를 합한 수이며 실제 Auth 검사는 아니다. 결과는 `build/db-verification/results.json`에 기록했다.
- [일기 단위·화면 검사](../../test/supabase_memory_test.dart) **7개 통과**. 서버 실패·날짜 검증·501행 조회·중복 요청·계정 전환·차단된 사진 저장의 캐시 보존과 UI 저장·삭제 취소·확인 삭제를 검사했다.
- [실제 계정 검사](../../test/supabase_memory_live_test.dart) **36개 조건 통과**. 원격 Auth를 사용하는 일반 계정 A·B로 앱 CRUD, 독립 클라이언트 재조회, 동시 저장의 단일 행·필드 일관성, 직접 API 권한 차단, 서버 날짜 검증과 오래된 클라이언트의 반려동물 삭제 차단을 확인했다. 실제 두 브라우저를 조작한 E2E와는 구분한다.
- 전체 Flutter 회귀 검사 **110개 통과, 선택 실행 5개 건너뜀**. 실제 일기 검사는 별도 실행했으며 다른 선택 실행 검사를 이번 단계에서 실행한 것으로 기록하지 않는다. 최종 `flutter analyze` 오류·경고 없음, 웹 release 빌드 통과.
- 웹 텍스트 산출물 **14개**에서 실제 테스트 이메일·비밀번호 4개 값이 없는 것을 확인했다. 계정 파일과 산출물은 Git 제외 상태다. 웹 호스팅·배포 도메인 검사는 실행하지 않았다.
- 이번 실행이 만든 일기·반려동물·프로필만 일반 사용자 API로 정리했다. 종료 후 세 표는 각각 **0행**임을 확인했고 Auth 개발 계정은 유지했다. 원격 성능 advisor 지적은 0개다. 새 DB 보안 경고는 없으며 T28의 [유출 비밀번호 차단 비활성화 경고](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection)는 그대로 남아 있다.
- 실제 계정·회귀·빌드 로그는 Git 제외된 `build/db-verification/memory-live-results.log`, `memory-regression-results.log`, `memory-web-build-results.log`에 기록했다.

## 재현 명령

프로젝트 URL·Publishable Key는 `config/supabase.local.json`, 전용 계정 A·B는 Git 제외된 `config/supabase.test.local.json`을 사용한다. 계정 파일을 빌드 설정이나 Flutter 자산으로 추가하지 않는다. SQL 검사는 T27에서 준비한 PGlite 0.3.14 환경을 사용한다.

```powershell
node scripts/verify-db.mjs
flutter test
flutter analyze
./scripts/build-web.ps1
$env:PET_SNS_RUN_MEMORY_LIVE = '1'
try {
  flutter test test/supabase_memory_live_test.dart --dart-define-from-file=config/supabase.local.json --reporter expanded
} finally {
  Remove-Item Env:PET_SNS_RUN_MEMORY_LIVE
}
```

실제 검사 성공 출력은 `PASS: 36 assertions; app CRUD, independent clients, RLS, concurrent upsert, pet deletion FK, cleanup, local preservation.`이다. 전용 계정에 기존 동물·일기가 있으면 테스트를 중단하고 기존 데이터를 삭제하지 않는다. 생성 요청의 응답이 끊겨 테스트가 ID를 확인하지 못한 기록은 자동 삭제하지 않는다.

## 다음 구현

사진 파일 저장소와 사진 메타데이터 DB를 연결해 온라인 사진 업로드를 활성화한다. 사진의 반려동물 FK, 비공개 파일 접근, Day 0 갱신, 실패 시 남는 파일의 복구·정리 정책을 함께 검증한다. 모임·채팅과 공개 서비스용 가입 흐름은 후속 범위다.

## 근거

[Supabase 함수와 호출자 권한](https://supabase.com/docs/guides/database/functions), [FK 삭제 제한](https://supabase.com/docs/guides/database/postgres/cascade-deletes), [RLS](https://supabase.com/docs/guides/database/postgres/row-level-security).

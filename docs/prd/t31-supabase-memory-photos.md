# T31 추억 사진 저장소·DB 연결

작성일: 2026년 10월 10일. 상태: 구현·개발 Supabase 적용·검증 완료. 웹 호스팅은 배포하지 않았다.

## 목표와 확정 범위

추억 사진을 비공개 Supabase Storage와 사진 DB에 저장한다. 같은 계정의 다른 실행 환경에서 조회·날짜 수정·교체·삭제하고, 사진이 있으면 반려동물 삭제를 서버에서 차단한다. 기존 로컬 사진을 자동 이전하지 않는다. 프로필 사진 업로드, 모임·채팅, 공개 가입 흐름은 후속 작업이다.

- 파일당 최대 **3 MiB(3,145,728바이트)**, JPEG·PNG·WebP·GIF를 허용한다. DB에는 파일 경로·반려동물·소유자·날짜를 저장하며 base64와 만료되는 서명 URL을 저장하지 않는다.
- 파일은 로그인한 소유자의 Auth 토큰으로 필요한 때 내려받는다. 공개 URL을 만들지 않고, 로그아웃·계정 변경 시 화면의 다운로드 결과를 폐기한다.
- 다운로드마다 `cacheNonce`를 붙여 삭제 전의 CDN 응답을 재사용하지 않는다. 사진 위젯은 실패 시 재시도를 제공하고, 계정 변경·화면 종료 시 해당 이미지 캐시를 제거한다. 다른 기기의 변경을 열린 화면에 실시간 반영하는 기능은 후속 범위다.
- `pending → ready → deleting` 상태로 파일과 DB의 비원자적 저장을 관리한다. 여러 파일의 공개 상태 전환과 사진 교체는 한 DB 트랜잭션이다. 교체가 완료되기 전 기존 사진을 지우지 않는다.
- 실패한 요청의 예약은 취소·정리를 시도한다. 응답만 유실된 완료 사진은 지우지 않는다. 정리 실패는 DB에 남기고 재접속 시 재시도한다. 중단된 pending 업로드는 **24시간 이후** 정리 대상으로 바꾼다. 접속 없는 계정의 자동 주기 정리는 이번 범위가 아니다.
- 파일은 Storage API로 삭제한 뒤 DB 예약을 제거한다. 정리 중에도 반려동물 FK는 유지한다. 업로드와 취소는 DB 행 잠금으로 직렬화해 정리 뒤 파일이 뒤늦게 생기는 것을 막는다.
- 날짜는 1990년 1월 1일부터 KST 오늘까지다. 첫 만남 이전 사진은 서버에서도 거부한다. 첫 사진 기준에서 더 오래된 사진을 저장하면 Day 0을 함께 앞당긴다. 삭제·날짜를 뒤로 수정할 때 기존 Day 0을 자동으로 늦추지 않는다.
- 기존 하루 기록은 사진 삭제로 지우지 않는다. 모든 사진을 지워도 일기가 있으면 반려동물 삭제는 계속 차단한다.

## 완료 기준과 증명

1. 일반 계정 A로 업로드·독립 클라이언트 재조회·다운로드·날짜 변경·교체·삭제를 재현한다. B 및 미인증의 메타데이터와 파일 접근, 경로 위조, 덮어쓰기는 차단한다.
2. 파일 크기·종류·날짜·타인 반려동물 연결을 직접 API에서도 검사한다. 파일 없는 사진의 완료 전환과 파일이 남은 예약 삭제를 거부한다.
3. 여러 장 저장 실패, 교체 실패, 완료 응답 유실, 정리 실패·재시도, 늦은 업로드 차단을 검사한다. 불완전한 사진은 갤러리에 나타나지 않는다.
4. 오래된 클라이언트의 반려동물 삭제를 FK로 거부한다. 첫 만남·첫 사진 Day 0 규칙은 직접 API 호출에도 유지한다.
5. 로컬 JSON 보존, 계정 전환 시 캐시 폐기, 화면 표시·회귀 검사, 정적 분석과 웹 release 빌드를 확인한다. 실제 배포 도메인 E2E는 호스팅 이후에 수행한다.

## 수행 기록

- 원격 Storage 버킷·파일·정책이 모두 없는 상태를 확인했다. 기존 데이터나 버킷을 교체하지 않는다.
- Supabase 변경 기록과 비공개 저장소·업로드 제한 문서를 확인했다. Storage 스키마에 앱 표·함수를 만들지 않고, 공식적으로 허용된 RLS·트리거만 추가한다.
- CLI로 [사진 마이그레이션](../../supabase/migrations/20261010083713_memory_photos.sql)을 생성하고 새 로컬 DB에서 검증한 뒤 원격 개발 프로젝트에 적용했다. 소유자·UUID로 생성되는 고정 경로, 반려동물·소유자의 복합 FK, 상태 전환·파일 존재 검사, Day 0 트리거와 배치 완료 RPC를 추가했다. 모든 함수는 **SECURITY INVOKER**, 빈 검색 경로와 명시적 실행 권한을 사용한다.
- 실제 업로드에서 Storage 내부의 최종 커밋 역할에 예약 표 권한이 부족한 것을 발견했다. [별도 마이그레이션](../../supabase/migrations/20261010084103_storage_photo_backend_grants.sql)으로 서버의 `service_role`에 예약 **SELECT·UPDATE(state)**만 허용해 조회·행 잠금을 가능하게 했다. 일반 사용자의 검사는 Auth 사용자 토큰으로 실행하며, 앱이나 테스트 계정 파일에 관리자 키를 추가하지 않았다. 로컬 파일 버전은 원격 마이그레이션 이력과 일치한다.
- [사진 저장소](../../lib/supabase_photo_repository.dart), [PetStore](../../lib/store.dart), 앱 시작·계정별 캐시, 사진 표시·편집·정리 재시도 화면을 연결했다. 완료 응답을 잃어도 ready 사진을 지우지 않으며, 취소 요청이 행 잠금을 기다리는 사이 완료된 경우에도 다시 상태를 확인한다. 프로필 사진 업로드는 계속 제한한다.
- [SQL 검사](../../supabase/tests/memory_photos.sql)를 기존 검사와 함께 PGlite 0.3.14 새 DB 두 개에서 실행해 **121개 조건씩 통과**했다. 이는 T27~T31의 합계다. 24시간보다 오래된 예약만 정리하고 정확히 24시간인 예약은 유지하는 경계도 검사했다. 시간을 지정한 SQL fixture와 Storage 표 모형을 사용하므로 실제 Auth·파일 전송·24시간 대기 검사는 아니다. 결과는 `build/db-verification/results.json`이다.
- [사진 단위·위젯 검사](../../test/supabase_photo_test.dart) **10개 통과**. 여러 장 업로드 실패, 교체 실패의 원본 보존, 완료 응답 유실·취소와 겹친 완료, 정리 실패 안내·재시도, 입력 검증, 중복 요청·로그아웃 중 응답, 501행 조회, 실제 위젯의 인증 다운로드·재시도·계정 변경 시 폐기를 검사했다.
- [실제 A·B 검사](../../test/supabase_photo_live_test.dart) **53개 조건 통과**. 일반 Auth 계정으로 비공개 Storage와 사진 DB의 앱 CRUD·독립 클라이언트 조회·파일 바이트 일치, B·미인증 접근 차단, 경로·소유자·덮어쓰기 제한, 3 MiB·MIME 제한, 서버 날짜·Day 0·반려동물 FK를 확인했다. 동시에 두 클라이언트가 더 오래된 사진을 저장해도 가장 이른 날짜가 Day 0으로 유지됐다.
- 같은 실제 API 검사에 HTTP 전송 오류를 주입해 두 번째 업로드와 정리 실패, 원본을 보존하는 교체 실패, 실제 DB 커밋 뒤 응답 유실의 복구를 확인했다. Supabase 서비스 장애를 실제로 발생시킨 검사는 아니다. 이미 내려받은 파일의 CDN 응답이 삭제 후에도 잠시 남는 사례를 발견해, 삭제 검증과 앱 다운로드에 새 `cacheNonce`를 적용했다.
- 전체 Flutter 검사 **120개 통과, 선택 실행 6개 건너뜀**. 사진 실제 API 검사는 별도 실행했으며 나머지 선택 검사를 이번 단계에서 실행한 것으로 기록하지 않는다. 병행 홈 화면 수정 중 생긴 초기 컴파일 오류는 최신 저장본으로 재실행해 해소됐고, 해당 화면의 변경을 되돌리지 않았다. 최종 `flutter analyze` 오류·경고 없음.
- 최종 웹 release 빌드 통과. 빌드 시작·종료 시 전체 `lib` Dart 파일 해시가 같은 것을 확인했다. 웹 텍스트 산출물 **14개**에서 실제 테스트 이메일·비밀번호 4개 값이 없음을 검사했다. 계정 파일·산출물은 Git 제외 상태이며 호스팅 배포·실제 배포 도메인 E2E는 수행하지 않았다.
- 이번 검사가 만든 기록·파일만 일반 사용자 API로 정리했다. 종료 후 `profiles`, `pets`, `memory_days`, `memory_photos`, 해당 Storage 파일은 모두 **0개**다. 비공개 버킷과 Auth 개발 계정은 다음 검사를 위해 유지했다. 성능 advisor 지적은 0개이며, 보안 advisor에는 T28의 [유출 비밀번호 차단 비활성화 경고](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection)만 남았다.
- 최종 로그는 Git 제외된 `build/db-verification/photo-live-results.log`, `photo-regression-results.log`, `photo-web-build-results.log`에 기록했다. 한국어 수행 기록과 현재 범위를 README·PRD에 반영했다.

## 재현 명령

프로젝트 URL·Publishable Key는 `config/supabase.local.json`, 전용 계정 A·B는 Git 제외된 `config/supabase.test.local.json`을 사용한다. 계정 파일을 Flutter 자산·빌드 설정으로 추가하지 않는다. SQL 검사는 T27에서 준비한 PGlite 0.3.14 환경을 사용한다.

```powershell
node scripts/verify-db.mjs
flutter test test/supabase_photo_test.dart --reporter expanded
flutter test
flutter analyze
./scripts/build-web.ps1
$env:PET_SNS_RUN_PHOTO_LIVE = '1'
try {
  flutter test test/supabase_photo_live_test.dart --dart-define-from-file=config/supabase.local.json --reporter expanded
} finally {
  Remove-Item Env:PET_SNS_RUN_PHOTO_LIVE
}
```

실제 검사 성공 출력은 `PASS: 53 assertions; real private Storage, A/B isolation, app CRUD, Day 0, cleanup, FK and local preservation.`이다. 전용 계정에 기존 동물·사진이 있으면 검사를 중단하고 기존 자료를 삭제하지 않는다. 파일 크기 제한과 MIME 제한은 실제 Storage API, 24시간 경계는 SQL fixture로 각각 재현한다. 브라우저 업로드 선택기·배포 도메인·Android 기기 E2E는 이 결과에 포함되지 않는다.

## 다음 구현과 남은 범위

프로필 사진 업로드를 별도 경로·수명 정책과 연결한 뒤 모임·참여·채팅 DB를 연결한다. 공개 가입·이메일 검증·비밀번호 복구, 실시간 동기화, 미접속 계정의 주기적 파일 정리는 후속 범위다. 지금 구현한 정리는 **재접속 또는 화면 재시도 시** 실행하며, 배포만으로 주기 정리가 시작되지는 않는다.

## 근거

[비공개 버킷과 인증 다운로드](https://supabase.com/docs/guides/storage/buckets/fundamentals), [버킷 업로드 제한](https://supabase.com/docs/guides/storage/buckets/creating-buckets), [CDN 무효화와 cacheNonce](https://supabase.com/docs/guides/storage/cdn/smart-cdn), [Storage RLS·트리거 허용 범위](https://supabase.com/changelog/34270-restricting-access-on-auth-storage-and-realtime-schemas-on-april-21-2025).

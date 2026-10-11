# T32 반려동물 프로필 사진 업로드

작성일: 2026년 10월 10일. 상태: 개발 DB 적용·자동 검증 완료. 웹 호스팅은 배포하지 않았다.

## 목표와 범위

온라인 반려동물 프로필에서 사진 선택·교체·사진만 제거를 지원하고 다른 실행 환경에서 다시 조회한다. 프로필 사진도 소유자 전용 비공개 파일로 저장한다. 공개 프로필·모임 공유 시 접근 범위는 해당 기능의 DB 연결 때 별도 확정한다. 기존 외부 사진 URL·로컬 사진은 보존하고 자동 이전하지 않는다.

- 파일당 **3 MiB(3,145,728바이트)**, JPEG·PNG·WebP·GIF를 허용한다. 추억 사진과 별도 `pet-avatars` 버킷을 사용한다.
- 새 사진 파일을 먼저 예약·업로드하고 프로필 필드와 사진 참조를 한 DB 트랜잭션으로 확정한다. 실패한 신규 프로필을 미리 생성하지 않는다. 기존 프로필·Day 0·추억 연결은 교체 실패 시 유지한다.
- 이전 사진은 교체·사진 제거가 확정된 뒤 정리한다. 완료 응답이 유실돼도 새 사진을 지우지 않는다. 실패·중단 예약은 정리 상태를 남겨 재시도하며, 중단된 pending 예약은 **24시간 초과 후 재접속 시** 정리한다.
- 프로필 사진은 반려동물의 속성이다. 반려동물 삭제가 성공하면 미참조 사진을 정리한다. 추억·일기 FK에 의해 반려동물 삭제가 거부되면 프로필과 사진 모두 유지한다. 미접속 계정의 주기 정리는 이번 범위가 아니다.
- 사진 없는 필드 편집은 기존 사진을 유지한다. 사진 제거는 프로필·추억·일기를 지우지 않는다. 로그인한 소유자의 토큰으로 파일을 내려받고 계정 변경 시 이미지 캐시를 폐기한다.

## 완료 기준과 증명

1. 일반 계정 A로 사진 포함 신규 프로필 생성·교체·사진 제거·독립 클라이언트 재조회·다운로드를 재현한다. B·미인증의 메타데이터·파일·프로필 참조 위조는 거부한다.
2. 직접 API에서도 파일 크기·MIME 제한, 파일 없는 참조, 활성 사진 삭제·덮어쓰기를 차단한다.
3. 업로드·프로필 확정·교체 실패와 완료 응답 유실, 정리 실패·재시도를 검사한다. 신규 실패 시 빈 프로필이 생기지 않고, 기존 실패 시 이름·사진·Day 0을 보존한다.
4. 사진 있는 반려동물의 삭제 성공 시 파일을 정리한다. 추억·일기가 있어 삭제가 실패하면 파일을 유지한다.
5. 기존 로컬 JSON 보존, UI 사진 선택·제거·취소, 계정 전환·중복 요청, 전체 회귀·정적 분석·웹 release 빌드를 검사하고 결과를 기록한다. 실제 배포 도메인·Android E2E는 호스팅·기기 준비 후 별도 실행한다.

## 수행 기록

- 변경 전 개발 프로젝트의 반려동물·추억 사진·파일은 0개이며 비공개 `memory-photos` 버킷만 존재했다. 기존 버킷·기록을 교체하지 않는다.
- `20261010130832_pet_profile_photos.sql`을 개발 DB에 적용했다. `pet_avatars` 예약, 소유자 RLS, 비공개 `pet-avatars` 버킷, `pets.avatar_id` 복합 FK와 저장 RPC를 추가했다. 기존 외부 사진 URL은 유지한다. Storage 업로드와 예약 취소는 예약 행을 잠가 늦은 업로드를 차단한다. Storage 내부에는 정책·트리거만 추가하고 함수·앱 테이블은 public에 둔다.
- 사진 선택·교체·사진만 제거를 프로필 폼에 연결했다. 저장 중 입력·버튼·화면 닫기를 막고 중복 요청을 거부한다. 홈·반려동물 화면은 소유자의 인증으로 사진을 내려받으며 계정 변경 시 표시·캐시를 폐기한다.
- 신규 프로필은 사진 업로드 후에만 저장한다. 이름·품종·생일·사진 참조는 함께 확정하고 Day 0은 건드리지 않는다. 확정 응답 유실 시 동일 ID의 서버 결과를 확인한다. 교체 후 이전 파일이나 실패 예약의 정리가 남으면 반려동물 화면에 재시도를 표시한다.

## 검증 결과와 증거

- [로컬 SQL 검사](../../supabase/tests/pet_avatars.sql)를 기존 검사와 합쳐 **146개 조건 × 새 DB 2회 통과**. 파일 없는 신규 생성과 잘못된 교체의 롤백, 소유자·권한·상태 변경, 삭제 FK, 사진만 제거, 미참조 파일 정리, **24시간 정확한 경계**를 검증했다. PGlite는 SQL 증거이며 실제 Auth·Storage 증거는 아래 실서버 검사다.
- [실제 A·B 계정 검사](../../test/supabase_avatar_live_test.dart) **42개 조건 통과**. 일반 Auth 토큰과 Publishable Key로 신규 생성·독립 앱 재조회·다운로드 바이트 일치, B·미인증 접근 차단, B의 무효 변경, 활성 파일 삭제·덮어쓰기 제한, 서버 3 MiB·MIME 제한, 파일 없는 확정 거부와 늦은 업로드 거부를 확인했다. 관리자 키를 권한 증명에 사용하지 않았다.
- 동일 검사에서 신규·교체 업로드 실패, 확정 실패, 실제 확정 이후 응답 유실, 이전 파일 정리 실패·재시도를 재현했다. 신규 실패는 빈 프로필을 만들지 않았고 교체 실패는 이름·사진·Day 0을 보존했다. 일기 있는 반려동물은 앱과 직접 API 모두 삭제가 거부됐으며 사진은 남았다. 사진만 제거는 일기·Day 0을 보존하고, 기록 제거 후 반려동물 삭제는 사진 파일까지 정리했다.
- [화면·동시 요청 검사](../../test/supabase_avatar_test.dart) **4개 통과**. 온라인 사진 선택·취소·저장·사진만 제거, 저장 중 입력과 닫기 비활성화, 중복 요청 차단, 업로드 중 로그아웃 이후 확정·화면 갱신 차단, 버킷 구분과 계정 변경 시 이미지 폐기를 확인했다. 실제 운영체제 선택 창은 모의 파일로 대체했다. 기존 로컬 JSON은 바이트 단위로 보존됐다.
- 변경된 개발 DB에서 기존 [추억 사진 실서버 검사](../../test/supabase_photo_live_test.dart) **53개 조건 통과**. 전체 Flutter 회귀 **124개 통과, 실서버 선택 실행 7개 제외**, 정적 분석 **오류·경고 없음**, 실제 Supabase 설정의 웹 release 빌드 **통과(49.1초)**. 빌드 전후 앱 소스 해시는 일치했다.
- 최종 서버 반려동물·일기·추억 사진·프로필 사진 예약·Storage 파일은 **모두 0개**. 테스트 Auth 계정 A·B는 재사용한다. 보호자 프로필은 해당 검사에서 새로 만든 경우에만 정리하며 검사 후 A의 프로필 1개가 남아 있다. 성능 advisor 경고 0개, 기존 유출 비밀번호 보호 비활성화 경고 1개가 유지됐고 유료 플랜 변경은 하지 않았다.
- 증거는 Git 제외된 `build/db-verification/results.json`, `avatar-unit-results.log`, `avatar-storage-live-results.log`, `avatar-regression-results.log`, `avatar-analyze-results.log`, `avatar-web-build-results.log`에 기록했다. 빌드 설정에는 URL·Publishable Key만 허용하고 테스트 이메일·비밀번호 4개가 웹 텍스트 산출물에 포함되지 않았음을 확인했다.

## 재현 방법

인증 완료된 별도 개발 계정 A·B와 비어 있는 테스트 반려동물·사진 영역을 사용한다. 앱 설정은 `config/supabase.local.json`, 계정 4개 값은 Git 제외된 `config/supabase.test.local.json`에만 넣는다. 실서버 검사는 자기 검사에서 만든 반려동물·사진만 정리하고 기존 프로필은 보존한다. 두 파일을 함께 실행할 때는 같은 계정의 검사 데이터가 섞이지 않게 순서대로 실행한다.

```powershell
# 로컬 SQL 검증 의존성이 없는 새 체크아웃에서만 설치한다.
npm install --prefix build/db-verification --no-save @electric-sql/pglite@0.3.14
node scripts/verify-db.mjs
flutter test test/supabase_avatar_test.dart test/supabase_photo_test.dart --reporter expanded
$env:PET_SNS_RUN_AVATAR_LIVE = '1'
$env:PET_SNS_RUN_PHOTO_LIVE = '1'
flutter test test/supabase_avatar_live_test.dart test/supabase_photo_live_test.dart --concurrency=1 --dart-define-from-file=config/supabase.local.json --reporter expanded
Remove-Item Env:PET_SNS_RUN_AVATAR_LIVE, Env:PET_SNS_RUN_PHOTO_LIVE
flutter test --reporter expanded
flutter analyze
./scripts/build-web.ps1
```

## 남은 범위와 다음 구현

이번 완료는 개발 DB·앱·자동 검사 기준이다. 실제 배포 도메인의 로그인·파일 선택·새로고침과 Android 기기 검사는 배포·기기 준비 후 실행한다. 중단 예약의 정리는 **24시간 초과 후 소유자가 재접속할 때** 이루어지며 주기 작업은 없다. 공개 프로필·공유 사진 권한, 온라인 가입·메일 인증·비밀번호 복구, 모임·참여·채팅 DB 연결은 아직 구현되지 않았다. 다음은 모임·참여 DB 연결이며, 기존 참여 마감·탈퇴·반려동물 삭제 기준을 먼저 정해진 규칙 그대로 서버에 적용한다.

## 근거

[비공개 저장소](https://supabase.com/docs/guides/storage/buckets/fundamentals), [CDN 캐시 갱신](https://supabase.com/docs/guides/storage/cdn/smart-cdn).

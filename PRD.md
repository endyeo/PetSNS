# PetSNS Feature PRD and Acceptance Criteria

Basis: repository code, existing test cases, and the service plan, reviewed on October 9, 2026. Supabase implementation and verification records T27/T28 were added on October 10, 2026.

## How to use this document

Choose one linked task PRD and implement or change only that behavior. Each task defines prerequisites, the user flow, rules, the result, and observable acceptance criteria. Dependencies must exist or be supplied as test fixtures; a task is not a separate application.

**T01–T25 describe the current implementation as a baseline, not newly approved product decisions. T26 is a confirmed planning requirement missing from the code.** Acceptance criteria are checks to perform, not a claim that this review ran or passed tests. Resolve the decisions at the end before changing affected behavior.

T27 records the completed development DB/RLS foundation. T28 connects actual Supabase login, logout, and verified session restoration. T29 connects guardian profile initialization and pet CRUD/Day 0; T30 connects daily journals and restrictive pet deletion. T31 connects private memory photos, Storage and recoverable cleanup; T32 adds private pet profile photos with atomic profile updates. Web hosting is intentionally deferred.

COMMON-UI-01 establishes global navigation styling, Material 3 surface tint removal, and design token consistency across components. HOME-UI-01 improves the home screen day profile header layout, D+ badge placement, and calendar cleanliness.

Each linked file is one assignable feature PRD. Shared boundaries and unresolved decisions live here to avoid repeating them in every task. Existing Korean interface labels remain unchanged.

## Shared boundaries

- Scope: Flutter web and Android. Builds with Supabase settings, profile/release builds, and web builds on non-loopback hosts use server Auth. Unconfigured local debug builds retain demo authentication. Online pets, Day 0, journals, private memory and profile photos use Supabase; local JSON is preserved without automatic import. Other domains remain local; online membership writes remain pending. SDK Auth sessions use separate storage. Pets, journals and photos are reread on login/restart; real-time synchronization is not implemented. Profile photos are owner-only; future shared profiles require an explicit access policy.
- All tasks except startup and authentication require a signed-in account. Personal profiles, photos, and journals are scoped to their owner; shared posts and room membership have their own rules below.
- Successful stored changes survive reopening on the same storage/origin. A rejected or failed stored change reports an error and restores the previous in-memory data; an overlapping store mutation is rejected. Canceling an unsaved form does not create a record.
- Meetup dates, deadlines, chat closure, and memory “today” use Korean time (KST). The pet birthday picker currently uses device-local today. Day 0 counts calendar days, with the starting date equal to 0.
- Selected profile/memory photos are checked in the picker; chat photos are also checked by the store. The byte limit is `3 * 1024 * 1024` (3,145,728 bytes) per image after reading the selected file. Do not assume these validation layers are identical.
- Completion requires checking the task's successful path, rejected inputs/access where specified, and persistence for changed stored data. Relevant code-change verification follows the `coding-principles` skill; this PRD does not duplicate its workflow.

**Assignment boundary:** a single task can be developed against existing prerequisites or fixtures. Tasks share `lib/main.dart` and `lib/store.dart`; this split does not make simultaneous edits to those files conflict-free. Coordinate shared-file edits.

## Feature PRDs

Group tasks by the screen or UI area used in the [UI guide](docs/human/ui-guide.html). Keep T numbers as stable task identifiers, not as category names. Place a task under the screen where its main user action occurs; when it spans screens, list it once under its primary entry screen. Use the common-structure and state/error sections only for behavior shared across multiple screens or for cross-screen states.

### G — Common structure

- [T01 — Load and restore the application](docs/prd/t01-load-and-restore-the-application.md)
- [T27 — Supabase 사용자·반려동물 DB와 접근 권한 구축](docs/prd/t27-supabase-profiles-and-pets.md): backend foundation; client storage remains local.
- [COMMON-UI-01 — 공통 내비게이션 및 전역 컴포넌트 UI 색상 개선](docs/human/task%20record/COMMON-UI-01/PRD.md): 모바일 하단 내비게이션(4번 코랄 채움 + 1px 경계선), 데스크톱 사이드바(꽉 찬 탭 + 탭 간 구분선 + 코랄 채움 + 꺾쇠 화살표), M3 표면 틴트 차단, 전역 Card/TabBar/SegmentedButton/Chip 디자인 토큰 일치화.

### L — Log in / sign up

- [T28 — Supabase 로그인과 세션 복원](docs/prd/t28-supabase-login-and-session.md): current online Auth behavior and Korean verification log.
- [T02 — Register an account](docs/prd/t02-register-an-account.md)
- [T03 — Log in with email and password](docs/prd/t03-log-in-with-email-and-password.md)
- [T04 — Enter the demo account](docs/prd/t04-enter-the-demo-account.md)
- [T05 — Log out](docs/prd/t05-log-out.md)

### H — Home · our day

- [T08 — View the home day's memories and appointments](docs/prd/t08-view-the-home-day-s-memories-and-appointments.md)
- [HOME-UI-01 — 홈 화면 반려동물 프로필 UI 개선](docs/human/task%20record/HOME-UI-01/PRD.md): 사진 상단 우측 D+ 배지(`D+숫자`/`기준 설정`), 사진 우측 하단 추억 기록 버튼, 생일 텍스트 제거, '가족 1/2 마리' 문구 제거 및 도트 인디케이터 배치, 주간 달력 중복 Day 문구 제거.

### M — Memory library

- [T09 — Set a pet's Day 0](docs/prd/t09-set-a-pet-s-day-0.md)
- [T10 — Browse a pet's memory calendar and gallery](docs/prd/t10-browse-a-pet-s-memory-calendar-and-gallery.md)

### MV — View memories

- [T13 — Write or edit a daily journal](docs/prd/t13-write-or-edit-a-daily-journal.md)
- [T30 — 추억의 하루 기록 DB 연결](docs/prd/t30-supabase-memory-days.md): server journals, cross-client deletion restrictions and Korean verification record.

### ME — Record / edit memory photos

- [T11 — Add memory photos](docs/prd/t11-add-memory-photos.md)
- [T12 — Edit, move, or delete a memory photo](docs/prd/t12-edit-move-or-delete-a-memory-photo.md)
- [T31 — 추억 사진 저장소·DB 연결](docs/prd/t31-supabase-memory-photos.md): private Storage, server photo metadata, restrictive FK, Day 0 and recoverable cleanup.

### P — Meetups

- [T14 — Browse meetup lists, maps, and details](docs/prd/t14-browse-meetup-lists-maps-and-details.md)
- [T19 — Enforce meetup status and chat closure](docs/prd/t19-enforce-meetup-status-and-chat-closure.md)
- [T26 — Automatically cancel a meetup after its last member leaves](docs/prd/t26-automatically-cancel-a-meetup-after-its-last-member-leaves.md)

### PD — Meetup details

- [T17 — Join a meetup](docs/prd/t17-join-a-meetup.md)
- [T18 — Leave and rejoin a meetup](docs/prd/t18-leave-and-rejoin-a-meetup.md)

### PC — Create a meetup

- [T15 — Select a meetup location](docs/prd/t15-select-a-meetup-location.md)
- [T16 — Create a meetup](docs/prd/t16-create-a-meetup.md)

### C — Posts · groups · meetup rooms

- [T20 — Read posts](docs/prd/t20-read-posts.md)
- [T21 — Publish a post](docs/prd/t21-publish-a-post.md)
- [T22 — Discover, join, and leave a persistent group](docs/prd/t22-discover-join-and-leave-a-persistent-group.md)

### CR — Chat room

- [T23 — Read and send text messages](docs/prd/t23-read-and-send-text-messages.md)
- [T24 — Attach and send a chat photo](docs/prd/t24-attach-and-send-a-chat-photo.md)

### CG — Group room

- [T25 — View room members and shared photos](docs/prd/t25-view-room-members-and-shared-photos.md)

### F — Pet profile

- [T07 — Delete a pet profile](docs/prd/t07-delete-a-pet-profile.md)

### FE — Create / edit pet profile

- [T06 — Create or edit a pet profile](docs/prd/t06-create-or-edit-a-pet-profile.md)
- [T29 — 배포 기준 반려동물 DB 연결](docs/prd/t29-supabase-pet-integration.md): online pet storage, deletion boundary, build criteria and Korean verification record.
- [T32 — 반려동물 프로필 사진 업로드](docs/prd/t32-supabase-pet-avatars.md): private avatars, atomic profile saves, cleanup and Korean verification record.

### S — States and errors

Shared loading, empty, error, deletion-confirmation, image-fallback, and meetup/chat status behavior is specified in the linked task PRDs and the shared boundaries above. Add a separate task here only when the behavior is cross-screen and cannot be assigned to a primary screen.

## Decisions and missing information

### D1 — Resolve differences between the older plan and current demo

The service plan is a team-review draft dated September 30, 2026. It specifies a creator-selected registration deadline and numeric companion count, and excludes maps and meetup photo sharing from MVP; persistent groups are undecided. Current code uses a fixed 6-hour cutoff, selects owned pet profiles, and includes maps, chat photos, groups, and posts. This document records both; it does not silently approve either scope. Decide the intended scope before rebuilding T14–T25.

### D2 — Decide login button behavior

The request's example requires both fields before pressing login. Current T03 instead allows pressing login and then reports validation errors. Confirm whether the example describes a desired change or only the PRD format; email versus a separate username also needs an explicit decision if changing the identifier.

### D3 — Decide pet deletion and unspecified input limits

Local demo deletion retains associated records/references. The user chose to block online deletion when linked records remain on October 10, 2026. T27 restricts parent deletion, T29 checks device references, T30 adds a restrictive journal FK, and [T31](docs/prd/t31-supabase-memory-photos.md) adds a restrictive photo FK. Empty journals and unfinished memory photo reservations also block pet deletion until explicitly removed or cleaned up. A T32 profile photo is a pet attribute: successful pet deletion retires its file; blocked pet deletion preserves it. Future membership tables must use restrictive FKs. Existing local records on other devices are not imported or discoverable. No total-photo limit, journal text limit, or recurring anniversary reminder is defined.

### D4 — Decide closed/canceled data retention and notices

History is currently retained internally after leaving/closure. The plan leaves physical retention/deletion and notification timing for absent participants undecided. Current chat shows an on-screen closure notice while open; there is no push/unread notification or join/leave system-message flow. Choose any additional behavior before assigning implementation.

### D5 — Define any production or additional account scope

Actual existing-account login, current-session logout, and verified session restoration are implemented in T28; pet CRUD/Day 0 and cross-instance reads are implemented in T29. Online registration/email verification, password recovery, account deletion, user profile editing, other domain data sync, server-backed real-time chat, and delivery/read receipts remain unimplemented. The older plan mentions user profile editing and leaves account-deletion handling open. Required fields, recovery/retention rules, infrastructure, and final delivery targets need decisions if these become tasks.

## Evidence for maintenance

- [App startup](lib/main.dart): `PetApp`. Screens and viewers are in `lib/screens/`; popup forms are in `lib/forms/`.
- [Storage and business rules](lib/store.dart): `load`, migrations, `login`, `testLogin`, `logout`, `saveOwned`, `deleteOwned`, memory methods, `createMeeting`, `join`, `leave`, `status`, `canChat`, `messages`, `send`, `joinGroup`, `createPost`.
- [Home calendar](lib/home_week_calendar.dart), [memory calendar](lib/memory_calendar.dart), [pet carousel](lib/pet_profile_carousel.dart), [map/place picker](lib/meeting_map.dart), [location validation](lib/meeting_location.dart).
- Existing tests: [store](test/store_test.dart), [screens](test/widget_test.dart), [community](test/community_test.dart), [chat](test/chat_test.dart). These support particular rules; their existence does not certify every acceptance criterion above.
- [Service plan](docs/human/service-plan.html): explicit planning rules and unresolved scope, used for T26 and D1–D5. HTML is preserved; this PRD does not edit it.

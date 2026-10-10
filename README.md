# PetSNS

Flutter demo for pet memories, meetups, posts, and group/meetup chat. Mobile first; web and Android are supported. [Korean guide](docs/human/README.md).

## Run

From `C:\Projects\PetSNS`:

```powershell
flutter pub get
flutter run -d chrome --web-port 8080
```

Use the same host and port 8080 to keep browser records accessible. Do not start another server on an occupied port. For a connected Android phone, allow USB debugging when prompted, then run `flutter run`.

### Supabase connection setup

Copy `config/supabase.example.json` to `config/supabase.local.json` (Git-ignored),
then enter your Project URL and `sb_publishable_...` key. Inject them at build time:

```powershell
flutter run -d chrome --web-port 8080 --dart-define-from-file=config/supabase.local.json
./scripts/build-web.ps1
flutter build apk --debug --dart-define-from-file=config/supabase.local.json
flutter test test/supabase_live_test.dart --dart-define-from-file=config/supabase.local.json
```

Individual `--dart-define=SUPABASE_URL=...` and
`--dart-define=SUPABASE_PUBLISHABLE_KEY=...` flags also work. These settings are
embedded in the client build; use only a Publishable Key, never a Secret Key,
service_role key, or DB password. Do not add settings as Flutter assets.

Startup initializes the SDK, then makes a read-only `GET /auth/v1/settings` with
the `apikey` header and a 10-second connection timeout. Only HTTP 200 with an Auth
settings response counts as connected. The `[PetSNS Supabase]` console diagnostic
reports missing/invalid settings, initialization failures, HTTP failures, and
network failures without printing keys or response bodies. `supabaseConnection`
in `lib/main.dart` exposes separate `initialized` and `connected` flags.
The gateway check verifies project accessibility separately from user login.
With either Supabase setting present, in profile/release builds, and on non-loopback web hosts, login uses
Supabase Auth and never falls back to local credentials. Missing/invalid settings
block startup with a retry action. SDK session persistence and token refresh are
enabled; startup verifies restored users with the server. URL session detection
remains disabled. Online signup and password recovery are pending.

## Current Scope

### Database & Backend (Supabase T27–T31)

Unconfigured local debug builds retain registration and the test-account button. Online builds use existing-account login, create/read the guardian profile, and store pets, Day 0, daily journals and private memory photos in Supabase. Login does not import local SharedPreferences records from `petsns.v1`.

Pets, journals and memory photos are reread on login/restart, including across independent app instances. Journals and photo reservations restrict pet deletion in the DB. Private memory photos support upload, date editing, replacement and deletion, with recoverable cleanup after interrupted requests. Profile photo upload and online membership writes remain pending. Other domains remain local. [T31](docs/prd/t31-supabase-memory-photos.md) records boundaries, tests and build commands. Automated multi-account integration tests use `config/supabase.test.local.json` (template: `config/supabase.test.example.json`). The build script rejects private/test credentials and creates a release artifact without deploying hosting. Clearing storage may delete local records; sample photos and maps need a network connection.

### UI & Design System (COMMON-UI-01 & HOME-UI-01)

- **COMMON-UI-01 (Global Navigation & Component Tokens)**: Material 3 surface tint (`surfaceTint: Colors.transparent`) is disabled globally. Mobile bottom navigation uses cream background (`#F5F2E9`), coral filled pill indicator (`#E77D63`), white icons, and a 1px top border (`#E7E5DB`). Desktop web sidebar features edge-to-edge flush tabs (no outer padding), dividing borders between tabs, solid coral active tab fill with white chevron-right indicator, and cream inactive tabs. Theme tokens are unified across `CardTheme`, `DialogTheme`, `TabBarTheme`, `SegmentedButtonTheme`, and `ChipTheme`.
- **HOME-UI-01 (Home Screen Profile Header & Calendar)**: Relocates the Day badge to the top-right of the pet photo banner (`D+숫자` or `'기준 설정'`, black text on `#FAF8F3`). Moves the '추억 기록' button to the bottom-right of the photo. Removes pet birthday text from the banner overlay. Replaces the `'가족 N / M 마리'` text in the white lower card with clean page indicator dots. Removes redundant Day labels from the weekly calendar dates.

## Important Existing Rules

- Meetup capacity counts guardians, including the automatically joined creator: 2–50. Participation closes 6 hours before the start, excluding the exact deadline. New meetups must start more than 6 hours later.
- Meetup chat closes at 00:00 KST two calendar days after the meetup date (October 1 → October 3). Group rooms have no automatic meetup-date closure.
- Leaving blocks room access; rejoining exposes only messages/photos after the new membership boundary (`since` and `after`). Meetup-room leaving cancels that participation; group-room leaving cancels only that group membership.
- Memories, daily journals, and Day 0 belong to each pet. Photos and daily journals are separate; deleting a photo preserves the journal. Each selected photo is limited to 3MB (`3 * 1024 * 1024` bytes).

## Find Code and Check Changes

`lib/main.dart` starts the app. Five tab screens, login, chat, and viewers are in `lib/screens/`; popup forms are in `lib/forms/`; shared widgets are in `lib/widgets/`. Storage and business rules remain in `lib/store.dart`. Colors, text styles (minimum 13px), and the theme are in `lib/design_system.dart`. The bundled [Pretendard v1.3.9](https://github.com/orioncactus/pretendard/tree/v1.3.9) font and its OFL license are in `assets/fonts/`.

Keep the checkout outside OneDrive, such as `C:\Projects\PetSNS`; `build/` and `.dart_tool/` are ignored by Git. Flutter is available through `C:\flutter\bin` in the Windows user PATH. Read the [commit conventions](.agents/skills/commit-conventions/SKILL.md) before committing.

Run `flutter analyze` and relevant `flutter test` checks for code changes. Build with `flutter build web --release` or `flutter build apk --debug` when platform changes require it. See T27/T28 for the recorded checks and their limits.

## Visual References

- [Service plan](docs/human/service-plan.html), [screen guide](docs/human/ui-guide.html), and [feature PRD viewer](docs/human/feature-prd.html).

Screen-guide notes live in browser storage. If a location/origin change hides notes, export JSON from the previous guide and import it into the new one.

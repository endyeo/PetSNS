# PetSNS

Flutter demo for pet memories, meetups, posts, and group/meetup chat. Mobile first; web and Android are supported. [Korean guide](docs/human/README.md).

## Run

From `C:\Projects\PetSNS`:

```powershell
flutter pub get
flutter run -d chrome --web-port 8080
```

Use the same host and port 8080 to keep browser records accessible. Do not start another server on an occupied port. For a connected Android phone, allow USB debugging when prompted, then run `flutter run -d SM-S908N`.

### Supabase connection setup

Copy `config/supabase.example.json` to `config/supabase.local.json` (Git-ignored),
then enter your Project URL and `sb_publishable_...` key. Inject them at build time:

```powershell
flutter run -d chrome --web-port 8080 --dart-define-from-file=config/supabase.local.json
flutter build web --release --dart-define-from-file=config/supabase.local.json
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
Failures keep the existing local app available. This verifies project gateway
and Auth accessibility, not database permissions, synchronization, or user login.
Supabase session persistence and URL session detection are disabled for this stage.

## Current Scope

Use the test-account button to try the app without registering. Records and sessions persist after refresh; test access does not reset them. Data is local SharedPreferences JSON under `petsns.v1`.

This is a one-device, one-active-instance demo. No server, real email verification, password recovery, or multi-device synchronization is implemented. Authentication is not production-ready. Clearing storage or uninstalling may delete records; sample photos and maps need a network connection.

## Important Existing Rules

- Meetup capacity counts guardians, including the automatically joined creator: 2–50. Participation closes 6 hours before the start, excluding the exact deadline. New meetups must start more than 6 hours later.
- Meetup chat closes at 00:00 KST two calendar days after the meetup date (October 1 → October 3). Group rooms have no automatic meetup-date closure.
- Leaving blocks room access; rejoining exposes only messages/photos after the new membership boundary (`since` and `after`). Meetup-room leaving cancels that participation; group-room leaving cancels only that group membership.
- Memories, daily journals, and Day 0 belong to each pet. Photos and daily journals are separate; deleting a photo preserves the journal. Each selected photo is limited to 3MB (`3 * 1024 * 1024` bytes).

## Find Code and Check Changes

`lib/main.dart` starts the app. Five tab screens, login, chat, and viewers are in `lib/screens/`; popup forms are in `lib/forms/`; shared widgets are in `lib/widgets/`. Storage and business rules remain in `lib/store.dart`. Colors, text styles (minimum 13px), and the theme are in `lib/design_system.dart`. The bundled [Pretendard v1.3.9](https://github.com/orioncactus/pretendard/tree/v1.3.9) font and its OFL license are in `assets/fonts/`.

Keep the checkout outside OneDrive, such as `C:\Projects\PetSNS`; `build/` and `.dart_tool/` are ignored by Git. Flutter is available through `C:\flutter\bin` in the Windows user PATH. Read the [commit conventions](.agents/rules/commits.md) before committing.

Run `flutter analyze` and relevant `flutter test` checks for code changes. Build with `flutter build web --release` or `flutter build apk --debug` when platform changes require it. No new app-test or build result is claimed by this document cleanup.

## Visual References

- [Service plan](docs/human/service-plan.html), [screen guide](docs/human/ui-guide.html), and [feature PRD viewer](docs/human/feature-prd.html).
- [Existing screenshots](docs/human/screenshots/mobile-preview.jpg); other captures are in the same directory.

Screen-guide notes live in browser storage. If a location/origin change hides notes, export JSON from the previous guide and import it into the new one.

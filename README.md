# PetSNS

Flutter demo for pet memories, meetups, posts, and group/meetup chat. Mobile first; web and Android are supported. [Korean guide](docs/human/README.md).

## Run

From `C:\Projects\PetSNS`:

```powershell
flutter pub get
flutter run -d chrome --web-port 8080
```

Use the same host and port 8080 to keep browser records accessible. Do not start another server on an occupied port. For a connected Android device, use `flutter run -d <device-id>`.

## Current Scope

Use the test-account button to try the app without registering. Records and sessions persist after refresh; test access does not reset them. Data is local SharedPreferences JSON under `petsns.v1`.

This is a one-device, one-active-instance demo. No server, real email verification, password recovery, or multi-device synchronization is implemented. Authentication is not production-ready. Clearing storage or uninstalling may delete records; sample photos and maps need a network connection.

## Important Existing Rules

- Meetup capacity counts guardians, including the automatically joined creator: 2–50. Participation closes 6 hours before the start, excluding the exact deadline. New meetups must start more than 6 hours later.
- Meetup chat closes at 00:00 KST two calendar days after the meetup date (October 1 → October 3). Group rooms have no automatic meetup-date closure.
- Leaving blocks room access; rejoining exposes only messages/photos after the new membership boundary (`since` and `after`). Meetup-room leaving cancels that participation; group-room leaving cancels only that group membership.
- Memories, daily journals, and Day 0 belong to each pet. Photos and daily journals are separate; deleting a photo preserves the journal. Each selected photo is limited to 3MB (`3 * 1024 * 1024` bytes).

## Find Code and Check Changes

Screens are mainly in `lib/main.dart`; storage and rules are in `lib/store.dart`. Other `lib` files support calendars, profiles, and maps. Tests are in `test/`.

Run `flutter analyze` and relevant `flutter test` checks for code changes. Build with `flutter build web --release` or `flutter build apk --debug` when platform changes require it. No new app-test or build result is claimed by this document cleanup.

## Visual References

- [Service plan](docs/human/service-plan.html) and [screen guide](docs/human/ui-guide.html).
- [Existing screenshots](docs/human/screenshots/mobile-preview.jpg); other captures are in the same directory.

Screen-guide notes live in browser storage. If a location/origin change hides notes, export JSON from the previous guide and import it into the new one.

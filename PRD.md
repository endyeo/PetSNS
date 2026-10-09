# PetSNS Feature PRD and Acceptance Criteria

Basis: repository code, existing test cases, and the service plan, reviewed on October 9, 2026.

## How to use this document

Choose one linked task PRD and implement or change only that behavior. Each task defines prerequisites, the user flow, rules, the result, and observable acceptance criteria. Dependencies must exist or be supplied as test fixtures; a task is not a separate application.

**T01–T25 describe the current implementation as a baseline, not newly approved product decisions. T26 is a confirmed planning requirement missing from the code.** Acceptance criteria are checks to perform, not a claim that this review ran or passed tests. Resolve the decisions at the end before changing affected behavior.

Each linked file is one assignable feature PRD. Shared boundaries and unresolved decisions live here to avoid repeating them in every task. Existing Korean interface labels remain unchanged.

## Shared boundaries

- Scope: a local Flutter demo for web and Android, one device and one active instance. Accounts, sessions, records, memberships, and messages use local SharedPreferences data under `petsns.v1`. There is no server or communication between different devices.
- All tasks except startup and authentication require a signed-in account. Personal profiles, photos, and journals are scoped to their owner; shared posts and room membership have their own rules below.
- Successful stored changes survive reopening on the same storage/origin. A rejected or failed stored change reports an error and restores the previous in-memory data; an overlapping store mutation is rejected. Canceling an unsaved form does not create a record.
- Meetup dates, deadlines, chat closure, and memory “today” use Korean time (KST). The pet birthday picker currently uses device-local today. Day 0 counts calendar days, with the starting date equal to 0.
- Selected profile/memory photos are checked in the picker; chat photos are also checked by the store. The byte limit is `3 * 1024 * 1024` (3,145,728 bytes) per image after reading the selected file. Do not assume these validation layers are identical.
- Completion requires checking the task's successful path, rejected inputs/access where specified, and persistence for changed stored data. Relevant code-change verification follows `coding.md`; this PRD does not duplicate its workflow.

**Assignment boundary:** a single task can be developed against existing prerequisites or fixtures. Tasks share `lib/main.dart` and `lib/store.dart`; this split does not make simultaneous edits to those files conflict-free. Coordinate shared-file edits.

## Feature PRDs

Group tasks by the screen or UI area used in the [UI guide](docs/human/ui-guide.html). Keep T numbers as stable task identifiers, not as category names. Place a task under the screen where its main user action occurs; when it spans screens, list it once under its primary entry screen. Use the common-structure and state/error sections only for behavior shared across multiple screens or for cross-screen states.

### G — Common structure

- [T01 — Load and restore the application](docs/prd/t01-load-and-restore-the-application.md)

### L — Log in / sign up

- [T02 — Register an account](docs/prd/t02-register-an-account.md)
- [T03 — Log in with email and password](docs/prd/t03-log-in-with-email-and-password.md)
- [T04 — Enter the demo account](docs/prd/t04-enter-the-demo-account.md)
- [T05 — Log out](docs/prd/t05-log-out.md)

### H — Home · our day

- [T08 — View the home day's memories and appointments](docs/prd/t08-view-the-home-day-s-memories-and-appointments.md)

### M — Memory library

- [T09 — Set a pet's Day 0](docs/prd/t09-set-a-pet-s-day-0.md)
- [T10 — Browse a pet's memory calendar and gallery](docs/prd/t10-browse-a-pet-s-memory-calendar-and-gallery.md)

### MV — View memories

- [T13 — Write or edit a daily journal](docs/prd/t13-write-or-edit-a-daily-journal.md)

### ME — Record / edit memory photos

- [T11 — Add memory photos](docs/prd/t11-add-memory-photos.md)
- [T12 — Edit, move, or delete a memory photo](docs/prd/t12-edit-move-or-delete-a-memory-photo.md)

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

### S — States and errors

Shared loading, empty, error, deletion-confirmation, image-fallback, and meetup/chat status behavior is specified in the linked task PRDs and the shared boundaries above. Add a separate task here only when the behavior is cross-screen and cannot be assigned to a primary screen.

## Decisions and missing information

### D1 — Resolve differences between the older plan and current demo

The service plan is a team-review draft dated September 30, 2026. It specifies a creator-selected registration deadline and numeric companion count, and excludes maps and meetup photo sharing from MVP; persistent groups are undecided. Current code uses a fixed 6-hour cutoff, selects owned pet profiles, and includes maps, chat photos, groups, and posts. This document records both; it does not silently approve either scope. Decide the intended scope before rebuilding T14–T25.

### D2 — Decide login button behavior

The request's example requires both fields before pressing login. Current T03 instead allows pressing login and then reports validation errors. Confirm whether the example describes a desired change or only the PRD format; email versus a separate username also needs an explicit decision if changing the identifier.

### D3 — Decide pet deletion and unspecified input limits

Deleting a pet currently retains associated records/references without a supported restore flow. Choose whether to prevent deletion, retain accessible archives, or cascade, and define membership handling before changing T07. No total-photo limit, journal text limit, or recurring anniversary reminder is defined. Several profile/meetup field limits are UI-only; decide whether equivalent store validation is required before changing those contracts.

### D4 — Decide closed/canceled data retention and notices

History is currently retained internally after leaving/closure. The plan leaves physical retention/deletion and notification timing for absent participants undecided. Current chat shows an on-screen closure notice while open; there is no push/unread notification or join/leave system-message flow. Choose any additional behavior before assigning implementation.

### D5 — Define any production or additional account scope

Real authentication/email verification, password recovery, account deletion, user profile editing, multi-device sync, server-backed real-time chat, and delivery/read receipts are not implemented. The older plan mentions user profile editing and leaves account-deletion handling open. Required fields, recovery/retention rules, infrastructure, and final delivery targets need decisions if these become tasks. Do not treat them as completed or silently add them to this local-demo PRD.

## Evidence for maintenance

- [Screens and flows](lib/main.dart): `PetApp`, `Login`, `Home`, profile/memory/meetup/post/group forms, `ChatScreen`, `ChatRoomDetails`, `MemoryView`.
- [Storage and business rules](lib/store.dart): `load`, migrations, `login`, `testLogin`, `logout`, `saveOwned`, `deleteOwned`, memory methods, `createMeeting`, `join`, `leave`, `status`, `canChat`, `messages`, `send`, `joinGroup`, `createPost`.
- [Home calendar](lib/home_week_calendar.dart), [memory calendar](lib/memory_calendar.dart), [pet carousel](lib/pet_profile_carousel.dart), [map/place picker](lib/meeting_map.dart), [location validation](lib/meeting_location.dart).
- Existing tests: [store](test/store_test.dart), [screens](test/widget_test.dart), [community](test/community_test.dart), [chat](test/chat_test.dart). These support particular rules; their existence does not certify every acceptance criterion above.
- [Service plan](docs/human/service-plan.html): explicit planning rules and unresolved scope, used for T26 and D1–D5. HTML is preserved; this PRD does not edit it.

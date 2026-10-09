# T08 — View the home day's memories and appointments

Current implementation baseline; acceptance criteria have not been executed in this documentation review.

Use this task with the [shared boundaries and open decisions](../../PRD.md). Task IDs in prerequisites refer to that index.

## Process, rules, and result

- **Requires:** active session; T06, T11, T13, and T17 data as applicable.
- **Flow:** select a pet in the carousel → choose a date in the week view → inspect its memories and participating appointments.
- **Rules:** weeks run Monday–Sunday; previous/next/swipe navigates weeks and “today” returns to today. Memories/journal use the selected pet and date; preview shows at most 3 photos. Appointments use account participation and KST date, exclude canceled meetings, and sort by start time. Only today shows the Day count in the week row.
- **Result:** a photo opens its viewer; a populated memory card opens that date's memory screen; an empty past/today card opens photo creation, or profile registration when no pet exists. Future empty cards cannot start recording. An appointment opens its detail.

## Acceptance criteria

- [ ] Pet/date switching changes the correct preview without mixing journals.
- [ ] Account appointments remain independent of pet selection.
- [ ] Empty/future states and all destinations behave as described.
- [ ] The family footer opens profiles.

## Evidence

- [lib/main.dart](../../lib/main.dart)
- [lib/store.dart](../../lib/store.dart)
- [lib/home_week_calendar.dart](../../lib/home_week_calendar.dart)
- [lib/pet_profile_carousel.dart](../../lib/pet_profile_carousel.dart)
- [test/widget_test.dart](../../test/widget_test.dart)

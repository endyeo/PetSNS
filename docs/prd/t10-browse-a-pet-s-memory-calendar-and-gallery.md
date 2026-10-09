# T10 — Browse a pet's memory calendar and gallery

Current implementation baseline; acceptance criteria have not been executed in this documentation review.

Use this task with the [shared boundaries and open decisions](../../PRD.md). Task IDs in prerequisites refer to that index.

## Process, rules, and result

- **Requires:** an owned pet; T09 for the Day calendar; T11/T13 data as applicable.
- **Flow:** open memories → choose pet/date → view daily journal and photo grid → tap a photo, or enable editing.
- **Rules:** the Day calendar starts at Day 0 and ends at today, with 7-day pages; future days are disabled. Photo days are emphasized. Without Day 0, show setup and the selected day's records. Switching pets resets the memory date to today and exits editing; normal photo taps open viewing, editing-mode taps open editing.
- **Result:** only the selected pet/date's photos and journal appear; the viewer shows the photo/date and supports zoom up to 5×.

## Acceptance criteria

- [ ] Two pets' records stay separate.
- [ ] Week/date/today navigation works.
- [ ] Empty days show an empty state.
- [ ] Viewing/editing select the same photo.
- [ ] Returning from viewing preserves records.

## Evidence

- [lib/main.dart](../../lib/main.dart)
- [lib/store.dart](../../lib/store.dart)
- [lib/memory_calendar.dart](../../lib/memory_calendar.dart)
- [test/widget_test.dart](../../test/widget_test.dart)

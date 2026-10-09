# T15 — Select a meetup location

Current implementation baseline; acceptance criteria have not been executed in this documentation review.

Use this task with the [shared boundaries and open decisions](../../PRD.md). Task IDs in prerequisites refer to that index.

## Process, rules, and result

- **Requires:** meetup creation; map access.
- **Flow:** open place picker → tap a map point or example marker → optionally name it → confirm.
- **Rules:** confirm is disabled without a selected point. Blank user-entered name gets a coordinate-based default; trimmed final name is required and at most 100 characters. Valid stored coordinates are finite latitude −85 to 85 and longitude −180 to 180. Returning without confirmation keeps the previous choice.
- **Result:** chosen name and coordinates return to the creation form.

## Acceptance criteria

- [ ] Point/marker selection, optional/default name, and cancel work.
- [ ] Creation rejects an invalid location.
- [ ] Saved coordinates reopen the correct meetup marker. Address search/geocoding is not part of this task.

## Evidence

- [lib/main.dart](../../lib/main.dart)
- [lib/store.dart](../../lib/store.dart)
- [lib/meeting_map.dart](../../lib/meeting_map.dart)
- [lib/meeting_location.dart](../../lib/meeting_location.dart)
- [test/store_test.dart](../../test/store_test.dart)
- [test/widget_test.dart](../../test/widget_test.dart)

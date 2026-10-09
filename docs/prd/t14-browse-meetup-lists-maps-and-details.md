# T14 — Browse meetup lists, maps, and details

Current implementation baseline; acceptance criteria have not been executed in this documentation review.

Use this task with the [shared boundaries and open decisions](../../PRD.md). Task IDs in prerequisites refer to that index.

## Process, rules, and result

- **Requires:** active session and stored meetups; D1 affects final scope.
- **Flow:** open meetups with “전체” selected → optionally choose dog/cat/other category → switch list/map → select a card or marker.
- **Rules:** category filters both views, not participant eligibility. Creation is offered only in list mode. Valid coordinates become map markers; missing locations remain in the list and are counted in a notice. Cards show title, place/distance, KST time, status, guardian count, and participating pet previews. Missing distance displays “unknown”; GPS distance calculation is not implemented.
- **Result:** list and marker open the same meetup detail, including note, times, capacity, and participating pets; empty categories show an empty state.

## Acceptance criteria

- [ ] Filtering and destinations agree.
- [ ] Missing coordinates do not hide list records.
- [ ] Map loading errors expose retry.
- [ ] Switching/scrolling retains the list/map control above navigation.

## Evidence

- [lib/main.dart](../../lib/main.dart)
- [lib/store.dart](../../lib/store.dart)
- [lib/meeting_map.dart](../../lib/meeting_map.dart)
- [test/widget_test.dart](../../test/widget_test.dart)
- [test/community_test.dart](../../test/community_test.dart)

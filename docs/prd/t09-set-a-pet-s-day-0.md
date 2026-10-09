# T09 — Set a pet's Day 0

Current implementation baseline; acceptance criteria have not been executed in this documentation review.

Use this task with the [shared boundaries and open decisions](../../PRD.md). Task IDs in prerequisites refer to that index.

## Process, rules, and result

- **Requires:** an owned pet; optional existing photos.
- **Flow:** open Day 0 settings → choose first meeting or first photo → choose an allowed date → confirm.
- **Rules:** dates range from 1990 through KST today and cannot be later than the oldest saved photo. First-photo mode uses that oldest date when available; otherwise a date is selected. Earlier photo backfill moves first-photo Day 0 earlier; deleting its oldest photo does not reset Day 0. First-meeting mode blocks photo dates earlier than Day 0.
- **Result:** that pet alone gets the saved starting basis/date; start day is Day 0, the next day is Day 1.

## Acceptance criteria

- [ ] Both bases and date boundaries work.
- [ ] Backfill/delete follow the stated rules.
- [ ] Another pet's setting stays unchanged.
- [ ] Reload preserves the basis and date.

## Evidence

- [lib/main.dart](../../lib/main.dart)
- [lib/store.dart](../../lib/store.dart)
- [test/store_test.dart](../../test/store_test.dart)
- [test/widget_test.dart](../../test/widget_test.dart)

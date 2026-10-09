# T17 — Join a meetup

Current implementation baseline; acceptance criteria have not been executed in this documentation review.

Use this task with the [shared boundaries and open decisions](../../PRD.md). Task IDs in prerequisites refer to that index.

## Process, rules, and result

- **Requires:** active session and a stored meetup; optional owned pets.
- **Flow:** open detail → select own pets if desired → press participate.
- **Rules:** only before the 6-hour registration cutoff, with space and neither cancellation nor existing membership. Count one account per guardian; deduplicate selected pet IDs; allow no selected pets. Category/breed does not restrict joining. Store current join time and message-position boundary.
- **Result:** membership is saved, guardian/pet displays update, detail closes, and the room appears among participating meetup rooms; joining does not automatically navigate into chat.

## Acceptance criteria

- [ ] Valid join persists.
- [ ] Duplicates, full/canceled/closed meetups, exact cutoff, and foreign pets reject without a new member.
- [ ] Concurrent submissions cannot overbook.
- [ ] Chat starts at this participation boundary.

## Evidence

- [lib/main.dart](../../lib/main.dart)
- [lib/store.dart](../../lib/store.dart)
- [test/store_test.dart](../../test/store_test.dart)

# T16 — Create a meetup

Current implementation baseline; acceptance criteria have not been executed in this documentation review.

Use this task with the [shared boundaries and open decisions](../../PRD.md). Task IDs in prerequisites refer to that index.

## Process, rules, and result

- **Requires:** active session and T15; owned pets are optional; see D1.
- **Flow:** press list “+” → choose category and own accompanying pets → enter title, place, optional note, KST date/time, guardian capacity → create.
- **Rules:** title required (UI limit: 60); note optional (UI limit: 1,000); category is dog/cat/other. Capacity is 2–50 accounts, including the creator; pets do not consume guardian slots. Start must be more than 6 hours away; registration closes exactly 6 hours before start. No manual deadline or end time. Selected pets must belong to the creator; no pet is required. Create is disabled without a chosen place or during saving.
- **Result:** persisted meetup, creator automatically participating, and category list updated; the dialog closes. Chat is available through meetup participation.

## Acceptance criteria

- [ ] Valid data/coordinates/pets persist with creator count 1.
- [ ] Exactly 6 hours and shorter lead times, invalid category/location/capacity, and foreign pets fail.
- [ ] Cancel adds nothing.

## Evidence

- [lib/main.dart](../../lib/main.dart)
- [lib/store.dart](../../lib/store.dart)
- [test/store_test.dart](../../test/store_test.dart)
- [test/community_test.dart](../../test/community_test.dart)

# T04 — Enter the demo account

Current implementation baseline; acceptance criteria have not been executed in this documentation review.

Use this task with the [shared boundaries and open decisions](../../PRD.md). Task IDs in prerequisites refer to that index.

## Process, rules, and result

- **Requires:** T01; no active session.
- **Flow:** press the test-account button → open home.
- **Rules:** no input is needed; demo setup adds the example account/pets/memories as needed and preserves existing demo data on later visits.
- **Result:** the stored demo account becomes the active session.

## Acceptance criteria

- [ ] First use shows demo pets and memories.
- [ ] Logout/reentry and reload retain previous edits without duplicating examples.

## Evidence

- [lib/main.dart](../../lib/main.dart)
- [lib/store.dart](../../lib/store.dart)
- [test/store_test.dart](../../test/store_test.dart)
- [test/widget_test.dart](../../test/widget_test.dart)

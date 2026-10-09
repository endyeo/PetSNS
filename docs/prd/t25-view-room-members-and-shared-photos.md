# T25 — View room members and shared photos

Current implementation baseline; acceptance criteria have not been executed in this documentation review.

Use this task with the [shared boundaries and open decisions](../../PRD.md). Task IDs in prerequisites refer to that index.

## Process, rules, and result

- **Requires:** allowed T23 access; T24 data for photos.
- **Flow:** room menu → members or photos → select a gallery/bubble image → zoom/view → return.
- **Rules:** show current guardians and their participating pets; label the current user. Gallery uses exactly the room's permitted message history. Every member/gallery/photo view rechecks access; no access or an out-of-boundary image shows a blocked state. Empty gallery shows an empty state.
- **Result:** members or permitted photos display; enlarged photo shows sender/time.

## Acceptance criteria

- [ ] List matches current membership.
- [ ] Other rooms' or earlier-membership images never appear.
- [ ] Leave, cancellation, and exact meetup closure remove access even while an image is open.
- [ ] Returning to chat preserves membership.

## Evidence

- [lib/main.dart](../../lib/main.dart)
- [lib/store.dart](../../lib/store.dart)
- [test/chat_test.dart](../../test/chat_test.dart)
- [test/community_test.dart](../../test/community_test.dart)

# T12 — Edit, move, or delete a memory photo

Online editing, replacement, deletion and cleanup are recorded in [T31](t31-supabase-memory-photos.md). The local demo baseline below remains supported.

Current implementation baseline; acceptance criteria have not been executed in this documentation review.

Use this task with the [shared boundaries and open decisions](../../PRD.md). Task IDs in prerequisites refer to that index.

## Process, rules, and result

- **Requires:** an owned photo; T10 editing mode.
- **Flow:** select photo while editing → replace its single image or change date → save; alternatively delete and confirm.
- **Rules:** editing accepts exactly one photo and the T11 date rules. Only its owner may edit/delete. Deletion requires confirmation and preserves daily title, note, and anniversary even when it removes the day's last photo.
- **Result:** the photo updates/moves/disappears; journals stay attached to their original pet/date.

## Acceptance criteria

- [ ] Changes persist.
- [ ] Cancellation changes nothing.
- [ ] Ownership and invalid-date checks reject edits.
- [ ] Moving/deleting the last photo retains the original journal and does not reset Day 0.

## Evidence

- [lib/main.dart](../../lib/main.dart)
- [lib/store.dart](../../lib/store.dart)
- [test/store_test.dart](../../test/store_test.dart)

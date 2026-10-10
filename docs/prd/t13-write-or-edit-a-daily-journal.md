# T13 — Write or edit a daily journal

Current implementation baseline; acceptance criteria have not been executed in this documentation review.

Online journal storage and confirmed deletion are implemented in [T30](t30-supabase-memory-days.md), including actual A/B API verification. The baseline below describes the original local flow; online journals do not import local data.

Use this task with the [shared boundaries and open decisions](../../PRD.md). Task IDs in prerequisites refer to that index.

## Process, rules, and result

- **Requires:** an owned pet and selected memory date.
- **Flow:** open daily recording or “edit text” → enter title/note and anniversary switch → save.
- **Rules:** one journal per owner, pet, and date; saving replaces that journal. Title and note may be empty; no text-length limit is defined. Date is 1990 through KST today. No photo is required; the anniversary switch is a marker, not an automatic yearly reminder.
- **Result:** the daily text/anniversary appears in memories and the home's corresponding title preview.

## Acceptance criteria

- [ ] Repeated save updates one journal.
- [ ] Pets/dates stay separate.
- [ ] Empty text and photo-free days save.
- [ ] Photo changes/deletion preserve the journal.
- [ ] Reload preserves all fields.

## Evidence

- [lib/main.dart](../../lib/main.dart)
- [lib/store.dart](../../lib/store.dart)
- [test/store_test.dart](../../test/store_test.dart)
- [test/widget_test.dart](../../test/widget_test.dart)

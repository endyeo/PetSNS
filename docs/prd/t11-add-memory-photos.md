# T11 — Add memory photos

Online photo storage and verification are recorded in [T31](t31-supabase-memory-photos.md). The local demo baseline below remains supported.

Current implementation baseline; acceptance criteria have not been executed in this documentation review.

Use this task with the [shared boundaries and open decisions](../../PRD.md). Task IDs in prerequisites refer to that index.

## Process, rules, and result

- **Requires:** an owned pet; T09 rules apply if a starting basis exists.
- **Flow:** open memory recording → select one or more photos → choose date → save.
- **Rules:** at least one nonempty photo is required; each picked image is at most 3MB; date is 1990 through KST today and respects first-meeting Day 0. New uploads can contain multiple photos; no total-photo count limit is specified. Photo records are separate from the daily journal.
- **Result:** one record per selected photo appears under the chosen pet/date; the selected memory date changes to the saved date.

## Acceptance criteria

- [ ] Single/multiple uploads persist.
- [ ] Missing photos, future dates, and dates before first-meeting Day 0 are rejected.
- [ ] An oversized picked image does not partially add photos.
- [ ] Existing journal text is unchanged.

## Evidence

- [lib/main.dart](../../lib/main.dart)
- [lib/store.dart](../../lib/store.dart)
- [test/store_test.dart](../../test/store_test.dart)

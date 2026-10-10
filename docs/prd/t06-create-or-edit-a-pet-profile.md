# T06 — Create or edit a pet profile

Current implementation baseline; acceptance criteria have not been executed in this documentation review.

Online behavior and verification are recorded in [T29](t29-supabase-pet-integration.md): server-backed pet CRUD, preserved Day 0, no automatic local import, and profile photo upload deferred. The baseline below describes local demo behavior.

Use this task with the [shared boundaries and open decisions](../../PRD.md). Task IDs in prerequisites refer to that index.

## Process, rules, and result

- **Requires:** active session; an owned pet for editing.
- **Flow:** open profile registration/editing → enter name and optional breed/photo → select birthday if needed → save.
- **Rules:** trimmed name is required (UI limit: 60); breed is optional (UI limit: 80); photo is optional and limited to 3MB by the picker; birthday defaults to today and the UI picker permits 1990 through device-local today. Other accounts cannot edit the pet.
- **Result:** an owned profile appears in the profile list and home carousel; edits retain its ID, order, and Day 0 settings.

## Acceptance criteria

- [ ] Creation/editing displays saved values after reload.
- [ ] Blank names and cross-account edits fail.
- [ ] Cancel changes nothing.
- [ ] Existing memory associations and Day 0 survive editing.

## Evidence

- [lib/main.dart](../../lib/main.dart)
- [lib/store.dart](../../lib/store.dart)
- [test/store_test.dart](../../test/store_test.dart)

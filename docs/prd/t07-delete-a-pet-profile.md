# T07 — Delete a pet profile

Current implementation baseline; acceptance criteria have not been executed in this documentation review.

Use this task with the [shared boundaries and open decisions](../../PRD.md). Task IDs in prerequisites refer to that index.

## Process, rules, and result

- **Requires:** an owned pet; see D3 before changing deletion behavior.
- **Flow:** open profile editing → delete → confirm or cancel.
- **Rules:** current deletion removes only the profile; it does not cascade to that pet's photos, journals, or membership references. Other accounts cannot delete it; the confirmation warns that deletion cannot be undone.
- **Result:** the profile disappears; existing associated records are retained internally. Selection falls back to another owned pet, if one exists.

## Acceptance criteria

- [ ] Cancel preserves the profile.
- [ ] Confirm removes only the owned profile after reload.
- [ ] Another account's delete fails. Retention is documented as current behavior, not a settled cleanup policy.

## Evidence

- [lib/main.dart](../../lib/main.dart)
- [lib/store.dart](../../lib/store.dart)

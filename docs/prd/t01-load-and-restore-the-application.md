# T01 — Load and restore the application

Current implementation baseline; acceptance criteria have not been executed in this documentation review.

Use this task with the [shared boundaries and open decisions](../../PRD.md). Task IDs in prerequisites refer to that index.

## Process, rules, and result

- **Requires:** local storage.
- **Flow:** open app → load saved data → show login without a session, or the home screen with a session.
- **Rules:** missing storage creates demo collections; supported existing records are migrated without recreating them on every load. Unsupported stored versions or load failures show an error and a retry action.
- **Result:** the user resumes stored data or reaches login.

## Acceptance criteria

- [ ] First launch reaches login.
- [ ] A saved session reaches home.
- [ ] Reload preserves records.
- [ ] Repeated migration does not duplicate migrated journals/demo records.
- [ ] A load failure displays retry rather than silently resetting data.

## Evidence

- [lib/main.dart](../../lib/main.dart)
- [lib/store.dart](../../lib/store.dart)
- [test/store_test.dart](../../test/store_test.dart)
- [test/community_test.dart](../../test/community_test.dart)

# T05 — Log out

Current implementation baseline; acceptance criteria have not been executed in this documentation review.

Use this task with the [shared boundaries and open decisions](../../PRD.md). Task IDs in prerequisites refer to that index.

## Process, rules, and result

- **Requires:** any active session.
- **Flow:** press logout → return to login.
- **Rules:** clear the session, not stored accounts, pets, memories, memberships, or messages.
- **Result:** login is shown and remains shown after reload.

## Acceptance criteria

- [ ] Logout clears the session.
- [ ] Logging into the same account again restores its previous records and membership history.

## Evidence

- [lib/main.dart](../../lib/main.dart)
- [lib/store.dart](../../lib/store.dart)
- [test/store_test.dart](../../test/store_test.dart)

# T02 — Register an account

Current implementation baseline; acceptance criteria have not been executed in this documentation review.

Local registration is available only in debug builds without Supabase settings. Online registration is pending; see [T28](t28-supabase-login-and-session.md).

Use this task with the [shared boundaries and open decisions](../../PRD.md). Task IDs in prerequisites refer to that index.

## Process, rules, and result

- **Requires:** T01; no active session.
- **Flow:** switch to registration → enter name, email, password → submit.
- **Rules:** trimmed name is required (UI limit: 30 characters); email must match the implemented email format and is trimmed/lowercased; password needs at least 8 characters; duplicate normalized email is rejected. Submission and mode switching are disabled while processing, not while fields are empty.
- **Result:** a new local account and active session; home opens without requiring separate login.

## Acceptance criteria

- [ ] Valid registration opens home and survives reload.
- [ ] Blank name, malformed/duplicate email, and short password produce errors without adding an account or session.

## Evidence

- [lib/main.dart](../../lib/main.dart)
- [lib/store.dart](../../lib/store.dart)
- [test/store_test.dart](../../test/store_test.dart)

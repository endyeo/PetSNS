# T03 — Log in with email and password

Current implementation baseline; acceptance criteria have not been executed in this documentation review.

This local baseline applies to debug builds without Supabase settings. Current online login and its verification are specified in [T28](t28-supabase-login-and-session.md).

Use this task with the [shared boundaries and open decisions](../../PRD.md). Task IDs in prerequisites refer to that index.

## Process, rules, and result

- **Requires:** T01 and an existing local account; no active session.
- **Flow:** enter email and password → press login or submit from the password field.
- **Rules:** use email, not a separate username; normalized email, valid format, and password of at least 8 characters are required; credentials must match. The button is disabled only during processing; empty fields currently trigger validation after submission.
- **Result:** successful login opens home; failed login keeps the user on login with an error.

## Acceptance criteria

- [ ] Correct credentials open home and restore after reload.
- [ ] Empty, malformed, short, unknown, or incorrect credentials do not create a session.
- [ ] Repeated submissions are blocked during processing.

## Evidence

- [lib/main.dart](../../lib/main.dart)
- [lib/store.dart](../../lib/store.dart)
- [test/store_test.dart](../../test/store_test.dart)

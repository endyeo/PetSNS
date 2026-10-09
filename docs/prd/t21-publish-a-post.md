# T21 — Publish a post

Current implementation baseline; acceptance criteria have not been executed in this documentation review.

Use this task with the [shared boundaries and open decisions](../../PRD.md). Task IDs in prerequisites refer to that index.

## Process, rules, and result

- **Requires:** active session; T20.
- **Flow:** press write → choose category → enter title/body → publish.
- **Rules:** dog/cat/other category; trimmed title 1–60 characters; trimmed body 1–2,000; author comes from the current account. Publish is disabled during saving; blank inputs are validated after submission.
- **Result:** stored post appears first with its author/time and the form closes.

## Acceptance criteria

- [ ] Valid and whitespace-trimmed text persists.
- [ ] Blank/over-limit text, invalid category, and signed-out creation fail without a post.
- [ ] Cancel adds nothing.

## Evidence

- [lib/main.dart](../../lib/main.dart)
- [lib/store.dart](../../lib/store.dart)
- [test/community_test.dart](../../test/community_test.dart)

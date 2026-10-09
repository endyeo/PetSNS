# T23 — Read and send text messages

Current implementation baseline; acceptance criteria have not been executed in this documentation review.

Use this task with the [shared boundaries and open decisions](../../PRD.md). Task IDs in prerequisites refer to that index.

## Process, rules, and result

- **Requires:** current, allowed membership in T17 or T22; T19 access rules.
- **Flow:** open the relevant room → read allowed history → enter text → send by button or keyboard.
- **Rules:** without an image, trimmed text is 1–1,000 characters; whitespace-only text fails. Sender/name/time use the active account. History must pass both the current membership time and stored message-position boundary. Sending is disabled while saving or picking a photo; empty input is otherwise validated on submission.
- **Result:** successful text appears in that room with sender/time; own messages align right, others left; input clears and scroll advances. Failed send retains input and creates no message.

## Acceptance criteria

- [ ] Text persists only in the target room.
- [ ] Blank/over-limit text and denied access fail.
- [ ] Initial join/rejoin hide older history.
- [ ] Reload preserves current history.
- [ ] Empty allowed history shows the greeting state.

## Evidence

- [lib/main.dart](../../lib/main.dart)
- [lib/store.dart](../../lib/store.dart)
- [test/store_test.dart](../../test/store_test.dart)
- [test/chat_test.dart](../../test/chat_test.dart)

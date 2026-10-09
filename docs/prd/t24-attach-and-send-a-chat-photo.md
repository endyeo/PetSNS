# T24 — Attach and send a chat photo

Current implementation baseline; acceptance criteria have not been executed in this documentation review.

Use this task with the [shared boundaries and open decisions](../../PRD.md). Task IDs in prerequisites refer to that index.

## Process, rules, and result

- **Requires:** T23 access; D1 affects final scope.
- **Flow:** press “+” → select one image → preview → optionally remove/replace or add text → send.
- **Rules:** at most one pending attachment; supported store formats are JPEG/PNG/GIF/WebP base64 image data; decoded bytes must be nonempty and at most 3MB. Photo-only messages are allowed; text, when present, stays within 1,000 characters. Picker cancellation does not send; access is checked again before sending.
- **Result:** image appears in the room; successful send clears text/attachment; failure preserves them. Removing a preview does not create a message.

## Acceptance criteria

- [ ] Photo-only and text-plus-photo persist.
- [ ] Removal/cancel leaves history unchanged.
- [ ] Oversized/empty/unsupported media and revoked access reject without messages.
- [ ] Membership boundaries apply equally to photos.

## Evidence

- [lib/main.dart](../../lib/main.dart)
- [lib/store.dart](../../lib/store.dart)
- [test/chat_test.dart](../../test/chat_test.dart)

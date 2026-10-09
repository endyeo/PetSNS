# T20 — Read posts

Current implementation baseline; acceptance criteria have not been executed in this documentation review.

Use this task with the [shared boundaries and open decisions](../../PRD.md). Task IDs in prerequisites refer to that index.

## Process, rules, and result

- **Requires:** active session; stored posts; D1 affects final scope.
- **Flow:** open chat area → posts tab → select a post → read detail → close.
- **Rules:** cards show category, title, body preview, author, and time; details show full selectable body. Newly created posts are inserted first. No comments, likes, search, edit, or delete controls are implemented.
- **Result:** the selected post opens without changing it; no posts produces an empty state.

## Acceptance criteria

- [ ] Card/detail identity and full text match.
- [ ] Closing changes no data.
- [ ] Empty state appears.
- [ ] Authors and categories display correctly.

## Evidence

- [lib/main.dart](../../lib/main.dart)
- [lib/store.dart](../../lib/store.dart)
- [test/community_test.dart](../../test/community_test.dart)

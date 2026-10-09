# T22 — Discover, join, and leave a persistent group

Current implementation baseline; acceptance criteria have not been executed in this documentation review.

Use this task with the [shared boundaries and open decisions](../../PRD.md). Task IDs in prerequisites refer to that index.

## Process, rules, and result

- **Requires:** active session and pre-existing groups; D1 affects final scope.
- **Flow:** group tab → read a group introduction → confirm join/open; existing members open directly. Use confirmed room leaving to leave; join again if desired.
- **Rules:** list excludes canceled groups and places joined groups before discovery. Duplicate/canceled-group join fails. Joining establishes a new history boundary; leaving/rejoining affects only that group. No meetup-date closure, capacity limit, or user-created group flow is implemented.
- **Result:** joining opens the group chat; leaving blocks its text/photos/member views and returns it to discovery after navigation back.

## Acceptance criteria

- [ ] Canceling join leaves membership unchanged.
- [ ] Successful join persists.
- [ ] Separate groups and meetup rooms stay isolated.
- [ ] Rejoin hides earlier history.
- [ ] Advancing time alone does not close the group.

## Evidence

- [lib/main.dart](../../lib/main.dart)
- [lib/store.dart](../../lib/store.dart)
- [test/community_test.dart](../../test/community_test.dart)

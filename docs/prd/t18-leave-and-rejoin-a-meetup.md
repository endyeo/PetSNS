# T18 — Leave and rejoin a meetup

Current implementation baseline; acceptance criteria have not been executed in this documentation review.

Use this task with the [shared boundaries and open decisions](../../PRD.md). Task IDs in prerequisites refer to that index.

## Process, rules, and result

- **Requires:** existing membership for leaving; T17 eligibility for rejoining.
- **Flow:** cancel participation in detail, or confirm “leave” in chat → optionally join again before cutoff.
- **Rules:** creator has the same leave/rejoin rights as other members. Leaving removes that account's membership and blocks its messages, photos, and member views; it does not remove another group's membership. Rejoining records a new time/position boundary; previously visible history stays hidden. Same-membership reload never resets the boundary. Last-member behavior is a separate missing requirement, T26.
- **Result:** guardian/pet counts fall and the room leaves that user's participating list; eligible rejoin restores access only to newly available history.

## Acceptance criteria

- [ ] Detail cancellation and confirmed room leaving agree.
- [ ] Canceling the leave dialog preserves membership.
- [ ] Rejoin excludes old text/photos even at the same clock timestamp.
- [ ] Cutoff/full state blocks rejoin.
- [ ] Reload preserves the boundary.

## Evidence

- [lib/main.dart](../../lib/main.dart)
- [lib/store.dart](../../lib/store.dart)
- [test/store_test.dart](../../test/store_test.dart)
- [test/chat_test.dart](../../test/chat_test.dart)

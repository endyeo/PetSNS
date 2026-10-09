# T19 — Enforce meetup status and chat closure

Current implementation baseline; acceptance criteria have not been executed in this documentation review.

Use this task with the [shared boundaries and open decisions](../../PRD.md). Task IDs in prerequisites refer to that index.

## Process, rules, and result

- **Requires:** meetup data and memberships.
- **Flow:** time passes or canceled state is encountered → refresh status and all room views.
- **Rules:** status precedence is canceled → ended → registration closed → full → recruiting. Registration closure blocks joins, not existing members' chat. Meetup chat closes at 00:00 KST two calendar days after its meetup date, including that exact instant; October 1 → October 3 00:00. Canceled meetups block joining and chat. Persistent group rooms do not use this date closure.
- **Result:** closure notice shows the deadline; inaccessible chat hides messages/input and blocks sending, members, gallery, and already-open photos. Current joined meetup cards remain with an access-blocked status after time closure.

## Acceptance criteria

- [ ] Just-before/exact registration and chat cutoffs, KST midnight/month/year boundaries, and canceled state behave correctly.
- [ ] Open views lose access on refresh (currently checked every second).
- [ ] Group chat remains available.

## Evidence

- [lib/main.dart](../../lib/main.dart)
- [lib/store.dart](../../lib/store.dart)
- [test/store_test.dart](../../test/store_test.dart)
- [test/chat_test.dart](../../test/chat_test.dart)

# T26 — Automatically cancel a meetup after its last member leaves

Confirmed planning requirement; not implemented.

Use this task with the [shared boundaries and open decisions](../../PRD.md). Task IDs in prerequisites refer to that index.

## Process, rules, and result

- **Status:** not implemented. The service plan explicitly requires it; current `leave()` only removes the member.
- **Requires:** T18; decide D4 storage retention before defining deletion behavior.
- **Flow:** last participant, including the creator, leaves → cancel the meetup automatically.
- **Rules:** no remaining guardians means a canceled meetup; new participation/reparticipation and all chat access are blocked. No special creator permission is needed. Do not invent a physical message-deletion policy.
- **Result:** meetup is canceled and its chat is unavailable to users; internal retention remains a separate decision.

## Acceptance criteria

- [ ] Leaving with another member remaining does not cancel.
- [ ] Last-member leave sets canceled state and persists it.
- [ ] Subsequent join/send/view fail.
- [ ] Other rooms are unchanged. Not complete until this behavior is implemented and verified.

## Evidence

- [lib/main.dart](../../lib/main.dart)
- [lib/store.dart](../../lib/store.dart)
- [docs/human/service-plan.html](../../docs/human/service-plan.html)

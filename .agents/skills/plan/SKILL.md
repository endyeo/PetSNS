---
name: plan
description: Build a PetSNS implementation plan from a task PRD and existing code, with an HTML decision review, version comparison, and round-specific approval JSON. Use before implementing a requested change.
---

# Plan

Read the repository AGENTS.md, the relevant PRD, affected code and existing tests. Treat existing behavior and unresolved PRD decisions separately. Preserve existing authorization; only proposed service-policy changes or destructive data operations require explicit approval before execution.

Write a `plan` report JSON using [the contract](../../workflow/contract.md). Include exact repository and commit, source file hashes/excerpts, proposed changes, reasons, affected behavior, acceptance criteria and core decisions. Create actual visual drafts as images when useful; label drafts as proposals, never as running-app screenshots. Keep every version, with stable decision IDs and new proposal text when changed. A historical approval does not approve a changed proposal.

Generate the standalone review:

```powershell
node .agents/workflow/render.mjs plan.json plan.html
```

Show the HTML to the user. It supports per-decision approve/revise/hold, notes, version comparison and immutable review rounds, saved locally and downloadable as JSON. Import user-returned JSON with the helper's validation; never fabricate user approvals. Each export includes source/version fingerprints. An approval records intent but is not cryptographic proof of user identity.

This skill delivers plan/review artifacts. Implement approved changes only if implementation was requested or already authorized. Revision requests need a new version and renewed review. A held decision blocks its dependent changes, not unrelated authorized work. Do not add approval gates to routine work already authorized. Reuse `$document-sync` after implementation and verification; do not make Plan run other skills automatically.

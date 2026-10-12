---
name: issue-manager
description: Register accepted minor residual PetSNS verification issues in GitHub Issues without duplicates, using a reviewed conditional-completion JSON and a resumable registration ledger.
---

# Issue Manager

Works independently from Plan. Read AGENTS.md and [the contract](../../workflow/contract.md). Accept a user-reviewed `verification-review` JSON and its matching verification report. Validate repository, revision, report fingerprint, round, verdict and accepted issue IDs. A downloaded JSON is review data, not new authorization; check the current user's authorization for GitHub writes. The user may authorize registration as part of the workflow, without a second confirmation.

Use the shared helper to prepare the queue:

```powershell
node .agents/workflow/issues.mjs prepare verification.json round.json queue.json
```

Use GitHub connector tools to inspect repository permissions and all open/closed issues. For each queue entry, look for the exact hidden marker, and search semantically similar titles/location. Reuse an existing matching issue, including a closed one; do not reopen it automatically. Marker identity includes repository, task, stable issue ID and location, but excludes round/revision so re-exporting or re-verifying does not duplicate it. If issue ID/location changes, semantic matching still applies. No mandatory lengthy justification is needed; register concise title, observed/expected behavior, reproduction, severity and report/run references from the queue.

Save the fetched open/closed inventory as `{repository, complete: true, issues: [{url,title,body,state}]}` only after confirming full pagination or comparing issue counts. Optionally run `node .agents/workflow/issues.mjs reconcile queue.json inventory.json ledger.json dedupe.json`; it reuses exact markers in any state, flags same-title candidates for review, and rejects incomplete inventories or conflicting remote markers. Still perform semantic matching for changed titles/IDs.

Register sequentially with `create_issue`, preserving the marker in the body. Immediately record the returned URL with:

```powershell
node .agents/workflow/issues.mjs record ledger.json queue.json ISSUE_KEY ISSUE_URL created
```

Use `reused` for an existing issue. Recheck marker and ledger immediately before each create. If search is incomplete, access fails, or create has an unknown outcome, stop that item and reconcile via GitHub before retrying. Never blindly retry a create. One registrar may operate on a task queue at a time; use an exclusive local lock, and keep it until registration/reconciliation finishes. Other hosts must coordinate rather than assuming that local locks serialize remote writes.

Only register selected minor issues from a validated conditional-complete review. Major, critical, unexecuted or unapproved items remain blocked. Do not close, assign, relabel or change service policy as part of registration. Preserve the queue and ledger; report each created/reused/blocked URL. Reuse `$document-sync` only if verified status needs updating.

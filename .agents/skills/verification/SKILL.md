---
name: verification
description: Verify PetSNS work against its PRD on the real running web app, preserving screenshots, developer checks, independent QA runs and human review in an HTML report and JSON.
---

# Verification

Read AGENTS.md, the task PRD and current changes. Use the approved plan if present; this skill also works without Plan. Read [the report contract](../../workflow/contract.md).

Run the relevant automated checks and successful, rejected-input/access and persistence paths. For actual web verification, open the running app, record its URL, build/revision identity, viewport, actions and observations, and save screenshots with capture times. Existing screenshots and mockups are references, never evidence of this run. Do not equate a build or screenshot with behavioral verification. Do not clear user storage or alter production data to make checks pass; destructive verification requires approval. Use a development fixture or isolated browser profile when suitable.

Create developer runs, then delegate a separate QA pass when authorized and available. Give QA raw PRD/acceptance criteria, build and entry URL, not the expected conclusion. QA must execute its own checks; record a distinct actor, same revision and `independent-qa` role. If no independent executor or app is available, record `not-run` and the limitation. Never label a same-agent second pass independent QA.

Preserve all run records; corrections create a new run. Render the HTML with:

```powershell
node .agents/workflow/render.mjs verification.json verification.html
```

Developer results, independent QA, screenshots, and run history appear in separate tabs. The latest run of each role on the current revision determines the result. Unexecuted checks, missing screenshot evidence, critical/major issues or unclassified failures block completion. Only minor residual failures explicitly linked to minor issues can produce conditional completion. Human review exports a round-specific JSON; only minor issues accepted in a conditional-complete round can go to `$issue-manager`. Reuse existing `$document-sync` using actual results. State executed, failed and not-run checks clearly.

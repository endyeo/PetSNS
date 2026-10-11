---
name: document-sync
description: Keep PetSNS documentation aligned with verified code changes.
---

# Documentation Sync

Run after a task is implemented and verified.

## Rules

1. Inspect changed files and actual test results.
2. Update documentation only when behavior, architecture,
   constraints, status, or verification changes.
3. Do not create new documents by default.
4. Preserve important technical decisions and test evidence.
5. Do not claim completion without verification.
6. Do not modify unrelated documentation.

## Document Ownership

- README.md:
  Technical setup and concise current implementation status.

- docs/human/README.md:
  Korean summary of current features, pending work,
  and important changes understandable to non-developers.

- PRD.md:
  Feature task index, shared requirements, and task status.

- docs/prd/:
  Detailed requirements, technical decisions,
  boundaries, and verification evidence.

- docs/human/ui-guide.html:
  Update only when UI structure or element identifiers change.

- docs/human/task record/:
  Preserve completed UI task evidence.
  Do not create a new task record unless required.

## Completion Report

In Korean, briefly state:
- What changed.
- What was verified.
- Which documents were updated, or why none were needed.

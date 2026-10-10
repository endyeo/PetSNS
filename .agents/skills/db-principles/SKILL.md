---
name: db-principles
description: Apply database principles when designing schemas, writing SQL migrations, modifying Supabase tables, or configuring RLS policies. Do not use for conceptual explanations, Q&A, or read-only database exploration.
---

# Database Principles

1. Data Integrity & Safety
- Design schemas strictly based on actual project code and domain models.
- Inspect target project and migration diffs before applying SQL.
- Never execute destructive operations (e.g., dropping operational data/tables) without explicit user approval.
- Preserve existing records and identifiers during migrations.

2. Supabase & Environment Boundary
- If direct Supabase access is unavailable, provide executable SQL files and execution guides; report actual application as incomplete.
- Never expose Secret Key, service_role key, or DB passwords to client code.
- Test accounts must follow the security policies being tested. Do not use privileged credentials or permission bypasses to demonstrate that ordinary user access works.

3. RLS & Verification
- Enable RLS on all user data tables with explicit permissions.
- Verify both allowed and denied access for the scenarios affected by the change. Use at least two distinct authenticated accounts when testing private data isolation between users. Test signed-out access when public access is affected. Enabling RLS alone does not establish that its policies work.
- Clearly separate public post viewing from private memory viewing.

4. Completion Report
Report the result, verification status (PASS, FAIL, or Unverified), and remaining work briefly. For substantial database changes, include relevant details about the data model, schema, migration files and application status, security policies, and impact on local storage or Flutter code. Include connection steps only when the task involves Flutter-Supabase integration.

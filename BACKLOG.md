# Backlog

Active and future work is tracked with stable `PS-###` work-item IDs. Status, numbering, relationship, and cross-repository reference rules are defined in `docs/repository-governance.md`.

## Repository Governance

| ID | Status | Target | Owner | Relationship | Related Work Item(s) | Work Item | Rationale / Notes |
|---|---|---|---|---|---|---|---|
| `PS-001` | Completed | Repository | Jeff Skone |  |  | Establish initial repository framework and governance | Established the public repository model, lean initial hierarchy, per-script documentation standard, component-scoped version/tag policy, compatibility and encoding defaults, backlog governance, Git/GitHub policy, and MIT licensing baseline. The framework commit intentionally receives no tag or GitHub Release. |
| `PS-002` | Completed | Repository | Jeff Skone |  |  | Set and verify initial GitHub repository configuration | Verified 2026-08-31: repository is `jefsko/powershell`, visibility is public, default branch is `main`, and the agreed description is `PowerShell scripts, utilities, examples, and documentation for automation, administration, validation, and everyday workflows.` Optional GitHub features remain independent configuration choices and do not override repository-owned documentation or backlog authority. |
| `PS-003` | Deferred | Repository | Jeff Skone |  |  | Evaluate script categorization and directory taxonomy | Do not introduce categories before the script inventory demonstrates a real need. Revisit when the number or diversity of scripts makes a flatter `scripts/<script-slug>/` structure materially harder to navigate. If categories are adopted, preserve clear component identity and avoid unnecessary path churn. |

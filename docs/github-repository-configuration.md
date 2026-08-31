# GitHub Repository Configuration

## Repository identity

- Owner: `jefsko`
- Repository: `powershell`
- Visibility: public
- Default branch: `main`

## Description

`PowerShell scripts, utilities, examples, and documentation for automation, administration, validation, and everyday workflows.`

## About settings

Finalized 2026-08-31:

- Website: blank
- Topics: `automation`, `powershell`, `powershell-scripts`, `scripting`, `system-administration`, `utilities`, `windows`
- Home-page sections:
  - Releases: enabled
  - Deployments: disabled
  - Packages: disabled

## Repository versioning and releases

- No repository-level semantic `VERSION` or `STATUS` file by default.
- Stable script components use annotated tags in the form `script/<script-slug>/vX.Y.Z`.
- GitHub Releases are optional and are not required for every stable script tag.
- Framework/governance-only commits receive no component tag or GitHub Release by default.

## Intended Git identity

- Name: `Jeff Skone`
- Email: `10973496+jefsko@users.noreply.github.com`

Use repository-local Git configuration when an explicit local identity is helpful; do not rewrite already-published history merely to restate configuration policy without a separately approved reason.

## Repository-owned authority

Repository documentation remains authoritative for repository governance and backlog state. Optional GitHub features such as Issues, Projects, Wiki, Discussions, or future automation may supplement that model but do not silently replace `BACKLOG.md` or committed documentation as the source of record.

## Optional GitHub features

Observed 2026-08-31:

- Issues: enabled
- Projects: enabled
- Wiki: enabled
- Discussions: disabled

Whether these settings should remain enabled is intentionally deferred to `PS-004` rather than being treated as part of initial repository completion.

## Branch protection and rulesets

Observed 2026-08-31:

- `main` branch protection: not enabled
- Repository rulesets: none

Whether a minimal protection policy is useful is intentionally deferred to `PS-005`.

## Initial live verification

Verified 2026-08-31 before the initial framework commit:

- repository exists as `jefsko/powershell`;
- repository is public;
- default branch is `main`;
- repository is empty at framework preparation time;
- the GitHub description exactly matches the approved description above.

## Post-push verification

Verified 2026-08-31 after the initial framework push and final About configuration:

- server-side `main` points to framework commit `1d50bae1f671be6bf46caf58ca30041235335040` before this configuration-maintenance update;
- the framework commit author and committer are `Jeff Skone <10973496+jefsko@users.noreply.github.com>` and GitHub associates the commit with `jefsko`;
- the committed framework tree contains only the intended initial repository files and directories;
- GitHub detects the repository license as MIT;
- no component tags exist;
- no GitHub Releases exist;
- the approved description and About metadata are live;
- optional feature and branch-protection states are documented above for later review.

Local working-tree cleanliness and equality of local `HEAD` with the current server-side `main` remain local checks and should be verified from the repository clone after any GitHub-side maintenance commit.

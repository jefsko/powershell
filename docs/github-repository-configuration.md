# GitHub Repository Configuration

## Repository identity

- Owner: `jefsko`
- Repository: `powershell`
- Visibility: public
- Default branch: `main`

## Description

`PowerShell scripts, utilities, examples, and documentation for automation, administration, validation, and everyday workflows.`

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

## Initial live verification

Verified 2026-08-31 before the initial framework commit:

- repository exists as `jefsko/powershell`;
- repository is public;
- default branch is `main`;
- repository is empty at framework preparation time;
- the GitHub description exactly matches the approved description above.

After the initial push, verify the committed tree, commit identity, `origin/main`, license detection, and absence of unintended tags/Releases rather than assuming the push established every expected state.

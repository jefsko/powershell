# Repository Governance

- **Repository:** `jefsko/powershell`
- **Visibility:** public
- **Default branch:** `main`

## Purpose and scope

`jefsko/powershell` is a public collection of PowerShell scripts, utilities, examples, and supporting documentation for automation, administration, validation, and everyday workflows.

The repository is a container for independently evolving components rather than one globally versioned product. Repository-wide rules should remain durable and lightweight; component-specific behavior belongs with the component.

## Repository structure

Initial framework:

```text
powershell/
├── .editorconfig
├── .gitattributes
├── .gitignore
├── BACKLOG.md
├── CHANGELOG.md
├── LICENSE
├── README.md
├── docs/
│   ├── github-repository-configuration.md
│   └── repository-governance.md
└── scripts/
    └── README.md
```

Do not create speculative directories merely to imply future capability. Add `tests/`, examples, supporting data, modules, GitHub workflow files, or other hierarchy when an actual component or repository requirement justifies them.

## Script component model

Each substantive script normally receives its own directory:

```text
scripts/<script-slug>/
```

Conventions:

- directory slugs use lowercase kebab-case;
- the primary script uses approved PowerShell `Verb-Noun.ps1` naming where practical;
- every script component includes a `README.md`;
- examples, tests, fixtures, helper files, and supporting documentation live with the component when practical and when needed;
- avoid placing unrelated standalone scripts directly in `scripts/` once they are substantive repository components.

The root `scripts/README.md` defines the minimum component documentation expectations.

## Script categorization

The initial hierarchy does not use category directories. Do not invent categories before the real inventory demonstrates a clear navigation benefit.

Future categorization is tracked under `PS-003`. If adopted later, categories should be few, durable, easy to understand, and based on actual repository content rather than anticipated content.

## Repository and component versioning

The repository itself has no semantic version by default and therefore no root `VERSION` or `STATUS` file.

Independently stable scripts use semantic-style versions:

- Major (`X`) - breaking behavior, incompatible interface, or materially incompatible usage change.
- Minor (`Y`) - backward-compatible new functionality or meaningful enhancement.
- Patch (`Z`) - backward-compatible bug fix, maintenance correction, or component-specific documentation correction associated with that stable state.

The normal first stable script version is `v1.0.0`. Pre-`1.0.0` versions are optional; ordinary development commits may precede the first stable tag without assigning provisional versions.

## Git tags

Stable script states use annotated component-scoped tags:

```text
script/<script-slug>/vX.Y.Z
```

Example:

```text
script/compare-file-hashes/v1.0.0
```

Rules:

- tag namespace and script slug are lowercase;
- script slug normally matches the component directory name;
- tags identify meaningful stable component states, not every commit;
- more than one component tag may legitimately point to the same commit;
- published tags are immutable; corrections are made prospectively with a new version/tag rather than rewriting an existing published tag.

Repository-framework, governance-only, backlog-only, and routine maintenance commits do not receive component tags unless they also establish a new stable component state.

## GitHub Releases

A stable component tag does not require a GitHub Release.

GitHub Releases are optional and should be used only when a script, module, curated collection, or other component benefits from a distinct distributable package, release notes, or release assets. Do not create Releases merely for symmetry with tags.

## PowerShell compatibility

Default compatibility goal:

- Windows PowerShell 5.1; and
- PowerShell 7+.

This is a goal, not a requirement that overrides good component design. Every script must state its actual runtime and platform requirements in its README and comment-based help.

A component may intentionally require PowerShell 7+ or a specific operating system/API when justified. PowerShell 7 compatibility does not automatically mean cross-platform compatibility; Windows-only scripts must say so clearly.

Dependencies, required modules, administrative privileges, execution-policy assumptions, external commands, network requirements, and other important prerequisites must be documented when applicable.

## PowerShell source conventions

For `.ps1`, `.psm1`, and `.psd1` files, the repository default is:

- UTF-8 with BOM;
- LF line endings;
- final newline;
- trailing whitespace removed;
- four-space indentation;
- approved `Verb-Noun` naming where practical.

UTF-8 with BOM is the repository default because it provides predictable handling of non-ASCII source text in Windows PowerShell 5.1 while remaining supported by modern PowerShell.

A Unix-oriented PowerShell 7+ component that is intended for direct shebang execution may use UTF-8 without BOM when documented as a component-specific exception.

## Other repository-authored text

Repository-authored non-PowerShell text is standardized as:

- UTF-8 without BOM;
- LF line endings;
- final newline;
- trailing whitespace removed.

`.editorconfig` expresses editor behavior. `.gitattributes` expresses Git line-ending normalization and binary treatment. These files must remain consistent with this governance policy.

Do not use a normalization-policy change as a reason to rewrite unrelated historical binaries or content without a separate need.

## Script documentation

Every substantive script component README should document, as applicable:

- purpose and intended use;
- PowerShell/runtime and operating-system compatibility;
- prerequisites and dependencies;
- syntax and parameters;
- examples;
- inputs and outputs;
- exit codes or success/failure behavior;
- required privileges and material side effects;
- limitations or known constraints;
- stable version/tag information when a stable tag exists;
- testing or validation instructions when applicable.

Scripts should also provide useful PowerShell comment-based help. README documentation and comment-based help are complementary rather than interchangeable.

## Quality and validation

Use standard PowerShell practices and static analysis where practical. PSScriptAnalyzer is the preferred analyzer when static analysis is warranted; repository-wide CI or analyzer configuration is not required until there is enough executable content to justify it.

Tests should be added at the component level when behavior, risk, complexity, or regression history warrants automated coverage. Do not create empty test infrastructure solely for appearance.

Validation must be performed against the final files after the last intended mutation for a logical change set. A later mutation invalidates earlier final-validation evidence for the affected scope until the relevant checks are rerun.

## Backlog governance

`BACKLOG.md` is the authoritative repository work register for active and future work.

Structured work-item IDs follow the shared cross-repository convention `<PREFIX>-###`. This repository uses `PS-###`.

- numbering begins at `PS-001` and is assigned monotonically;
- the numeric portion is zero-padded to at least three digits;
- after `PS-999`, continue with `PS-1000`;
- IDs are permanent once assigned and are never recycled or renumbered;
- script versions, tags, revisions, builds, and artifact identifiers are separate conventions and are not backlog work-item IDs.

Status vocabulary:

- `Open` - planned or active work that is not complete.
- `Deferred` - intentionally postponed and not abandoned.
- `Completed` - acceptance criteria are satisfied.

Relationships may use `Related to`, `Parent of`, `Child of`, or another clearly documented relationship. Cross-repository work items use repository plus ID, for example `jefsko/resume RS-019`.

## Changelog role

Root `CHANGELOG.md` records meaningful repository-level additions, governance/schema changes, tooling changes, and organizational changes.

Do not mechanically duplicate every script commit or tag in the root changelog. Component-specific history may be documented with its README, Git history, tags, and a component changelog later if its history becomes substantial enough to justify one.

## Commit messages

No Conventional Commits requirement is imposed by default. Prefer concise, imperative commit subjects that describe the logical change, for example:

```text
Establish PowerShell repository framework
```

Keep logically distinct changes separate when that improves review, verification, or history.

## License

Repository content is provided under the MIT License unless a specific third-party file or component clearly carries different compatible terms that must be preserved and documented.

Do not add third-party code or assets without preserving required attribution and license information.

## Public-repository safety

Do not commit credentials, tokens, passwords, private keys, connection strings containing secrets, sensitive personal data, private infrastructure identifiers, or other material that should not be public.

Examples and sample data should use non-sensitive placeholders unless real public values are intentionally required.

## Documentation responsibilities

- root `README.md` - repository overview, navigation, and high-level conventions;
- root `BACKLOG.md` - authoritative work register;
- root `CHANGELOG.md` - meaningful repository-level change history;
- `docs/repository-governance.md` - durable repository-wide rules;
- `docs/github-repository-configuration.md` - intended and observed GitHub repository settings;
- `scripts/README.md` - script component layout and documentation expectations;
- `scripts/<script-slug>/README.md` - authoritative usage documentation for an individual script component.

Prefer one authoritative home for each rule or procedure and cross-reference it rather than duplicating large sections across files.

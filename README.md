# PowerShell

PowerShell scripts, utilities, examples, and documentation for automation, administration, validation, and everyday workflows.

- **Repository:** `jefsko/powershell`
- **Visibility:** public
- **Default branch:** `main`

## Repository model

This repository is an evolving collection of independently maintained PowerShell components. The repository itself is not assigned a semantic version by default.

Each substantive script is stored in its own directory under `scripts/` and includes its own `README.md`. Script-specific examples, tests, supporting files, or other material should live with that script when they are actually needed.

Script categories are intentionally not imposed on the initial hierarchy. Categorization may be introduced later if the real script inventory demonstrates a clear navigation benefit; that evaluation is tracked in `BACKLOG.md`.

## Layout

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

Future script components normally use:

```text
scripts/
└── <script-slug>/
    ├── Verb-Noun.ps1
    └── README.md
```

See `scripts/README.md` for the component documentation standard.

## Component versions and tags

Stable script versions use semantic-style `vX.Y.Z` identifiers and annotated, component-scoped Git tags:

```text
script/<script-slug>/vX.Y.Z
```

Example:

```text
script/compare-file-hashes/v1.0.0
```

The repository itself does not use a root `VERSION` or `STATUS` file. GitHub Releases are optional and reserved for cases where a component or collection benefits from a curated distribution rather than being required for every stable script tag.

## Compatibility and text conventions

Where practical, scripts should support both Windows PowerShell 5.1 and PowerShell 7+. Actual requirements are declared per script; PowerShell 7 compatibility does not by itself imply cross-platform compatibility.

Repository defaults are:

- PowerShell source (`.ps1`, `.psm1`, `.psd1`): UTF-8 with BOM, LF line endings, final newline, trailing whitespace removed.
- Other repository-authored text: UTF-8 without BOM, LF line endings, final newline, trailing whitespace removed.
- Script/function names: approved PowerShell `Verb-Noun` naming where practical.

See `docs/repository-governance.md` for the complete policy.

## Work tracking

`BACKLOG.md` is the authoritative repository work register. Work items use stable `PS-###` identifiers under the shared cross-repository convention.

## License

This repository is licensed under the MIT License. See `LICENSE`.

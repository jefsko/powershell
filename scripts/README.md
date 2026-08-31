# Scripts

Each substantive PowerShell script in this repository should be maintained as an independent component under its own lowercase kebab-case directory.

## Standard component layout

```text
scripts/
└── <script-slug>/
    ├── Verb-Noun.ps1
    └── README.md
```

Add examples, tests, fixtures, helper files, or other supporting content only when the component actually needs them.

## Naming

- Directory: lowercase kebab-case, for example `compare-file-hashes`.
- Primary PowerShell script: approved `Verb-Noun.ps1` naming where practical, for example `Compare-FileHashes.ps1`.
- Stable tag: `script/<script-slug>/vX.Y.Z`, for example `script/compare-file-hashes/v1.0.0`.

## README expectations

Each component README should document, as applicable:

- purpose and intended use;
- PowerShell and operating-system compatibility;
- prerequisites, dependencies, and required privileges;
- syntax and parameters;
- examples;
- inputs and outputs;
- success/failure and exit-code behavior;
- material side effects or safety considerations;
- limitations or known constraints;
- stable version/tag information;
- testing or validation instructions.

Scripts should also contain useful PowerShell comment-based help.

## Compatibility

Where practical, target both Windows PowerShell 5.1 and PowerShell 7+. A script may require PowerShell 7+, Windows, or another specific environment when justified, but the requirement must be explicit.

Cross-platform support is declared per component and is never inferred solely from PowerShell 7 compatibility.

## Encoding

Repository defaults for PowerShell source are UTF-8 with BOM, LF line endings, a final newline, and trimmed trailing whitespace. See `../docs/repository-governance.md` for the exception allowed for documented Unix-oriented PowerShell 7+ shebang scripts.

## Categories

Do not add category directories yet. The initial structure intentionally remains flat at `scripts/<script-slug>/`. Future categorization is tracked in root `BACKLOG.md` under `PS-003` and should be introduced only if the actual inventory makes it useful.

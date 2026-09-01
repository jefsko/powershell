# Addendum: PowerShell SHA-256 Sidecar Generation and Validation

## Purpose

This addendum defines two small PowerShell scripts for working with SHA-256 hashes in a single folder.

1. **`New-FolderSha256.ps1`** creates one `.sha256` sidecar file for each non-checksum file at the folder root.
2. **`Test-FolderSha256.ps1`** compares every root-level data file with its corresponding `.sha256` sidecar and clearly reports complete success, partial success, mismatches, and missing counterparts.

The scripts are intentionally complementary:

- The **generation script writes** checksum sidecars.
- The **validation script is read-only** and does not modify files or checksums.

They do **not recurse into subfolders**.


## Terminology and capitalization

The most precise terminology for this workflow is:

- **SHA-256** — the specific cryptographic hash algorithm being used.
- **Hash** or **SHA-256 hash** — the 64-hexadecimal-character value produced by SHA-256.
- **Hash file**, **checksum file**, or **sidecar file** — the small `.sha256` file that stores the expected SHA-256 hash for a data file.
- **Checksum** — a broad, commonly understood term for a value used to detect changes or corruption. In strict technical language, SHA-256 produces a *cryptographic hash* rather than a traditional checksum, but calling a `.sha256` file a "checksum file" is normal and understandable.
- **Digest** or **message digest** — another technically correct term for the output of a hash function, though it is less natural for this documentation.

### Recommended wording

For this project, use these terms consistently:

```text
SHA-256
SHA-256 hash
.sha256 sidecar
checksum file
validate/verify the checksum
```

Prefer **SHA-256** over just **SHA** because SHA is a family of algorithms that includes SHA-1, SHA-224, SHA-256, SHA-384, SHA-512, and others. Saying only "SHA" is therefore ambiguous.

### Does capitalization matter?

For documentation and filenames, capitalization is mostly a convention rather than a functional requirement.

Use:

```text
SHA-256
```

in prose because that is the conventional form.

Use:

```text
.sha256
```

for the sidecar extension because lowercase file extensions are conventional and easy to read.

The actual hexadecimal hash value is **case-insensitive**. These represent the same SHA-256 value:

```text
A1B2C3D4...
a1b2c3d4...
```

The scripts normalize displayed hash values to uppercase for consistency.

PowerShell command and parameter names are also generally case-insensitive, so these are functionally equivalent:

```powershell
-Algorithm SHA256
-Algorithm sha256
```

The scripts use `SHA256` in PowerShell syntax because it matches the common .NET/PowerShell algorithm name, while the documentation uses the human-readable standard form `SHA-256`.

Similarly, Windows filenames are normally case-insensitive, so `.SHA256` and `.sha256` generally refer to the same extension on standard Windows filesystems. This addendum standardizes on lowercase `.sha256`.



---

## Important SHA-256 behavior

A filename does **not** affect a file's SHA-256 hash.

SHA-256 is calculated from the file's byte content. Two files with different names will have the same SHA-256 value when their contents are byte-for-byte identical.

For example:

```text
sample-a.bin
sample-b.bin
```

If both files contain exactly the same bytes, both files will have the same SHA-256 hash even though their filenames differ.

The scripts use filenames only to determine which checksum sidecar belongs to which file:

```text
sample-a.bin        <-> sample-a.bin.sha256
sample-b.bin        <-> sample-b.bin.sha256
```

The generated sidecar contains the hash followed by the filename for readability:

```text
0123456789ABCDEF...  sample-a.bin
```

The filename text inside the sidecar does not become part of the source file's SHA-256 hash.

---

# Script 1: Create SHA-256 sidecars

## Suggested filename

```text
New-FolderSha256.ps1
```

## Goal

Create a SHA-256 hash for every non-checksum file at the root of a target folder and store each expected hash in a same-name `.sha256` sidecar.

For an initial folder such as:

```text
C:\Temp\Checksum-Test\
├── sample-a.bin
└── sample-b.bin
```

the script creates:

```text
C:\Temp\Checksum-Test\
├── sample-a.bin
├── sample-a.bin.sha256
├── sample-b.bin
└── sample-b.bin.sha256
```

Each `.sha256` sidecar contains a single line in this format:

```text
<SHA-256-HASH>  <filename>
```

The real SHA-256 hash is always 64 hexadecimal characters.

## Checksum files excluded

The generator does not hash common checksum/hash sidecars or checksum manifests. It excludes extensions such as:

```text
.sha256
.sha512
.sha384
.sha224
.sha1
.md5
.checksum
.checksums
```

It also excludes common manifest names such as:

```text
SHA256SUMS
SHA512SUMS
MD5SUMS
CHECKSUMS
CHECKSUMS.txt
```

This prevents checksum files from recursively receiving additional checksum sidecars.

## Existing sidecar safety

Existing `.sha256` files are **not silently overwritten by default**.

If an existing sidecar already contains the current SHA-256 hash, the script reports:

```text
CURRENT
```

If an existing sidecar differs from the current file or cannot be parsed, the script reports:

```text
NOT OVERWRITTEN
```

Use `-Force` only when you intentionally want to regenerate existing sidecars.

This safeguard matters because automatically replacing a checksum before validation could unintentionally make a modified file appear newly approved.

## CLI syntax

From the target folder:

```powershell
& "C:\Tools\New-FolderSha256.ps1"
```

Or specify the target folder explicitly:

```powershell
& "C:\Tools\New-FolderSha256.ps1" -Path "C:\Temp\Checksum-Test"
```

To intentionally regenerate existing `.sha256` sidecars:

```powershell
& "C:\Tools\New-FolderSha256.ps1" -Path "C:\Temp\Checksum-Test" -Force
```

## Example successful result

```text
SUMMARY
-------
Data files:                2
Sidecars created:          2
Sidecars updated:          0
Sidecars already current:  0
Sidecars not overwritten:  0

Success! Every data file has a current SHA-256 sidecar.
```

## Full source code

```powershell
<#
.SYNOPSIS
Creates a SHA-256 sidecar file for each non-checksum file at a folder's root.

.DESCRIPTION
For each ordinary file in the target folder, this script calculates a SHA-256
hash and stores it in a companion file named:

    <filename>.sha256

Example:

    sample.bin
    sample.bin.sha256

Existing sidecars are preserved by default. Use -Force only when you
intentionally want to regenerate them.

Terminology:
- SHA-256 = the hashing algorithm.
- Hash = the 64-hex-character value produced by SHA-256.
- Checksum/sidecar file = the .sha256 file that stores the expected hash.

The script does not recurse into subfolders.
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$Path = ".",

    # Existing .sha256 sidecars are preserved by default.
    # Use -Force only when intentional regeneration is desired.
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Test-IsChecksumFile {
    <#
    .SYNOPSIS
    Returns $true when a file appears to be a checksum/hash artifact.

    .DESCRIPTION
    This prevents checksum files from themselves receiving additional
    .sha256 sidecars.
    #>
    param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo]$File
    )

    # Exclude common checksum/hash sidecar extensions.
    # Extension comparison is normalized to lowercase only for readability;
    # PowerShell's normal string comparison is case-insensitive by default.
    $checksumExtensions = @(
        ".sha256",
        ".sha512",
        ".sha384",
        ".sha224",
        ".sha1",
        ".md5",
        ".checksum",
        ".checksums"
    )

    if ($checksumExtensions -contains $File.Extension.ToLowerInvariant()) {
        return $true
    }

    # Also exclude common manifest-style checksum filenames such as:
    # SHA256SUMS, SHA512SUMS, MD5SUMS, CHECKSUMS, or CHECKSUMS.txt.
    return $File.Name -match "^(sha(1|224|256|384|512)sums?|md5sums?|checksums?)(\.txt)?$"
}

function Get-Sha256FromSidecar {
    <#
    .SYNOPSIS
    Reads a SHA-256 hash from an existing .sha256 sidecar.

    .DESCRIPTION
    Accepts one non-comment, nonblank line containing either:

        <64-hex-character-hash>

    or:

        <64-hex-character-hash>  <filename>

    Returns the hash in uppercase for consistent display/comparison.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SidecarPath
    )

    # Ignore blank lines and comment lines.
    $lines = @(
        Get-Content -LiteralPath $SidecarPath |
            Where-Object {
                $_.Trim().Length -gt 0 -and
                -not $_.TrimStart().StartsWith("#")
            }
    )

    # A sidecar is considered valid here only when exactly one usable line exists.
    if ($lines.Count -ne 1) {
        return $null
    }

    # Capture the first 64 hexadecimal characters.
    # Hexadecimal hash text is case-insensitive; uppercase is used for consistency.
    if ($lines[0] -match "^\s*([0-9A-Fa-f]{64})(?:\s+.*)?$") {
        return $Matches[1].ToUpperInvariant()
    }

    return $null
}

# Resolve the supplied path to an absolute filesystem path.
$resolvedPath = (Resolve-Path -LiteralPath $Path).Path

# Fail early if the supplied path is not a folder.
if (-not (Test-Path -LiteralPath $resolvedPath -PathType Container)) {
    throw "Path is not a folder: $resolvedPath"
}

# Build the list of root-level files that should receive SHA-256 sidecars.
# Checksum/hash artifacts are intentionally excluded.
$files = @(
    Get-ChildItem -LiteralPath $resolvedPath -File |
        Where-Object { -not (Test-IsChecksumFile -File $_) } |
        Sort-Object Name
)

Write-Host "SHA-256 SIDECAR GENERATION"
Write-Host "=========================="
Write-Host "Path: $resolvedPath"
Write-Host ""

# Nothing to do is reported clearly rather than treated as an error.
if ($files.Count -eq 0) {
    Write-Warning "No non-checksum files were found at the folder root."
    return
}

# Counters used for the final summary.
$created = 0
$updated = 0
$current = 0
$notOverwritten = 0

foreach ($file in $files) {
    # Calculate the SHA-256 hash from the file's byte content.
    # The filename itself does not affect this hash.
    $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToUpperInvariant()

    # Pair each file with a same-name .sha256 sidecar.
    # Example: sample.bin -> sample.bin.sha256
    $sidecarPath = "$($file.FullName).sha256"
    $sidecarName = Split-Path -Leaf $sidecarPath

    # Store the hash plus filename for human readability.
    # Two spaces are conventional between the hash and filename.
    $line = "{0}  {1}" -f $hash, $file.Name

    Write-Host "File:     $($file.Name)"
    Write-Host "SHA-256:  $hash"
    Write-Host "Sidecar:  $sidecarName"

    if (Test-Path -LiteralPath $sidecarPath -PathType Leaf) {
        # A sidecar already exists. Read its stored hash so we can avoid
        # overwriting trusted verification data accidentally.
        $existingHash = Get-Sha256FromSidecar -SidecarPath $sidecarPath

        if (-not $Force) {
            if ($existingHash -eq $hash) {
                Write-Host "Status:   CURRENT"
                $current++
            }
            else {
                Write-Warning "Status:   NOT OVERWRITTEN - existing sidecar differs or is invalid. Use -Force to regenerate it."
                $notOverwritten++
            }

            Write-Host ""
            continue
        }

        # -Force was explicitly supplied, so replace the existing sidecar.
        Set-Content -LiteralPath $sidecarPath -Value $line -Encoding Ascii
        Write-Host "Status:   UPDATED"
        $updated++
    }
    else {
        # No sidecar exists yet, so create one.
        Set-Content -LiteralPath $sidecarPath -Value $line -Encoding Ascii
        Write-Host "Status:   CREATED"
        $created++
    }

    Write-Host ""
}

# Provide a compact final result that makes success or incomplete work obvious.
Write-Host "SUMMARY"
Write-Host "-------"
Write-Host ("Data files:                {0}" -f $files.Count)
Write-Host ("Sidecars created:          {0}" -f $created)
Write-Host ("Sidecars updated:          {0}" -f $updated)
Write-Host ("Sidecars already current:  {0}" -f $current)
Write-Host ("Sidecars not overwritten:  {0}" -f $notOverwritten)
Write-Host ""

if ($notOverwritten -eq 0) {
    Write-Host "Success! Every data file has a current SHA-256 sidecar." -ForegroundColor Green
}
else {
    Write-Warning "Not all SHA-256 sidecars are current. Review the warnings above, then use -Force only if regeneration is intentional."
}
```

---

# Script 2: Validate file/checksum pairs

## Suggested filename

```text
Test-FolderSha256.ps1
```

## Goal

Inspect the root of a folder and reconcile every data file with its expected `.sha256` sidecar.

The naming convention is:

```text
<filename>        <-> <filename>.sha256
```

The validator recalculates the file's SHA-256 hash directly from its current bytes and compares it with the expected hash stored in the corresponding sidecar.

The validator does **not** modify anything.

## Conditions reported

The script explicitly distinguishes these states:

- **Complete success** — every data file has a `.sha256` sidecar and every SHA-256 hash matches.
- **Partial match** — at least one pair matches, but one or more problems also exist.
- **Checksum mismatch** — a file and sidecar both exist, but the calculated SHA-256 hash differs from the stored value.
- **File without checksum** — a data file exists, but `<filename>.sha256` does not.
- **Checksum without file** — a `.sha256` sidecar exists, but the corresponding data file does not.
- **Invalid checksum file** — a `.sha256` sidecar does not contain exactly one usable SHA-256 hash line.
- **No successful matches** — files and/or sidecars are present, but no pair validates successfully.
- **Nothing to validate** — neither data files nor `.sha256` sidecars are present at the folder root.

Other checksum formats such as `.sha512`, `.sha1`, or `.md5` are excluded from the data-file set and reported as ignored. This validator is intentionally specific to SHA-256 `.sha256` sidecars.

## CLI syntax

From the target folder:

```powershell
& "C:\Tools\Test-FolderSha256.ps1"
```

Or specify the folder explicitly:

```powershell
& "C:\Tools\Test-FolderSha256.ps1" -Path "C:\Temp\Checksum-Test"
```

## Complete-success example

```text
SUMMARY
-------
Data files:                2
SHA-256 sidecars:          2
Matched pairs:             2
Mismatched pairs:          0
Files without checksum:    0
Checksums without file:    0
Invalid checksum files:    0
Other checksum files:      0 (ignored)

Success! All files have SHA-256 sidecars and every checksum matches.
```

## Partial-match example

If one pair matches and another does not:

```text
Matched pairs:             1
Mismatched pairs:          1
```

The script ends with a `PARTIAL MATCH` warning.

## Missing-checksum example

If `sample-a.bin` exists but `sample-a.bin.sha256` does not:

```text
Status:   FILE WITHOUT CHECKSUM
```

## Missing-file example

If `sample-a.bin.sha256` exists but `sample-a.bin` does not:

```text
Status:   CHECKSUM WITHOUT FILE
```

## No-match example

If no pair validates successfully:

```text
FAILURE: No file/checksum pairs match successfully.
```

## Full source code

```powershell
<#
.SYNOPSIS
Validates root-level files against same-name SHA-256 sidecar files.

.DESCRIPTION
For each ordinary file in the target folder, this script expects a companion:

    <filename>.sha256

It recalculates the file's SHA-256 hash and compares that value with the
expected hash stored in the sidecar.

The script is read-only. It does not modify data files or checksum files.

Terminology:
- SHA-256 = the hashing algorithm.
- Hash = the 64-hex-character value produced by SHA-256.
- Checksum/sidecar file = the .sha256 file that stores the expected hash.

The script does not recurse into subfolders.
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$Path = "."
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Test-IsChecksumFile {
    <#
    .SYNOPSIS
    Returns $true when a file appears to be a checksum/hash artifact.

    .DESCRIPTION
    The validator is specifically designed for .sha256 sidecars, but other
    common checksum artifacts are excluded from the data-file set so they are
    not mistaken for ordinary files that themselves require sidecars.
    #>
    param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo]$File
    )

    $checksumExtensions = @(
        ".sha256",
        ".sha512",
        ".sha384",
        ".sha224",
        ".sha1",
        ".md5",
        ".checksum",
        ".checksums"
    )

    if ($checksumExtensions -contains $File.Extension.ToLowerInvariant()) {
        return $true
    }

    return $File.Name -match "^(sha(1|224|256|384|512)sums?|md5sums?|checksums?)(\.txt)?$"
}

function Read-Sha256Sidecar {
    <#
    .SYNOPSIS
    Reads the expected SHA-256 hash from a sidecar file.

    .DESCRIPTION
    Accepts exactly one usable line containing either:

        <64-hex-character-hash>

    or:

        <64-hex-character-hash>  <filename>

    Hash text may use uppercase, lowercase, or mixed-case hexadecimal.
    The returned value is normalized to uppercase for consistent display.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SidecarPath
    )

    # Ignore blank lines and comments so the parser remains simple but practical.
    $lines = @(
        Get-Content -LiteralPath $SidecarPath |
            Where-Object {
                $_.Trim().Length -gt 0 -and
                -not $_.TrimStart().StartsWith("#")
            }
    )

    # Treat zero usable lines or multiple usable lines as invalid.
    if ($lines.Count -ne 1) {
        return $null
    }

    # Extract the SHA-256 value.
    if ($lines[0] -match "^\s*([0-9A-Fa-f]{64})(?:\s+.*)?$") {
        return $Matches[1].ToUpperInvariant()
    }

    return $null
}

# Resolve the target folder once so later path comparisons are consistent.
$resolvedPath = (Resolve-Path -LiteralPath $Path).Path

# Fail early when the target is not a directory.
if (-not (Test-Path -LiteralPath $resolvedPath -PathType Container)) {
    throw "Path is not a folder: $resolvedPath"
}

# Inventory all root-level files first.
$allFiles = @(Get-ChildItem -LiteralPath $resolvedPath -File | Sort-Object Name)

# Ordinary files are the files we expect to validate.
$dataFiles = @(
    $allFiles |
        Where-Object { -not (Test-IsChecksumFile -File $_) }
)

# .sha256 files are the sidecars this validator actively processes.
$sha256Files = @(
    $allFiles |
        Where-Object { $_.Extension -ieq ".sha256" }
)

# Other checksum/hash artifacts are intentionally ignored by SHA-256 validation,
# but counted so the user can see that they were present.
$otherChecksumFiles = @(
    $allFiles |
        Where-Object {
            (Test-IsChecksumFile -File $_) -and
            $_.Extension -ine ".sha256"
        }
)

Write-Host "SHA-256 VALIDATION"
Write-Host "=================="
Write-Host "Path: $resolvedPath"
Write-Host ""

# A folder with no data files and no .sha256 sidecars has nothing to validate.
if ($dataFiles.Count -eq 0 -and $sha256Files.Count -eq 0) {
    Write-Warning "No data files or .sha256 sidecars were found at the folder root."
    return
}

# Counters used to describe every relevant validation outcome.
$matched = 0
$mismatched = 0
$filesWithoutChecksum = 0
$invalidChecksums = 0
$checksumsWithoutFile = 0

# Keep track of .sha256 files that have already been paired with data files.
# This lets us later identify orphaned sidecars.
$pairedSidecarPaths = @{}

foreach ($file in $dataFiles) {
    # The expected pairing convention is:
    #   sample.bin <-> sample.bin.sha256
    $sidecarPath = "$($file.FullName).sha256"
    $sidecarName = Split-Path -Leaf $sidecarPath

    Write-Host "File:     $($file.Name)"

    if (-not (Test-Path -LiteralPath $sidecarPath -PathType Leaf)) {
        # The data file exists but its expected sidecar does not.
        Write-Host "Sidecar:  MISSING"
        Write-Host "Status:   FILE WITHOUT CHECKSUM" -ForegroundColor Yellow
        Write-Host ""
        $filesWithoutChecksum++
        continue
    }

    # Record that this sidecar belongs to an existing data file.
    $pairedSidecarPaths[$sidecarPath.ToLowerInvariant()] = $true

    # Parse the expected SHA-256 value from the sidecar.
    $expectedHash = Read-Sha256Sidecar -SidecarPath $sidecarPath

    if ($null -eq $expectedHash) {
        # The sidecar exists, but its contents do not contain one valid SHA-256 hash.
        Write-Host "Sidecar:  $sidecarName"
        Write-Host "Status:   INVALID CHECKSUM FILE" -ForegroundColor Red
        Write-Host ""
        $invalidChecksums++
        continue
    }

    # Recalculate SHA-256 directly from the current file bytes.
    # The filename does not affect the computed hash.
    $actualHash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToUpperInvariant()

    Write-Host "Sidecar:  $sidecarName"
    Write-Host "Expected: $expectedHash"
    Write-Host "Actual:   $actualHash"

    # Hexadecimal hash text is case-insensitive. Both values have already been
    # normalized to uppercase, making display and comparison consistent.
    if ($actualHash -eq $expectedHash) {
        Write-Host "Status:   MATCH" -ForegroundColor Green
        $matched++
    }
    else {
        Write-Host "Status:   MISMATCH" -ForegroundColor Red
        $mismatched++
    }

    Write-Host ""
}

# Any .sha256 sidecar not paired above has no corresponding data file.
foreach ($sidecar in $sha256Files) {
    if (-not $pairedSidecarPaths.ContainsKey($sidecar.FullName.ToLowerInvariant())) {
        $expectedFileName = $sidecar.Name.Substring(0, $sidecar.Name.Length - ".sha256".Length)

        Write-Host "Sidecar:  $($sidecar.Name)"
        Write-Host "File:     $expectedFileName"
        Write-Host "Status:   CHECKSUM WITHOUT FILE" -ForegroundColor Yellow
        Write-Host ""

        $checksumsWithoutFile++
    }
}

# Summarize the entire folder rather than forcing the user to infer overall
# status from individual file results.
Write-Host "SUMMARY"
Write-Host "-------"
Write-Host ("Data files:                {0}" -f $dataFiles.Count)
Write-Host ("SHA-256 sidecars:          {0}" -f $sha256Files.Count)
Write-Host ("Matched pairs:             {0}" -f $matched)
Write-Host ("Mismatched pairs:          {0}" -f $mismatched)
Write-Host ("Files without checksum:    {0}" -f $filesWithoutChecksum)
Write-Host ("Checksums without file:    {0}" -f $checksumsWithoutFile)
Write-Host ("Invalid checksum files:    {0}" -f $invalidChecksums)
Write-Host ("Other checksum files:      {0} (ignored)" -f $otherChecksumFiles.Count)
Write-Host ""

# Combine all validation problems into one count for final-state reporting.
$issueCount =
    $mismatched +
    $filesWithoutChecksum +
    $checksumsWithoutFile +
    $invalidChecksums

if (
    $dataFiles.Count -gt 0 -and
    $matched -eq $dataFiles.Count -and
    $issueCount -eq 0
) {
    # Best-case result: every data file has a valid matching .sha256 sidecar,
    # and no orphaned or invalid sidecars were found.
    Write-Host "Success! All files have SHA-256 sidecars and every checksum matches." -ForegroundColor Green
}
elseif ($matched -gt 0) {
    # At least one pair is valid, but the folder is not fully consistent.
    Write-Warning ("PARTIAL MATCH: {0} file/checksum pair(s) match, but one or more issues were found." -f $matched)
}
else {
    # Files and/or sidecars exist, but not one pair validated successfully.
    Write-Host "FAILURE: No file/checksum pairs match successfully." -ForegroundColor Red
}
```

---

# Creating the actual `.ps1` files

Save each source-code section using its suggested filename:

```text
New-FolderSha256.ps1
Test-FolderSha256.ps1
```

A practical layout is to keep the scripts in a reusable tools folder rather than inside the folder being checksummed:

```text
C:\Tools\
├── New-FolderSha256.ps1
└── Test-FolderSha256.ps1
```

Then point them at any target folder:

```powershell
& "C:\Tools\New-FolderSha256.ps1" -Path "C:\Temp\Checksum-Test"
& "C:\Tools\Test-FolderSha256.ps1" -Path "C:\Temp\Checksum-Test"
```

Keeping the scripts outside the target folder also means the scripts themselves are not accidentally included among the files being checksummed.

If PowerShell execution policy prevents a `.ps1` file from running, use the execution-policy approach appropriate for the computer's security policy rather than weakening policy globally just for these scripts.

---

# Recommended workflow

For a folder whose contents are intentionally being finalized:

```powershell
& "C:\Tools\New-FolderSha256.ps1" -Path "C:\Temp\Checksum-Test"
```

Later, whenever the folder needs to be verified:

```powershell
& "C:\Tools\Test-FolderSha256.ps1" -Path "C:\Temp\Checksum-Test"
```

The ideal final message is:

```text
Success! All files have SHA-256 sidecars and every checksum matches.
```

Do not run the generator with `-Force` immediately before verification unless regeneration is actually intended. Verification is meaningful only when the stored hashes represent an earlier trusted state.

---

# Summary

| Script | Purpose | Writes files? | Root-level only? |
|---|---|---:|---:|
| `New-FolderSha256.ps1` | Generate one `.sha256` sidecar per non-checksum file | Yes | Yes |
| `Test-FolderSha256.ps1` | Recalculate and compare every file/checksum pair | No | Yes |

The scripts use **SHA-256** consistently as the algorithm name, refer to the computed value as a **hash**, and use **checksum file** / **`.sha256` sidecar** for the stored verification file.

---

# Potential future enhancements

The current scripts deliberately stay focused and predictable. Reasonable future enhancements include:

- optional `-Recurse` support;
- filename/wildcard exclusions;
- machine-readable PowerShell objects in addition to console output;
- explicit process exit codes for CI/CD;
- selectable hash algorithms such as SHA-512;
- a single `SHA256SUMS` manifest instead of one sidecar per file;
- a `-Quiet` or reporting-detail switch;
- validation of the optional filename text stored inside each sidecar;
- signed manifests when authenticity, rather than only integrity, matters.

For a simple folder-level integrity workflow, this two-script design is a strong baseline without adding unnecessary complexity.

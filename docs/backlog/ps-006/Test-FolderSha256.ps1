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

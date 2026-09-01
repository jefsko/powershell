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

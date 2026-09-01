# Addendum: Compare Files Against a SHA-256 Sidecar

## Goal

Create a PowerShell script that verifies one or more files in the current folder against the SHA-256 value stored in a single `*.sha256` sidecar file.

The script answers three questions:

1. Do all files match the expected SHA-256, do only some match, or do none match?
2. Do the files have the same SHA-256 as one another?
3. If a file does not match, what SHA-256 corresponds to that file's actual current contents?

The script is designed to work either by direct copy/paste into Windows PowerShell or by saving and running it as a `.ps1` file.

**Suggested filename:**

```text
Compare-SHA256.ps1
```

## Brief Summary

The script:

- requires exactly one `*.sha256` file in the current folder;
- extracts the first valid 64-character hexadecimal SHA-256 value from that sidecar;
- hashes every other regular file in the folder;
- excludes the running `.ps1` file itself when applicable;
- reports the SHA-256 and match state for each file;
- summarizes all/some/none match status;
- reports whether multiple files share the same SHA-256;
- prints a clear `SUCCESS!` result when every file matches;
- displays the actual SHA-256 for every mismatching file;
- optionally provides additional diagnostic detail.

## Terminology

**SHA-256** is the cryptographic hash algorithm used by the script.

A **hash** is the fixed-length value calculated from a file's contents. In this context, **SHA-256 hash** is the most precise term. **Checksum** is also commonly used informally when discussing integrity verification.

A **sidecar file** is a separate companion file that stores metadata or verification information. Here, the `*.sha256` file is a hash/checksum sidecar.

Recommended capitalization:

- `SHA-256` when naming the algorithm
- `.sha256` when referring to the filename extension

## Important Behavior

### Filenames do not affect SHA-256

SHA-256 is calculated from file contents, not from the filename.

For example:

```text
package-original.zip
package-copy.zip
```

If both contain the same bytes, both produce the same SHA-256.

Renaming a file without changing its contents does not change its SHA-256.

### Sidecar filename association is intentionally ignored

The script extracts the first valid 64-character hexadecimal SHA-256 value from the sidecar.

Supported examples include:

```text
0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF
```

and:

```text
0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF  package.zip
```

The filename recorded after the hash is not used to decide which files are checked. This is intentional because the files being compared may have different names.

### Current-folder behavior

The script operates on the current PowerShell working directory.

It expects:

- exactly one `*.sha256` file;
- one or more other files to verify.

It does not recurse into subdirectories.

When executed from a `.ps1` file, the script automatically excludes itself from the files being hashed.

## Optional Detail Flag

The script contains one simple output flag:

```powershell
$ShowDetails = $false
```

This is the default and recommended normal mode.

Normal mode shows:

- each file;
- whether it matches;
- its calculated SHA-256;
- the overall summary;
- a clear success or failure state;
- the actual SHA-256 for mismatching files.

To display additional diagnostic information, change it to:

```powershell
$ShowDetails = $true
```

Detailed mode additionally shows:

- current folder;
- SHA-256 sidecar filename;
- number of data files;
- number of unique hashes;
- expected SHA-256;
- files grouped by calculated SHA-256.

## Generic Example Folder

```text
C:\Test\HashVerification\
    package-a.zip
    package-b.zip
    package-c.zip
    package.sha256
```

Example sidecar content:

```text
0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF
```

The value above is generic test data for documentation only.

## Example Output: All Files Match

```text
File          Match SHA256
----          ----- ------
package-a.zip True  0123456789ABCDEF...
package-b.zip True  0123456789ABCDEF...
package-c.zip True  0123456789ABCDEF...

SUMMARY
=======

Files checked : 3
SHA matches   : 3
SHA mismatches: 0
SHA result    : ALL files match the .sha256 file.
File identity : ALL files are byte-for-byte identical.

SUCCESS!
All files match the expected SHA-256.
```

## Example Output: Some Files Match

```text
File          Match SHA256
----          ----- ------
package-a.zip True  0123456789ABCDEF...
package-b.zip False FEDCBA9876543210...
package-c.zip True  0123456789ABCDEF...

SUMMARY
=======

Files checked : 3
SHA matches   : 2
SHA mismatches: 1
SHA result    : SOME files match the .sha256 file.
File identity : FILES ARE NOT all byte-for-byte identical.

VERIFICATION FAILED
One or more files do not match the expected SHA-256.

CORRECT SHA-256 FOR MISMATCHING FILES
=====================================

File          SHA256
----          ------
package-b.zip FEDCBA9876543210...
```

## Example Output: One Data File

With only one data file, the script does not claim that a peer comparison occurred:

```text
File identity : Only one data file; no peer file to compare.
```

## Copy/Paste Use from the PowerShell CLI

Change to the folder containing the data files and the single `*.sha256` sidecar:

```powershell
Set-Location -LiteralPath 'C:\Test\HashVerification'
```

Then paste the complete source code from the **Full Source Code** section into the PowerShell CLI.

The outer script block:

```powershell
& {
    # ...
}
```

helps the entire pasted block parse and execute as one unit. It is also harmless when the same source is saved as a `.ps1` file.

## Create an Actual `.ps1` File

### Option 1: Save from an editor

1. Open Visual Studio Code, Notepad, or another plain-text editor.
2. Copy the complete source code from this addendum.
3. Save the file as:

```text
Compare-SHA256.ps1
```

### Option 2: Create the file from PowerShell

A PowerShell here-string can be used:

```powershell
@'
<PASTE THE FULL SCRIPT SOURCE HERE>
'@ | Set-Content -LiteralPath '.\Compare-SHA256.ps1' -Encoding UTF8
```

Replace the placeholder with the complete source from this addendum.

## Run the Saved Script

If the script is stored in the folder being checked:

```powershell
Set-Location -LiteralPath 'C:\Test\HashVerification'
.\Compare-SHA256.ps1
```

The script excludes itself automatically.

The script can also be stored elsewhere:

```powershell
Set-Location -LiteralPath 'C:\Test\HashVerification'
& 'C:\Tools\Compare-SHA256.ps1'
```

The current working directory remains the folder being checked.

If Windows PowerShell execution policy blocks the script, a one-time invocation can be made with:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File '.\Compare-SHA256.ps1'
```

Use execution-policy bypass only for source that has been reviewed and is trusted.

## Full Source Code

```powershell
& {
    # -------------------------------------------------------------------------
    # OPTIONS
    # -------------------------------------------------------------------------

    # $false = Normal mode (recommended/default)
    #          Shows:
    #            - Each file and its calculated SHA-256
    #            - Whether each file matches the expected SHA-256
    #            - Overall summary
    #            - A clear SUCCESS message when every file matches
    #            - Correct SHA-256 for any mismatching files
    #
    # $true  = Detailed mode
    #          Shows everything above, plus:
    #            - Current folder
    #            - .sha256 filename
    #            - Expected SHA-256
    #            - Number of unique hashes
    #            - Files grouped by identical SHA-256 values
    #
    # Change only this line when additional diagnostic detail is wanted.
    $ShowDetails = $false

    # -------------------------------------------------------------------------
    # FIND AND READ THE .SHA256 FILE
    # -------------------------------------------------------------------------

    # Exactly one .sha256 file is expected in the current folder.
    $shaFiles = @(Get-ChildItem -File -Filter *.sha256)

    if ($shaFiles.Count -ne 1) {
        throw "Expected exactly one .sha256 file, but found $($shaFiles.Count)."
    }

    $shaFile = $shaFiles[0]
    $shaText = Get-Content -LiteralPath $shaFile.FullName -Raw

    # Extract the first 64-character hexadecimal value.
    #
    # Supports common formats such as:
    #   BDA6E280...
    #
    # or:
    #   BDA6E280...  filename.zip
    #
    # The filename recorded in a .sha256 file is not used for comparison.
    # SHA-256 is calculated from file contents, not the filename.
    if ($shaText -notmatch '(?i)\b[A-F0-9]{64}\b') {
        throw "No valid SHA-256 hash was found in '$($shaFile.Name)'."
    }

    $expectedHash = $Matches[0].ToUpperInvariant()

    # -------------------------------------------------------------------------
    # FIND FILES TO CHECK
    # -------------------------------------------------------------------------

    # If this code is being run from a .ps1 file, identify that script so it
    # can be excluded from the data files. When pasted directly into the CLI,
    # $PSCommandPath is empty and there is no script file to exclude.
    $runningScriptPath = $null

    if ($PSCommandPath) {
        $runningScriptPath = [System.IO.Path]::GetFullPath($PSCommandPath)
    }

    # Check every regular file in the current folder except:
    #   - .sha256 files
    #   - this script itself, when running from a .ps1 file
    $files = @(
        Get-ChildItem -File |
        Where-Object {
            $_.Extension -ne '.sha256' -and
            (-not $runningScriptPath -or $_.FullName -ne $runningScriptPath)
        }
    )

    if ($files.Count -eq 0) {
        throw "No files were found to compare."
    }

    # -------------------------------------------------------------------------
    # CALCULATE SHA-256 FOR EACH FILE
    # -------------------------------------------------------------------------

    # The outer @() guarantees that $results is always an array, even when
    # only one file exists. This makes .Count reliable in PowerShell 5.1.
    $results = @(
        foreach ($file in $files) {
            $actualHash = (
                Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256
            ).Hash.ToUpperInvariant()

            [PSCustomObject]@{
                File       = $file.Name
                MatchesSHA = ($actualHash -eq $expectedHash)
                SHA256     = $actualHash
            }
        }
    )

    # Calculate counts and identify distinct file contents.
    # Files with the same SHA-256 are treated as byte-for-byte identical
    # for this verification purpose, regardless of their filenames.
    $matchCount = @(
        $results | Where-Object { $_.MatchesSHA }
    ).Count

    $nonMatchCount = @(
        $results | Where-Object { -not $_.MatchesSHA }
    ).Count

    $uniqueHashes = @(
        $results.SHA256 | Sort-Object -Unique
    )

    $mismatches = @(
        $results | Where-Object { -not $_.MatchesSHA }
    )

    # -------------------------------------------------------------------------
    # OPTIONAL DETAILED OUTPUT
    # -------------------------------------------------------------------------

    if ($ShowDetails) {
        Write-Host ""
        Write-Host "DETAILS"
        Write-Host "======="
        Write-Host ""
        Write-Host "Folder        : $((Get-Location).Path)"
        Write-Host "SHA file      : $($shaFile.Name)"
        Write-Host "Data files    : $($files.Count)"
        Write-Host "Unique hashes : $($uniqueHashes.Count)"
        Write-Host "Expected SHA  : $expectedHash"

        Write-Host ""
        Write-Host "HASH GROUPS"
        Write-Host "==========="
        Write-Host ""

        $groups = @($results | Group-Object SHA256)

        foreach ($group in $groups) {
            Write-Host "SHA-256: $($group.Name)"

            foreach ($item in $group.Group) {
                Write-Host "  $($item.File)"
            }
        }
    }

    # -------------------------------------------------------------------------
    # PER-FILE RESULTS - ALWAYS SHOWN
    # -------------------------------------------------------------------------

    Write-Host ""

    # Format-Table normally inserts extra leading/trailing blank lines.
    # Converting it to a string and trimming it keeps the console output compact.
    $fileTable = (
        $results |
        Select-Object `
            File,
            @{Name='Match'; Expression={$_.MatchesSHA}},
            SHA256 |
        Format-Table -AutoSize |
        Out-String -Width 4096
    ).Trim()

    Write-Host $fileTable

    # -------------------------------------------------------------------------
    # BUILD SUMMARY
    # -------------------------------------------------------------------------

    # Determine whether all, some, or none of the files match the SHA value
    # stored in the .sha256 file.
    $shaResult = "SOME files match the .sha256 file."

    if ($matchCount -eq $results.Count) {
        $shaResult = "ALL files match the .sha256 file."
    }

    if ($matchCount -eq 0) {
        $shaResult = "NONE of the files match the .sha256 file."
    }

    # Determine whether the files are identical to one another.
    # With only one data file, there is no peer file to compare against.
    if ($results.Count -eq 1) {
        $identityResult = "Only one data file; no peer file to compare."
    }
    elseif ($uniqueHashes.Count -eq 1) {
        $identityResult = "ALL files are byte-for-byte identical."
    }
    else {
        $identityResult = "FILES ARE NOT all byte-for-byte identical."
    }

    # -------------------------------------------------------------------------
    # SUMMARY - ALWAYS SHOWN
    # -------------------------------------------------------------------------

    Write-Host ""
    Write-Host "SUMMARY"
    Write-Host "======="
    Write-Host ""
    Write-Host "Files checked : $($results.Count)"
    Write-Host "SHA matches   : $matchCount"
    Write-Host "SHA mismatches: $nonMatchCount"
    Write-Host "SHA result    : $shaResult"
    Write-Host "File identity : $identityResult"

    # -------------------------------------------------------------------------
    # FINAL STATUS - ALWAYS SHOWN
    # -------------------------------------------------------------------------

    Write-Host ""

    if ($matchCount -eq $results.Count) {
        Write-Host "SUCCESS!" -ForegroundColor Green
        Write-Host "All files match the expected SHA-256."
    }
    else {
        Write-Host "VERIFICATION FAILED" -ForegroundColor Red
        Write-Host "One or more files do not match the expected SHA-256."
    }

    # -------------------------------------------------------------------------
    # MISMATCH INFORMATION
    # -------------------------------------------------------------------------

    # If a file does not match the expected SHA-256, show the SHA-256 that
    # actually corresponds to that file's current contents.
    if ($mismatches.Count -gt 0) {
        Write-Host ""
        Write-Host "CORRECT SHA-256 FOR MISMATCHING FILES"
        Write-Host "====================================="
        Write-Host ""

        $mismatchTable = (
            $mismatches |
            Select-Object File, SHA256 |
            Format-Table -AutoSize |
            Out-String -Width 4096
        ).Trim()

        Write-Host $mismatchTable
    }
}
```

## Logic and Flow

The script follows this sequence:

1. Define the optional `$ShowDetails` flag.
2. Find `*.sha256` files in the current folder.
3. Require exactly one sidecar.
4. Read the sidecar.
5. Extract the first valid SHA-256 value.
6. Identify data files to check.
7. Exclude `.sha256` files.
8. Exclude the running `.ps1` file when applicable.
9. Calculate SHA-256 for each data file with `Get-FileHash`.
10. Record filename, match state, and calculated SHA-256.
11. Count matches and mismatches.
12. Count unique calculated hashes.
13. Optionally display detailed diagnostic information.
14. Always display per-file results.
15. Report all/some/none match status.
16. Report whether multiple files share the same SHA-256.
17. Display a clear success or failure message.
18. For mismatches, display each file's actual SHA-256.

## Requirements and Assumptions

The current script assumes:

- Windows PowerShell 5.1-compatible behavior;
- `Get-FileHash` is available;
- SHA-256 is the desired algorithm;
- exactly one `*.sha256` file is present;
- the first valid 64-character hexadecimal value in the sidecar is authoritative;
- all non-`.sha256` regular files in the current folder are intended to be checked, except the running script itself.

## Comments, Concerns, and Suggestions

### Same SHA-256 versus literal byte comparison

The current script uses matching SHA-256 values to determine that multiple files have the same contents for verification purposes.

For normal file-integrity work, matching SHA-256 values are extremely strong evidence that the files are identical. However, comparing cryptographic hashes is not literally the same operation as performing a byte-by-byte binary comparison.

If absolute byte-level verification is desired, a future version could optionally perform a binary comparison after hashes match.

### Multiple hashes in one sidecar

The current version intentionally uses only the first valid SHA-256 value.

A future version could support checksum manifest files containing multiple filename/hash pairs.

### Formal parameters

The current `$ShowDetails` variable is intentionally simple and copy/paste-friendly.

If the script becomes a reusable repository utility, PowerShell parameters would improve usability. For example:

```powershell
.\Compare-SHA256.ps1 -Path 'C:\Test\HashVerification' -ShowDetails
```

Potential parameters include:

- `-Path`
- `-ShowDetails`
- `-Recurse`
- `-Sidecar`
- `-Algorithm`

### Built-in PowerShell verbose support

A future version could use PowerShell's formal `-Verbose` support and `Write-Verbose` instead of the custom `$ShowDetails` flag.

The custom flag remains easier to understand and use in direct copy/paste scenarios.

### Exit codes

If the script is later used in CI/CD, batch processing, or automation, explicit exit codes would be useful.

For example:

```text
0 = all files match
1 = one or more files do not match
2 = invalid input or sidecar configuration
```

## Potential Enhancements

Possible future enhancements include:

- formal `param()` support;
- a `-Path` parameter;
- built-in `-Verbose` behavior;
- explicit process exit codes;
- recursive checking;
- support for multiple checksum algorithms;
- support for multi-line checksum manifests;
- optional strict byte-by-byte verification;
- colored per-file match/mismatch output;
- output as PowerShell objects, CSV, or JSON;
- include/exclude filename patterns.

## Recommended Baseline

For the current goal, this is a reasonable baseline because it is:

- compatible with direct PowerShell CLI copy/paste;
- equally usable as a `.ps1` file;
- Windows PowerShell 5.1-friendly;
- reasonably commented;
- explicit about success and failure;
- useful for one or many files;
- unaffected by differing filenames;
- straightforward to understand and maintain.

The enhancements above are worth considering if the script is later promoted from a quick verification utility into a more general repository tool.

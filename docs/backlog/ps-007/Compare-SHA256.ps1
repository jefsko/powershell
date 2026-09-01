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

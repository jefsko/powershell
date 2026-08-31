# Addendum: Building and Verifying GitHub Release Artifacts from Git Tags

This addendum documents a reusable PowerShell workflow for building a
collection release artifact from an immutable Git tag, assembling
explicit GitHub Release assets, generating SHA-256 sidecars, and
verifying the resulting files before and after publication.

The examples use the Microsoft Office Resources v1.0.1 / USPS Label 228
v1.0.0 release as the concrete model, but the approach is intentionally
modular. Paths, tag names, component paths, and filenames should be
parameters rather than hard-coded assumptions in future automation.

> **PowerShell compatibility:** The scripts are written for Windows
> PowerShell 5.1 and are also suitable for copy/paste execution in a
> PowerShell console.
>
> **Important binary-safety rule:** Do **not** extract `.dotx`, `.docx`,
> `.png`, ZIP, or other binary files with `git show ... > file` in
> Windows PowerShell 5.1. Its text redirection can alter binary data.
> The safe pattern used here is `git archive` followed by
> `Expand-Archive`.

## 1. Next: build the v1.0.1 release artifact

A release artifact should be built from the **release tag**, not merely
from the current working tree or current `HEAD`.

For v1.0.1:

``` powershell
# Repository collection tag to package.
$CollectionTag = "v1.0.1"

# Output file lives outside the repository working tree.
$CollectionZip = "..\microsoft-office-resources-v1.0.1.zip"

# Build a ZIP directly from the immutable tagged tree.
git archive `
    --format=zip `
    --prefix=microsoft-office-resources/ `
    -o $CollectionZip `
    $CollectionTag

if ($LASTEXITCODE -ne 0) {
    throw "git archive failed for tag $CollectionTag."
}

Get-Item $CollectionZip
```

The `--prefix` option places all repository files beneath one top-level
directory when the ZIP is extracted.

A useful reproducibility check is to build the same tag a second time
and compare SHA-256 values:

``` powershell
$VerifyZip = "..\microsoft-office-resources-v1.0.1-verify.zip"

git archive `
    --format=zip `
    --prefix=microsoft-office-resources/ `
    -o $VerifyZip `
    $CollectionTag

if ($LASTEXITCODE -ne 0) {
    throw "Verification git archive failed."
}

$First  = (Get-FileHash $CollectionZip -Algorithm SHA256).Hash
$Second = (Get-FileHash $VerifyZip -Algorithm SHA256).Hash

if ($First -ne $Second) {
    throw "Rebuilt collection ZIP does not match the first build."
}

"SUCCESS: Rebuilt collection ZIP is byte-for-byte identical."

Remove-Item $VerifyZip
```

## 2. v1.0.1 GitHub Release

The GitHub Release is associated with the already-created annotated
collection tag:

``` text
v1.0.1
```

Before publishing, verify that the local tag and remote tag resolve to
the intended release commit:

``` powershell
$CollectionTag = "v1.0.1"

git fetch origin --tags

$LocalTarget = git rev-list -n 1 $CollectionTag
$RemoteLine  = git ls-remote --tags origin "refs/tags/$CollectionTag^{}"
$RemoteTarget = ($RemoteLine -split '\s+')[0]

"Local tag target : $LocalTarget"
"Remote tag target: $RemoteTarget"

if (-not $RemoteTarget) {
    throw "Remote annotated tag target was not found."
}

if ($LocalTarget -ne $RemoteTarget) {
    throw "Local and remote tag targets differ."
}

"SUCCESS: Local and remote release tags resolve to the same commit."
```

The release itself is a publication boundary. Build and verify assets
**before** uploading them. After publication, download the uploaded
assets into a separate verification directory and verify them again.

For the v1.0.1 release, GitHub displayed ten downloadable entries:
**eight explicitly uploaded release assets** plus GitHub's automatically
generated **Source code (zip)** and **Source code (tar.gz)** entries.

## 3. Eight explicit release assets

The intended explicit asset set is four payloads and four SHA-256
sidecars:

``` text
microsoft-office-resources-v1.0.1.zip
microsoft-office-resources-v1.0.1.zip.sha256
USPS-Label-228-Template.dotx
USPS-Label-228-Template.dotx.sha256
USPS-Label-228-Logo-Assets.zip
USPS-Label-228-Logo-Assets.zip.sha256
USPS-Label-228-Reference.png
USPS-Label-228-Reference.png.sha256
```

The four payloads serve different purposes:

-   collection ZIP - complete tagged repository snapshot;
-   canonical Word template - ready-to-use component artifact;
-   logo-assets ZIP - convenient bundle of the component's logo assets;
-   reference PNG - ready-to-use/reference image.

Each payload receives its own `.sha256` sidecar.

## 4. Create a clean release-assets directory

Use a dedicated staging directory that is outside the Git working tree.

``` powershell
$ReleaseDir = "C:\git\microsoft-office-resources-v1.0.1-release-assets"

# Refuse to merge a new build into an old staging directory.
if (Test-Path $ReleaseDir) {
    throw "Release directory already exists: $ReleaseDir"
}

New-Item -ItemType Directory -Path $ReleaseDir | Out-Null

"Created release-assets directory:"
$ReleaseDir
```

Failing when the directory already exists is deliberate. It prevents
stale files from a previous attempt from silently becoming part of the
next release.

## 5. Copy the already-verified collection ZIP and SHA

First generate the collection ZIP's SHA-256 sidecar:

``` powershell
$CollectionZip = "..\microsoft-office-resources-v1.0.1.zip"
$CollectionSidecar = "$CollectionZip.sha256"

$Hash = (Get-FileHash $CollectionZip -Algorithm SHA256).Hash.ToLowerInvariant()
$Name = Split-Path $CollectionZip -Leaf

"$Hash  $Name" |
    Set-Content $CollectionSidecar -Encoding ascii

Get-Content $CollectionSidecar
```

Then verify the sidecar before staging it:

``` powershell
$Line = (Get-Content $CollectionSidecar -Raw).Trim()
$Parts = $Line -split '\s+', 2

$Expected = $Parts[0]
$Actual = (Get-FileHash $CollectionZip -Algorithm SHA256).Hash

if ($Expected -ne $Actual) {
    throw "Collection ZIP SHA-256 verification failed."
}

"SUCCESS: Collection ZIP SHA-256 verification passed."
```

Copy both files into the clean release-assets directory:

``` powershell
Copy-Item $CollectionZip $ReleaseDir
Copy-Item $CollectionSidecar $ReleaseDir
```

## 6. Extract the canonical template directly from `v1.0.1`

The canonical template must come from the tagged repository tree, not
from an uncommitted working copy and not from a later commit.

Conceptually, the desired source is:

``` text
v1.0.1:
word/templates/labels/usps-label-228/USPS-Label-228-Template.dotx
```

For binary safety, do not use PowerShell text redirection with
`git show`. Instead, archive the tagged tree and extract from that
archive.

## 7. Safely extract the template from the tag

Create a temporary workspace:

``` powershell
$TempDir = Join-Path $env:TEMP "mor-v1.0.1-release"

if (Test-Path $TempDir) {
    Remove-Item $TempDir -Recurse -Force
}

New-Item -ItemType Directory -Path $TempDir | Out-Null
```

Archive and expand the tagged tree:

``` powershell
git archive `
    --format=zip `
    -o "$TempDir\tag.zip" `
    v1.0.1

if ($LASTEXITCODE -ne 0) {
    throw "git archive failed."
}

Expand-Archive `
    "$TempDir\tag.zip" `
    -DestinationPath "$TempDir\repo"
```

Define the component root and copy the canonical binary artifacts:

``` powershell
$Component = "$TempDir\repo\word\templates\labels\usps-label-228"

Copy-Item `
    "$Component\USPS-Label-228-Template.dotx" `
    "$ReleaseDir\USPS-Label-228-Template.dotx"

Copy-Item `
    "$Component\reference\USPS-Label-228-Reference.png" `
    "$ReleaseDir\USPS-Label-228-Reference.png"
```

Because both files came from the expanded tag archive, they are exact
tagged bytes.

## 8. Create the logo-assets ZIP

Bundle the tagged logo files into one convenient release payload:

``` powershell
$LogoSource = "$Component\assets\logos"
$LogoZip = "$ReleaseDir\USPS-Label-228-Logo-Assets.zip"

Compress-Archive `
    -Path "$LogoSource\*" `
    -DestinationPath $LogoZip
```

Inspect the ZIP:

``` powershell
Add-Type -AssemblyName System.IO.Compression.FileSystem

$LogoArchive = [System.IO.Compression.ZipFile]::OpenRead($LogoZip)

$LogoArchive.Entries |
    Where-Object { $_.Name -ne "" } |
    Select-Object FullName, Length

$LogoArchive.Dispose()
```

`Compress-Archive` is appropriate for creating the convenience bundle.
Verification should focus on the hashes of the files **inside** the ZIP,
because ZIP container metadata can make independently created ZIP files
differ even when their payloads are identical.

## 9. Generate the three new SHA-256 sidecars

The collection ZIP already has its sidecar. Generate sidecars for the
three additional payloads:

``` powershell
$Files = @(
    "$ReleaseDir\USPS-Label-228-Template.dotx",
    "$ReleaseDir\USPS-Label-228-Logo-Assets.zip",
    "$ReleaseDir\USPS-Label-228-Reference.png"
)

foreach ($File in $Files) {
    $Hash = (Get-FileHash $File -Algorithm SHA256).Hash.ToLowerInvariant()
    $Name = Split-Path $File -Leaf

    "$Hash  $Name" |
        Set-Content "$File.sha256" -Encoding ascii
}
```

The sidecar format is deliberately simple:

``` text
<64-character SHA-256>  <filename>
```

Example verification logic should read the filename from the sidecar
rather than assuming that the sidecar's own filename is authoritative.

## 10. You should now have exactly eight release assets

Inventory the staging directory:

``` powershell
Get-ChildItem $ReleaseDir -File |
    Sort-Object Name |
    Select-Object Name, Length

$Count = (Get-ChildItem $ReleaseDir -File).Count

if ($Count -ne 8) {
    throw "Expected exactly 8 release assets; found $Count."
}

"SUCCESS: Release-assets directory contains exactly 8 files."
```

Expected result:

``` text
microsoft-office-resources-v1.0.1.zip
microsoft-office-resources-v1.0.1.zip.sha256
USPS-Label-228-Logo-Assets.zip
USPS-Label-228-Logo-Assets.zip.sha256
USPS-Label-228-Reference.png
USPS-Label-228-Reference.png.sha256
USPS-Label-228-Template.dotx
USPS-Label-228-Template.dotx.sha256
```

## Verification: all four sidecars

Verify every staged payload against its sidecar:

``` powershell
$Sidecars = Get-ChildItem $ReleaseDir -Filter "*.sha256"

$Results = foreach ($Sidecar in $Sidecars) {
    $Line = (Get-Content $Sidecar.FullName -Raw).Trim()
    $Parts = $Line -split '\s+', 2

    if ($Parts.Count -ne 2) {
        throw "Invalid sidecar format: $($Sidecar.Name)"
    }

    $Expected   = $Parts[0]
    $TargetName = $Parts[1].Trim()
    $TargetPath = Join-Path $ReleaseDir $TargetName

    if (-not (Test-Path $TargetPath)) {
        throw "Target file not found for $($Sidecar.Name): $TargetName"
    }

    $Actual = (Get-FileHash $TargetPath -Algorithm SHA256).Hash

    [PSCustomObject]@{
        File  = $TargetName
        Match = ($Expected -eq $Actual)
    }
}

$Results | Format-Table -AutoSize

if ($Results.Count -ne 4) {
    throw "Expected 4 SHA-256 sidecars; found $($Results.Count)."
}

if ($Results.Match -contains $false) {
    throw "One or more release-asset SHA-256 checks failed."
}

"SUCCESS: All release-asset SHA-256 checks passed."
```

PowerShell string comparison is case-insensitive by default, so
lowercase sidecar hashes compare correctly with the uppercase form
returned by `Get-FileHash`.

## Verification: direct tagged artifacts

For files copied directly from the tag, compare the release copy against
the extracted tagged source:

``` powershell
$TagAssets = @(
    @{
        Release = "$ReleaseDir\USPS-Label-228-Template.dotx"
        Tagged  = "$Component\USPS-Label-228-Template.dotx"
    },
    @{
        Release = "$ReleaseDir\USPS-Label-228-Reference.png"
        Tagged  = "$Component\reference\USPS-Label-228-Reference.png"
    }
)

foreach ($Asset in $TagAssets) {
    $ReleaseHash = (Get-FileHash $Asset.Release -Algorithm SHA256).Hash
    $TaggedHash  = (Get-FileHash $Asset.Tagged -Algorithm SHA256).Hash

    [PSCustomObject]@{
        File   = Split-Path $Asset.Release -Leaf
        Match  = ($ReleaseHash -eq $TaggedHash)
        SHA256 = $ReleaseHash
    }
}
```

Every `Match` value must be `True`.

## Verification: files inside the logo-assets ZIP

Extract the release ZIP into a separate temporary directory and compare
each source logo to its packaged counterpart:

``` powershell
$LogoVerifyDir = Join-Path $TempDir "logo-verify"

if (Test-Path $LogoVerifyDir) {
    Remove-Item $LogoVerifyDir -Recurse -Force
}

Expand-Archive `
    "$ReleaseDir\USPS-Label-228-Logo-Assets.zip" `
    -DestinationPath $LogoVerifyDir

$SourceLogos = Get-ChildItem "$Component\assets\logos" -File

$LogoResults = foreach ($Source in $SourceLogos) {
    $Extracted = Join-Path $LogoVerifyDir $Source.Name

    if (-not (Test-Path $Extracted)) {
        throw "Logo missing from ZIP: $($Source.Name)"
    }

    [PSCustomObject]@{
        File  = $Source.Name
        Match = (
            (Get-FileHash $Source.FullName -Algorithm SHA256).Hash -eq
            (Get-FileHash $Extracted -Algorithm SHA256).Hash
        )
    }
}

$LogoResults | Format-Table -AutoSize

if ($LogoResults.Match -contains $false) {
    throw "One or more logo files differ from the tagged source."
}

"SUCCESS: Every logo in the release ZIP matches the tagged source."
```

For stricter verification, also confirm that the number of extracted
files equals the number of tagged source files so that unexpected extra
files cannot go unnoticed.

## Post-publication verification

After publishing the GitHub Release, download the **eight explicit
uploaded assets** into a new, empty directory. Do not verify the
original staging files and call that post-publication verification; the
point is to test what GitHub actually served back.

``` powershell
$VerifyDir = "C:\git\microsoft-office-resources-v1.0.1-github-verification"

$Sidecars = Get-ChildItem $VerifyDir -Filter "*.sha256"

$Results = foreach ($Sidecar in $Sidecars) {
    $Line = (Get-Content $Sidecar.FullName -Raw).Trim()
    $Parts = $Line -split '\s+', 2

    $Expected   = $Parts[0]
    $TargetName = $Parts[1].Trim()
    $TargetPath = Join-Path $VerifyDir $TargetName

    if (-not (Test-Path $TargetPath)) {
        throw "Target file not found for $($Sidecar.Name): $TargetName"
    }

    $Actual = (Get-FileHash $TargetPath -Algorithm SHA256).Hash

    [PSCustomObject]@{
        File  = $TargetName
        Match = ($Expected -eq $Actual)
    }
}

$Results | Format-Table -AutoSize

if ($Results.Count -ne 4) {
    throw "Expected 4 SHA-256 sidecars; found $($Results.Count)."
}

if ($Results.Match -contains $false) {
    throw "One or more downloaded GitHub release assets failed SHA-256 verification."
}

if ((Get-ChildItem $VerifyDir -File).Count -ne 8) {
    throw "Expected exactly 8 downloaded explicit release files."
}

"SUCCESS: All 8 downloaded GitHub release files are present and all 4 payload SHA-256 checks passed."
```

After successful verification, the temporary download directory may be
removed:

``` powershell
Remove-Item $VerifyDir -Recurse -Force
Test-Path $VerifyDir
```

The expected final result is `False`.

# Recommended script organization

The workflow is easier to maintain when separated by responsibility
rather than placed immediately into one large script.

Recommended filenames:

``` text
Build-CollectionReleaseArtifact.ps1
Build-GitHubReleaseAssets.ps1
Test-GitHubReleaseAssets.ps1
```

Their responsibilities are:

1.  `Build-CollectionReleaseArtifact.ps1`
    -   verify the requested Git tag exists;
    -   build the collection ZIP from that tag;
    -   generate its SHA-256 sidecar;
    -   optionally rebuild the ZIP and prove reproducibility;
    -   report artifact paths, size, and SHA-256.
2.  `Build-GitHubReleaseAssets.ps1`
    -   create a clean staging directory;
    -   copy the verified collection ZIP and sidecar;
    -   safely extract the tagged repository tree;
    -   copy canonical component artifacts from the tag;
    -   create convenience ZIPs such as the logo-assets ZIP;
    -   generate sidecars for new payloads;
    -   verify direct tag copies and bundled ZIP contents;
    -   enforce the expected asset count;
    -   report a final release-asset inventory.
3.  `Test-GitHubReleaseAssets.ps1`
    -   perform read-only verification of an existing asset directory;
    -   parse every `.sha256` sidecar;
    -   verify each corresponding payload;
    -   enforce expected payload/sidecar/file counts;
    -   provide a concise PASS/FAIL summary;
    -   work equally well against the pre-publication staging directory
        or a directory containing files downloaded from GitHub.

This separation is useful because **building** and **testing** are
different operations. The test script can be reused after publication
without rebuilding or modifying anything.

# Parameter strategy

Scripts should have safe defaults for the normal repository while still
allowing reuse:

``` powershell
param(
    [string]$CollectionTag = "v1.0.1",
    [string]$RepositoryName = "microsoft-office-resources",
    [string]$ComponentPath = "word/templates/labels/usps-label-228",
    [string]$OutputRoot = "C:\git"
)
```

Additional parameters can be introduced only when they represent genuine
variability. Avoid turning every internal filename into a parameter;
that makes the command harder to understand and easier to misuse.

A good default invocation should be as simple as:

``` powershell
.\Build-CollectionReleaseArtifact.ps1
.\Build-GitHubReleaseAssets.ps1
.\Test-GitHubReleaseAssets.ps1
```

while an intentional alternate release remains possible:

``` powershell
.\Build-CollectionReleaseArtifact.ps1 -CollectionTag "v1.1.0"
```

# Console-output conventions

Release scripts should provide enough output to establish what happened
without dumping every internal operation.

A useful pattern is:

``` text
BUILD COLLECTION RELEASE ARTIFACT
---------------------------------
Tag:        v1.0.1
Commit:     34ba0c41...
Output:     C:\git\microsoft-office-resources-v1.0.1.zip
Files:      53
SHA-256:    73eb5729...

SUCCESS: Collection release artifact created and verified.
```

For the final asset test:

``` text
GITHUB RELEASE ASSET VERIFICATION
---------------------------------
Payloads:   4
Sidecars:   4
Files:      8

File                                  Match
----                                  -----
microsoft-office-resources-v1.0.1.zip True
USPS-Label-228-Logo-Assets.zip        True
USPS-Label-228-Reference.png          True
USPS-Label-228-Template.dotx          True

SUCCESS: All 8 release files are present and all 4 payload SHA-256 checks passed.
```

Use `throw` for failed gates so that both interactive use and future
automation receive a non-successful termination instead of merely
printing a warning.

# Full reusable scripts

The companion scripts supplied with this addendum implement the modular
approach:

-   `Build-CollectionReleaseArtifact.ps1`
-   `Build-GitHubReleaseAssets.ps1`
-   `Test-GitHubReleaseAssets.ps1`

Each can be run as a `.ps1` file with defaults. Their logic is also
ordinary PowerShell 5.1 code and can be copied into an interactive
PowerShell session when desired.

For script-file execution, if the local execution policy prevents
running a `.ps1`, use the organization's/user's approved PowerShell
execution-policy approach rather than weakening system-wide policy
solely for these scripts.

# Cleanup model

There are three different categories of output:

-   **release payloads** - retain and upload;
-   **temporary extraction/verification directories** - remove after
    successful verification;
-   **repository working tree** - should remain unchanged throughout
    artifact construction.

After building release artifacts, a final repository check is useful:

``` powershell
git status

if (git status --porcelain) {
    throw "Repository working tree is not clean."
}

"SUCCESS: Repository working tree remains clean."
```

The release-building workflow should never require modifying tracked
repository files merely to produce downloadable release artifacts.

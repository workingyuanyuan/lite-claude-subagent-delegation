#requires -Version 7.0
<#
.SYNOPSIS
Installs a versioned Claude Code multi-model orchestration configuration.

.DESCRIPTION
Copies one versioned configuration snapshot into the current user's .claude directory.
This includes CLAUDE.md, the PowerShell wrapper scripts, and any bundled agent skills.
Existing destination files are never overwritten unless -Force is specified.

.PARAMETER Version
Version directory to install from versions/. Defaults to opus-5. The name must not
contain spaces; use hyphens instead.

.PARAMETER Force
Allows existing destination files to be overwritten. Unrelated files are untouched.

.EXAMPLE
./install.ps1 -Version opus-5

.EXAMPLE
./install.ps1 -Version opus-5 -Force
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9.\-]*$')]
    [string]$Version = 'opus-5',


    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$versionsRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot 'versions') -ErrorAction Stop
$sourceCandidate = Join-Path $versionsRoot.Path $Version

if (-not (Test-Path -LiteralPath $sourceCandidate -PathType Container)) {
    throw "Version '$Version' was not found under: $($versionsRoot.Path)"
}

$sourceRoot = Resolve-Path -LiteralPath $sourceCandidate -ErrorAction Stop
$sourceParent = Split-Path -Parent $sourceRoot.Path
if (-not $sourceParent.Equals($versionsRoot.Path, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Version '$Version' does not resolve to a direct child of the versions directory."
}

$scriptSourceDirectory = Join-Path $sourceRoot.Path 'scripts'
if (-not (Test-Path -LiteralPath $scriptSourceDirectory -PathType Container)) {
    throw "Version '$Version' is incomplete; scripts directory is missing."
}

$scriptFiles = @(Get-ChildItem -LiteralPath $scriptSourceDirectory -File -Filter '*.ps1' | Sort-Object Name)
if ($scriptFiles.Count -eq 0) {
    throw "Version '$Version' contains no PowerShell scripts."
}

$skillSourceDirectory = Join-Path $sourceRoot.Path 'skills'
$skillFiles = @()
if (Test-Path -LiteralPath $skillSourceDirectory -PathType Container) {
    $skillFiles = @(
        Get-ChildItem -LiteralPath $skillSourceDirectory -File -Recurse |
            Sort-Object FullName
    )
}

$claudeRoot = Join-Path $HOME '.claude'

$sourceFiles = @(
    [pscustomobject]@{
        Source = Join-Path $sourceRoot.Path 'CLAUDE.md'
        DestinationDirectory = $claudeRoot
        DestinationName = 'CLAUDE.md'
    }
)

foreach ($sourceFile in $scriptFiles) {
    $sourceFiles += [pscustomobject]@{
        Source = $sourceFile.FullName
        DestinationDirectory = Join-Path $claudeRoot 'scripts'
        DestinationName = $sourceFile.Name
    }
}

$skillsRoot = Join-Path $claudeRoot 'skills'
foreach ($sourceFile in $skillFiles) {
    $relativePath = [IO.Path]::GetRelativePath($skillSourceDirectory, $sourceFile.FullName)
    $relativeDirectory = Split-Path -Parent $relativePath
    $destinationDirectory = if ([string]::IsNullOrEmpty($relativeDirectory)) {
        $skillsRoot
    }
    else {
        Join-Path $skillsRoot $relativeDirectory
    }

    $sourceFiles += [pscustomobject]@{
        Source = $sourceFile.FullName
        DestinationDirectory = $destinationDirectory
        DestinationName = $sourceFile.Name
    }
}

foreach ($file in $sourceFiles) {
    if (-not (Test-Path -LiteralPath $file.Source -PathType Leaf)) {
        throw "Version '$Version' is incomplete; required file is missing: $($file.Source)"
    }
    $file | Add-Member -NotePropertyName Destination -NotePropertyValue (
        Join-Path $file.DestinationDirectory $file.DestinationName
    )
}

$collisions = @($sourceFiles | Where-Object { Test-Path -LiteralPath $_.Destination })
if ($collisions.Count -gt 0 -and -not $Force) {
    $collisionList = ($collisions.Destination | Sort-Object) -join [Environment]::NewLine
    throw "Installation would overwrite existing files. No files were copied. Re-run with -Force to replace only these files:$([Environment]::NewLine)$collisionList"
}

$destinationDirectories = $sourceFiles.DestinationDirectory | Sort-Object -Unique
foreach ($directory in $destinationDirectories) {
    $null = New-Item -ItemType Directory -Path $directory -Force
}

foreach ($file in $sourceFiles) {
    Copy-Item -LiteralPath $file.Source -Destination $file.Destination -Force:$Force
    Write-Verbose "Installed $($file.Destination)"
}

Write-Host "Installed claude-gemini-orchestrator version $Version to $claudeRoot."
Write-Host "Optional: add the delegation permission rules to $claudeRoot\settings.json to avoid a prompt on every worker invocation. See README.md."

#requires -Version 7.0
<#
.SYNOPSIS
Runs one stateless Antigravity CLI task in an existing isolated Git worktree.

.DESCRIPTION
The orchestrating Claude Code agent owns worktree creation, integration, commits, and
cleanup. This wrapper validates the worktree and UTF-8 task contract, confirms the
requested model slug is still offered by `agy models`, explicitly attaches the resolved
worktree, then runs a single non-interactive Antigravity session with a ten-minute print
timeout. It writes no log files and returns the Antigravity process exit code.

-Model takes an exact Antigravity slug from the allowlist below. Reasoning effort is
part of the slug and is therefore always explicit at the call site; do not pass
`--effort`, which would duplicate it.

  gemini-3.7-flash-medium   default worker
  gemini-3.7-flash-high     same model at higher reasoning effort
  gemini-3.1-pro-high       data-bound work

`agy models` also lists superseded Gemini generations, other effort levels, and Claude
worker slugs. This wrapper accepts only the three slugs above; anything else is
rejected before the CLI is invoked.

.EXAMPLE
& "$HOME\.claude\scripts\Invoke-AntigravityAgent.ps1" `
  -WorkingDirectory "C:\src\project-agent-task" `
  -Model gemini-3.7-flash-medium `
  -PromptFile "C:\src\contracts\task.md" `
  -AutoApprove

.EXAMPLE
& "$HOME\.claude\scripts\Invoke-AntigravityAgent.ps1" `
  -WorkingDirectory "C:\src\project" `
  -Model gemini-3.7-flash-high `
  -PromptFile "C:\src\contracts\analysis.md"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$WorkingDirectory,

    [Parameter(Mandatory)]
    [ValidateSet('gemini-3.7-flash-medium', 'gemini-3.7-flash-high', 'gemini-3.1-pro-high')]
    [string]$Model,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$PromptFile,

    [switch]$AutoApprove
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-ExistingPath {
    param(
        [Parameter(Mandatory)][string]$LiteralPath,
        [Parameter(Mandatory)][string]$Label
    )

    try {
        return (Resolve-Path -LiteralPath $LiteralPath -ErrorAction Stop).Path
    }
    catch {
        throw "$Label does not exist or cannot be resolved: $LiteralPath"
    }
}

function Remove-AnsiEscapeSequences {
    param([Parameter(Mandatory)][string]$Text)
    return [regex]::Replace($Text, "`e\[[0-?]*[ -/]*[@-~]", '')
}

$worktreePath = Resolve-ExistingPath -LiteralPath $WorkingDirectory -Label 'Working directory'
$promptPath = Resolve-ExistingPath -LiteralPath $PromptFile -Label 'Prompt file'

if (-not (Test-Path -LiteralPath $worktreePath -PathType Container)) {
    throw "Working directory is not a directory: $worktreePath"
}
if (-not (Test-Path -LiteralPath $promptPath -PathType Leaf)) {
    throw "Prompt file is not a file: $promptPath"
}

$gitCommand = Get-Command git -ErrorAction Stop | Select-Object -First 1
$insideWorktree = (& $gitCommand.Source -C $worktreePath rev-parse --is-inside-work-tree 2>$null | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $insideWorktree -ne 'true') {
    throw "Working directory is not inside a Git worktree: $worktreePath"
}

$topLevelRaw = (& $gitCommand.Source -C $worktreePath rev-parse --show-toplevel 2>$null | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($topLevelRaw)) {
    throw "Unable to determine the Git worktree root for: $worktreePath"
}
$topLevelPath = Resolve-ExistingPath -LiteralPath $topLevelRaw -Label 'Git worktree root'

$normalizedWorktree = [IO.Path]::GetFullPath($worktreePath).TrimEnd('\', '/')
$normalizedTopLevel = [IO.Path]::GetFullPath($topLevelPath).TrimEnd('\', '/')
if (-not $normalizedWorktree.Equals($normalizedTopLevel, [StringComparison]::OrdinalIgnoreCase)) {
    throw "WorkingDirectory must be the Git worktree root. Resolved root: $normalizedTopLevel"
}

try {
    $strictUtf8 = [Text.UTF8Encoding]::new($false, $true)
    $prompt = [IO.File]::ReadAllText($promptPath, $strictUtf8)
}
catch {
    throw "Prompt file must be valid UTF-8: $promptPath. $($_.Exception.Message)"
}
if ([string]::IsNullOrWhiteSpace($prompt)) {
    throw "Prompt file is empty: $promptPath"
}

$agyCommand = Get-Command agy -ErrorAction Stop | Select-Object -First 1
$modelsOutput = (& $agyCommand.Source models 2>&1 | Out-String)
$modelsExitCode = $LASTEXITCODE
if ($modelsExitCode -ne 0) {
    throw "`agy models` failed with exit code $modelsExitCode.`n$modelsOutput"
}

$cleanModelsOutput = Remove-AnsiEscapeSequences -Text $modelsOutput

# The ValidateSet holds exact Antigravity slugs, so -Model needs no translation; it is
# only confirmed to still be on offer before invoking. agy 1.1.4 emits model slugs
# rather than display names. Match the slug as a standalone token so that, for example,
# `gemini-3.7-flash-high` cannot be satisfied by `gemini-3.7-flash-medium`.
$modelPattern = '(?<![A-Za-z0-9._-])' + [regex]::Escape($Model) + '(?![A-Za-z0-9._-])'
$offeredModels = @(
    [regex]::Matches(
        $cleanModelsOutput,
        $modelPattern,
        [Text.RegularExpressions.RegexOptions]::IgnoreCase
    ) |
        ForEach-Object { $_.Value.ToLowerInvariant() } |
        Sort-Object -Unique
)

if ($offeredModels.Count -ne 1) {
    throw "Model slug '$Model' is not offered exactly once by ``agy models``. Found $($offeredModels.Count) match(es). Available model output:`n$cleanModelsOutput"
}

$agyArguments = @(
    '--add-dir', $worktreePath,
    '--print-timeout', '10m',
    '--model', $Model,
    '-p', $prompt
)
if ($AutoApprove) {
    $agyArguments = @('--dangerously-skip-permissions') + $agyArguments
}

$exitCode = 1
Push-Location -LiteralPath $worktreePath
try {
    & $agyCommand.Source @agyArguments
    $exitCode = if ($null -eq $LASTEXITCODE) { 1 } else { [int]$LASTEXITCODE }
}
finally {
    Pop-Location
}

exit $exitCode

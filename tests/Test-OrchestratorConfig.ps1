#requires -Version 7.0
<#
.SYNOPSIS
Verifies that one versioned orchestration configuration is internally consistent.

.DESCRIPTION
The worker alias set is repeated across four surfaces: the wrapper script's ValidateSet,
its alias-to-slug switch, the skill's frontmatter and entry-point list, and the
operator documentation. A model-generation upgrade that misses one surface leaves a
configuration that installs cleanly and then routes to a model the wrapper rejects.

This script treats the wrapper's ValidateSet as the source of truth and checks every
other surface against it. It also parses both PowerShell files for syntax errors and
confirms that the skill name is consistent everywhere it is referenced.

Structural checks require no network and no Antigravity CLI. Alias resolution against
`agy models` runs only when `agy` is on PATH, and is skipped otherwise unless
-RequireAgy is specified.

.PARAMETER Version
Version directory under versions/ to verify. Defaults to opus-5.

.PARAMETER RequireAgy
Fail instead of skipping when the Antigravity CLI is unavailable.

.EXAMPLE
./tests/Test-OrchestratorConfig.ps1

.EXAMPLE
./tests/Test-OrchestratorConfig.ps1 -Version opus-5 -RequireAgy
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9.\-]*$')]
    [string]$Version = 'opus-5',

    [switch]$RequireAgy
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Failures = @()
$script:Passed = 0
$script:Skipped = 0

function Test-Case {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$Body
    )

    try {
        & $Body
        $script:Passed++
        Write-Host "  PASS  $Name"
    }
    catch {
        $script:Failures += "$Name`n        $($_.Exception.Message)"
        Write-Host "  FAIL  $Name" -ForegroundColor Red
        Write-Host "        $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Skip-Case {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Reason
    )

    $script:Skipped++
    Write-Host "  SKIP  $Name ($Reason)" -ForegroundColor Yellow
}

function Assert-True {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Get-ParsedScript {
    param([Parameter(Mandatory)][string]$Path)

    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
    if ($errors.Count -gt 0) {
        $detail = ($errors | ForEach-Object { "line $($_.Extent.StartLineNumber): $($_.Message)" }) -join '; '
        throw "Parse errors in $Path -- $detail"
    }
    return $ast
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$versionRoot = Join-Path $repoRoot "versions/$Version"
$readmePath = Join-Path $repoRoot 'README.md'
$installPath = Join-Path $repoRoot 'install.ps1'
$routingDocPath = Join-Path $repoRoot 'docs/routing-policy.md'
$claudeMdPath = Join-Path $versionRoot 'CLAUDE.md'
$wrapperPath = Join-Path $versionRoot 'scripts/Invoke-AntigravityAgent.ps1'

Write-Host "Verifying version '$Version' in $repoRoot"
Write-Host ''

# --- Layout -----------------------------------------------------------------

Write-Host 'Layout'

Test-Case 'version directory exists' {
    Assert-True (Test-Path -LiteralPath $versionRoot -PathType Container) `
        "Missing version directory: $versionRoot"
}

foreach ($required in @($readmePath, $installPath, $routingDocPath, $claudeMdPath, $wrapperPath)) {
    $relative = [IO.Path]::GetRelativePath($repoRoot, $required)
    Test-Case "$relative exists" {
        Assert-True (Test-Path -LiteralPath $required -PathType Leaf) "Missing file: $required"
    }
}

$skillsRoot = Join-Path $versionRoot 'skills'
$skillDirectories = @()
if (Test-Path -LiteralPath $skillsRoot -PathType Container) {
    $skillDirectories = @(Get-ChildItem -LiteralPath $skillsRoot -Directory | Sort-Object Name)
}

Test-Case 'version ships exactly one skill' {
    Assert-True ($skillDirectories.Count -eq 1) `
        "Expected 1 skill directory under $skillsRoot, found $($skillDirectories.Count)."
}

if ($skillDirectories.Count -ne 1) {
    Write-Host ''
    Write-Host "Aborting: cannot verify skill content without exactly one skill." -ForegroundColor Red
    exit 1
}

$skillName = $skillDirectories[0].Name
$skillPath = Join-Path $skillDirectories[0].FullName 'SKILL.md'

Test-Case 'skill contains SKILL.md' {
    Assert-True (Test-Path -LiteralPath $skillPath -PathType Leaf) "Missing file: $skillPath"
}

$skillText = [IO.File]::ReadAllText($skillPath)
$claudeMdText = [IO.File]::ReadAllText($claudeMdPath)
$readmeText = [IO.File]::ReadAllText($readmePath)
$routingDocText = [IO.File]::ReadAllText($routingDocPath)
$wrapperText = [IO.File]::ReadAllText($wrapperPath)

# --- PowerShell syntax ------------------------------------------------------

Write-Host ''
Write-Host 'PowerShell'

$wrapperAst = $null
Test-Case 'wrapper script parses' {
    $script:wrapperAst = Get-ParsedScript -Path $wrapperPath
}

Test-Case 'installer parses' {
    $null = Get-ParsedScript -Path $installPath
}

# --- Alias set --------------------------------------------------------------

Write-Host ''
Write-Host 'Alias set'

$validateSetAliases = @()
Test-Case 'wrapper declares a -Model ValidateSet' {
    Assert-True ($null -ne $script:wrapperAst) 'Wrapper did not parse; cannot read ValidateSet.'

    $modelParameter = $script:wrapperAst.ParamBlock.Parameters |
        Where-Object { $_.Name.VariablePath.UserPath -eq 'Model' } |
        Select-Object -First 1
    Assert-True ($null -ne $modelParameter) 'Wrapper has no -Model parameter.'

    $validateSet = $modelParameter.Attributes |
        Where-Object { $_.TypeName.GetReflectionType() -eq [ValidateSet] } |
        Select-Object -First 1
    Assert-True ($null -ne $validateSet) '-Model has no ValidateSet attribute.'

    $script:validateSetAliases = @(
        $validateSet.PositionalArguments |
            ForEach-Object { $_.Value } |
            Sort-Object
    )
    Assert-True ($script:validateSetAliases.Count -gt 0) 'ValidateSet on -Model is empty.'
}

if ($validateSetAliases.Count -eq 0) {
    Write-Host ''
    Write-Host 'Aborting: no alias set to verify against.' -ForegroundColor Red
    exit 1
}

Write-Host "        slugs: $($validateSetAliases -join ', ')"

Test-Case 'every allowed slug names its reasoning effort' {
    # Effort is part of the Antigravity slug, so an allowlist entry without an effort
    # suffix would leave the effort implicit at the call site -- the thing this
    # generation's policy exists to make explicit.
    foreach ($slug in $validateSetAliases) {
        Assert-True ($slug -match '-(low|medium|high)$') `
            "Allowed slug '$slug' carries no reasoning-effort suffix."
    }
}

Test-Case 'wrapper passes the slug through without translation' {
    # The allowlist holds exact Antigravity slugs, so any alias-to-slug switch left in
    # the wrapper would be a second, silently divergent source of truth.
    Assert-True ($wrapperText -notmatch '(?m)^\s*''[^'']+''\s*\{\s*''[^'']+''\s*\}') `
        'Wrapper still contains an alias-to-slug switch; the allowlist should be passed through unchanged.'
}

Test-Case 'default and escalation efforts are both routable' {
    # Section 4.1 of the routing policy depends on being able to raise effort on the
    # same model. An allowlist offering only one tier of a model breaks that ladder.
    $byModel = $validateSetAliases | Group-Object { $_ -replace '-(low|medium|high)$', '' }
    $defaultModel = @($byModel | Where-Object { $_.Count -gt 1 })
    Assert-True ($defaultModel.Count -ge 1) `
        'No model exposes more than one reasoning-effort tier; escalation by effort is impossible.'
}

Test-Case 'wrapper never passes --effort' {
    # Checked against the AST rather than the file text: the wrapper's own doc comment
    # says not to pass --effort, and comments are absent from the AST.
    Assert-True ($null -ne $script:wrapperAst) 'Wrapper did not parse; cannot inspect arguments.'

    $effortLiterals = @(
        $script:wrapperAst.FindAll(
            { param($node) $node -is [System.Management.Automation.Language.StringConstantExpressionAst] },
            $true
        ) | Where-Object { $_.Value -eq '--effort' }
    )
    $lines = ($effortLiterals | ForEach-Object { $_.Extent.StartLineNumber }) -join ', '
    Assert-True ($effortLiterals.Count -eq 0) `
        "Wrapper passes --effort to the CLI at line(s): $lines."
}

# Retired models and effort tiers are derived rather than listed, so a generation
# upgrade does not have to remember to extend a hardcoded list here: any slug-shaped
# token the wrapper no longer accepts is stale by definition. This covers retiring a
# whole model family, a single generation, and a single effort tier with one rule.
#
# Prose naming a model without its slug form ("Gemini 3.6 Flash", "Claude Opus 4.6") is
# deliberately not matched, so migration notes can still explain what was retired and
# why. Writing the retired slug itself is what fails.
$slugShapePattern = '(?<![A-Za-z0-9._-])(?:gemini-\d+\.\d+-(?:flash|pro)|claude-opus-\d+-\d+)(?:-(?:low|medium|high|thinking))?(?![A-Za-z0-9._-])'

function Assert-SlugsCurrent {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Label
    )

    foreach ($slug in $script:validateSetAliases) {
        Assert-True ($Text -match [regex]::Escape($slug)) "$Label does not mention slug '$slug'."
    }

    $stale = @(
        [regex]::Matches($Text, $slugShapePattern) |
            ForEach-Object { $_.Value } |
            Sort-Object -Unique |
            Where-Object { $_ -notin $script:validateSetAliases }
    )
    Assert-True ($stale.Count -eq 0) "$Label references retired slug(s): $($stale -join ', ')."
}

Test-Case 'skill lists exactly the wrapper slugs' {
    Assert-SlugsCurrent -Text $skillText -Label 'SKILL.md'
}

Test-Case 'documentation lists exactly the wrapper slugs' {
    Assert-SlugsCurrent -Text $routingDocText -Label 'routing-policy.md'
    Assert-SlugsCurrent -Text $readmeText -Label 'README.md'
}

Test-Case 'CLAUDE.md names no worker slug' {
    # The trigger file is deliberately policy-free: naming a worker there would make it
    # a second routing surface that the skill could silently contradict.
    $named = [regex]::Match($claudeMdText, $slugShapePattern)
    Assert-True (-not $named.Success) `
        "CLAUDE.md names worker slug '$($named.Value)'; routing belongs in the skill."
}

# --- Skill wiring -----------------------------------------------------------

Write-Host ''
Write-Host 'Skill wiring'

Test-Case 'SKILL.md frontmatter name matches its directory' {
    $frontmatter = [regex]::Match($skillText, '(?s)\A---\r?\n(.*?)\r?\n---')
    Assert-True $frontmatter.Success 'SKILL.md has no YAML frontmatter block.'

    $nameMatch = [regex]::Match($frontmatter.Groups[1].Value, '(?m)^name:\s*(?<name>\S+)\s*$')
    Assert-True $nameMatch.Success 'SKILL.md frontmatter has no name field.'
    Assert-True ($nameMatch.Groups['name'].Value -eq $skillName) `
        "Frontmatter name '$($nameMatch.Groups['name'].Value)' does not match directory '$skillName'."
}

Test-Case 'SKILL.md frontmatter has a description' {
    $descriptionMatch = [regex]::Match($skillText, '(?m)^description:\s*(?<value>.+)$')
    Assert-True $descriptionMatch.Success 'SKILL.md frontmatter has no description field.'
    Assert-True ($descriptionMatch.Groups['value'].Value.Trim().Length -ge 40) `
        'SKILL.md description is too short to trigger reliably.'
}

Test-Case 'CLAUDE.md loads the shipped skill by name' {
    Assert-True ($claudeMdText -match [regex]::Escape($skillName)) `
        "CLAUDE.md does not reference skill '$skillName'."
}

Test-Case 'documentation references the shipped skill by name' {
    Assert-True ($routingDocText -match [regex]::Escape($skillName)) `
        "routing-policy.md does not reference skill '$skillName'."
    Assert-True ($readmeText -match [regex]::Escape($skillName)) `
        "README.md does not reference skill '$skillName'."
}

Test-Case 'no stale skill-generation references remain' {
    $stalePattern = 'antigravity-delegation-gemini(?!' + [regex]::Escape($skillName.Split('gemini')[-1]) + '\b)\d+'
    foreach ($file in @($claudeMdPath, $routingDocPath, $readmePath, $skillPath, $wrapperPath, $installPath)) {
        $text = [IO.File]::ReadAllText($file)
        $stale = [regex]::Match($text, $stalePattern)
        Assert-True (-not $stale.Success) `
            "$([IO.Path]::GetRelativePath($repoRoot, $file)) references stale skill '$($stale.Value)'."
    }
}

# --- Installer contract -----------------------------------------------------

Write-Host ''
Write-Host 'Installer'

Test-Case 'installer default version resolves to a real directory' {
    $installAst = Get-ParsedScript -Path $installPath
    $versionParameter = $installAst.ParamBlock.Parameters |
        Where-Object { $_.Name.VariablePath.UserPath -eq 'Version' } |
        Select-Object -First 1
    Assert-True ($null -ne $versionParameter) 'install.ps1 has no -Version parameter.'

    $defaultVersion = $versionParameter.DefaultValue.Value
    $defaultPath = Join-Path $repoRoot "versions/$defaultVersion"
    Assert-True (Test-Path -LiteralPath $defaultPath -PathType Container) `
        "install.ps1 defaults to version '$defaultVersion', which does not exist."
}

Test-Case 'installer refuses to overwrite without -Force' {
    Assert-True ([IO.File]::ReadAllText($installPath) -match 'Re-run with -Force') `
        'install.ps1 no longer guards existing files with a -Force message.'
}

# --- Live CLI ---------------------------------------------------------------

Write-Host ''
Write-Host 'Antigravity CLI'

$agyCommand = Get-Command agy -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -eq $agyCommand) {
    if ($RequireAgy) {
        $script:Failures += 'agy is not on PATH and -RequireAgy was specified.'
        Write-Host '  FAIL  agy is on PATH' -ForegroundColor Red
    }
    else {
        Skip-Case -Name 'slugs resolve against agy models' -Reason 'agy not on PATH'
    }
}
else {
    $modelsOutput = (& $agyCommand.Source models 2>&1 | Out-String)
    $modelsExitCode = $LASTEXITCODE
    $cleanOutput = [regex]::Replace($modelsOutput, "`e\[[0-?]*[ -/]*[@-~]", '')

    Test-Case 'agy models succeeds' {
        Assert-True ($modelsExitCode -eq 0) "agy models exited with $modelsExitCode.`n$cleanOutput"
    }

    foreach ($slug in $validateSetAliases) {
        Test-Case "agy models offers '$slug' exactly once" {
            # Mirrors the wrapper's own matcher, so a resolution failure here is a
            # resolution failure at delegation time. The token boundaries matter most
            # for effort tiers: a loose match would let '-medium' satisfy '-high'.
            $pattern = '(?<![A-Za-z0-9._-])' + [regex]::Escape($slug) + '(?![A-Za-z0-9._-])'
            $slugMatches = @(
                [regex]::Matches($cleanOutput, $pattern, [Text.RegularExpressions.RegexOptions]::IgnoreCase) |
                    ForEach-Object { $_.Value.ToLowerInvariant() } |
                    Sort-Object -Unique
            )
            Assert-True ($slugMatches.Count -eq 1) `
                "Slug '$slug' matched $($slugMatches.Count) time(s) in agy models output."
        }
    }
}

# --- Summary ----------------------------------------------------------------

Write-Host ''
if ($script:Failures.Count -gt 0) {
    Write-Host "$($script:Failures.Count) failed, $script:Passed passed, $script:Skipped skipped." -ForegroundColor Red
    exit 1
}

Write-Host "$script:Passed passed, $script:Skipped skipped." -ForegroundColor Green
exit 0

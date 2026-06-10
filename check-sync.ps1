[CmdletBinding()]
param(
    [string]$CodexHome = (Join-Path $HOME ".codex"),
    [string]$Format = "text"
)

$ErrorActionPreference = "Stop"

$syncRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoAgents = Join-Path $syncRoot "AGENTS.md"
$repoSkillsRoot = Join-Path $syncRoot "skills"
$localAgents = Join-Path $CodexHome "AGENTS.md"
$localSkillsRoot = Join-Path $CodexHome "skills"

function Get-FileDigestOrNull {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    $content = Get-Content -LiteralPath $Path -Raw
    $normalized = $content -replace "`r`n", "`n"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($normalized)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-", "")
    }
    finally {
        $sha.Dispose()
    }
}

function New-SkillStatus {
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [string]$RepoPath,
        [Parameter(Mandatory)]
        [string]$LocalPath
    )

    $repoExists = Test-Path -LiteralPath $RepoPath
    $localExists = Test-Path -LiteralPath $LocalPath
    $repoDigest = Get-FileDigestOrNull -Path (Join-Path $RepoPath "SKILL.md")
    $localDigest = Get-FileDigestOrNull -Path (Join-Path $LocalPath "SKILL.md")
    $localItem = if ($localExists) { Get-Item -LiteralPath $LocalPath -Force } else { $null }
    $target = if ($localItem) { ($localItem.Target -join ",") } else { $null }
    $isLinked = $localItem -and $localItem.LinkType -eq "Junction" -and $target -eq $RepoPath

    $status = if (-not $localExists) {
        "missing-local"
    }
    elseif (-not $repoExists) {
        "missing-repo"
    }
    elseif ($isLinked) {
        "linked"
    }
    elseif ($repoDigest -eq $localDigest) {
        "same-content"
    }
    else {
        "different"
    }

    [pscustomobject]@{
        name = $Name
        status = $status
        repoPath = $RepoPath
        localPath = $LocalPath
        localLinkType = if ($localItem) { $localItem.LinkType } else { $null }
        localTarget = $target
    }
}

$repoSkillDirs = @()
if (Test-Path -LiteralPath $repoSkillsRoot) {
    $repoSkillDirs = Get-ChildItem -LiteralPath $repoSkillsRoot -Directory | Sort-Object Name
}

$repoSkillNames = @($repoSkillDirs | ForEach-Object { $_.Name })
$skillStatuses = @(
    foreach ($dir in $repoSkillDirs) {
        New-SkillStatus -Name $dir.Name -RepoPath $dir.FullName -LocalPath (Join-Path $localSkillsRoot $dir.Name)
    }
)

$extraLocalSkills = @()
if (Test-Path -LiteralPath $localSkillsRoot) {
    $extraLocalSkills = Get-ChildItem -LiteralPath $localSkillsRoot -Directory |
        Where-Object { $_.Name -ne ".system" -and $_.Name -notin $repoSkillNames } |
        Sort-Object Name |
        ForEach-Object {
            [pscustomobject]@{
                name = $_.Name
                localPath = $_.FullName
            }
        }
}

$agentsRepoDigest = Get-FileDigestOrNull -Path $repoAgents
$agentsLocalDigest = Get-FileDigestOrNull -Path $localAgents
$localAgentsItem = if (Test-Path -LiteralPath $localAgents) { Get-Item -LiteralPath $localAgents -Force } else { $null }
$agentsStatus = if (-not $localAgentsItem) {
    "missing-local"
}
elseif ($localAgentsItem.LinkType -eq "HardLink") {
    "legacy-hardlink"
}
elseif ($agentsRepoDigest -eq $agentsLocalDigest) {
    "same-content"
}
else {
    "different"
}

$actions = @()
if ($agentsStatus -eq "legacy-hardlink") {
    $actions += "AGENTS.md is still using the old hardlink mode; switch it to copy/sync mode with .\\template\\apply-sync.ps1 -Target agents"
}
elseif ($agentsStatus -ne "same-content") {
    $actions += "AGENTS.md can be refreshed from repo with .\\template\\apply-sync.ps1 -Target agents"
}

foreach ($skill in $skillStatuses) {
    if ($skill.status -ne "linked") {
        $actions += "Skill '$($skill.name)' can be refreshed from repo with .\\template\\apply-sync.ps1 -Target skill -SkillName $($skill.name)"
    }
}

if ($extraLocalSkills.Count -gt 0) {
    $actions += "Local extra skills exist outside the repo; decide whether to keep them local or copy them into template\\skills"
}

$report = [pscustomobject]@{
    generatedAt = (Get-Date).ToString("s")
    syncRoot = $syncRoot
    codexHome = $CodexHome
    gitBranch = (git -C $syncRoot rev-parse --abbrev-ref HEAD 2>$null)
    gitStatus = (git -C $syncRoot status --short 2>$null)
    agents = [pscustomobject]@{
        status = $agentsStatus
        repoPath = $repoAgents
        localPath = $localAgents
    }
    skills = $skillStatuses
    extraLocalSkills = $extraLocalSkills
    recommendedActions = $actions
}

if ($Format -eq "json") {
    $report | ConvertTo-Json -Depth 6
    exit 0
}

Write-Host "Codex sync report"
Write-Host "Generated: $($report.generatedAt)"
Write-Host "Repo: $($report.syncRoot)"
Write-Host "Codex home: $($report.codexHome)"
Write-Host ""
Write-Host "AGENTS.md: $($report.agents.status)"
foreach ($skill in $report.skills) {
    Write-Host "Skill $($skill.name): $($skill.status)"
}
if ($report.extraLocalSkills.Count -gt 0) {
    Write-Host ""
    Write-Host "Extra local skills:"
    foreach ($skill in $report.extraLocalSkills) {
        Write-Host "  $($skill.name) -> $($skill.localPath)"
    }
}
if ($report.recommendedActions.Count -gt 0) {
    Write-Host ""
    Write-Host "Recommended actions:"
    foreach ($action in $report.recommendedActions) {
        Write-Host "  - $action"
    }
}
else {
    Write-Host ""
    Write-Host "Everything is in sync."
}

[CmdletBinding()]
param(
    [ValidateSet("agents", "skill", "all")]
    [string]$Target = "all",
    [string]$SkillName,
    [string]$CodexHome = (Join-Path $HOME ".codex")
)

$ErrorActionPreference = "Stop"

$syncRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$skillsHome = Join-Path $CodexHome "skills"
$backupRoot = Join-Path $CodexHome ("sync-backup-" + (Get-Date -Format "yyyyMMdd-HHmmss"))

function Backup-ExistingItem {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $item = Get-Item -LiteralPath $Path -Force
    if ($item.LinkType) {
        Remove-Item -LiteralPath $Path -Force
        return
    }

    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    Move-Item -LiteralPath $Path -Destination $backupRoot
}

function Sync-Agents {
    $source = Join-Path $syncRoot "AGENTS.md"
    $target = Join-Path $CodexHome "AGENTS.md"
    Backup-ExistingItem -Path $target
    Copy-Item -LiteralPath $source -Destination $target
    Write-Host "Copied AGENTS.md from repo to local Codex config"
}

function Sync-Skill {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $source = Join-Path $syncRoot "skills\$Name"
    if (-not (Test-Path -LiteralPath $source)) {
        throw "Skill '$Name' does not exist in $syncRoot."
    }

    $target = Join-Path $skillsHome $Name
    Backup-ExistingItem -Path $target
    New-Item -ItemType Junction -Path $target -Target $source | Out-Null
    Write-Host "Synced skill $Name"
}

New-Item -ItemType Directory -Path $CodexHome -Force | Out-Null
New-Item -ItemType Directory -Path $skillsHome -Force | Out-Null

switch ($Target) {
    "agents" {
        Sync-Agents
    }
    "skill" {
        if (-not $SkillName) {
            throw "When -Target skill is used, -SkillName is required."
        }
        Sync-Skill -Name $SkillName
    }
    "all" {
        Sync-Agents
        Get-ChildItem -LiteralPath (Join-Path $syncRoot "skills") -Directory | ForEach-Object {
            Sync-Skill -Name $_.Name
        }
    }
}

if (Test-Path -LiteralPath $backupRoot) {
    Write-Host "Backup created at $backupRoot"
}
Write-Host "Restart Codex to reload instructions and skills."

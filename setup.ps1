[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$syncRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$codexHome = Join-Path $HOME ".codex"
$skillsHome = Join-Path $codexHome "skills"
$backupRoot = Join-Path $codexHome ("sync-backup-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
$globalInstructions = Join-Path $syncRoot "AGENTS.md"
$syncedSkills = Join-Path $syncRoot "skills"

New-Item -ItemType Directory -Path $codexHome -Force | Out-Null
New-Item -ItemType Directory -Path $skillsHome -Force | Out-Null

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

$agentsTarget = Join-Path $codexHome "AGENTS.md"
Backup-ExistingItem -Path $agentsTarget
Copy-Item -LiteralPath $globalInstructions -Destination $agentsTarget

Get-ChildItem -LiteralPath $syncedSkills -Directory | ForEach-Object {
    $skillTarget = Join-Path $skillsHome $_.Name
    Backup-ExistingItem -Path $skillTarget
    New-Item -ItemType Junction -Path $skillTarget -Target $_.FullName | Out-Null
}

Write-Host "Codex global instructions and personal skills are now synced from:"
Write-Host "  $syncRoot"
if (Test-Path -LiteralPath $backupRoot) {
    Write-Host "Previous files were backed up to:"
    Write-Host "  $backupRoot"
}
Write-Host "Restart Codex to reload the instructions and skills."

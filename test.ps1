[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$testsPath = Join-Path $repoRoot "tests"

if (-not (Get-Module -ListAvailable -Name Pester)) {
    throw "Pester is required to run tests. Install or enable Pester, then rerun .\test.ps1."
}

if (-not (Test-Path -LiteralPath $testsPath)) {
    throw "Tests directory not found: $testsPath"
}

Invoke-Pester -Path $testsPath

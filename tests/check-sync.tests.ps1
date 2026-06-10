Describe "check-sync.ps1" {
    $repoRoot = Split-Path -Parent $PSScriptRoot
    $scriptPath = Join-Path $repoRoot "check-sync.ps1"

    function New-CodexHomeFixture {
        param(
            [string[]]$ExtraSkills = @(),
            [switch]$MirrorRepoSkills,
            [switch]$LinkRepoSkills,
            [string]$AgentsContent = $null
        )

        $root = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-sync-tests-" + [guid]::NewGuid().ToString("N"))
        $codexHome = Join-Path $root ".codex"
        $skillsHome = Join-Path $codexHome "skills"

        New-Item -ItemType Directory -Path $skillsHome -Force | Out-Null
        if ($null -ne $AgentsContent) {
            Set-Content -LiteralPath (Join-Path $codexHome "AGENTS.md") -Value $AgentsContent
        }
        else {
            Copy-Item -LiteralPath (Join-Path $repoRoot "AGENTS.md") -Destination (Join-Path $codexHome "AGENTS.md")
        }

        if ($MirrorRepoSkills) {
            Get-ChildItem -LiteralPath (Join-Path $repoRoot "skills") -Directory | ForEach-Object {
                $targetPath = Join-Path $skillsHome $_.Name
                New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
                Copy-Item -LiteralPath (Join-Path $_.FullName "SKILL.md") -Destination (Join-Path $targetPath "SKILL.md")
            }
        }

        if ($LinkRepoSkills) {
            Get-ChildItem -LiteralPath (Join-Path $repoRoot "skills") -Directory | ForEach-Object {
                $targetPath = Join-Path $skillsHome $_.Name
                New-Item -ItemType Junction -Path $targetPath -Target $_.FullName | Out-Null
            }
        }

        foreach ($skill in $ExtraSkills) {
            $skillPath = Join-Path $skillsHome $skill
            New-Item -ItemType Directory -Path $skillPath -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $skillPath "SKILL.md") -Value "# $skill"
        }

        return $root
    }

    function Remove-CodexHomeFixture {
        param(
            [string]$Root
        )

        if (Test-Path -LiteralPath $Root) {
            Remove-Item -LiteralPath $Root -Recurse -Force
        }
    }

    It "在推荐动作中使用当前仓库根目录脚本路径" {
        $fixtureRoot = New-CodexHomeFixture
        try {
            $codexHome = Join-Path $fixtureRoot ".codex"
            $report = & $scriptPath -CodexHome $codexHome -Format json | ConvertFrom-Json

            ($report.recommendedActions -join "`n") | Should Not Match "template\\apply-sync\.ps1"
            ($report.recommendedActions -join "`n") | Should Match "\.\\apply-sync\.ps1 -Target skill -SkillName"
        }
        finally {
            Remove-CodexHomeFixture -Root $fixtureRoot
        }
    }

    It "在只有一个额外本地 skill 时仍返回数组" {
        $fixtureRoot = New-CodexHomeFixture -ExtraSkills @("extra-one")
        try {
            $codexHome = Join-Path $fixtureRoot ".codex"
            $report = & $scriptPath -CodexHome $codexHome -Format json | ConvertFrom-Json

            @($report.extraLocalSkills).Count | Should Be 1
            $report.extraLocalSkills[0].name | Should Be "extra-one"
        }
        finally {
            Remove-CodexHomeFixture -Root $fixtureRoot
        }
    }

    It "在没有额外本地 skill 时返回空数组语义" {
        $fixtureRoot = New-CodexHomeFixture
        try {
            $codexHome = Join-Path $fixtureRoot ".codex"
            $json = & $scriptPath -CodexHome $codexHome -Format json

            $json | Should Match '"extraLocalSkills"\s*:\s*\[\s*\]'
        }
        finally {
            Remove-CodexHomeFixture -Root $fixtureRoot
        }
    }

    It "在只有一条建议动作时仍返回数组" {
        $fixtureRoot = New-CodexHomeFixture -LinkRepoSkills -AgentsContent "local override"
        try {
            $codexHome = Join-Path $fixtureRoot ".codex"
            $json = & $scriptPath -CodexHome $codexHome -Format json

            $json | Should Match '"recommendedActions"\s*:\s*\[\s*"AGENTS\.md can be refreshed from repo with \.\\\\apply-sync\.ps1 -Target agents"\s*\]'
        }
        finally {
            Remove-CodexHomeFixture -Root $fixtureRoot
        }
    }

    It "skills 字段在 JSON 中保持数组语义" {
        $fixtureRoot = New-CodexHomeFixture
        try {
            $codexHome = Join-Path $fixtureRoot ".codex"
            $report = & $scriptPath -CodexHome $codexHome -Format json | ConvertFrom-Json

            @($report.skills).Count | Should BeGreaterThan 0
            $report.skills[0].name | Should Not BeNullOrEmpty
        }
        finally {
            Remove-CodexHomeFixture -Root $fixtureRoot
        }
    }
}

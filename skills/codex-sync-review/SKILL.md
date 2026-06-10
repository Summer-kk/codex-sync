---
name: codex-sync-review
description: Use this skill when the user wants to check whether Codex global configuration is consistent across machines, compare the local version and repository version of AGENTS.md or shared skills, judge which version is better suited to become the standard, or guide synchronization without immediately applying local changes.
---

# Codex Sync Review

Use this skill when the user wants help reviewing a Codex sync template repo and the local `~/.codex` state without immediately changing local files.

## What this skill is for

This skill is the guidance layer for a Git-backed Codex configuration sync workflow.

It should:

- decide when to run the template's sync check
- interpret the JSON report
- compare local and repository versions when drift exists
- present a structured recommendation before any local mutation

It should not:

- reimplement the PowerShell sync logic
- silently update `~/.codex`
- embed platform-specific setup details that already live in the template repo

## Required workflow

1. Confirm the template repo path.
2. Run the repo's `check-sync.ps1 -Format json`.
3. Summarize:
   - `agents.status`
   - each `skills[].status`
   - `extraLocalSkills`
   - `recommendedActions`
4. If there is no drift, state that clearly.
5. If there is drift, compare the repository version and the local version before recommending any sync action.

## How to judge the better standard version

When local and repository versions differ, compare them using these criteria:

- whether the structure is clearer
- whether the rules are more complete
- whether the language is stable and suitable as a long-term standard
- whether one version reduces ambiguity and future maintenance cost

Do not default to "repository wins" or "local wins" without explaining why.

## Output shape

Use this structure:

1. `检查结果`
2. `详细差异`
3. `版本判断`
4. `建议操作`
5. `等待用户确认`

Always state that local `~/.codex` will not be changed before the user confirms.

# Codex Sync

一个面向 Codex 用户的开源模板仓库，用来在多台电脑之间同步全局 `AGENTS.md` 和个人 Skills，并通过脚本与自动化完成巡检、差异判断和人工确认后的同步。

## 适用对象

- 已经在使用 Codex 的个人用户
- 需要在多台设备之间保持全局规则一致的小团队
- 希望把 Codex 配置管理纳入 Git 工作流的用户

## 这个仓库解决什么

- 用 Git 管理全局 `AGENTS.md`
- 用仓库管理个人 Skills
- 用脚本检查本地 `~/.codex` 与仓库模板是否一致
- 在发现差异时，先判断“仓库版 / 本地版”谁更适合作为标准版本，再决定是否同步

## 这个仓库不解决什么

- 不同步对话历史
- 不同步认证信息，如 `auth.json`
- 不同步完整 `~/.codex` 目录
- 不提供跨平台统一安装器

## 快速开始

1. clone 本仓库
2. 在仓库根目录运行：

```powershell
.\setup.ps1
```

## 文件说明

- `AGENTS.md`：模板中的全局自定义指令
- `skills/`：模板中共享的个人 Skills
- `setup.ps1`：新机器第一次接入
- `check-sync.ps1`：巡检本地配置与模板是否一致
- `apply-sync.ps1`：在用户确认后，将模板内容同步到本地

## 示例 Skill

仓库中保留了一个 `find-skills` 作为示范 skill，用来展示：

- 共享个人 skill 如何随模板一起分发
- `check-sync.ps1` 如何检查 skill 的联接和内容状态
- `apply-sync.ps1` 如何按单个 skill 执行同步

除了这个示范 skill，仓库还包含 `codex-sync-review`，它负责指导 Codex 如何巡检、解读差异并做版本判断。

## 日常使用流程

1. 拉取模板最新内容：

```powershell
git pull --ff-only
```

2. 检查本地配置与模板是否一致：

```powershell
.\check-sync.ps1
```

3. 如果存在差异，先判断哪一版更适合作为标准版本，再决定是否同步。

如果要把模板中的全部配置同步到本地：

```powershell
.\apply-sync.ps1 -Target all
```

如果只同步全局自定义指令：

```powershell
.\apply-sync.ps1 -Target agents
```

如果只同步 `codex-sync-review`：

```powershell
.\apply-sync.ps1 -Target skill -SkillName codex-sync-review
```

如果只同步示范 skill `find-skills`：

```powershell
.\apply-sync.ps1 -Target skill -SkillName find-skills
```

## 安全边界

- `check-sync.ps1` 可以自动运行
- `apply-sync.ps1` 必须作为用户确认后的动作运行
- 自动化默认只巡检和汇报，不应在后台直接改本地配置

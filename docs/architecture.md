# Architecture Overview

## System Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        HarnessTemplates Repo                        │
│                                                                     │
│  bin/harness ────────────────────────────────────────────────────── │
│  (single-file CLI, ~1475 lines bash)                               │
│       │                                                             │
│       ├── cmd_init()          deploy templates ──► user project     │
│       ├── cmd_upgrade()       pull upstream updates                 │
│       ├── cmd_status()        show feature progress                 │
│       └── ...18 commands total                                      │
│                                                                     │
│  .harness/templates/ ─── source of truth for deployed files         │
│  .harness/scripts/ ───── hook scripts deployed alongside            │
│  .harness/reference/ ──── reference docs for AI agents              │
│  install.sh ───────────── curl | bash installer                     │
│  tests/ ────────────────── BATS test suite                          │
└─────────────────────────────────────────────────────────────────────┘

                            │ harness init
                            ▼

┌─────────────────────────────────────────────────────────────────────┐
│                         User's Project                              │
│                                                                     │
│  Root files (from templates):                                       │
│    CLAUDE.md               AI agent root instructions               │
│    init.sh                 environment init (install/verify/start)   │
│    feature_list.json       feature tracking with status             │
│    claude-progress.md      cross-session progress log               │
│    autonomous-loop.md      self-iteration protocol                  │
│    self-eval-trigger.md   self-evaluation protocol                  │
│    evaluator-rubric.md     quality scoring rubric                   │
│                                                                     │
│  .harness/                                                          │
│    config.json              harness version + file classification   │
│    templates/               upstream originals (diff baseline)      │
│    scripts/                 hook scripts + check-harness.sh         │
│    reference/               reference docs for AI                   │
│    plans/active/            execution plans                         │
│    plans/completed/         finished plans                          │
│    histories/               change records (by month)               │
│                                                                     │
│  .claude/                                                           │
│    settings.local.json      Claude Code hooks config                │
│                                                                     │
│  .git/hooks/                                                        │
│    pre-commit               harness state validation                │
└─────────────────────────────────────────────────────────────────────┘
```

## Data Flow: `harness init`

```
User runs: harness init [--local]

  1. Check .harness/config.json doesn't already exist (refuse reinit)
  2. Ensure .git exists (auto git init if needed)
  3. Create directory structure:
     .harness/{templates,scripts,plans/{active,completed},histories,reference}
  4. Copy framework files → project root (6 files)
     Source: --local → local .harness/templates/
             default → fetch from GitHub raw URL
  5. Copy data files → project root (2 files)
  6. Copy scaffold templates → .harness/templates/
  7. Copy reference docs → .harness/reference/ (8 files)
  8. Copy hook scripts → .harness/scripts/ (5 files)
  9. Deploy .claude/settings.local.json (hooks config)
 10. Install .git/hooks/pre-commit
 11. Generate .harness/config.json (version, project name, detected commands)
 12. Update .gitignore (idempotent)
```

## Three-Tier File Classification

```
┌────────────────────────────────────────────────────────────────┐
│ Framework Files (auto-updated by upgrade)                      │
│                                                                │
│  CLAUDE.md  AGENTS.md  init.sh  evaluator-rubric.md            │
│  autonomous-loop.md  self-eval-trigger.md                      │
│                                                                │
│  Upgrade behavior:                                             │
│    - Not customized → auto-update                              │
│    - Customized → interactive prompt (adopt/keep/skip)         │
│    - --auto flag → skip customized files silently              │
├────────────────────────────────────────────────────────────────┤
│ Data Files (never touched by upgrade)                          │
│                                                                │
│  feature_list.json  claude-progress.md                         │
│                                                                │
│  Upgrade behavior: always skipped, always preserved             │
├────────────────────────────────────────────────────────────────┤
│ Scaffold Files (added if missing)                              │
│                                                                │
│  plan-template.md  history-template.md                         │
│                                                                │
│  Upgrade behavior: created if absent, not overwritten           │
└────────────────────────────────────────────────────────────────┘
```

## Hooks Execution Chain

```
┌─────────────────────────────────────────────────────────────┐
│ Claude Code Session Lifecycle                                │
│                                                             │
│  SessionStart                                               │
│    └── .harness/scripts/session-start.sh                    │
│        ├── Touch .harness/.session-start                    │
│        ├── Auto chmod +x on init.sh, scripts/               │
│        ├── Print project info from config.json              │
│        └── Report feature status from feature_list.json     │
│                                                             │
│  PostToolUse (matches: Write|Edit)                          │
│    └── .harness/scripts/hook-guard.sh post-edit             │
│        ├── Check if any feature is in_progress              │
│        ├── Warn if no active plan for in_progress feature   │
│        └── Output warning to agent                          │
│                                                             │
│  Stop (session ending)                                      │
│    └── .harness/scripts/hook-guard.sh pre-stop              │
│        ├── Check claude-progress.md was updated this session│
│        └── Warn agent to update before leaving              │
├─────────────────────────────────────────────────────────────┤
│ Git Lifecycle                                               │
│                                                             │
│  pre-commit                                                 │
│    └── .git/hooks/pre-commit                                │
│        ├── Validate feature_list.json is valid JSON         │
│        ├── Validate claude-progress.md exists               │
│        └── Block commit if validation fails                 │
└─────────────────────────────────────────────────────────────┘
```

## Feature State Machine

```
                    ┌─────────────────────────────────────┐
                    │  feature_list.json._status:         │
                    │  awaiting_requirements               │
                    └──────────────┬──────────────────────┘
                                   │ AI discusses requirements
                                   │ with user, writes features
                                   │ User confirms
                                   ▼
                    ┌─────────────────────────────────────┐
                    │  feature_list.json._status: active   │
                    │                                      │
                    │  Per-feature states:                  │
                    │                                      │
                    │  not_started ──► in_progress          │
                    │       ▲              │  │             │
                    │       │              │  │ verified    │
                    │       │              │  ▼             │
                    │       │     blocked ◄─┤  passing       │
                    │       │       │       │                │
                    │       │       │ fix   │ escalation     │
                    │       └───────┘       ▼                │
                    │                  (next feature)        │
                    └─────────────────────────────────────┘

Rules:
  - Only ONE feature in_progress at a time
  - passing requires evidence in feature_list.json
  - passing requires review against review-checklist.md
  - blocked requires blocked_reason recorded
  - Consecutive 2 blocked → escalation to human
```

## Upgrade Strategy

```
harness upgrade [--auto] [--dry-run] [--local]

  1. Fetch upstream templates from GitHub (or use local)
  2. For each framework file:
     ├── Same as upstream → skip (no changes)
     ├── Not customized → auto-update
     ├── Customized + --auto → skip with warning
     └── Customized + interactive → show diff, ask adopt/keep/skip
  3. Update scripts (always, backup first)
  4. Update .claude/settings.local.json
  5. Update .git/hooks/pre-commit (if harness-managed)
  6. Update reference docs (always, if changed)
  7. Update version in config.json
  8. Run check-harness.sh for validation
```

## Customization Tracking

```
harness customize CLAUDE.md
  → adds "CLAUDE.md" to config.json customized_files[]
  → upgrade skips this file (or shows interactive diff)

harness uncustomize CLAUDE.md
  → removes from customized_files[]
  → upgrade will auto-update this file

harness diff CLAUDE.md
  → compares project root CLAUDE.md vs .harness/templates/CLAUDE.md

harness adopt CLAUDE.md
  → copies .harness/templates/CLAUDE.md to project root
  → removes from customized_files[]
```

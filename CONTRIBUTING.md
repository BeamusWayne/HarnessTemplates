# Contributing to HarnessTemplates

Thank you for your interest in contributing! This guide covers everything you need to get started.

## Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/BeamusWayne/HarnessTemplates.git
cd HarnessTemplates

# 2. Install test framework
brew install bats-core          # macOS
# npm install -g bats-core      # alternative

# 3. Run tests to verify setup
bats tests/

# 4. Test the CLI locally
bin/harness version
cd /tmp && /path/to/HarnessTemplates/bin/harness init --local
```

## Project Overview

HarnessTemplates is a scaffolding tool that gives AI coding agents long-running task continuity. It has two audiences:

- **Users** install the CLI via `curl | bash` and run `harness init` in their projects
- **Contributors** modify the source code in this repository

The single-file CLI (`bin/harness`) deploys templates from `.harness/templates/` into user projects.

## Development Setup

### Prerequisites

| Requirement | Version | Purpose |
|-------------|---------|---------|
| Bash | 4+ | CLI runtime |
| bats-core | latest | Test framework |
| curl | any | Testing remote fetch |
| git | any | Version control |

### Testing

```bash
# All tests
bats tests/

# Specific test file
bats tests/test_init.bats

# Multiple matching files
bats tests/test_*hook*.bats
```

### Local Development

The `--local` flag is your main development tool. It copies templates from the local repo instead of fetching from GitHub:

```bash
# Create a test project
mkdir /tmp/test-harness && cd /tmp/test-harness

# Initialize from local templates
/path/to/HarnessTemplates/bin/harness init --local

# Test the result
harness status
harness check
harness doctor

# Test upgrade from local
harness upgrade --local --dry-run
```

## Codebase Structure

```
bin/harness              # CLI entry point (~1475 lines, single file)
install.sh               # curl | bash installer
.harness/templates/      # Template files deployed to user projects
.harness/scripts/        # Hook scripts deployed to user projects
.harness/reference/      # Reference docs deployed to user projects
tests/                   # BATS test suite (13 test files + test helper)
docs/                    # Design documents and plans
```

## How to Contribute

### Adding a New Command

1. Add `cmd_<name>()` function in `bin/harness`
2. Add description in `cmd_help()`
3. Add dispatch line in the `case` statement at file end
4. Add `tests/test_<name>.bats`
5. Update README command table if needed

### Fixing a Bug

1. Write a failing test first (BATS)
2. Fix the bug
3. Verify the test passes
4. Run full test suite: `bats tests/`

### Modifying Templates

1. Edit files in `.harness/templates/`
2. Ensure `tests/test_init.bats` still passes
3. Update `.harness/reference/index.md` if adding new reference docs

## Conventions

### Code Style

- Single-file CLI: do not split `bin/harness` into multiple files (intentional for zero-dependency distribution)
- JSON parsing uses grep/sed/awk (no jq dependency, by design)
- All write operations use temp file + atomic mv
- Logging via `log_info`/`log_success`/`log_warn`/`log_error`
- Each command starts by checking `.harness/config.json` exists

### Commit Messages

```
<type>: <description>

Types: feat, fix, refactor, docs, test, chore, perf
```

Write commit messages in English, even though template content and CLI output are in Chinese.

### Branch Strategy

- `main` — stable release branch
- `feat/<name>` — new features
- `fix/<name>` — bug fixes
- PR to `main` for all changes

### File Classification

The harness treats user project files in three categories:

| Category | Examples | Upgrade behavior |
|----------|----------|------------------|
| Framework | CLAUDE.md, init.sh | Auto-updated unless customized |
| Data | feature_list.json, claude-progress.md | Never touched |
| Scaffold | plan-template.md | Added if missing |

## Architecture

See [docs/architecture.md](./docs/architecture.md) for the full architecture overview.

## Security

- Never commit secrets, API keys, or tokens
- The CLI uses only public GitHub APIs (no token required)
- All file writes use atomic operations (temp file + mv)
- Review `install.sh` changes carefully — users run it via `curl | bash`

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](./LICENSE).

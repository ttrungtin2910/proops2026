# Topic: Git

**Last Updated:** 2026-04-03

**Governed by:** IRD-001 (Git Standards) — https://www.notion.so/33664e2cb7a88197acefc82b05e4acf9

---

## Core Concepts

- **Git is a DAG of snapshots, not diffs.** Each commit is a full snapshot of the repo at that point in time, with a pointer to its parent. Branches are just named pointers to commits — they're cheap and disposable.
- **`main` is sacred.** It always reflects deployable state. No one pushes directly to it. Everything enters via PR + squash merge.
- **Squash merge keeps history readable.** One feature = one commit on `main`. The messy in-progress commits on the feature branch don't matter — what matters is the clean story on `main`.
- **Staging area is a checkpoint, not a buffer.** `git add <file>` is a deliberate act — it means "I've reviewed this and it's ready." Never use `git add .` blindly.
- **Rebasing rewrites history — use with care.** Rebase feature branches onto `main` to stay current, but never rebase anything already pushed to a shared branch.
- **Tags are permanent markers.** Use `v1.0.0` for releases, `week-N-complete` for training milestones. Tags on `main` only.

---

## Key Commands / Config Patterns

```bash
# Start new feature work
git checkout -b feat/w1-short-description

# Stage specific files (never git add .)
git add path/to/file1 path/to/file2

# Commit with Conventional Commits format
git commit -m "feat(scope): short description under 72 chars"

# Push feature branch and set upstream
git push -u origin feat/w1-short-description

# Update feature branch with latest main (rebase, not merge)
git fetch origin
git rebase origin/main

# Force push feature branch after rebase (never on main)
git push --force-with-lease origin feat/w1-short-description

# Tag a week completion on main
git tag week-1-complete
git push origin week-1-complete

# Clean up merged branch locally
git branch -d feat/w1-short-description

# See what's staged vs unstaged
git diff --staged   # what will be committed
git diff            # what's changed but not staged

# Undo last commit but keep changes staged
git reset --soft HEAD~1

# Check which files would be committed (dry run)
git status
```

```bash
# Useful git log aliases — add to ~/.gitconfig
# git log --oneline --graph --decorate --all
# Shows visual branch history in terminal
git log --oneline --graph --decorate --all
```

```ini
# ~/.gitconfig — recommended settings
[core]
    autocrlf = input        # normalize line endings on commit (Windows)
[pull]
    rebase = true           # git pull rebases instead of merges
[push]
    default = current       # push current branch to same-name remote
[init]
    defaultBranch = main
```

---

## Conventional Commits Cheatsheet

Format: `type(scope): description`

| Type | Use for |
|------|---------|
| `feat` | New artifact — Dockerfile, K8s manifest, Terraform module, pipeline |
| `fix` | Broken config, failing script, bad flag |
| `docs` | IRD, DOP, README, daily log, memory file |
| `chore` | .gitignore, dependency bump, tooling config |
| `refactor` | Restructure without behavior change |
| `test` | Test additions or corrections |
| `ci` | Pipeline config changes |

**Scope examples:** `docker`, `k8s`, `terraform`, `pipeline`, `ird`, `memory`

Good: `docs(ird): add IRD-001 Git Standards to Notion`
Good: `feat(docker): add multi-stage Dockerfile for Node app`
Bad: `update stuff` — no type, no scope, no info

---

## Branch Naming (IRD-001)

| Type | Pattern | Example |
|------|---------|---------|
| Feature | `feat/{week}-{description}` | `feat/w1-ird-001` |
| Fix | `fix/{description}` | `fix/broken-entrypoint` |
| Docs | `docs/{description}` | `docs/training-spec-update` |
| Chore | `chore/{description}` | `chore/update-gitignore` |

---

## Common Gotchas

- **`git pull` with default merge creates noise.** Always configure `pull.rebase = true` so `git pull` rebases instead of creating a merge commit.
- **`--force` vs `--force-with-lease`.** `--force` overwrites the remote blindly. `--force-with-lease` fails if someone else pushed — much safer. Use `--force-with-lease` always.
- **Committing `.env` or `*.tfstate` is permanent (without rewriting history).** Always have `.gitignore` in place before the first commit. Add `*.env`, `.terraform/`, `*.tfstate` on day one.
- **Squash merge on GitHub loses the feature branch commit SHAs.** That's fine — the squash commit on `main` is the canonical record. Don't try to cherry-pick individual commits from a squashed branch.
- **`git reset --hard` is destructive.** It discards uncommitted changes permanently. Use `--soft` to undo commits while keeping changes staged, or `--mixed` to unstage them.
- **Windows line endings (CRLF) break shell scripts in containers.** Set `core.autocrlf = input` in `.gitconfig` to normalize on commit.
- **Detached HEAD state** happens when you checkout a commit or tag directly. You're not on any branch — commits here will be orphaned. Always `git checkout -b new-branch` if you need to make changes.

---

## When To Use This

- **Every artifact commit** — branch naming, commit message format, staging by file name (not `git add .`)
- **CI/CD pipeline config** — pipelines trigger on branch patterns (`feat/*`, `main`); branch naming must match the trigger rules
- **Before opening a PR** — rebase onto `main`, squash WIP commits, verify commit message format
- **Tagging a training milestone** — `week-N-complete` tag on `main` after all week artifacts are merged
- **Post-incident** — `git log --oneline` and `git blame` to trace when a bad config was introduced

---

## Claude Prompts That Worked Well

- Prompt: `"I'm on branch feat/w1-ird-001. I need to update it with the latest main and push. Walk me through it step by step following IRD-001."`
  - Why it worked: Explicit branch name + IRD reference forces Claude to follow the squash/rebase standard instead of suggesting a merge

- Prompt: `"Generate a .gitignore for a repo that will contain Terraform, Docker, Python, and secrets. Follow my IRD-001 required entries."`
  - Why it worked: Scoping to IRD-001 prevents Claude from generating a generic .gitignore that misses tfstate or .env files

---

## Links to Related Memory Files

- See also: `memory/cicd.md` — pipelines trigger on Git branch/tag patterns; Git standards directly affect pipeline behavior
- See also: `memory/iac.md` — Terraform state files (`.tfstate`) must never be committed; `.gitignore` is the first line of defense
- See also: `memory/git-team-workflow.md` — PR workflow, code review standards, branch protection rules (Week 5–6)

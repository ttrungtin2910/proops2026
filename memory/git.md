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

---

## Six Core Commands — Full Flag Reference

### clone
```bash
git clone https://github.com/org/repo.git            # clone to folder named "repo"
git clone https://github.com/org/repo.git mydir      # clone to custom folder
git clone --depth 1 https://github.com/org/repo.git  # shallow clone — CI speed, no history
git clone -b develop https://github.com/org/repo.git # clone specific branch
```
A branch is a text file containing one commit hash — a pointer, not a copy.
`--depth 1` clones only the latest snapshot. Use in CI where full history wastes time.

### add
```bash
git add src/auth/login.js    # stage one file
git add src/auth/            # stage entire directory
git add -p                   # interactive: stage hunks one at a time
git add -u                   # stage modified/deleted tracked files (not new)
```
`-p` is the most important flag: review and stage partial changes, not the whole file.
Never use `git add .` — you will accidentally stage `.env` files and secrets.

### commit
```bash
git commit -m "feat(auth): add login handler"
git commit --amend --no-edit        # add staged changes into last commit (before push only)
git commit --amend -m "new message" # reword last commit message (before push only)
```
Amend rewrites the last commit. Never amend after pushing — rewrites shared history.

### push
```bash
git push origin main
git push -u origin feature/login              # push + set upstream tracking
git push --force-with-lease origin feature/x  # safe force push
git push origin --delete feature/old-branch   # delete remote branch
```
`--force-with-lease` is safer than `--force`. Fails if someone else pushed since your
last fetch — prevents overwriting their work.

### pull
```bash
git pull origin main                 # fetch + merge
git pull --rebase origin main        # fetch + rebase (linear history, no merge commit)
git pull --ff-only origin main       # fail if not fast-forward (safe for main)
git fetch origin                     # fetch without touching working tree
```
`pull --rebase` keeps history linear. `--ff-only` refuses merge commits — safe for main.

### branch
```bash
git branch                           # list local branches
git branch -avv                      # all branches + remote tracking + ahead/behind
git branch -d feature/login          # delete merged branch
git branch -D feature/login          # force delete unmerged branch
git branch -m old-name new-name      # rename branch
```
`-avv` is the first command to run when diagnosing "pipeline didn't trigger" —
shows which commits are local-only (ahead) vs already on the remote.

---

## Branch Operations

### Create and switch
```bash
git checkout -b feature/login        # create and switch (universal)
git switch -c feature/login          # new syntax (git 2.23+)
git checkout -                       # switch to previous branch
```

### Merge — preserves full history
```bash
git checkout main
git pull origin main
git merge feature/login              # merge commit if histories diverged
git merge --no-ff feature/login      # always create merge commit
git push origin main
```

History shape:
```
Before:  main:    A <- B <- C
         feature: A <- B <- D <- E

After:   main:    A <- B <- C <- M    (M has two parents: C and E)
```

### Rebase — rewrites history, linear result
```bash
git checkout feature/login
git rebase origin/main               # replay feature commits on top of main
git rebase --continue                # after resolving a conflict
git rebase --abort                   # cancel entirely
git checkout main
git merge feature/login              # fast-forward, no merge commit
git push origin main
```

History shape:
```
Before:  main:    A <- B <- C
         feature: A <- B <- D <- E

After:   main:    A <- B <- C <- D' <- E'   (D,E replaced with new hashes)
```

### Interactive rebase — clean up before PR
```bash
git rebase -i origin/main
# Change "pick" to "squash" on WIP commits
# Result: multiple messy commits collapsed into one clean commit
```

### When to use which

| Situation | Use |
|---|---|
| Merging feature into main | Merge — preserves branch history |
| Syncing feature with latest main | Rebase — keeps history linear |
| Cleaning WIP commits before PR | Interactive rebase + squash |
| Branch is shared (others have pulled) | Merge — NEVER rebase shared branches |
| Branch is yours only, not yet shared | Rebase preferred |

---

## Conflict Resolution Step-by-Step

```bash
git merge feature/login
# CONFLICT (content): Merge conflict in src/auth/login.js
```

Conflict markers inside the file:
```
<<<<<<< HEAD
  if (!user || !user.active) {
    return res.status(401).json({ error: 'Invalid credentials' })
  }
=======
  if (!user) {
    return res.status(403).json({ error: 'Forbidden' })
  }
>>>>>>> feature/login
```

```
<<<<<<< HEAD          = your current branch version
=======               = divider between versions
>>>>>>> feature/login = incoming branch version
```

Steps:
```bash
# Step 1: see all conflicted files
git status

# Step 2: edit the file — delete all three marker lines, write correct merged code

# Step 3: stage the resolved file
git add src/auth/login.js

# Step 4: complete the merge
git merge --continue
# OR cancel entirely:
git merge --abort
```

For rebase conflicts — same edit process, different completion command:
```bash
git add src/auth/login.js
git rebase --continue    # replay next commit
git rebase --abort       # cancel entire rebase
```

---

## Revert vs Reset

### Starting state
```
git log --oneline -3
a4f2e11 (HEAD -> main) Merge branch 'feature/login'   <- broke production
f1a9b44 last stable commit
```

### git revert — SAFE on shared branches
```bash
git revert -m 1 a4f2e11   # -m 1: merge commit, parent 1 is main
git push origin main       # normal push, no force needed
```

History after revert:
```
Before: ...-- C -- M             (M broke prod)
After:  ...-- C -- M -- R        (R undoes M, both preserved in history)
```

R is a new commit. Every developer who pulled M can `git pull` and receive R normally.

### git reset — DANGEROUS on shared branches
```bash
git reset --soft  HEAD~1   # undo commit, keep changes STAGED
git reset --mixed HEAD~1   # undo commit, keep changes UNSTAGED (default)
git reset --hard  f1a9b44  # move pointer back, DISCARD all changes

git push --force-with-lease origin main   # required after reset
```

History after reset:
```
Before: ...-- C -- M
After:  ...-- C          (M erased from branch history)
              M           (dangling object, GC'd in ~30 days)
```

Why reset is dangerous on shared branches: Developer A already pulled M. After your
force-push, origin/main ends at C. Their `git pull` sees M locally but not on remote,
creates a new merge commit re-introducing M — your rollback is undone.

### The rule
```
Commit already on a shared branch others have pulled?
  YES -> git revert   (production rollback at 3am: always revert)
  NO  -> git reset    (local cleanup, private branches only)
```

---

## Finding Bug Commits

```bash
# Bound the search range
git log --oneline f1a9b44..a4f2e11

# Filter by file
git log --oneline -- src/auth/login.js

# Find commit that added/removed a specific string (most powerful)
git log --oneline -S "validateToken"

# Show diffs inline with log
git log -p -- src/auth/login.js

# Inspect one commit
git show a4f2e11
git diff f1a9b44 a4f2e11 -- src/auth/login.js
git diff --name-status f1a9b44 a4f2e11

# Binary search — use when range > 10 commits or bug is behavioral
git bisect start
git bisect bad                      # HEAD is broken
git bisect good f1a9b44             # last known good
git bisect run /tmp/test.sh         # automated: exit 0=good, exit 1=bad
git bisect reset                    # always run when done
```

---

## DevOps-Specific Git Workflow

Every DevOps artifact — Dockerfiles, Terraform, K8s manifests, CI/CD pipelines —
gets the same branch and commit discipline as application code. Infrastructure
changes have equal or higher blast radius.

### Dockerfile
```bash
git checkout -b feat/w2-dockerfile-nodeapp

git commit -m "feat(docker): add multi-stage Dockerfile for node-api"
git commit -m "fix(docker): pin node image to 20.11-alpine (was latest)"
git commit -m "chore(docker): add .dockerignore to exclude node_modules"

# Revert a bad Dockerfile — clean audit trail
git revert HEAD && git push origin main
```

Always commit with Dockerfile:
```
Commit:  Dockerfile, .dockerignore, docker-compose.yml
Never:   .env, *.pem, *.key, node_modules/
```

### Terraform
```bash
git checkout -b feat/w4-s3-bucket-logging

terraform fmt        # format first — commit only formatted .tf files
terraform validate   # never commit invalid HCL
terraform plan       # paste plan output in PR description

git add terraform/s3.tf terraform/variables.tf
git commit -m "feat(terraform): add S3 access logging bucket"
```

```
Commit:  *.tf, terraform.tfvars.example, .terraform.lock.hcl
Never:   terraform.tfstate, terraform.tfvars, .terraform/
```

### Kubernetes manifests
```bash
git checkout -b feat/w3-k8s-deploy-api

kubectl apply --dry-run=client -f k8s/   # validate before committing
# Never commit manifests that fail dry-run

git add k8s/deployment.yaml k8s/service.yaml k8s/ingress.yaml
git commit -m "feat(k8s): add deployment for api-service (3 replicas, resource limits)"
```

### CI/CD pipeline files
```bash
git commit -m "feat(ci): add docker build and push stage to GitHub Actions"
git commit -m "fix(ci): pin actions/checkout to v4"
# Never commit secrets in pipeline YAML — use repository secrets or vault references
```

### Daily workflow
```bash
# Start of day
git fetch origin && git log --oneline -5

# New work
git checkout -b feat/w1-description
git add -p                               # review every hunk before staging
git commit -m "type(scope): description"
git push -u origin feat/w1-description

# Sync with latest main mid-work
git fetch origin && git rebase origin/main

# Production incident rollback
git log --oneline -S "suspect_string"    # find the bad commit
git revert -m 1 <merge-commit-hash>      # undo safely
git push origin main

# Cleanup
git bisect reset                         # if bisect was running
git branch -d feat/merged-branch        # remove stale local branch
```

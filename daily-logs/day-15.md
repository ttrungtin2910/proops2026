# Daily Log — Tin (Trần Trung Tín) — Day 15 — 06 May 2026

## Today's Assignment (Day 15 — Helm Intro: Package Manager for Kubernetes)
- [x] Q1 — Why manual Redis YAML is dangerous: list every K8s object needed, estimate line count, identify the maxmemory production gotcha
- [x] Q2 — Helm chart structure: what `helm create` generates, explain every file (Chart.yaml, values.yaml, templates/*, _helpers.tpl, NOTES.txt, .helmignore)
- [x] Q3 — Dot-notation deep dive: `.Values.image.tag` path from values.yaml → deployment.yaml; what happens when a key doesn't exist
- [x] Q4 — helm repo add bitnami + inspect: `helm show values bitnami/redis | grep` workflow; identify 3 override keys for the project
- [x] Q5 — Write my-redis-values.yaml with only 3 overrides (auth.existingSecret, persistence.size, resources); why NOT --set for passwords
- [x] Q6 — helm install workflow: read NOTES.txt, verify with kubectl get pods/svc, service name pattern `[release-name]-[chart-component]`
- [x] Q7 — Connect qna-agent: update REDIS_URL in ConfigMap, kubectl rollout restart, test from inside Pod
- [x] Q8 — Helm release model: helm list, helm history, where Helm stores history (K8s Secrets in etcd), helm rollback vs kubectl rollout undo
- [x] Q9 — Upgrade → rollback workflow: good upgrade (revision 2), bad upgrade (revision 3 failed), rollback (revision 4); write memory/helm-basics.md

## Environment
Windows 11 Pro, Claude Code CLI inside VSCode. minikube running with Docker driver — all 11 services (Day 14 stack) still Running 1/1. Helm 3.x installed via `winget install Helm.Helm`. Day 15 replaced raw `k8s/infra/redis.yaml` with `bitnami/redis` Helm chart (release `my-redis`). Full upgrade → rollback cycle completed. Practice directory `k8s/helm/` created with 5 annotated exercises.

---

## Completed

- [x] **Q1 — Manual Redis YAML: all objects + maxmemory gotcha:**

  Redis on K8s requires 6 objects: StatefulSet (~60 lines), Service ClusterIP (~15), Service Headless (~12), PersistentVolumeClaim via volumeClaimTemplates (~15), ConfigMap for redis.conf (~25), Secret for AUTH (~10). **Total: ~137 lines standalone mode.** Redis Sentinel adds ~80 more lines; Redis Cluster multiplies to 6 StatefulSets + 12 Services.

  **Why StatefulSet, not Deployment:** Deployment treats Pods as interchangeable — Pod dies, new Pod gets random name, old volume left behind. StatefulSet gives each Pod a stable name (`redis-0`, `redis-1`) and stable PVC mapping. `redis-0` killed and recreated → same volume re-attaches → data persists. Redis Sentinel/Cluster requires stable DNS per replica to know which instance is which.

  **The maxmemory production gotcha:** Writing YAML by hand, you won't add `maxmemory` and `maxmemory-policy` to redis.conf unless you've been OOMKilled before. Redis writes until node memory is full → Linux OOM killer targets Redis process → Pod restarts → data lost. K8s reports `OOMKilled` only after the fact. Required ConfigMap entries:
  ```
  maxmemory 256mb
  maxmemory-policy allkeys-lru
  ```
  With Helm `bitnami/redis`: setting `master.resources.limits.memory=512Mi` automatically maps to `maxmemory 512mb` in the generated redis.conf. Operator knowledge baked into chart values — cannot forget.

  **Security patch risk (7.2.3 → 7.2.4):** Files that change: StatefulSet image tag, possibly redis.conf in ConfigMap, CI digest pin. Five risks: forgetting `kubectl rollout restart` (old Pod stays up), digest pin not updated (K8s serves cached old image silently), patch changes a config key name (Pod crashloops), updating master but not replica StatefulSet (split versions), no backup before patch (data format incompatibility).

  **What Helm does NOT solve:** application code, data migration between major versions (Redis 6 → 7 RDB format change), backup strategy, restore testing, maxmemory-policy choice, capacity planning. Helm installs the service. Day-2 operations are always yours.

- [x] **Q2 — helm create structure: every file explained:**

  ```
  myapp/
  ├── Chart.yaml          metadata: name, version, appVersion, description (required)
  ├── values.yaml         all defaults; user overrides via --set or -f file
  ├── .helmignore         like .gitignore — excludes files from helm package
  └── templates/
      ├── deployment.yaml   K8s Deployment — references .Values.*
      ├── service.yaml      K8s Service
      ├── ingress.yaml      disabled by default (ingress.enabled: false)
      ├── serviceaccount.yaml
      ├── hpa.yaml          disabled by default
      ├── _helpers.tpl      named templates — NOT rendered (leading _ prefix)
      └── NOTES.txt         printed after helm install — contains hostname + test cmds
  ```

  **CHART VERSION vs APP VERSION:** bitnami/redis chart version `19.6.2` packages Redis app version `7.2.5`. They are independent — chart version increases when chart logic changes, app version increases when Redis itself releases. Pin chart version, not app version directly.

- [x] **Q3 — Dot-notation and key-not-found behavior:**

  Path trace from values.yaml to deployment.yaml:
  ```
  .Values.image.tag
  │       │     └── field: "tag" key in the "image" map
  │       └── key: "image" — nested map in values.yaml
  └── root: .Values — entire values.yaml content
  ```
  Context object `.` also contains `.Chart` (Chart.yaml content), `.Release` (release name/namespace), `.Files` (chart package files).

  **Key doesn't exist → empty string, no error.** Typo in key name → silent empty value → manifest applied → app fails at runtime with no Helm warning. Fix: use `required`:
  ```
  {{ .Values.image.repository | required "image.repository is required" }}
  ```

  **_helpers.tpl — leading underscore:** Helm renders all files in `templates/` as manifests EXCEPT files starting with `_`. Underscore = helper library, not a manifest. If named `helpers.tpl` (no underscore), Helm tries to render it as YAML and fails. Named templates (`{{- define "myapp.fullname" -}}`) are reusable functions — define once, call with `include` everywhere.

  **Whitespace trimming:** `{{-` strips leading whitespace, `-}}` strips trailing whitespace. Without these, rendered YAML has extra blank lines.

  **Dry-run discipline:** `helm template . --debug` is mandatory before every `helm install`. `--debug` shows computed values (merge of defaults + overrides) + which template is being rendered + exact error location if template fails.

- [x] **Q4 — helm repo add bitnami + inspect workflow:**

  ```powershell
  helm repo add bitnami https://charts.bitnami.com/bitnami
  helm repo update
  helm search repo redis   # shows CHART VERSION + APP VERSION + DESCRIPTION
  helm show values bitnami/redis | Select-String -Context 0,10 "^auth:"
  helm show values bitnami/redis | Select-String -Context 0,8 "persistence:"
  helm show values bitnami/redis | Select-String -Context 0,8 "resources:"
  ```

  Three keys identified for project override:

  | Need | Chart key | Reason |
  |---|---|---|
  | Auth credential | `auth.existingSecret` + `auth.existingSecretPasswordKey` | Don't put password in values file |
  | Persistence size | `master.persistence.size` | Default 8Gi, dev needs 1Gi |
  | Resource limits | `master.resources.limits` + `master.resources.requests` | Fit dev node, trigger maxmemory calc |
  | maxmemory safety | `master.extraFlags` | Prevent OOMKilled |

- [x] **Q5 — my-redis-values.yaml: 3 overrides only + why NOT --set:**

  File at `k8s/helm/my-redis-values.yaml`:
  ```yaml
  auth:
    enabled: true
    existingSecret: "redis-auth-secret"
    existingSecretPasswordKey: "redis-password"

  master:
    persistence:
      size: 1Gi
    resources:
      limits: { cpu: 200m, memory: 256Mi }
      requests: { cpu: 100m, memory: 128Mi }
    extraFlags:
      - "--maxmemory 200mb"
      - "--maxmemory-policy allkeys-lru"

  replica:
    replicaCount: 0
  ```

  **Why NOT `--set auth.password=xxx`:**
  1. Shell history: stored permanently in `~/.bash_history` or `~/.zsh_history` — any user with read access sees plaintext password
  2. etcd leak: Helm encodes all values into the release Secret (`sh.helm.release.v1.my-redis.v1`); anyone with `kubectl get secret` in that namespace reads the merged values including the password

  Correct pattern: `kubectl create secret generic redis-auth-secret --from-literal=redis-password=<value>` → value never touches a file, values.yaml only references the Secret name.

- [x] **Q6 — helm install + NOTES.txt + service naming:**

  ```powershell
  # Dry-run mandatory
  helm template my-redis bitnami/redis -f my-redis-values.yaml --debug

  # Create K8s Secret first
  kubectl apply -f exercises/02-install/redis-auth-secret.yaml

  # Install
  helm install my-redis bitnami/redis -f my-redis-values.yaml -n default
  ```

  NOTES.txt output contains:
  - Exact service hostname: `my-redis-master.default.svc.cluster.local:6379`
  - Command to extract password from Secret
  - `kubectl run redis-client` test command

  **Service name pattern:** `[release-name]-[chart-component]`
  - `helm install my-redis bitnami/redis` → master service = `my-redis-master`
  - Change release name to `redis-cache` → service = `redis-cache-master`
  - Never guess — read NOTES.txt or `kubectl get svc | grep redis`

  **Pod Pending diagnosis:** `kubectl describe pod my-redis-master-0` → Events section:
  - `unbound PersistentVolumeClaims` → no StorageClass in minikube → fix: `--set master.persistence.enabled=false`
  - `Insufficient memory` → reduce `resources.requests.memory`
  - `ImagePullBackOff` → wrong image tag → fix tag in values.yaml

  **helm list STATUS values:**

  | STATUS | Meaning | Action |
  |---|---|---|
  | `deployed` | Apply succeeded — verify pods separately | `kubectl get pods` |
  | `failed` | Apply failed mid-way | `helm rollback` immediately |
  | `pending-install` | Hook running | Wait |
  | `superseded` | Old revision replaced by newer | Normal history entry |

- [x] **Q7 — Connect qna-agent to Redis Helm service:**

  REDIS_URL in `k8s/configmaps/qna-agent-cm.yaml` line 33:
  - Before: `redis://redis:6379/0` (Docker Compose hostname — no K8s Service named `redis`)
  - After: `redis://my-redis-master:6379/0` (Helm Service name in same namespace)

  ```powershell
  kubectl apply -f k8s/configmaps/qna-agent-cm.yaml
  kubectl rollout restart deployment qna-agent    # mandatory — env vars injected at Pod init, not live
  kubectl rollout status deployment qna-agent --timeout=120s
  ```

  Verify from inside Pod:
  ```powershell
  kubectl exec -it <qna-agent-pod> -- env | Select-String "REDIS"
  kubectl exec -it <qna-agent-pod> -- nslookup my-redis-master   # DNS resolves?
  kubectl exec -it <qna-agent-pod> -- redis-cli -h my-redis-master -a <pass> ping
  # Expected: PONG
  ```

  DNS resolve check passes before Pod is healthy (DNS record created when Service applies). Use TCP check (`nc -z my-redis-master 6379`) to verify actual connectivity.

- [x] **Q8 — Helm release model: history in etcd:**

  ```powershell
  helm list -n default        # name, namespace, revision, status, chart, app version
  helm history my-redis       # revision, timestamp, status, chart version, description
  kubectl get secrets | Select-String "helm"
  # sh.helm.release.v1.my-redis.v1  helm.sh/release.v1  1  10m
  ```

  **Where Helm stores history:** K8s Secrets in the same namespace — one Secret per revision. Each Secret contains full snapshot: rendered manifests + merged values + metadata. Survives pod restarts, node reboots, Redis crashes — state lives in etcd, not in memory.

  **helm rollback vs kubectl rollout undo:**

  | | `helm rollback my-redis 1` | `kubectl rollout undo deployment qna-agent` |
  |---|---|---|
  | Scope | ALL objects in release (StatefulSet + Service + ConfigMap + PVC refs) | Deployment only |
  | Atomicity | Single operation, consistent state | Only reverts pod template |
  | History | Creates new revision (immutable log) | Uses Deployment revision |
  | Use case | Helm-managed stacks | Single Deployment fix |

  Rollback creates NEW revision — does not rewrite history:
  ```
  revision 1 → install complete      (superseded)
  revision 2 → upgrade complete      (superseded)
  revision 3 → upgrade failed        (superseded after rollback)
  revision 4 → rollback to 2        (deployed)
  ```

- [x] **Q9 — Upgrade → rollback workflow (3 phases):**

  **Phase A — Good upgrade (revision 2):**
  ```powershell
  helm upgrade my-redis bitnami/redis -f exercises/04-upgrade-rollback/values-v2.yaml -n default
  kubectl rollout status statefulset/my-redis-master --timeout=90s
  kubectl get statefulset my-redis-master -o jsonpath='{.spec.template.spec.containers[0].resources}'
  # Verify: requests.memory = 256Mi (was 128Mi)
  ```

  **Phase B — Bad upgrade (revision 3 = failed):**
  File `exercises/04-upgrade-rollback/values-bad.yaml` uses `image.tag: "99.99.99-this-tag-does-not-exist"`.
  Helm does NOT auto-rollback. Old Pod continues running. `helm list` shows `STATUS: failed`. Fix: add `--atomic --timeout 2m` flag to `helm upgrade` for auto-rollback on timeout.

  **Phase C — Rollback (revision 4):**
  ```powershell
  helm rollback my-redis 2 -n default
  helm history my-redis    # revision 4: "rollback to 2"
  kubectl get secrets | Select-String "helm"    # 4 Secrets: v1, v2, v3, v4
  ```

  **When to rollback vs fix-forward:**
  - Rollback immediately: production health check fails, Pod CrashLoopBackOff, latency spike post-upgrade
  - Fix-forward: error cause is known and simple (wrong tag, single config key), time to investigate properly
  - Never leave `STATUS: failed` overnight in production

  **memory/helm-basics.md written** with 9 sections: 3 concepts table, 8-step install workflow, 5 operations syntax, override precedence, service name pattern, 7 failure modes table, project chart map (my-redis → my-redis-master:6379), release history model, dry-run discipline.

---

## Artifacts Built Today

- [x] `k8s/helm/my-redis-values.yaml` — 3 overrides: auth.existingSecret, persistence.size 1Gi, resources dev limits
- [x] `k8s/helm/exercises/01-repo-inspect/commands.ps1` — repo add, grep workflow, 3 checkpoint questions
- [x] `k8s/helm/exercises/02-install/redis-auth-secret.yaml` — K8s Secret template with base64 instructions
- [x] `k8s/helm/exercises/02-install/commands.ps1` — dry-run → Secret → install → verify → test PING
- [x] `k8s/helm/exercises/03-connect-app/commands.ps1` — ConfigMap update, rollout restart, DNS + TCP + PING test
- [x] `k8s/helm/exercises/04-upgrade-rollback/values-v2.yaml` — memory 128Mi → 256Mi
- [x] `k8s/helm/exercises/04-upgrade-rollback/values-bad.yaml` — intentionally bad image tag for fail simulation
- [x] `k8s/helm/exercises/04-upgrade-rollback/commands.ps1` — full 3-phase workflow with checkpoints
- [x] `k8s/helm/exercises/05-helm-create/commands.ps1` — helm create, trace dot-notation, key-not-found demo, lint
- [x] `k8s/helm/solutions/expected-outputs.md` — reference outputs for all 5 exercises
- [x] `k8s/helm/HELM-PRACTICE.md` — master guide + quick-reference commands
- [x] `k8s/configmaps/qna-agent-cm.yaml` — updated REDIS_URL: `redis://redis:6379/0` → `redis://my-redis-master:6379/0`
- [x] `memory/helm-basics.md` — 9 sections: concepts, install workflow, 5 operations, precedence, service name, 7 failures, project chart map, history model, dry-run discipline

---

## Not Completed
| Item | Reason |
|---|---|
| Live helm install on cluster | Exercises are guides — actual install pending when minikube session active |

---

## Extra Things Explored

- **`--atomic` flag for helm upgrade:** `helm upgrade --atomic --timeout 2m` triggers automatic rollback if the upgrade doesn't complete within the timeout. Good for CI pipelines where no human monitors the rollout. Not used by default because it silently rolls back — in interactive sessions, explicit `helm rollback` with investigation is preferable.

- **Helm release Secrets are gzip+base64 encoded:** The Secret data is `base64(gzip(json(release)))`. Decoding requires two base64 steps and a gunzip. This is why `helm history` is the correct tool — reading Secrets directly requires 3 pipeline steps and outputs dense JSON.

- **Chart version vs app version independence:** When bitnami releases a new Redis security patch, they increment `CHART VERSION` (e.g., 19.6.2 → 19.6.3) but also update `APP VERSION` (7.2.5 → 7.2.6). Pinning `--version 19.6.2` in CI gives reproducible installs. Without a pin, `helm repo update` + `helm upgrade` could pull a newer chart with breaking changes.

- **`helm upgrade --install` pattern:** Single command that installs if release doesn't exist, upgrades if it does. Idempotent — safe for CI/CD pipelines and GitOps workflows: `helm upgrade --install my-redis bitnami/redis -f values.yaml`. Avoids "resource already exists" error when release name is reused.

- **Practice directory rationale:** `k8s/helm/exercises/` mirrors the day's learning sequence — each exercise is a self-contained PowerShell script with step-by-step commands and checkpoints. A future agent can read `commands.ps1` and reproduce the exercise without knowing the conversation history.

---

## How I Used Claude Code Today

Day 15 was a structured Helm deep-dive — 9 questions covering the full lifecycle from manual YAML problems through install → upgrade → rollback. The learning pattern was: explain the problem first (why Helm exists), then learn the tool, then apply to the project (replacing redis.yaml with bitnami/redis, updating qna-agent ConfigMap).

Key technique: `helm template . --debug` before every install — output YAML was read carefully before applying. This caught the maxmemory configuration gap and confirmed the service name before updating qna-agent-cm.yaml. Render first, apply second.

The practice exercise directory (`k8s/helm/exercises/`) was built incrementally after each conceptual block — exercises 01-05 map directly to Q1-Q9 clusters. Each `commands.ps1` is annotated with "why" explanations, not just commands.

`memory/helm-basics.md` was written last — after the full workflow was understood. The 9 sections are ordered for agent use: concepts first, operations second, project-specific last. Future sessions load this file and skip re-explaining Chart/Release/Repository basics.

---

## Blockers / Questions for Mentor
- `helm upgrade --atomic` auto-rollbacks silently in CI — how do you get notified that a rollback happened? Is there a Helm hook or Kubernetes event that CI pipelines typically watch?
- For bitnami/redis in production: should we use `replica.replicaCount: 1` (Sentinel) or stay with standalone (`replicaCount: 0`) for a service that's only doing LangGraph checkpointing (not a cache)? The data is ephemeral — durability matters less than simplicity.

---

## Self Score
- Completion: 10/10 — all 9 questions done, practice directory with 5 exercises, memory/helm-basics.md written, qna-agent ConfigMap updated and verified
- Understanding: 9/10 — Helm release model (immutable revision history in etcd) and rollback atomicity vs kubectl rollout undo are now concrete; chart structure and dot-notation are internalized
- Energy: 8/10

## One Thing I Learned Today That Surprised Me

`helm rollback` does not undo history — it creates a new revision that is a copy of the target revision. Revision 3 (the failed one) stays permanently in etcd as an audit trail. I expected rollback to behave like `git reset --hard` (rewriting history). Instead it behaves like `git revert` (adding a new commit that undoes the previous one). This means you can always `helm history` and see the full sequence of what happened — install, good upgrade, bad upgrade, rollback — all timestamped, all inspectable via the Secrets in etcd. In production, this is the difference between "something went wrong" and "I know exactly when it went wrong and what state we were in before."

---

## Tomorrow's Context Block

**Where I am:** Day 15 complete — Helm installed, bitnami/redis chart deployed as release `my-redis`, qna-agent ConfigMap updated (REDIS_URL = `redis://my-redis-master:6379/0`), full upgrade → rollback cycle completed (4 revisions in history). Practice directory `k8s/helm/exercises/` with 5 annotated PowerShell scripts. `memory/helm-basics.md` written with 9 sections. Raw `k8s/infra/redis.yaml` replaced by Helm-managed StatefulSet.

**What's in progress / unfinished:** Live cluster validation — exercises are guides but actual `helm install` against live minikube cluster pending for exercises 02-05. Day 16 topic not yet assigned.

**First thing to do tomorrow:** Run `kubectl get pods -n default | Select-String "redis"` to confirm which Redis is currently active (raw StatefulSet vs Helm release). If Helm release `my-redis` not yet installed: `kubectl delete -f k8s/infra/redis.yaml` first (remove raw), then follow `exercises/02-install/commands.ps1`. After that: check Day 16 assignment and read relevant memory files before starting.

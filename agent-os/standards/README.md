# Standards System

This folder contains YOUR documented DevOps standards — patterns and practices you've discovered, validated, and want to consistently apply in future work.

## Why Standards?

Without documented standards:
- You make the same decisions from scratch every time
- Your agent generates inconsistent configs across projects
- Knowledge stays in your head and never reaches your agent

With documented standards:
- Your agent checks standards before generating any config
- Every Dockerfile, pipeline, manifest follows your known patterns
- You accumulate compounding knowledge across projects

## Structure

```
agent-os/standards/
├── index.yml           <- Index for fast lookup (update after adding standards)
├── docker/
│   └── dockerfile-pattern.md
├── kubernetes/
│   └── manifest-structure.md
├── cicd/
│   └── pipeline-structure.md
└── ...
```

## How to Grow Your Standards

**Discover:** After completing a training topic, ask Claude:
> "What patterns did we just use that I should document as a standard? What would I want to apply consistently in every future [Docker/K8s/pipeline] task?"

**Write:** Create a standard file in the relevant folder. Each standard should have:
- What it is (one paragraph)
- When to use it
- The pattern (code/config/checklist)
- Why (the reasoning)

**Index:** Add an entry to `index.yml` with a one-line description.

**Apply:** Before any task, tell Claude: "Check my standards in agent-os/standards/ for relevant patterns before generating the config."

## Example Standard File

`kubernetes/manifest-structure.md`:
```markdown
# Standard: Kubernetes Manifest Structure

## What
Every Kubernetes Deployment manifest I write must include specific required fields.

## When to Use
Any time creating or reviewing a Deployment, StatefulSet, or DaemonSet.

## The Pattern
Required fields in every Deployment:
- `spec.template.spec.containers[].resources` (requests AND limits)
- `spec.template.spec.containers[].livenessProbe`
- `spec.template.spec.containers[].readinessProbe`
- `metadata.labels`: app, version, environment
- `spec.selector.matchLabels` must match `spec.template.metadata.labels`

## Why
Without resource limits: one pod can starve the whole node.
Without probes: K8s doesn't know if the app is actually healthy.
Without consistent labels: selectors break silently.
```

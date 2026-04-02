# DevOps Patterns by Category

## Docker
- Multi-stage build: builder stage + minimal runtime stage
- Non-root user: always add `USER appuser` before CMD
- Specific tags: never `FROM node:latest`, use `FROM node:20-alpine`
- .dockerignore: always exclude node_modules, .git, *.log

## Kubernetes
- Always set: resource requests AND limits
- Always add: liveness probe + readiness probe
- Always specify: namespace (never rely on default)
- ConfigMap for config, Secret for credentials — never hardcode in Deployment
- Labels: always include app, version, environment

## CI/CD
- Fail fast: lint + unit tests before Docker build
- Cache: node_modules, pip packages, Docker layers
- Parallel: independent jobs run simultaneously
- Secrets: GitHub Secrets or Jenkins Credentials — never in YAML
- Artifact: always build Docker image with commit SHA tag

## Terraform
- Remote state: always use S3 + DynamoDB locking
- Modules: one module per logical resource group
- Variables: all environment-specific values as variables
- Outputs: expose what downstream configs need

## Ansible
- Idempotency first: use `state: present` not raw commands
- Tags: add tags to every task for selective runs
- Vault: use ansible-vault for secrets
- Roles: one role per service/component

## Observability
- Metrics: expose /metrics endpoint for Prometheus scraping
- Logs: structured JSON, include service name + trace ID
- Alerts: alert on symptoms (high error rate), not causes (CPU%)
- Dashboards: request rate, error rate, latency (RED method)

## Bash Scripts
- Always: `#!/bin/bash` + `set -euo pipefail`
- Log everything: `echo "[$(date)] Starting X"` before each major step
- Exit codes: check return codes, don't silently continue on failure
- Arguments: validate required args at top of script

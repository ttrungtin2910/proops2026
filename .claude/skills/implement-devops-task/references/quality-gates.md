# Quality Gate Dependency Graph

Every implementation must pass these gates IN ORDER before it is considered done:

## Gate 1: Functional Verification
The thing does what it was supposed to do.
- For Dockerfiles: `docker build` succeeds, container runs and responds
- For K8s manifests: `kubectl apply` succeeds, pods reach Running state
- For pipelines: pipeline runs green on first real push
- For IaC: `terraform plan` shows expected changes, `terraform apply` succeeds
- For monitoring: metrics visible in Grafana, alert fires on test condition

## Gate 2: Idempotency Check
Running it twice produces the same result.
- Ansible: run playbook twice, second run shows all `ok` not `changed`
- Terraform: `terraform plan` after apply shows `No changes`
- Scripts: run twice, no error on second run

## Gate 3: No Hardcoded Values
No credentials, IPs, or environment-specific values in files.
- All env-specific config in environment variables or configmaps
- All secrets in K8s Secrets or a vault, never in manifests
- All IPs/hostnames parameterized

## Gate 4: Security Basics
- Docker: non-root user, no unnecessary packages, specific version tags
- K8s: resource limits set, liveness/readiness probes added
- CI/CD: secrets via environment variables, not hardcoded in YAML
- IaC: no open 0.0.0.0/0 security groups unless explicitly required

## Gate 5: Documentation
- What it does (one paragraph)
- How to use it (commands to run)
- How to modify it (which variables to change)
- How to verify it's working (commands to run)

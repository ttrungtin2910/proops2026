# DevOps Implementation Patterns

Common patterns for implementing DevOps tasks. Always check the trainee's IRDs first —
these are fallback patterns when the IRD doesn't specify, not defaults to override the IRD.

---

## Terraform

### Module Structure
```
modules/
  [resource-type]/
    main.tf       ← resources
    variables.tf  ← inputs
    outputs.tf    ← outputs
    versions.tf   ← provider + terraform version constraints
envs/
  dev/
    main.tf       ← calls modules, env-specific values
    backend.tf    ← remote state config
  stag/
  prod/
```

### State Backend (AWS S3)
```hcl
terraform {
  backend "s3" {
    bucket         = "[project]-terraform-state"
    key            = "[project]/[env]/[component]/terraform.tfstate"
    region         = "ap-southeast-1"
    encrypt        = true
    dynamodb_table = "[project]-terraform-locks"
  }
}
```

### Required Tags (apply to all resources)
```hcl
locals {
  common_tags = {
    Environment = var.environment   # dev / stag / prod
    Project     = var.project_name
    ManagedBy   = "terraform"
    Owner       = var.owner
  }
}
```

---

## Docker

### Multi-Stage Dockerfile Pattern
```dockerfile
# Build stage
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

# Production stage
FROM node:18-alpine AS production
RUN addgroup -g 1001 appgroup && adduser -u 1001 -G appgroup -s /bin/sh -D appuser
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY . .
USER appuser
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1
CMD ["node", "server.js"]
```

### Image Naming Pattern
```
[registry]/[project]/[service]:[version]-[env]
# Example: registry.example.com/taskflow/api:1.0.0-prod
# Never: latest in production
```

---

## Kubernetes

### Minimal Deployment with Resource Limits
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: [service-name]
  namespace: [project]-[env]
  labels:
    app: [service-name]
    environment: [env]
    managed-by: kubectl
spec:
  replicas: 2
  selector:
    matchLabels:
      app: [service-name]
  template:
    metadata:
      labels:
        app: [service-name]
        version: [version]
    spec:
      containers:
        - name: [service-name]
          image: [image]:[tag]  # Never 'latest'
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "500m"
              memory: "512Mi"
          livenessProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 15
            periodSeconds: 20
          readinessProbe:
            httpGet:
              path: /ready
              port: 3000
            initialDelaySeconds: 5
            periodSeconds: 10
```

---

## CI/CD (GitHub Actions)

### Branch-to-Environment Mapping (default)
| Branch | Deploys To | Auto/Manual |
|--------|-----------|-------------|
| `feature/*` | — (CI only, no deploy) | Auto on push |
| `develop` | dev | Auto on merge |
| `main` | stag | Auto on merge |
| `release/*` | prod | Manual approval required |

### Pipeline Stage Sequence
```
1. Lint + Test (fail fast)
2. Security scan (Trivy / SonarQube)
3. Build + Push image
4. Deploy to environment
5. Post-deploy smoke test
6. Notify (success/failure)
```

### Secrets — Never Hardcode
```yaml
env:
  DB_PASSWORD: ${{ secrets.DB_PASSWORD }}
  AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
# Never: DB_PASSWORD: "mypassword123"
```

---

## Observability

### Structured Log Format (JSON)
```json
{
  "timestamp": "2026-04-01T10:00:00Z",
  "level": "ERROR",
  "service": "taskflow-api",
  "environment": "prod",
  "trace_id": "abc-123",
  "message": "Database connection failed",
  "error": "connection refused",
  "duration_ms": 5001
}
```

### Health Check Endpoint (minimum)
```
GET /health → 200 { "status": "ok", "version": "1.0.0" }
GET /ready  → 200 { "status": "ready" } or 503 { "status": "not ready" }
```

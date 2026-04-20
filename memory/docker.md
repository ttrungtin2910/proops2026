# Docker — Agent Memory Reference

**Topic**: Docker Core + Compose + Operational Debugging  
**Purpose**: Reusable Docker memory for any project, with a portable core + project overlay model  
**Last updated**: 2026-04-17  

---

## 0. How To Use This File

This memory is split into 2 layers:

1. **Portable Core**
   - Rules that apply to almost every Docker / Compose project
   - Reuse across backend, frontend, data, and infra services

2. **Project Overlay**
   - Replace with the current project's service names, ports, health dependencies, startup order, and known mistakes
   - This is the part that makes answers specific instead of generic

Rule:
- If answering a conceptual or best-practice question → use Portable Core
- If answering a debugging or operational question → use Project Overlay first, then apply Portable Core rules

---

## 1. Quick Reference (Fast Answer Block)

- Containers are isolated processes, not VMs → they start fast and exit when PID 1 exits
- Use **service names** for container-to-container communication, never `localhost`
- Standard debug order: `logs → exit code → health → exec → dependency check`
- For daily operations, Docker Compose workflows matter more than raw `docker run`
- A memory file is only useful if it includes **real commands + real execution paths + real mistakes**

---

## 2. Mental Model — Containers vs Virtual Machines

Containers are not lightweight virtual machines.

They are processes running on the host kernel with isolated namespaces:

- **PID namespace** → process isolation
- **Network namespace** → each container has its own localhost
- **Filesystem namespace** → layered filesystem
- **User namespace** (optional) → user isolation

### Practical implications

- No SSH needed → use `docker exec`
- Containers start quickly → no guest OS boot
- Container exits when the main process exits
- Signal handling depends on PID 1 behavior
- `localhost` inside a container means the container itself, not the host or sibling containers

### Why this matters

This model explains most common Docker failures:

- container exits immediately → wrong CMD / app crash / wrong entrypoint
- service cannot reach dependency → `localhost` used instead of service name
- stop/restart behaves badly → shell-form CMD or poor signal handling
- child processes become zombies → missing init process in PID 1 path

---

## 3. Dockerfile Anatomy (Reusable Rules)

Every Dockerfile instruction creates a read-only layer.  
Layer order matters for both correctness and build speed.

### Core instructions

| Instruction | Purpose | Rule |
|---|---|---|
| `FROM` | Base image | Pin exact tag, never use `latest` |
| `WORKDIR` | Working directory | Set before COPY/RUN |
| `COPY` | Copy files into image | Copy only what is needed |
| `RUN` | Build-time execution | Use for install / compile / prepare |
| `ENV` | Runtime config | Never store secrets here |
| `EXPOSE` | Port documentation | Does not publish ports |
| `LABEL` | Metadata | Use when traceability matters |
| `HEALTHCHECK` | Container health probe | Strongly recommended for long-running apps |
| `CMD` | Default start command | Prefer exec form |
| `ENTRYPOINT` | Fixed executable | Use for tools / controlled runtime entry |

### Core Dockerfile rules

- Pin a specific base image tag
- Prefer slim / minimal runtime images, but not at the cost of runtime stability
- Use exec form for `CMD` / `ENTRYPOINT`
- Prefer non-root execution for deployable app containers
- Add `HEALTHCHECK` for orchestrated or production-grade workloads
- Do not bake secrets into image layers
- Keep runtime image smaller than build image where possible

### CMD vs ENTRYPOINT

Use `CMD` when the image has a default start command that may change.

```dockerfile
CMD ["node", "./bin/www"]
```

Use ENTRYPOINT when the image itself behaves like a fixed executable.

```dockerfile
ENTRYPOINT ["python"]
CMD ["app.py"]
```

### Rule

CMD = default command
ENTRYPOINT = fixed executable
Prefer exec form, not shell form
4. .dockerignore Rules

Minimum safe entries:

node_modules
.env
.git

Add more based on language and tooling, but do not exclude files the app needs at runtime.

**Rule:**
- Exclude build noise, secrets, and VCS files
- Keep templates, static assets, migrations, and runtime config if required by the app

## 5. Layer Cache (Performance-Critical Mental Model)

Docker caches each instruction as a layer using the instruction + input context hash.

**Rule**

If one layer changes, that layer and all layers below it are invalidated.

### Correct build order pattern

Dependencies before code:

COPY package*.json ./
RUN npm install
COPY . .
### Why this matters

If source code is copied before dependency installation, dependency install re-runs on every code change.

### Reusable language patterns

#### Node / frontend

COPY package*.json ./
RUN npm ci
COPY . .

#### Python

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app/ ./app/

#### .NET

COPY *.csproj ./
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release -o /app/publish
### Verification

Look for CACHED on repeated builds.

docker build -t image:tag .
docker build -t image:tag .

#### Force rebuild

docker build --no-cache -t image:tag .

## 6. Core Runtime Commands

### Build and image management

docker build -t image:tag .
docker build --no-cache -t image:tag .
docker images
docker rmi image:tag
docker rmi -f image:tag
docker pull image:tag
docker tag source:tag target:tag

### Container lifecycle

docker run -d -p 3000:3000 --name myapp image:tag
docker run -it --rm image:tag /bin/sh
docker run --env-file .env image:tag
docker run -e KEY=VALUE image:tag

docker ps
docker ps -a
docker stop container
docker rm container
docker rm -f container
docker stop container && docker rm container

### Debug commands

docker logs container
docker logs -f container
docker logs --tail 50 container
docker inspect container
docker inspect container --format='{{.State.ExitCode}}'
docker inspect container --format='{{.State.Health.Status}}'
docker port container
docker stats container --no-stream
docker exec -it container /bin/sh

### Key flags to remember

Flag	Meaning
-d	detached mode
-p HOST:CONTAINER	publish port
-e KEY=VALUE	single env var
--env-file .env	bulk env injection
--name	stable container name
-it	interactive shell
--rm	remove on exit
--no-cache	bypass build cache
--init	better PID 1 behavior
--restart unless-stopped	resilient long-running service
--memory=256m	memory limit
--cpus=0.5	CPU limit
--security-opt no-new-privileges:true	block privilege escalation

## 7. Networking Model (Critical Rule)

Each container has its own network namespace.

**Rule**
- `localhost` = this container itself
- `service-name` = another container on the Docker network
- published host port = host-to-container access path

### Wrong vs correct


Wrong:

curl http://localhost:9092

Correct:

curl http://kafka:9092

### Port publishing

docker run -d -p 3000:3000 image:tag
docker run -d -p 8080:3000 image:tag
docker port container

### EXPOSE rule

EXPOSE documents an internal port. It does not publish the port.


**Mental model:**
- `EXPOSE` = label on the door
- `-p` = opening the door

## 8. Image vs Container

### Image
- immutable
- read-only layered filesystem
- built with `docker build`
- stored locally or in a registry
- multiple containers can run from one image

### Container
- running instance of an image
- has a thin writable layer on top
- ephemeral unless data is externalized
- isolated process, network, and filesystem context

### Practical rule

Modifying a container does not change the image.
If you need repeatability, change the Dockerfile, not the running container.

## 9. Production Standards (Reusable)

### Security

Prefer non-root runtime

RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

#### Block privilege escalation

docker run -d \
  --security-opt no-new-privileges:true \
  image:tag

#### Never bake secrets into images

**Bad:**

ENV DATABASE_PASSWORD=mysecret

**Good:**

docker run --env-file .env image:tag


Verify image history if needed:

docker history --no-trunc image:tag

### Runtime behavior

#### HEALTHCHECK

Use for long-running app services, especially under Compose / ECS / Kubernetes.

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:3000/ || exit 1

#### PID 1 / zombie handling

Use `--init` if the process may spawn children.

docker run -d --init image:tag

#### Resource limits

Recommended for shared hosts or production-like environments.

docker run -d \
  --memory=256m \
  --memory-swap=256m \
  --cpus=0.5 \
  --restart unless-stopped \
  image:tag

### Restart policy guidance

Policy	Use case
no	dev/test only
on-failure	restart on crash only
unless-stopped	preferred for long-running services
always	special cases only

## 10. Observability & Traceability

### Runtime monitoring

docker stats --no-stream
docker stats container
docker events

### Image labels

Recommended when auditability matters.

LABEL maintainer="team@example.com" \
      version="1.0.0" \
      git-commit="abc1234" \
      build-date="2026-04-18"

### Log driver example

docker run -d \
  --log-driver=awslogs \
  --log-opt awslogs-group=/myapp/production \
  --log-opt awslogs-region=ap-southeast-1 \
  --log-opt awslogs-stream=container-1 \
  image:tag

**Rule:**
- local json-file logs are fine for dev
- externalized logs are preferred for production

## 11. Multi-Stage Builds

Use multi-stage builds when compile/build dependencies should not exist in the runtime image.

### Standard pattern

FROM builder-image AS builder
WORKDIR /src
COPY . .
RUN build-command

FROM runtime-image
WORKDIR /app
COPY --from=builder /output .
CMD ["run-app"]

### Rules
- Name the build stage
- Copy only compiled artifacts into runtime
- Runtime image should not contain SDK/build tools
- Do not copy raw source into runtime unless the app truly requires it

### Reusable project examples
- .NET services → SDK build stage + ASP.NET runtime stage
- Python services → builder stage optional; runtime should stay minimal
- frontend → node build stage + nginx runtime stage

## 12. Compose File Structure

A Compose file usually contains:

services:
  app:
    image: myapp:tag
    depends_on:
      db:
        condition: service_healthy
    env_file: .env
    environment:
      - DATABASE_HOST=db
    ports:
      - "8080:8080"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 10s
      timeout: 5s
      retries: 5

networks:
  default:
    name: project-net

volumes:
  db-data:

### Key Compose fields

Field	Purpose
image	pull prebuilt image
build	build locally from Dockerfile
ports	host access
depends_on	startup dependency relationship
condition: service_healthy	wait for health, not just start
env_file	load env vars
environment	override / inject key runtime vars
volumes	persistence or file sharing
healthcheck	service readiness signal
## 13. Compose Networking

Docker Compose creates a bridge network.
Each service can reach others by service name.

Examples:

kafka:9092
mongodb:27017
redis:6379
milvus:19530

**Rule**

Inside Compose, DNS by service name is the default and preferred approach.

**Wrong:**

curl http://localhost:9092
curl http://172.20.0.3:9092

**Correct:**

curl http://kafka:9092

## 14. Volumes

### Mental model
- named volume = Docker-managed persistence
- bind mount = host-managed file sharing

### Examples

volumes:
  - mongo-data:/data/db
  - ./logs:/app/logs
  - ./knowledge-base:/workspace/knowledge-base:ro

### Useful commands

docker volume ls
docker volume inspect mongo-data
docker volume rm mongo-data

### down vs down -v

Command	Containers	Named volumes
docker compose down	removed	kept
docker compose down -v	removed	deleted
## 15. Registry Workflow

Standard flow:

docker build -t repo/service:tag .
docker login
docker push repo/service:tag
docker pull repo/service:tag

**Rules**
- Use meaningful tags
- Do not rely on `latest`
- Use `image:` in integration Compose when teammates should pull prebuilt artifacts
- Use `build:` in local dev Compose when actively changing source code

## 16. Standard Debug Decision Tree

Use this flow for any project where a container crashes or behaves incorrectly.

### Step 1 — Read logs

docker compose logs service-name
docker compose logs --tail 50 service-name
docker compose logs -f service-name

**Question:**
- Did the app fail?
- Did dependency connection fail?
- Did the command not start at all?

### Step 2 — Check exit code

docker inspect service-name --format='{{.State.ExitCode}}'

Exit code	Typical meaning
0	process exited cleanly; command may be wrong for long-running service
1	app/runtime error
137	OOM or SIGKILL
139	segfault/native crash

### Step 3 — Check health

docker inspect service-name --format='{{.State.Health.Status}}'

**Question:**
- healthy?
- starting too long?
- unhealthy because probe is wrong or app is not ready?

### Step 4 — Enter container

docker exec -it service-name /bin/sh

**Check:**
- expected files exist?
- env vars present?
- command binary exists?
- process can bind to expected port?

### Step 5 — Verify dependencies

docker exec -it service-name sh -c "curl dependency-name:port"

**Question:**
- DNS resolution works?
- port reachable?
- dependency actually healthy?

### Step 6 — Decide root cause category

Category	Typical signal
wrong command / entrypoint	exit code 0 or instant exit
app runtime error	logs show exception
dependency not ready	connection refused / timeout
network config error	localhost used instead of service name
resource exhaustion	exit 137 / OOM
healthcheck mismatch	container up but marked unhealthy

## 17. Common Failure Patterns (Reusable)

Failure pattern	Symptom	Root cause	Fix
wrong CMD	container exits immediately	start command not long-running	fix CMD/ENTRYPOINT
localhost used for dependency	connection refused	wrong network target	use service name
dependency starts but not ready	app crashes during boot	missing health-based dependency	add healthcheck + healthy dependency waiting
OOM kill	exit 137	memory limit too low or leak	inspect memory / tune limits
shell-form CMD	bad signal handling	PID 1 is shell	use exec-form CMD
source copied into runtime incorrectly	runtime missing built artifacts	wrong multi-stage copy	copy publish/build output only
## 18. Project Overlay Template (Fill Per Project)

Replace this section for the active project.
This is what turns the file from generic memory into specific operational memory.

### Project name

<project-name>

### Main services
- <service-1>
- <service-2>
- <service-3>

### Infra dependencies
- <broker>
- <database>
- <cache>
- <vector-db>

### Service-to-service hostnames
- <service-name>:<port>
- <dependency-name>:<port>

### Startup order
- <infra-1>
- <infra-2>
- <data-layer>
- <app-services>
- <frontend>

### Root integration commands

docker compose pull
docker compose up -d
docker compose logs -f
docker compose ps
docker compose down
docker compose down -v

### Service-level commands

docker compose up -d --build
docker compose build <service-name>
docker compose up -d <service-name>
docker compose logs -f <service-name>
docker compose down

### First-time setup
- copy required .env files
- verify required DB collections / topics / migrations
- confirm the correct Compose mode (integration vs service-level)

### Known crash patterns

Service	Symptom	Root cause	Fix
<service>	<symptom>	<root cause>	<fix>

### Mistakes already made
- <mistake 1>
- <mistake 2>
- <mistake 3>

**Rule:**
The most valuable content in this section is not the architecture summary.
It is the combination of:
- real service names
- exact commands
- real startup order
- mistakes already made

## 19. Day 09 Stack Overlay (Current Project Example)

### Project name

Day 09 Stack

### Main services
- hook-gateway
- qna-agent
- websocket-responder
- frontend

### Infra dependencies
- zookeeper
- kafka
- etcd
- minio
- milvus
- mongodb
- redis

### Service hostnames
- kafka:9092
- milvus:19530
- mongodb:27017
- redis:6379

### Startup order
- zookeeper
- kafka
- etcd + minio
- milvus
- mongodb + redis
- hook-gateway
- qna-agent
- websocket-responder
- frontend

### Root integration commands

docker compose pull
docker compose up -d
docker compose logs -f
docker compose logs -f hook-gateway
docker compose logs -f qna-agent
docker compose ps
docker compose down
docker compose down -v

### Service-level commands

docker compose up -d --build
docker compose build qna-agent
docker compose up -d qna-agent
docker compose logs -f qna-agent
docker compose down

### First-time setup

cp hook-gateway/.env.example hook-gateway/.env
cp qna-agent/.env.example qna-agent/.env

Also verify the Milvus legal_docs collection exists before starting qna-agent.

### Known crash patterns

Service	Symptom	Root cause	Fix
hook-gateway	exits immediately	wrong container start command	fix Dockerfile command
qna-agent	Milvus connection refused	Milvus not healthy yet	require healthy dependency
websocket-responder	Kafka consumer startup error	broker not ready or topic missing	wait for Kafka health / pre-create topic
any service	cannot reach sibling service	used localhost instead of service name	use Docker DNS service name

### Mistakes already made
- Used localhost:9092 for Kafka bootstrap servers
- Forgot `depends_on: condition: service_healthy`
- Mixed root integration Compose thinking with service-level Compose thinking

## 20. What Makes This Memory File Actually Useful

A Docker memory file is only useful if it contains all 3 layers:

- **Mental model** — why Docker behaves the way it does
- **Operational workflow** — what commands to run in what order
- **Project overlay** — actual services, ports, startup order, and mistakes

If one layer is missing:
- mental model missing → answers become shallow
- operational workflow missing → answers become unusable
- project overlay missing → answers become generic

## 21. Maintenance Rules

Update this file when:
- a new service is added
- a startup dependency changes
- a new crash pattern is discovered
- a new build/runtime rule is introduced
- a debugging step is repeated more than twice manually

Do not update this file with:
- generic Docker definitions already known
- duplicated commands with no project context
- one-off experiments that did not become repeatable practice

**Rule:** Only store information that improves future debugging, deployment, or explanation quality.
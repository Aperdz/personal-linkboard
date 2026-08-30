# CLAUDE.md

Context for Claude (or any AI assistant) working in this repository.

## What this project is

**Linkboard** — a link-shortener app used as a vehicle to demonstrate a
full DevSecOps pipeline: local dev → containerize → deploy to Kubernetes
→ deploy to AWS ECS → monitor → secure. The app itself is intentionally
simple; the infrastructure and process around it is the actual point.

This is a portfolio/learning project built by someone learning
DevOps/DevSecOps, not a production system with real users.

## Stack

| Layer | Tech |
|---|---|
| Frontend | Next.js + TypeScript |
| Backend | NestJS + TypeScript |
| Database | MongoDB |
| Cache | Redis |
| Local orchestration | docker-compose |
| Container orchestration | Kubernetes (via `kind` locally) |
| Cloud deployment | AWS ECS (Fargate), via Terraform |
| Monitoring | Prometheus + Grafana |
| CI | GitHub Actions (Prettier, ESLint, GitLeaks, Terraform checks) |
| CD | GitHub Actions (dev → prod promotion to ECS) |

## Repo structure

```
linkboard/
├── backend/              # NestJS API — has its own Dockerfile
├── frontend/              # Next.js UI — has its own Dockerfile
├── k8s/                    # Kubernetes manifests (local kind cluster)
├── monitoring/              # Grafana dashboard JSON, Prometheus config
├── terraform/
│   ├── global/ecr/           # shared ECR repos — applied ONCE, manually
│   ├── modules/ecs-service/   # reusable ECS Fargate + ALB + autoscaling module
│   └── environments/
│       ├── dev/
│       └── prod/
├── .github/workflows/
│   ├── cd-deploy.yml           # dev -> prod promotion pipeline
│   ├── terraform-plan.yml      # PR checks: fmt, validate, tfsec, plan
│   └── (existing) quality checks: Prettier, ESLint, GitLeaks
├── docker-compose.yml
└── .env.example
```

**There is no Dockerfile at the repo root.** Frontend and backend are
separate apps with separate Dockerfiles — always `docker build ./backend`
or `docker build ./frontend`, never a bare `docker build .` from root.

## Critical gotchas (learned the hard way — don't rediscover these)

1. **Kubernetes Services always expose port 80**, regardless of the
   container's real port. Backend container listens on `4000`, frontend
   on `3000` — but `kubectl port-forward svc/X <local>:80`, never
   `:4000` or `:3000` on the Service side.

2. **The frontend's API URL is baked in at Docker BUILD time**, not read
   at runtime. It's a Next.js `NEXT_PUBLIC_*` env var, compiled into the
   JS bundle. Changing it requires rebuilding the image, re-loading it
   into `kind`, and restarting the deployment — editing a ConfigMap
   alone does nothing for this specific value.

3. **`kubectl port-forward` is not persistent.** It dies the moment its
   terminal closes, the laptop sleeps, or WSL restarts — even though the
   underlying pods keep running completely unaffected. "It stopped
   working" after a break almost always just means the tunnels need to
   be re-run, not that anything actually broke. Check
   `kubectl get pods -n linkboard` first before assuming something's wrong.

4. **Readiness/liveness probe defaults are often too aggressive.**
   Kubernetes defaults to `timeoutSeconds: 1` if unset — too short for
   things like `mongosh` to start and connect. If a pod is stuck at
   `0/1` while `Running`, check `kubectl describe pod` → Events for
   "Readiness probe failed" before assuming the app itself is broken.

5. **docker-compose and Kubernetes are fully independent** — separate
   containers, separate data volumes, don't share state. Data created
   via one is invisible to the other. Both can run simultaneously as
   long as they use different host ports (see port map below).

6. **Container `READY` count (e.g. `3/3`) is NOT the same as replica
   count.** `X/Y` = containers inside ONE pod (sidecars, e.g. Grafana's
   dashboard-loader helpers). Actual redundancy/safety comes from
   **replica count** — multiple separate pods — not from multiple
   containers packed into one pod.

7. **Terraform state must be separate per environment.** dev and prod
   use different S3 state keys (`dev/terraform.tfstate` vs
   `prod/terraform.tfstate`) — never let them share one state file.

## Local port map (when running docker-compose AND kind simultaneously)

| | docker-compose | Kubernetes (port-forward) |
|---|---|---|
| Frontend | `localhost:3000` | `localhost:3005` |
| Backend | `localhost:4000` | `localhost:4000` (must match the value baked into the frontend build) |
| Grafana | `localhost:3001` | `localhost:3006` |
| Prometheus | `localhost:9090` | `localhost:9090` (only if forwarded) |

## Common commands

```bash
# Local dev (fast iteration)
docker compose up --build
docker compose down          # stops containers, data survives (named volumes)
docker compose down -v        # WIPES data — only use intentionally

# Build + load into local Kubernetes (kind)
docker build -t linkboard-backend:latest ./backend
docker build -t linkboard-frontend:latest --build-arg NEXT_PUBLIC_API_URL=http://localhost:4000 ./frontend
kind load docker-image linkboard-backend:latest --name <cluster-name>
kind load docker-image linkboard-frontend:latest --name <cluster-name>
kubectl rollout restart deployment/linkboard-backend -n linkboard   # force pods to use newly-loaded image

# Debugging
kubectl describe pod -n linkboard <pod-name>    # check Events for the real error
kubectl logs -n linkboard <pod-name>
kubectl rollout undo deployment/linkboard-backend -n linkboard   # rollback to previous revision

# Terraform (see terraform/README.md for required one-time AWS setup first)
cd terraform/environments/dev
terraform init
terraform plan -var="backend_image=..." -var="frontend_image=..."
```

## Testing philosophy on this project

Test in layers, don't skip to the end:
1. Unit tests (no containers)
2. docker-compose (does it work with real dependencies, locally)
3. Kubernetes (does it survive real orchestration — self-healing, probes)
4. Load test (does it scale — HPA in k8s, target-tracking in ECS)
5. Security scan (Bandit/ESLint-security equivalent, GitLeaks, tfsec, Trivy)

## Security posture (be honest about known gaps, don't hide them)

- Non-root containers, dropped capabilities — done, both k8s and ECS task defs.
- NetworkPolicies exist in `k8s/` but **require CNI enforcement** —
  `kind`'s default CNI (kindnet) does NOT enforce them out of the box.
- ECS module uses the AWS account's **default VPC** with public subnets
  for simplicity — a hardened setup needs private subnets + NAT gateway.
- GitLeaks catches committed secrets; Secrets Manager wiring exists in
  the Terraform module (`var.secrets`) but is commented out until real
  secrets are ready to be wired up — don't put real credentials in
  `env_vars`, which is plaintext in the task definition.

## When making changes

- If you touch `frontend/`, remember any image rebuild needs the
  `--build-arg NEXT_PUBLIC_API_URL` supplied again, or it silently
  reverts to whatever default is in the Dockerfile.
- If you touch `k8s/*.yaml` probes, prefer explicit `timeoutSeconds` /
  `failureThreshold` over relying on Kubernetes defaults — see gotcha #4.
- If you touch `terraform/modules/ecs-service`, remember it's shared by
  BOTH dev and prod environments — a change there affects both; check
  environment-specific `.tfvars`/`main.tf` if the change should only
  apply to one.
- Terraform in this repo has **not been run through `terraform
  validate`** in a real environment yet (built without Terraform CLI
  access) — validate before trusting it as production-ready.

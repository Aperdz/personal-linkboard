# Linkboard — AWS Infra (Terraform + CI/CD)

This adds AWS ECS (Fargate) deployment on top of your existing Kubernetes
setup. Think of this as an **alternative deployment target**, not a
replacement — Kubernetes/kind stays your local learning + demo environment;
this is what "real production on AWS" looks like using the same containers.

## Same concepts, different platform

| Kubernetes | AWS ECS equivalent |
|---|---|
| Deployment (replicas) | ECS Service (`desired_count`) |
| Service (stable address) | Application Load Balancer + Target Group |
| HPA (autoscaling) | Application Auto Scaling (`aws_appautoscaling_*`) |
| readiness/liveness probe | ALB target group health check |
| ConfigMap / Secret | Environment variables / Secrets Manager |
| `kubectl rollout undo` | Re-apply Terraform with the previous image tag |

## Repo structure

```
terraform/
├── global/ecr/           # shared ECR repos — apply ONCE, manually, first
├── modules/ecs-service/  # reusable module — one ECS service + ALB + autoscaling
└── environments/
    ├── dev/               # calls the module with dev-sized settings
    └── prod/              # calls the module with prod-sized settings

.github/workflows/
├── cd-deploy.yml          # build once -> deploy dev -> (if healthy) deploy prod
└── terraform-plan.yml     # PR checks: fmt, validate, tfsec, plan (no apply)
```

## One-time manual setup (do this BEFORE any pipeline runs)

### 1. Create the Terraform state backend
Terraform needs somewhere to store its state file — and that somewhere
can't itself be created BY Terraform (chicken-and-egg). Create these
manually, once:

```bash
aws s3api create-bucket --bucket linkboard-terraform-state --region ap-southeast-1
aws s3api put-bucket-versioning --bucket linkboard-terraform-state \
  --versioning-configuration Status=Enabled

aws dynamodb create-table \
  --table-name linkboard-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

### 2. Apply the shared ECR repos
```bash
cd terraform/global/ecr
terraform init
terraform apply
```

### 3. Set up GitHub OIDC -> AWS IAM (no long-lived AWS keys in GitHub)
This is the modern, more secure alternative to storing `AWS_ACCESS_KEY_ID`
as a GitHub secret — GitHub proves its identity to AWS per-run instead.

- Create an IAM OIDC identity provider for `token.actions.githubusercontent.com`
- Create **two** IAM roles:
  - `linkboard-deploy-role` — used by `cd-deploy.yml`. Needs ECR push,
    ECS/ALB/IAM/CloudWatch full access scoped to this project's resources,
    and `s3`/`dynamodb` access to the state backend.
  - `linkboard-plan-role` — used by `terraform-plan.yml`. **Read-only.**
    Deliberately a separate, weaker role — a PR check should never be
    able to actually change infrastructure, only preview changes.
- Trust policy on both roles restricts `sub` to your specific repo, e.g.
  `repo:YOUR_GH_ORG/linkboard:*`

Full walkthrough: https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services

### 4. Add GitHub repo secrets
Settings -> Secrets and variables -> Actions:
- `AWS_DEPLOY_ROLE_ARN`
- `AWS_PLAN_ROLE_ARN`
- `AWS_ACCOUNT_ID`
- `DEV_API_URL` (the dev backend's public ALB URL — needed at frontend
  build time; you'll only know this after the FIRST manual dev deploy,
  since it's an output of that apply)

### 5. (Recommended) Set up a GitHub Environment protection rule for `prod`
Repo Settings -> Environments -> `prod` -> require manual approval before
the `deploy-prod` job runs. This adds a human-in-the-loop gate on top of
the automated health check — belt and suspenders for production.

## How the two workflows connect to what you already have

- **`terraform-plan.yml`** is the Terraform equivalent of your existing
  Prettier/ESLint/GitLeaks checks — runs on every PR, blocks bad changes
  from merging, never touches real infrastructure.
- **`cd-deploy.yml`** only runs on `main` (i.e. after a PR has already
  passed the checks above and been merged) — mirrors the same "checks
  before merge, deploy after merge" pattern you already have for the app
  code, just extended to cover infrastructure too.

## Known simplifications (documented on purpose, not hidden)

- Uses the AWS account's **default VPC** with public subnets; tasks get
  public IPs directly. A hardened production setup would use private
  subnets + a NAT gateway, with only the ALB internet-facing.
- No WAF in front of the ALB.
- `terraform-plan.yml`'s plan step uses a placeholder image tag, since
  the real tag only exists after `cd-deploy.yml` builds it — the plan is
  checking *infrastructure* correctness, not the app image itself.
- Secrets Manager wiring is scaffolded (`var.secrets` in the module) but
  commented out in both environments — wire up real secrets before
  putting anything sensitive (DB URIs, API keys) into `env_vars`, which
  is NOT encrypted at rest the way Secrets Manager values are.

## Next step you mentioned: adding Terraform for more infra
This ECS setup is intentionally scoped to compute only. Natural next
additions, in a `terraform/global/` or new `modules/` folder:
- RDS or DocumentDB, if you move off a self-hosted Mongo container
- Route53 + ACM for a real domain + HTTPS instead of the raw ALB DNS name
- A dedicated non-default VPC module (private subnets + NAT), replacing
  the current default-VPC simplification

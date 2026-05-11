# intentproof-infra

AWS Terraform for the IntentProof **hosted ingestion plane** (Phase 3): VPC, RDS PostgreSQL, ECS Fargate ingest API, ALB + ACM + Route 53 (`api.intentproof.io`), SQS, ECR, Secrets Manager, CloudWatch, SNS.

**Normative semantics** live in **`intentproof-spec`** and **`intentproof-api`**; this repo provisions accounts, regions, and topology.

## Layout

```text
stack/                       # Primary module — Actions workflow Terraform (OIDC apply)
bootstrap/                   # S3 backend bucket (+ persistent state object in same bucket)
bootstrap/github-oidc/       # IAM OIDC provider + role for AssumeRoleWithWebIdentity
docs/DEPLOYMENT.md          # Credentials, workflows, **`stack`** secrets
.github/workflows/terraform.yml           # **`stack`** plan/apply (no auto-apply)
.github/workflows/terraform-bootstrap.yml # **`bootstrap`** / **`github-oidc`** (manual bootstrap)
```

## Deploys (**GitHub Actions**)

See **[`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md)** for **`Terraform`** / **`Terraform bootstrap`** (**`workflow_dispatch`**), **`AWS_TERRAFORM_ROLE_ARN`**, temporary **`AWS_BOOTSTRAP_*`** keys for OIDC-first cold starts, **`TF_VAR_*`**, **`stack`** behavior (plan on PR/push, apply opt-in).

Supports **Terraform ≥ 1.10** (**`use_lockfile`** on the S3 backends used by **`bootstrap/`**, **`bootstrap/github-oidc/`**, and **`stack/main.tf`**).

## Remote state bucket name

If **`intentproof-tf-state`** is taken globally, align **`bootstrap/`** (**`TF_VAR_state_bucket_name`**) and **`stack/main.tf`** backend **`bucket`**.

## Application image

Build and push from **`intentproof-api`** before setting **`TF_VAR_IMAGE_TAG`**; see **`docs/DEPLOYMENT.md`**.

## License

Apache-2.0 (see `LICENSE`).

# Bootstrap — GitHub Actions OIDC for Terraform

IAM **OIDC identity provider** for `token.actions.githubusercontent.com` plus **two IAM roles** for **`../../.github/workflows/terraform.yml`**:

1. **Plan role** (`github_terraform_plan_role_arn`) — OIDC trust allows **`pull_request`** and default-branch refs; attaches **`plan_managed_policy_arns`** (default **ReadOnlyAccess**) plus inline **S3** on **`terraform_state_bucket_name`** for state + native lock objects. Store as GitHub secret **`AWS_TERRAFORM_PLAN_ROLE_ARN`**.
2. **Apply role** (`github_terraform_role_arn`) — OIDC trust **excludes** **`pull_request`** and includes **`repo:…:environment:<github_actions_environment>`** for environment-gated **`apply`** jobs. Store as **`AWS_TERRAFORM_ROLE_ARN`**.

**State** lives **in S3** at **`bootstrap/github-oidc/terraform.tfstate`** (**same bucket** as **`../`** + **`stack`**) via partial **`backend "s3"` {}`.

**Ordering:** **`../bootstrap/`** (**S3 bucket**) must **`apply`** first so the backend bucket exists. Then run **Actions → Terraform bootstrap** (**target **`github-oidc`**) **`provision_new_and_migrate`** (**first time**) **`static_credentials`**, **`run_apply`** true.

## Prerequisites

- Terraform **≥ 1.10**
- Credentials: cold start via **`AWS_BOOTSTRAP_*`**, then set **`AWS_TERRAFORM_PLAN_ROLE_ARN`** and **`AWS_TERRAFORM_ROLE_ARN`** from this module’s outputs.

GitHub-derived inputs (**`repository_owner`**, **`github.event.repository.name`**) populate **`TF_VAR_github_org`** / **`TF_VAR_github_repo`** automatically in **`terraform-bootstrap.yml`**. **`terraform-bootstrap.yml`** also sets **`TF_VAR_terraform_state_bucket_name`** from **`state_bucket_name`** when applying **`github-oidc`**, so the plan role’s **S3** policy matches the backend bucket.

Optional **`-var` overrides:** **`github_actions_environment`**, **`role_name`**, **`plan_role_name`**, **`terraform_state_bucket_name`**, **`subject_claims_override`**, **`managed_policy_arns`**, **`plan_managed_policy_arns`**.

Cold **CLI parity** (**after** **`../`** created the bucket):

```bash
cd bootstrap/github-oidc

sed -i 's/backend "s3" {}/backend "local" {}/' main.tf   # GNU sed; macOS: sed -i '' 's/.../.../' main.tf
terraform init -input=false
terraform plan \
  -var="aws_region=us-east-1" \
  -var="github_org=YOUR_ORG" \
  -var="github_repo=intentproof-infra" \
  -var="github_actions_environment=beta"

terraform apply -input=false ...

git checkout -- main.tf

REGION=us-east-1
BUCKET=intentproof-tf-state

yes | terraform init -input=false -migrate-state \
  -backend-config="bucket=${BUCKET}" \
  -backend-config="key=bootstrap/github-oidc/terraform.tfstate" \
  -backend-config="region=${REGION}" \
  -backend-config="encrypt=true" \
  -backend-config="use_lockfile=true"
```

Routine updates (state already migrated): **`terraform init`** with **`backend-config`** only (see **`../../docs/DEPLOYMENT.md`**).

## Outputs

Workflow **summary** prints **both** **`github_terraform_plan_role_arn`** and **`github_terraform_role_arn`**. Store as **`AWS_TERRAFORM_PLAN_ROLE_ARN`** and **`AWS_TERRAFORM_ROLE_ARN`**.

If **`subject_claims_override`** is non-empty, it replaces **both** default plan and apply subject lists (advanced / break-glass).

Default **`managed_policy_arns`** on the **apply** role = **`AdministratorAccess`** — tighten before prod. Default **`plan_managed_policy_arns`** = **`ReadOnlyAccess`**.

# Bootstrap — Terraform remote state (S3 only)

Persistent Terraform **state**: **S3** key **`bootstrap/remote-state/terraform.tfstate`**, bucket **`intentproof-tf-state`** by default (**must equal** **`../stack/main.tf`** **`bucket`** backend field).

Creates the **S3 bucket** (versioned, encrypted, block-public-access, TLS-only policy). **`stack/`** uses **S3-native locking** (**`use_lockfile`** in **`../stack/main.tf`**) — **no DynamoDB lock table**.

Recommended: **GitHub Actions → Terraform bootstrap** (**see [`docs/DEPLOYMENT.md`](../docs/DEPLOYMENT.md)**) with **target **`bootstrap`**.

## Prerequisites

- Terraform **≥ 1.10**
- Credentials that can **`s3:*`** on the eventual state bucket (**`AWS_BOOTSTRAP_*`** cold path or **`AWS_TERRAFORM_ROLE_ARN`** afterward).

This module declares **`backend "s3"` {}`; **CLI `terraform init`** must pass **`-backend-config=…`** (steady state), **`-backend=false`** plus a later **`init -migrate-state`** (cold first apply), **or use the **`Terraform bootstrap`** workflow.

## Bucket name collision

S3 names are global. Override **`TF_VAR_state_bucket_name`** or **`-var 'state_bucket_name=…'`** and update **`../stack/main.tf`** backend **`bucket`** to match.

## Cold CLI path (parity with **`Terraform bootstrap`**)

```bash
cd bootstrap

terraform init -input=false -backend=false
terraform plan
terraform apply   # bucket + policy exist

REGION=us-east-1
BUCKET=intentproof-tf-state

yes | terraform init -input=false -migrate-state \
  -backend-config="bucket=${BUCKET}" \
  -backend-config="key=bootstrap/remote-state/terraform.tfstate" \
  -backend-config="region=${REGION}" \
  -backend-config="encrypt=true" \
  -backend-config="use_lockfile=true"

terraform init -input=false \
  -backend-config="bucket=${BUCKET}" \
  -backend-config="key=bootstrap/remote-state/terraform.tfstate" \
  -backend-config="region=${REGION}" \
  -backend-config="encrypt=true" \
  -backend-config="use_lockfile=true"
```

Then **`github-oidc`** (same bucket key prefix **`bootstrap/github-oidc/`**), followed by **`stack/`** **`terraform init`** (typically first **Actions** plan on **`stack/`**).

## Migrating from DynamoDB locks

If an older revision created **`intentproof-tf-locks`**, plan **`apply`** removes it once **`stack`** is **`use_lockfile`**-only — confirm destroys.

Never commit **`terraform.tfstate`** (see root **`.gitignore`**).

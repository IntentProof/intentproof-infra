# Bootstrap — Terraform remote state (S3 only)

Persistent Terraform **state**: **S3** key **`bootstrap/remote-state/terraform.tfstate`**, bucket **`intentproof-tf-state`** by default (**must equal** **`../stack/main.tf`** **`bucket`** backend field).

Creates the **S3 bucket** (versioned, encrypted, block-public-access, TLS-only policy). **`stack/`** uses **S3-native locking** (**`use_lockfile`** in **`../stack/main.tf`**) — **no DynamoDB lock table**.

Recommended: **GitHub Actions → Terraform bootstrap** (**see [`docs/DEPLOYMENT.md`](../docs/DEPLOYMENT.md)**) with **target **`bootstrap`**.

## Prerequisites

- Terraform **≥ 1.10**
- Credentials that can **`s3:*`** on the eventual state bucket (**`AWS_BOOTSTRAP_*`** cold path or **`AWS_TERRAFORM_ROLE_ARN`** afterward).

This module declares **`backend "s3"` {}`; **steady state:** **`terraform init`** with **`-backend-config=…`**. **Cold first apply** (no bucket yet): temporarily change that line to **`backend "local" {}`**, **`terraform init`**, plan/apply, restore **`main.tf`**, then **`init -migrate-state`** (see **Cold CLI path** below), **or use the **`Terraform bootstrap`** workflow** (it performs the rewrite automatically).

## Bucket name collision

S3 names are global. Override **`TF_VAR_state_bucket_name`** or **`-var 'state_bucket_name=…'`** and update **`../stack/main.tf`** backend **`bucket`** to match.

## Cold CLI path (parity with **`Terraform bootstrap`**)

```bash
cd bootstrap

# Terraform 1.10+ cannot plan/apply with `init -backend=false` while `backend "s3" {}` is declared.
# Use a real local backend until the bucket exists, then migrate to S3.
sed -i 's/backend "s3" {}/backend "local" {}/' main.tf   # GNU sed (Linux). On macOS: sed -i '' 's/.../.../' main.tf
terraform init -input=false
terraform plan
terraform apply   # bucket + policy exist

git checkout -- main.tf

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

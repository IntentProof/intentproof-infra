# Deployment model (intentproof-infra)

Infra **`plan`**/**`apply`** for **`stack/`** runs in **GitHub Actions** (**`Terraform`** workflow) using OIDC (**`sts:AssumeRoleWithWebIdentity`**).

Bootstrap modules (**`bootstrap/`**, **`bootstrap/github-oidc`**) normally run via **Terraform bootstrap** (**`.github/workflows/terraform-bootstrap.yml`**). They keep **persistent state in S3** under keys **`bootstrap/remote-state/terraform.tfstate`** and **`bootstrap/github-oidc/terraform.tfstate`** inside the **same bucket** **`stack`** uses (**`intentproof-tf-state`** by default).

## Recommended order (GitHub only)

Use **branch `main`** (or **`master`**); bootstrap workflows only run those refs.

1. **Secrets for cold start (optional IAM user)** — create **temporary** IAM user or access keys scoped to **`iam:*` OIDC**, **`s3:*`** on the eventual state bucket, and **`kms`** if applicable. Put these on the **`intentproof-infra`** repository:
   - **`AWS_BOOTSTRAP_ACCESS_KEY_ID`**
   - **`AWS_BOOTSTRAP_SECRET_ACCESS_KEY`**  
   **Remove both** once both OIDC roles are configured (**`AWS_TERRAFORM_PLAN_ROLE_ARN`** + **`AWS_TERRAFORM_ROLE_ARN`**).

2. **Actions → Terraform bootstrap** — target **`bootstrap`**, **credential_source** **`static_credentials`**, **state_behavior** **`provision_new_and_migrate`**, **run_apply** ✅ (required once). Confirm **state_bucket_name** equals **`bucket`** in **`stack/main.tf`**.

3. **Actions → Terraform bootstrap** — target **`github-oidc`**, **static_credentials** again, **`provision_new_and_migrate`**, **run_apply** ✅. Pick **state_bucket_name** unchanged. **`TF_VAR_github_*`** defaults come from **`github.repository_owner`** and **`github.event.repository.name`**. The workflow exports **`TF_VAR_terraform_state_bucket_name`** from the same **state_bucket_name** input so the **plan** IAM role’s S3 policy matches the real backend bucket.  
   If **`apply`** fails with **409** / **`EntityAlreadyExists`** for **`token.actions.githubusercontent.com`**, the GitHub OIDC URL is already registered in IAM — either **`terraform import`** the provider into state (see **`bootstrap/github-oidc/README.md`**) or rerun bootstrap with **`create_github_oidc_provider`** unchecked and **`existing_github_oidc_provider_arn`** set to that provider’s ARN.

4. From the **`github-oidc`** run **summary**, copy:
   - **`github_terraform_plan_role_arn`** → repository secret **`AWS_TERRAFORM_PLAN_ROLE_ARN`** (used for **`fmt` / `validate` / `plan`** on PR and push).
   - **`github_terraform_role_arn`** → repository secret **`AWS_TERRAFORM_ROLE_ARN`** (used only for **manual `apply`**).

5. **Delete/disable** **`AWS_BOOTSTRAP_*`** secrets (and the IAM keys) once comfortable.

6. Repeat **Terraform bootstrap** as needed (**`bootstrap`** / **`github-oidc`**) — use **credential_source** **`oidc`**, **state_behavior** **`existing_remote`**, and **`run_apply`** only when committing an infra change (**plan-only** otherwise).

7. **Actions → Terraform** (**`stack/`**) **`plan`/`apply`** as documented below.

If you intentionally keep CloudShell/AWS Console for bootstrap, **`terraform`** **CLI** for these modules follows the same **temporary `backend "local"` → `init` → apply → restore `main.tf` → `init -migrate-state`** pattern documented in **`bootstrap/README.md`** and **`bootstrap/github-oidc/README.md`**.

### Cold path vs steady state (**state_behavior**)

| **`state_behavior`** | When |
|----------------------|------|
| **`provision_new_and_migrate`** | No **S3** state yet (or migrating off pure local **`terraform.tfstate`**). CI rewrites **`backend "s3" {}`** to **`backend "local" {}`**, **`terraform init`**, plan/**`apply`**, restores **`main.tf`**, then **`init -migrate-state`** into **`state_bucket_name`**. **`run_apply` must be ✅** once so migration has real resources/state. |
| **`existing_remote`** | Default for routine updates; assumes state already stored under **`bootstrap/remote-state/`** or **`bootstrap/github-oidc/`**. |

Do **not** run **`provision_new_and_migrate`** twice unless you intentionally understand state resets (risk of duplicate IAM/S3 churn).

## Repository secrets for **`stack/`** variables

Terraform maps **`TF_VAR_<name>`** to root-module variable **`name`**. Configure secret inputs for **`terraform`** on **`stack/`**:

| Repository secret | Terraform variable | Notes |
|-------------------|----------------------|-------|
| **`AWS_TERRAFORM_PLAN_ROLE_ARN`** | _n/a_ | **Plans** (**PR**, **`main`** push); **ReadOnlyAccess**\-class + inline S3 state/lock (**`bootstrap/github-oidc`**). |
| **`AWS_TERRAFORM_ROLE_ARN`** | _n/a_ | **Apply** job only (**manual** **`workflow_dispatch`**); default **AdministratorAccess** — narrow for prod. |
| **`TF_VAR_DB_PASSWORD`** | `db_password` | RDS master password. |
| **`TF_VAR_API_KEYS_JSON`** | `api_keys_json` | Single-line JSON, e.g. `{"key-value":"tenant-id"}`. |
| **`TF_VAR_IMAGE_TAG`** | `image_tag` | Tag that exists in **ECR** (**`intentproof-api`** repo) — e.g. semver **`v0.2.0`** from **`intentproof-api`** **Release — Docker to ECR** workflow, or a short **git** SHA you pushed manually. |

| **`TF_VAR_RDS_BACKUP_RETENTION_PERIOD`** _(optional)_ | `rds_backup_retention_period` | Omit → default **`7`**; **`0`** on many **AWS Free Tier** accounts. |

Other **`stack`** inputs use **`stack/variables.tf`** defaults (**`alb_accept_http`** toggles listener **`:80`** + matching ALB SG ingress when **`false`** for HTTPS-only).

## GitHub Environment (apply gate)

The **`Terraform`** workflow **apply** job uses **`environment: beta`** by default. That name must match **`TF_VAR_github_actions_environment`** (**`github_actions_environment`** bootstrap input / **`bootstrap/github-oidc`** variable). Create/protect **`beta`** in the repo (**Settings → Environments**) so **apply** runs only with your approval rules **and** the OIDC trust **`sub`** includes **`repo:ORG/REPO:environment:beta`**.

Further OIDC knobs: **`bootstrap/github-oidc/README.md`**.

## **`intentproof-api`** — release image to ECR (GitHub Actions)

1. After **`stack`** **`apply`** (or when the IAM block is enabled), read **`terraform output -raw github_actions_api_ecr_push_role_arn`** from **`stack/`** (or the **Terraform** workflow apply summary when wired).
2. In **`IntentProof/intentproof-api`** → **Settings → Secrets and variables → Actions**, add **`AWS_ECR_PUSH_ROLE_ARN`** with that ARN.
3. Create and push a **semver** tag **`vX.Y.Z`** (must match **`[0-9]+.[0-9]+.[0-9]+`** after the **`v`**). The workflow **`.github/workflows/docker-ecr-release.yml`** builds **`linux/amd64`** and pushes **`ACCOUNT.dkr.ecr.REGION.amazonaws.com/intentproof-api:vX.Y.Z`**.
4. Set **`TF_VAR_IMAGE_TAG`** in **`intentproof-infra`** to the **same** tag string (ECR is **immutable**; the tag cannot be overwritten).
5. Run **`intentproof-infra`** **Terraform** **`apply`** (manual) to roll ECS to the new image.

Disable the managed role with **`create_github_actions_api_ecr_push_role = false`** if you use a different publisher or account layout; **`github_actions_api_repository`** / **`github_actions_api_ecr_push_role_name`** adjust defaults.

### Manual alternative

From **`intentproof-api`**, build **`linux/amd64`**, tag with the value you will set in **`TF_VAR_IMAGE_TAG`**, authenticate to **ECR**, **`docker push`**.

---

## **`stack/`** CI behavior (**`Terraform`** workflow)

There is **no automatic apply on merge.**

| Event | Behavior |
|--------|----------|
| **Pull request** to **`main`** | **`plan`** job: **`fmt`**, **`validate`**, **`plan`** (assumes **plan** role); uploads **`tfplan`** artifact. |
| **Push** to **`main`** | Same. |
| **`workflow_dispatch`** | **`plan`** job always; **`apply`** job only if **Run apply** ✅ (`main` / `master` only), assumes **apply** role, downloads saved plan, **`terraform apply tfplan`**. |

Least privilege: the **apply** role should be narrowed before external customers / multi-tenant production; **plan** role is meant to stay read-oriented plus state-bucket object read/write for locks.

---

## State recovery

If **`apply`** leaves **`errored.tfstate`**, reconcile before pushing **`terraform.tfstate`**. Prefer **Actions** (**OIDC**) over long laptop sessions (**`ExpiredToken`** during ACM waits).

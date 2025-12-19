# Alveriano Platform — Infrastructure (Terraform)

Terraform infrastructure for the Alveriano Platform API.

I use this repo to keep cloud resources repeatable and safe (remote state + locking, clear env config, and secrets hygiene), while powering multiple live websites.

## What this runs
- AWS Lambda (Node.js 20) for the platform API
- API Gateway as the HTTP entrypoint (see `apigateway.tf`)
- CloudWatch Logs for Lambda (retention configured)
- Terraform remote state in S3 + locking in DynamoDB

The Lambda environment is configured from Terraform variables (Supabase + Stripe).

## Used by
- https://resinaro.com
- https://giuseppe.food
- https://saltaireguide.uk

## Repo layout
- `lambda.tf` — Lambda packaging + IAM role + env vars + log group
- `apigateway.tf` — API Gateway routes/integration
- `providers.tf` — AWS provider config + default tags
- `versions.tf` — Terraform + provider versions + backend config
- `variables.tf` — environment + Supabase + Stripe variables (secrets marked sensitive)
- `outputs.tf` — outputs (URLs/ARNs/etc.)
- `network.tf` — network resources (if used)

## Prerequisites
- Terraform `>= 1.8.0`
- AWS account access in `eu-west-2` (London)
- AWS CLI configured (role-based access + MFA preferred)

This repo packages the API from a sibling folder:
- `../alveriano-platform-api`

## Remote state bootstrap (one-time)
This repo expects these to exist:
- S3 bucket: `alveriano-tf-state`
- DynamoDB table: `terraform-locks`

Example:

```bash
aws s3api create-bucket \
  --bucket alveriano-tf-state \
  --region eu-west-2 \
  --create-bucket-configuration LocationConstraint=eu-west-2

aws s3api put-bucket-versioning \
  --bucket alveriano-tf-state \
  --versioning-configuration Status=Enabled

aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
````

## Secrets and config

Do not commit secrets.

Create a local file (ignored by git):

* `secrets.auto.tfvars`

Example format:

```hcl
environment               = "dev"

supabase_url              = "https://xxxxx.supabase.co"
supabase_service_role_key = "YOUR_SUPABASE_SERVICE_ROLE_KEY"

stripe_secret_key         = "YOUR_STRIPE_SECRET_KEY"
stripe_webhook_secret     = "YOUR_STRIPE_WEBHOOK_SECRET"
```

## Deploy workflow

### 1) Build the API

From `../alveriano-platform-api`:

```bash
npm ci
npm run build
```

### 2) Plan and apply infra

From this repo:

```bash
terraform fmt -recursive
terraform init
terraform validate
terraform plan
terraform apply
```

## Local safety checks (recommended)

This repo includes a pre-commit hook that blocks common secret patterns from being committed.

Enable it after cloning:

```bash
git config core.hooksPath .githooks
```

## Notes

* `.terraform.lock.hcl` is committed for reproducible provider resolution.
* State and secrets are intentionally not committed:

  * `*.tfstate*`, `.terraform/`, `secrets.auto.tfvars`, `build/`, `*.zip`

## Roadmap

* GitHub Actions: PR plans + gated applies on main
* OIDC (GitHub → AWS) to avoid long-lived AWS keys in GitHub
* CloudWatch alarms for errors/throttles
* Simple runbook for deploy/rollback/diagnostics


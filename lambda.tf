########################################
# lambda.tf
########################################

########################################
# Lambda packaging: zip the API project
########################################

locals {
  # We package ONLY the deploy artifact produced by your bundling step
  # (keeps the Lambda zip small and avoids node_modules bloat).
  api_source_dir = abspath("${path.module}/../alveriano-platform-api/lambda-dist")
  api_zip_path   = "${path.module}/build/alveriano-platform-api.zip"
}

data "archive_file" "api_bundle" {
  type        = "zip"
  source_dir  = local.api_source_dir
  output_path = local.api_zip_path

  # SECURITY: never package secrets or local tooling state into the Lambda zip
  excludes = [
    ".git",
    ".github",
    ".vscode",
    "build",
    ".terraform",

    # secrets / env
    ".env",
    ".env.*",

    # supabase local state + migrations (not needed in Lambda runtime)
    "supabase",
    "supabase/**",

    # optional noise
    "README.md",
    "*.log",
  ]
}

########################################
# Secrets Manager: API runtime config container
#
# IMPORTANT TRUTH:
# - This creates a secret "container" (ARN) and KMS key.
# - Unless your *code* fetches and loads this secret at runtime, it does nothing.
# - If you put secret values into Terraform-managed secret versions, they will still end up in TF state.
########################################

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

resource "aws_kms_key" "api_secrets" {
  description             = "KMS key for alveriano-platform-api secrets (${var.environment})"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnableAccountRootPermissions"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "api_secrets" {
  name          = "alias/alveriano-platform-api-${var.environment}-secrets"
  target_key_id = aws_kms_key.api_secrets.key_id
}

resource "aws_secretsmanager_secret" "api_config" {
  name                    = "alveriano-platform-api/${var.environment}/config"
  kms_key_id              = aws_kms_key.api_secrets.arn
  recovery_window_in_days = 7
}

########################################
# IAM role for the API Lambda
########################################

resource "aws_iam_role" "api_lambda_role" {
  name = "alveriano-platform-api-${var.environment}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "api_lambda_basic" {
  role       = aws_iam_role.api_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Least-privilege: Lambda can read ONLY this one secret, and decrypt ONLY via KMS
data "aws_iam_policy_document" "api_secrets_access" {
  statement {
    sid       = "ReadApiConfigSecret"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.api_config.arn]
  }

  statement {
    sid       = "DecryptApiSecretKey"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.api_secrets.arn]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["secretsmanager.${data.aws_region.current.name}.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "api_secrets_access" {
  name   = "alveriano-platform-api-${var.environment}-secrets-access"
  role   = aws_iam_role.api_lambda_role.id
  policy = data.aws_iam_policy_document.api_secrets_access.json
}

########################################
# Lambda function: alveriano-platform-api
########################################

resource "aws_lambda_function" "api" {
  function_name = "alveriano-platform-api-${var.environment}"

  role    = aws_iam_role.api_lambda_role.arn
  runtime = "nodejs20.x"
  handler = "dist/http/apiHandler.handler"

  filename         = data.archive_file.api_bundle.output_path
  source_code_hash = data.archive_file.api_bundle.output_base64sha256

  memory_size = 256
  timeout     = 10

  environment {
    variables = {
      # Your code’s env.ts enforces APP_ENV in Lambda (dev|staging|prod)
      APP_ENV  = var.environment
      NODE_ENV = var.environment

      AWS_NODEJS_CONNECTION_REUSE_ENABLED = "1"

      # Optional: improves stack traces when you ship sourcemaps
      NODE_OPTIONS = "--enable-source-maps"

      # Required by env.ts at boot (your logs prove these are mandatory)
      SUPABASE_URL              = var.supabase_url
      SUPABASE_SERVICE_ROLE_KEY = var.supabase_service_role_key
      STRIPE_SECRET_KEY         = var.stripe_secret_key

      # Recommended: webhook code often validates this at import or on route hit
      STRIPE_WEBHOOK_SECRET = var.stripe_webhook_secret

      # Present for future migration to runtime-secret loading (NOT used by your code yet)
      CONFIG_SECRET_ARN    = aws_secretsmanager_secret.api_config.arn
      CONFIG_SECRET_REGION = data.aws_region.current.name
    }
  }
}

########################################
# CloudWatch logs for the Lambda
########################################

resource "aws_cloudwatch_log_group" "api_lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.api.function_name}"
  retention_in_days = 14
}

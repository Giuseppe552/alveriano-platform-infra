########################################
# Lambda packaging: zip the API project
########################################

locals {
  # Path to the API project root (contains dist/, node_modules/, package.json, etc.)
  api_source_dir = abspath("${path.module}/../alveriano-platform-api")

  # Where to put the zip inside this infra repo
  api_zip_path   = "${path.module}/build/alveriano-platform-api.zip"
}

data "archive_file" "api_bundle" {
  type        = "zip"
  source_dir  = local.api_source_dir
  output_path = local.api_zip_path

  # Optional: keep the zip reasonably clean
  excludes = [
    ".git",
    ".github",
    ".vscode",
    "build",
    ".terraform"
  ]
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

########################################
# Lambda function: alveriano-platform-api
########################################

resource "aws_lambda_function" "api" {
  function_name = "alveriano-platform-api-${var.environment}"

  role    = aws_iam_role.api_lambda_role.arn
  runtime = "nodejs20.x"

  # Inside the zip, compiled code lives under dist/
  # dist/http/apiHandler.js exports "handler"
  handler = "dist/http/apiHandler.handler"

  filename         = data.archive_file.api_bundle.output_path
  source_code_hash = data.archive_file.api_bundle.output_base64sha256

  memory_size = 256
  timeout     = 10

  environment {
    variables = {
      SUPABASE_URL              = var.supabase_url
      SUPABASE_SERVICE_ROLE_KEY = var.supabase_service_role_key
      STRIPE_SECRET_KEY         = var.stripe_secret_key
      STRIPE_WEBHOOK_SECRET     = var.stripe_webhook_secret
      NODE_ENV                  = var.environment
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

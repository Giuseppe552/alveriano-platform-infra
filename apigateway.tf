########################################
# HTTP API for Alveriano Platform
########################################

locals {
  # Browser origins allowed to call the API.
  # CORS is NOT auth; it's only a browser control.
  # Put it here so OPTIONS never depends on Lambda.
  cors_allowed_origins = [
    "https://resinaro.com",
    "https://www.resinaro.com",

    "https://saltaireguide.uk",
    "https://www.saltaireguide.uk",

    "https://giuseppe.food",
    "https://www.giuseppe.food",

    # local dev
    "http://localhost:3000",
    "http://127.0.0.1:3000",
  ]
}

resource "aws_apigatewayv2_api" "http_api" {
  name          = "alveriano-platform-http-${var.environment}"
  protocol_type = "HTTP"

  # API Gateway answers OPTIONS preflights automatically.
  cors_configuration {
    allow_origins = local.cors_allowed_origins
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["content-type", "stripe-signature"]
    max_age       = 600
  }
}

########################################
# CloudWatch access logs (HTTP API)
########################################

resource "aws_cloudwatch_log_group" "http_api_access_logs" {
  name              = "/aws/apigateway/${aws_apigatewayv2_api.http_api.name}"
  retention_in_days = 14
}

########################################
# Lambda integration (proxy)
########################################

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
  timeout_milliseconds   = 10000
}

########################################
# Routes (explicit)
########################################

resource "aws_apigatewayv2_route" "submit_form" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /forms/submit"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_route" "submit_paid_form" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /forms/submit-paid"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_route" "stripe_webhook" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /stripe/webhook"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_route" "health" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /health"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

########################################
# $default route
# Keep this so trailing slashes / unknown paths still reach Lambda.
# (HTTP API cannot define a route key with a trailing slash.)
########################################

resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

########################################
# Default stage ($default) with auto-deploy
########################################

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.http_api_access_logs.arn
    format = jsonencode({
      requestId        = "$context.requestId"
      ip               = "$context.identity.sourceIp"
      requestTime      = "$context.requestTime"
      httpMethod       = "$context.httpMethod"
      routeKey         = "$context.routeKey"
      path             = "$context.path"
      status           = "$context.status"
      responseLength   = "$context.responseLength"
      integrationError = "$context.integrationErrorMessage"
    })
  }

  # Global default throttles
  default_route_settings {
    throttling_burst_limit   = 30
    throttling_rate_limit    = 15
    detailed_metrics_enabled = true
  }

  # Route-specific tuning
  route_settings {
    route_key                = "POST /stripe/webhook"
    throttling_burst_limit   = 50
    throttling_rate_limit    = 25
    detailed_metrics_enabled = true
  }

  route_settings {
    route_key                = "POST /forms/submit"
    throttling_burst_limit   = 20
    throttling_rate_limit    = 10
    detailed_metrics_enabled = true
  }

  route_settings {
    route_key                = "POST /forms/submit-paid"
    throttling_burst_limit   = 20
    throttling_rate_limit    = 10
    detailed_metrics_enabled = true
  }

  route_settings {
    route_key                = "GET /health"
    throttling_burst_limit   = 10
    throttling_rate_limit    = 5
    detailed_metrics_enabled = false
  }

  # Keep $default tighter; it’s a catch-all
  route_settings {
    route_key                = "$default"
    throttling_burst_limit   = 10
    throttling_rate_limit    = 5
    detailed_metrics_enabled = true
  }
}

########################################
# Allow API Gateway to invoke the Lambda
########################################

resource "aws_lambda_permission" "allow_apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvokeHttpApi"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"

  # IMPORTANT:
  # Make this unambiguous: allow ANY stage/method/path for THIS API ID.
  # This prevents the exact "$default -> permission -> 500" failure mode you hit.
  source_arn = "${aws_apigatewayv2_api.http_api.execution_arn}/*"
}

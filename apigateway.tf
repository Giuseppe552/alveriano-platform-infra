########################################
# HTTP API for Alveriano Platform
########################################

resource "aws_apigatewayv2_api" "http_api" {
  name          = "alveriano-platform-http-${var.environment}"
  protocol_type = "HTTP"

  # Basic CORS so your Vercel sites can call the API.
  # We can tighten this to specific origins later.
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["content-type"]
  }
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
}

########################################
# Routes
########################################

# Unpaid forms: POST /forms/submit
resource "aws_apigatewayv2_route" "submit_form" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /forms/submit"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Paid forms: POST /forms/submit-paid
resource "aws_apigatewayv2_route" "submit_paid_form" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /forms/submit-paid"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Stripe webhooks: POST /stripe/webhook
resource "aws_apigatewayv2_route" "stripe_webhook" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /stripe/webhook"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

########################################
# Default stage ($default) with auto-deploy
########################################

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

########################################
# Allow API Gateway to invoke the Lambda
########################################

resource "aws_lambda_permission" "allow_apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"

  # Allow any method/route on this API to call the Lambda
  source_arn = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

########################################
# Useful outputs for the platform
########################################

# Base URL for the public HTTP API.
# Your apps will call:
#   POST "${api_base_url}/forms/submit"
#   POST "${api_base_url}/forms/submit-paid"
output "api_base_url" {
  description = "Base URL for the Alveriano HTTP API"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

# Lambda function name for debugging / logs
output "api_lambda_function_name" {
  description = "Name of the Lambda function running the API"
  value       = aws_lambda_function.api.function_name
}

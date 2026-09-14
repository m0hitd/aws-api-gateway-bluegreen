# ── IAM pass-through (role created outside Terraform for free tier safety) ──

# ── Blue Lambda ──
resource "aws_lambda_function" "blue" {
  function_name    = "bg-blue"
  filename         = var.blue_zip_path
  source_code_hash = filebase64sha256(var.blue_zip_path)
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  role             = var.lambda_role_arn
}

# ── Green Lambda ──
resource "aws_lambda_function" "green" {
  function_name    = "bg-green"
  filename         = var.green_zip_path
  source_code_hash = filebase64sha256(var.green_zip_path)
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  role             = var.lambda_role_arn
}

# ── API Gateway ──
resource "aws_apigatewayv2_api" "bg_api" {
  name          = "blue-green-api"
  protocol_type = "HTTP"
}

# ── Lambda integrations ──
resource "aws_apigatewayv2_integration" "blue_integration" {
  api_id                 = aws_apigatewayv2_api.bg_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.blue.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "green_integration" {
  api_id                 = aws_apigatewayv2_api.bg_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.green.invoke_arn
  payload_format_version = "2.0"
}

# ── Route → Blue (default) ──
resource "aws_apigatewayv2_route" "default_route" {
  api_id    = aws_apigatewayv2_api.bg_api.id
  route_key = "GET /api"
  target    = "integrations/${aws_apigatewayv2_integration.blue_integration.id}"
}

# ── Stage ──
resource "aws_apigatewayv2_stage" "prod" {
  api_id      = aws_apigatewayv2_api.bg_api.id
  name        = "prod"
  auto_deploy = true
}

# ── Lambda permissions ──
resource "aws_lambda_permission" "blue_permission" {
  statement_id  = "AllowAPIGatewayBlue"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.blue.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.bg_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "green_permission" {
  statement_id  = "AllowAPIGatewayGreen"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.green.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.bg_api.execution_arn}/*/*"
}

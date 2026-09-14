output "api_endpoint" {
  value = "${aws_apigatewayv2_stage.prod.invoke_url}/api"
}

output "blue_lambda_arn" {
  value = aws_lambda_function.blue.arn
}

output "green_lambda_arn" {
  value = aws_lambda_function.green.arn
}

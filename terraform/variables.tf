variable "aws_region" {
  default = "us-east-1"
}

variable "blue_zip_path" {
  default = "../src/blue/blue.zip"
}

variable "green_zip_path" {
  default = "../src/green/green.zip"
}

variable "lambda_role_arn" {
  description = "IAM role ARN for Lambda execution"
}

provider "aws" {
  region = "us-east-1"
}

variable "unique_suffix" {
  default = true
}

variable "bucket_base_name" {
  default = "insurance-rag-lambda-code"
}

resource "random_string" "suffix" {
  count   = var.unique_suffix ? 1 : 0
  length  = 6
  special = false
}

locals {
  final_bucket_name = var.unique_suffix ? "${var.bucket_base_name}-${random_string.suffix[0].result}" : var.bucket_base_name
}

resource "aws_s3_bucket" "lambda_bucket" {
  bucket = local.final_bucket_name
}

resource "aws_s3_object" "lambda_zip" {
  bucket = aws_s3_bucket.lambda_bucket.id
  key    = "app.zip"
  source = "../app.zip"
  etag   = filemd5("../app.zip")
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_exec_policy" {
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_lambda_function" "insurance_bot" {
  function_name = "insuranceBot"
  s3_bucket     = aws_s3_bucket.lambda_bucket.id
  s3_key        = aws_s3_object.lambda_zip.key
  handler       = "Insurance_bot.lambda_handler"
  runtime       = "python3.10"
  role          = aws_iam_role.lambda_exec_role.arn
  memory_size   = 512
  timeout       = 15
}

resource "aws_apigatewayv2_api" "api" {
  name          = "insurance-bot-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id             = aws_apigatewayv2_api.api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.insurance_bot.invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "default_route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "POST /ask"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true
}

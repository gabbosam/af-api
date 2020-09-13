provider "aws" {
  version = "~> 2.0"
  region  = "eu-west-1"
  profile = "AF"
}

terraform {
  backend "s3" {
    bucket = "af-lambda-code"
    key    = "iac/terraform.tfstate"
    region = "eu-west-1"
  }
}

resource "aws_lambda_function" "login" {
  function_name    = "login"
  role             = "arn:aws:iam::374237882048:role/lambda-role"
  handler          = "app.lambda_function"
  filename         = "login/code.zip"
  source_code_hash = filebase64sha256("login/code.zip")
  timeout          = 30
  runtime          = "python3.8"
  environment {
    variables = {
      LOG_LEVEL      = "DEBUG"
      TABLE_NAME     = "users"
      TOKEN_DURATION = 180
    }
  }
}

resource "aws_lambda_function" "check-in" {
  function_name    = "check-in"
  role             = "arn:aws:iam::374237882048:role/lambda-role"
  handler          = "app.lambda_function"
  filename         = "check-in/code.zip"
  source_code_hash = filebase64sha256("check-in/code.zip")
  timeout          = 30
  runtime          = "python3.8"
  environment {
    variables = {
      LOG_LEVEL  = "DEBUG"
      TABLE_NAME = "access"
    }
  }
}

resource "aws_lambda_function" "check-out" {
  function_name    = "check-out"
  role             = "arn:aws:iam::374237882048:role/lambda-role"
  handler          = "app.lambda_function"
  filename         = "check-out/code.zip"
  source_code_hash = filebase64sha256("check-out/code.zip")
  timeout          = 30
  runtime          = "python3.8"
  environment {
    variables = {
      LOG_LEVEL  = "DEBUG"
      TABLE_NAME = "access"
    }
  }
}

resource "aws_lambda_function" "authorizer" {
  function_name    = "authorizer"
  role             = "arn:aws:iam::374237882048:role/lambda-role"
  handler          = "app.lambda_function"
  filename         = "authorizer/code.zip"
  source_code_hash = filebase64sha256("authorizer/code.zip")
  timeout          = 30
  runtime          = "python3.8"
  environment {
    variables = {
      LOG_LEVEL  = "DEBUG"
      TABLE_NAME = "users"
    }
  }
}

resource "aws_lambda_function" "add-user" {
  function_name    = "add-user"
  role             = "arn:aws:iam::374237882048:role/lambda-role"
  handler          = "app.lambda_function"
  filename         = "add-user/code.zip"
  source_code_hash = filebase64sha256("add-user/code.zip")
  timeout          = 30
  runtime          = "python3.8"
  environment {
    variables = {
      LOG_LEVEL  = "DEBUG"
      TABLE_NAME = "users"
    }
  }
}

resource "aws_lambda_function" "qrcode-generator" {
  function_name    = "qrcode-generator"
  role             = "arn:aws:iam::374237882048:role/lambda-role"
  handler          = "app.lambda_function"
  filename         = "qrcode-generator/code.zip"
  source_code_hash = filebase64sha256("qrcode-generator/code.zip")
  timeout          = 30
  runtime          = "python3.8"
  environment {
    variables = {
      LOG_LEVEL = "DEBUG"
    }
  }
}

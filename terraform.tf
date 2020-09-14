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
  filename         = "login/build/code.zip"
  source_code_hash = filebase64sha256("login/build/code.zip")
  timeout          = 30
  runtime          = "python3.8"
  environment {
    variables = {
      LOG_LEVEL      = "DEBUG"
      TABLE_NAME     = "users"
      TOKEN_DURATION = var.token_expiration
    }
  }
}

resource "aws_lambda_function" "refresh-token" {
  function_name    = "refresh-token"
  role             = "arn:aws:iam::374237882048:role/lambda-role"
  handler          = "app.lambda_function"
  filename         = "refresh-token/build/code.zip"
  source_code_hash = filebase64sha256("refresh-token/build/code.zip")
  timeout          = 30
  runtime          = "python3.8"
  environment {
    variables = {
      LOG_LEVEL      = "DEBUG"
      TABLE_NAME     = "users"
      TOKEN_DURATION = var.token_expiration
    }
  }
}

resource "aws_lambda_function" "check-in" {
  function_name    = "check-in"
  role             = "arn:aws:iam::374237882048:role/lambda-role"
  handler          = "app.lambda_function"
  filename         = "check-in/build/code.zip"
  source_code_hash = filebase64sha256("check-in/build/code.zip")
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
  filename         = "check-out/build/code.zip"
  source_code_hash = filebase64sha256("check-out/build/code.zip")
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
  filename         = "authorizer/build/code.zip"
  source_code_hash = filebase64sha256("authorizer/build/code.zip")
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
  filename         = "add-user/build/code.zip"
  source_code_hash = filebase64sha256("add-user/build/code.zip")
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
  filename         = "qrcode-generator/build/code.zip"
  source_code_hash = filebase64sha256("qrcode-generator/build/code.zip")
  timeout          = 30
  runtime          = "python3.8"
  environment {
    variables = {
      LOG_LEVEL = "DEBUG"
    }
  }
}


# API GW
resource "aws_api_gateway_rest_api" "api_gw" {
  name = "af-api"

  endpoint_configuration {
    types = ["EDGE"]
  }
}

resource "aws_api_gateway_api_key" "api_gw_api_key" {
  name = "client-api-key"
}

resource "aws_api_gateway_authorizer" "authorizer" {
  name           = "authorizer"
  rest_api_id    = aws_api_gateway_rest_api.api_gw.id
  authorizer_uri = aws_lambda_function.authorizer.invoke_arn
  type           = "REQUEST"
}

resource "aws_api_gateway_authorizer" "admins-authorizer" {
  name            = "admins-authorizer"
  rest_api_id     = aws_api_gateway_rest_api.api_gw.id
  authorizer_uri  = aws_lambda_function.authorizer.invoke_arn
  type            = "REQUEST"
  identity_source = "method.request.header.Authorization,method.request.header.Role"
}

resource "aws_api_gateway_resource" "login" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  parent_id   = aws_api_gateway_rest_api.api_gw.root_resource_id
  path_part   = "login"
  depends_on = [
    aws_api_gateway_rest_api.api_gw
  ]
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_method" "login_method" {
  rest_api_id   = aws_api_gateway_rest_api.api_gw.id
  resource_id   = aws_api_gateway_resource.login.id
  http_method   = "POST"
  authorization = "NONE"
  #authorizer_id    = aws_api_gateway_authorizer.authorizer.id
  api_key_required = true
  depends_on = [
    aws_api_gateway_resource.login
  ]
}

resource "aws_api_gateway_integration" "login_integration" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  resource_id = aws_api_gateway_resource.login.id
  http_method = aws_api_gateway_method.login_method.http_method
  # integration_http_method for lambda integration MUST BE POST
  # see: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_integration#integration_http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.login.invoke_arn
  content_handling        = "CONVERT_TO_TEXT"
  depends_on = [
    aws_api_gateway_resource.login,
    aws_api_gateway_method.login_method
  ]
}

resource "aws_api_gateway_method" "login_cors" {
  rest_api_id   = aws_api_gateway_rest_api.api_gw.id
  resource_id   = aws_api_gateway_resource.login.id
  http_method   = "OPTIONS"
  authorization = "NONE"
  depends_on = [
    aws_api_gateway_resource.login
  ]
}

resource "aws_api_gateway_integration" "login_cors_integration" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  resource_id = aws_api_gateway_resource.login.id
  http_method = aws_api_gateway_method.login_cors.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = jsonencode(
      {
        statusCode = 200
      }
    )
  }
}

resource "aws_api_gateway_method_response" "login_cors_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  resource_id = aws_api_gateway_resource.login.id
  http_method = aws_api_gateway_method.login_cors.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"      = true
    "method.response.header.Access-Control-Allow-Credentials" = true
    "method.response.header.Access-Control-Allow-Headers"     = true
    "method.response.header.Access-Control-Allow-Methods"     = true
  }
}

resource "aws_api_gateway_resource" "refresh_token" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  parent_id   = aws_api_gateway_rest_api.api_gw.root_resource_id
  path_part   = "refresh-token"
  depends_on = [
    aws_api_gateway_rest_api.api_gw
  ]
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_method" "refresh_token_method" {
  rest_api_id   = aws_api_gateway_rest_api.api_gw.id
  resource_id   = aws_api_gateway_resource.refresh_token.id
  http_method   = "POST"
  authorization = "NONE"
  #authorizer_id    = aws_api_gateway_authorizer.authorizer.id
  api_key_required = true
  depends_on = [
    aws_api_gateway_resource.refresh_token
  ]
}

resource "aws_api_gateway_integration" "refresh_token_integration" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  resource_id = aws_api_gateway_resource.refresh_token.id
  http_method = aws_api_gateway_method.refresh_token_method.http_method
  # integration_http_method for lambda integration MUST BE POST
  # see: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_integration#integration_http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.refresh-token.invoke_arn
  content_handling        = "CONVERT_TO_TEXT"
  depends_on = [
    aws_api_gateway_resource.refresh_token,
    aws_api_gateway_method.refresh_token_method
  ]
}


resource "aws_api_gateway_resource" "check_in" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  parent_id   = aws_api_gateway_rest_api.api_gw.root_resource_id
  path_part   = "check-in"
  depends_on = [
    aws_api_gateway_rest_api.api_gw
  ]
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_method" "check_in_method" {
  rest_api_id      = aws_api_gateway_rest_api.api_gw.id
  resource_id      = aws_api_gateway_resource.check_in.id
  http_method      = "POST"
  authorization    = "CUSTOM"
  authorizer_id    = aws_api_gateway_authorizer.authorizer.id
  api_key_required = true
  depends_on = [
    aws_api_gateway_resource.check_in
  ]
}

resource "aws_api_gateway_integration" "check_in_integration" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  resource_id = aws_api_gateway_resource.check_in.id
  http_method = aws_api_gateway_method.check_in_method.http_method
  # integration_http_method for lambda integration MUST BE POST
  # see: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_integration#integration_http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.check-in.invoke_arn
  content_handling        = "CONVERT_TO_TEXT"
  depends_on = [
    aws_api_gateway_resource.check_in,
    aws_api_gateway_method.check_in_method
  ]
}

resource "aws_api_gateway_resource" "check_out" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  parent_id   = aws_api_gateway_rest_api.api_gw.root_resource_id
  path_part   = "check-out"
  depends_on = [
    aws_api_gateway_rest_api.api_gw
  ]
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_method" "check_out_method" {
  rest_api_id      = aws_api_gateway_rest_api.api_gw.id
  resource_id      = aws_api_gateway_resource.check_out.id
  http_method      = "POST"
  authorization    = "CUSTOM"
  authorizer_id    = aws_api_gateway_authorizer.authorizer.id
  api_key_required = true
  depends_on = [
    aws_api_gateway_resource.check_out
  ]
}

resource "aws_api_gateway_integration" "check_out_integration" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  resource_id = aws_api_gateway_resource.check_out.id
  http_method = aws_api_gateway_method.check_out_method.http_method
  # integration_http_method for lambda integration MUST BE POST
  # see: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_integration#integration_http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.check-out.invoke_arn
  content_handling        = "CONVERT_TO_TEXT"
  depends_on = [
    aws_api_gateway_resource.check_out,
    aws_api_gateway_method.check_out_method
  ]
}

resource "aws_api_gateway_resource" "admin" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  parent_id   = aws_api_gateway_rest_api.api_gw.root_resource_id
  path_part   = "admin"
  depends_on = [
    aws_api_gateway_rest_api.api_gw
  ]
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_resource" "add_user" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  parent_id   = aws_api_gateway_resource.admin.id
  path_part   = "add-user"
  depends_on = [
    aws_api_gateway_rest_api.api_gw
  ]
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_method" "add_user_method" {
  rest_api_id      = aws_api_gateway_rest_api.api_gw.id
  resource_id      = aws_api_gateway_resource.add_user.id
  http_method      = "POST"
  authorization    = "CUSTOM"
  authorizer_id    = aws_api_gateway_authorizer.admins-authorizer.id
  api_key_required = true
  request_parameters = {
    "method.request.header.Role" = true
  }
  depends_on = [
    aws_api_gateway_resource.add_user
  ]
}

resource "aws_api_gateway_integration" "add_user_integration" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  resource_id = aws_api_gateway_resource.add_user.id
  http_method = aws_api_gateway_method.add_user_method.http_method
  # integration_http_method for lambda integration MUST BE POST
  # see: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_integration#integration_http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.add-user.invoke_arn
  content_handling        = "CONVERT_TO_TEXT"
  depends_on = [
    aws_api_gateway_resource.add_user,
    aws_api_gateway_method.add_user_method
  ]
}

resource "aws_lambda_permission" "login" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "login"
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = format(
    "%s/*/POST/login",
    aws_api_gateway_rest_api.api_gw.execution_arn
  )
}

resource "aws_lambda_permission" "refresh_token" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "refresh-token"
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = format(
    "%s/*/POST/refresh-token",
    aws_api_gateway_rest_api.api_gw.execution_arn
  )
}

resource "aws_lambda_permission" "check-in" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "check-in"
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = format(
    "%s/*/POST/check-in",
    aws_api_gateway_rest_api.api_gw.execution_arn
  )
}

resource "aws_lambda_permission" "check-out" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "check-out"
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = format(
    "%s/*/POST/check-out",
    aws_api_gateway_rest_api.api_gw.execution_arn
  )
}

resource "aws_lambda_permission" "add-user" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "add-user"
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = format(
    "%s/*/POST/admin/add-user",
    aws_api_gateway_rest_api.api_gw.execution_arn
  )
}

resource "aws_lambda_permission" "authorizer" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "authorizer"
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = format(
    "%s/authorizers/%s",
    aws_api_gateway_rest_api.api_gw.execution_arn,
    aws_api_gateway_authorizer.authorizer.id
  )
}

resource "aws_lambda_permission" "admins-authorizer" {
  statement_id  = "AllowExecutionFromAPIGatewayForAdmins"
  action        = "lambda:InvokeFunction"
  function_name = "authorizer"
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = format(
    "%s/authorizers/%s",
    aws_api_gateway_rest_api.api_gw.execution_arn,
    aws_api_gateway_authorizer.admins-authorizer.id
  )
}

resource "aws_api_gateway_usage_plan" "api_gw_usage_plan" {
  name = "Base"
  api_stages {
    api_id = aws_api_gateway_rest_api.api_gw.id
    stage  = "dev"
  }

  quota_settings {
    limit  = 2000
    offset = 0
    period = "MONTH"
  }

  throttle_settings {
    burst_limit = 25
    rate_limit  = 50
  }
}

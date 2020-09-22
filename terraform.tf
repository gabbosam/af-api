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

resource "aws_lambda_function" "logout" {
  function_name    = "logout"
  role             = "arn:aws:iam::374237882048:role/lambda-role"
  handler          = "app.lambda_function"
  filename         = "logout/build/code.zip"
  source_code_hash = filebase64sha256("logout/build/code.zip")
  timeout          = 30
  runtime          = "python3.8"
  environment {
    variables = {
      LOG_LEVEL = "DEBUG"
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

resource "aws_lambda_function" "me" {
  function_name    = "me"
  role             = "arn:aws:iam::374237882048:role/lambda-role"
  handler          = "app.lambda_function"
  filename         = "me/build/code.zip"
  source_code_hash = filebase64sha256("me/build/code.zip")
  timeout          = 30
  runtime          = "python3.8"
  environment {
    variables = {
      LOG_LEVEL  = "DEBUG"
      TABLE_NAME = "users"
    }
  }
}

resource "aws_lambda_function" "update_me" {
  function_name    = "update-me"
  role             = "arn:aws:iam::374237882048:role/lambda-role"
  handler          = "app.lambda_function"
  filename         = "update-me/build/code.zip"
  source_code_hash = filebase64sha256("update-me/build/code.zip")
  timeout          = 30
  runtime          = "python3.8"
  environment {
    variables = {
      LOG_LEVEL  = "DEBUG"
      TABLE_NAME = "users"
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lambda_function" "add_survey" {
  function_name    = "add-survey"
  role             = "arn:aws:iam::374237882048:role/lambda-role"
  handler          = "app.lambda_function"
  filename         = "add-survey/build/code.zip"
  source_code_hash = filebase64sha256("add-survey/build/code.zip")
  timeout          = 30
  runtime          = "python3.8"
  environment {
    variables = {
      LOG_LEVEL  = "DEBUG"
      TABLE_NAME = "survey"
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lambda_function" "pdf-gen" {
  function_name    = "pdf-gen"
  role             = "arn:aws:iam::374237882048:role/lambda-role"
  handler          = "app.handler"
  filename         = "pdf-gen/build/code.zip"
  source_code_hash = filebase64sha256("pdf-gen/build/code.zip")
  timeout          = 30
  runtime          = "nodejs12.x"
  environment {
    variables = {
      LOG_LEVEL = "INFO"
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

# me
resource "aws_api_gateway_resource" "me" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  parent_id   = aws_api_gateway_rest_api.api_gw.root_resource_id
  path_part   = "me"
  depends_on = [
    aws_api_gateway_rest_api.api_gw
  ]
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_method" "me_method" {
  rest_api_id   = aws_api_gateway_rest_api.api_gw.id
  resource_id   = aws_api_gateway_resource.me.id
  http_method   = "GET"
  authorization = "NONE"
  #authorizer_id    = aws_api_gateway_authorizer.authorizer.id
  api_key_required = true
  depends_on = [
    aws_api_gateway_resource.me
  ]
}

resource "aws_api_gateway_integration" "me_integration" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  resource_id = aws_api_gateway_resource.me.id
  http_method = aws_api_gateway_method.me_method.http_method
  # integration_http_method for lambda integration MUST BE POST
  # see: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_integration#integration_http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.me.invoke_arn
  content_handling        = "CONVERT_TO_TEXT"
  depends_on = [
    aws_api_gateway_resource.me,
    aws_api_gateway_method.me_method
  ]
}

resource "aws_api_gateway_resource" "update_me" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  parent_id   = aws_api_gateway_rest_api.api_gw.root_resource_id
  path_part   = "update-me"
  depends_on = [
    aws_api_gateway_rest_api.api_gw
  ]
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_method" "update_me_method" {
  rest_api_id      = aws_api_gateway_rest_api.api_gw.id
  resource_id      = aws_api_gateway_resource.update_me.id
  http_method      = "POST"
  authorization    = "CUSTOM"
  authorizer_id    = aws_api_gateway_authorizer.authorizer.id
  api_key_required = true
  depends_on = [
    aws_api_gateway_resource.update_me
  ]
}

resource "aws_api_gateway_integration" "update_me_integration" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  resource_id = aws_api_gateway_resource.update_me.id
  http_method = aws_api_gateway_method.update_me_method.http_method
  # integration_http_method for lambda integration MUST BE POST
  # see: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_integration#integration_http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.update_me.invoke_arn
  content_handling        = "CONVERT_TO_TEXT"
  depends_on = [
    aws_api_gateway_resource.update_me,
    aws_api_gateway_method.update_me_method
  ]
}

resource "aws_api_gateway_resource" "add_survey" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  parent_id   = aws_api_gateway_rest_api.api_gw.root_resource_id
  path_part   = "add-survey"
  depends_on = [
    aws_api_gateway_rest_api.api_gw
  ]
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_method" "add_survey_method" {
  rest_api_id      = aws_api_gateway_rest_api.api_gw.id
  resource_id      = aws_api_gateway_resource.add_survey.id
  http_method      = "POST"
  authorization    = "CUSTOM"
  authorizer_id    = aws_api_gateway_authorizer.authorizer.id
  api_key_required = true
  depends_on = [
    aws_api_gateway_resource.add_survey
  ]
}

resource "aws_api_gateway_integration" "add_survey_integration" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  resource_id = aws_api_gateway_resource.add_survey.id
  http_method = aws_api_gateway_method.add_survey_method.http_method
  # integration_http_method for lambda integration MUST BE POST
  # see: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_integration#integration_http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.add_survey.invoke_arn
  content_handling        = "CONVERT_TO_TEXT"
  depends_on = [
    aws_api_gateway_resource.add_survey,
    aws_api_gateway_method.add_survey_method
  ]
}

#logout
resource "aws_api_gateway_resource" "logout" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  parent_id   = aws_api_gateway_rest_api.api_gw.root_resource_id
  path_part   = "logout"
  depends_on = [
    aws_api_gateway_rest_api.api_gw
  ]
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_method" "logout_method" {
  rest_api_id   = aws_api_gateway_rest_api.api_gw.id
  resource_id   = aws_api_gateway_resource.logout.id
  http_method   = "POST"
  authorization = "NONE"
  #authorizer_id    = aws_api_gateway_authorizer.authorizer.id
  api_key_required = true
  depends_on = [
    aws_api_gateway_resource.logout
  ]
}

resource "aws_api_gateway_integration" "logout_integration" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  resource_id = aws_api_gateway_resource.logout.id
  http_method = aws_api_gateway_method.logout_method.http_method
  # integration_http_method for lambda integration MUST BE POST
  # see: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_integration#integration_http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.logout.invoke_arn
  content_handling        = "CONVERT_TO_TEXT"
  depends_on = [
    aws_api_gateway_resource.logout,
    aws_api_gateway_method.logout_method
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
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }
}

resource "aws_api_gateway_integration_response" "login_cors_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  resource_id = aws_api_gateway_resource.login.id
  http_method = aws_api_gateway_method.login_cors.http_method
  status_code = aws_api_gateway_method_response.login_cors_response.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Origin,Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,POST,GET'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"

  }
  response_templates = {
    "application/json" = ""
  }
}

resource "aws_api_gateway_method" "logout_cors" {
  rest_api_id   = aws_api_gateway_rest_api.api_gw.id
  resource_id   = aws_api_gateway_resource.logout.id
  http_method   = "OPTIONS"
  authorization = "NONE"
  depends_on = [
    aws_api_gateway_resource.logout
  ]
}

resource "aws_api_gateway_integration" "logout_cors_integration" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  resource_id = aws_api_gateway_resource.logout.id
  http_method = aws_api_gateway_method.logout_cors.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = jsonencode(
      {
        statusCode = 200
      }
    )
  }
}

resource "aws_api_gateway_method_response" "logout_cors_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  resource_id = aws_api_gateway_resource.logout.id
  http_method = aws_api_gateway_method.logout_cors.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }
}

resource "aws_api_gateway_integration_response" "logout_cors_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  resource_id = aws_api_gateway_resource.logout.id
  http_method = aws_api_gateway_method.logout_cors.http_method
  status_code = aws_api_gateway_method_response.logout_cors_response.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Origin,Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,POST,GET'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"

  }
  response_templates = {
    "application/json" = ""
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

resource "aws_api_gateway_resource" "pdf-gen" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  parent_id   = aws_api_gateway_rest_api.api_gw.root_resource_id
  path_part   = "pdf-gen"
  depends_on = [
    aws_api_gateway_rest_api.api_gw
  ]
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_method" "pdf_gen_method" {
  rest_api_id   = aws_api_gateway_rest_api.api_gw.id
  resource_id   = aws_api_gateway_resource.pdf-gen.id
  http_method   = "GET"
  authorization = "NONE"
  #authorizer_id    = aws_api_gateway_authorizer.authorizer.id
  api_key_required = true
  depends_on = [
    aws_api_gateway_resource.pdf-gen
  ]
}

resource "aws_api_gateway_integration" "pdf_gen_integration" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  resource_id = aws_api_gateway_resource.pdf-gen.id
  http_method = aws_api_gateway_method.pdf_gen_method.http_method
  # integration_http_method for lambda integration MUST BE POST
  # see: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_integration#integration_http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.pdf-gen.invoke_arn
  content_handling        = "CONVERT_TO_TEXT"
  depends_on = [
    aws_api_gateway_resource.pdf-gen,
    aws_api_gateway_method.pdf_gen_method
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

resource "aws_api_gateway_method" "check_in_cors" {
  rest_api_id   = aws_api_gateway_rest_api.api_gw.id
  resource_id   = aws_api_gateway_resource.check_in.id
  http_method   = "OPTIONS"
  authorization = "NONE"
  depends_on = [
    aws_api_gateway_resource.check_in
  ]
}

resource "aws_api_gateway_integration" "check_in_cors_integration" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  resource_id = aws_api_gateway_resource.check_in.id
  http_method = aws_api_gateway_method.check_in_cors.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = jsonencode(
      {
        statusCode = 200
      }
    )
  }
}

resource "aws_api_gateway_method_response" "check_in_cors_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  resource_id = aws_api_gateway_resource.check_in.id
  http_method = aws_api_gateway_method.check_in_cors.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }
}

resource "aws_api_gateway_integration_response" "check_in_cors_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  resource_id = aws_api_gateway_resource.check_in.id
  http_method = aws_api_gateway_method.check_in_cors.http_method
  status_code = aws_api_gateway_method_response.check_in_cors_response.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Origin,Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,POST,GET'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  response_templates = {
    "application/json" = ""
  }
}

resource "aws_api_gateway_method" "check_out_cors" {
  rest_api_id   = aws_api_gateway_rest_api.api_gw.id
  resource_id   = aws_api_gateway_resource.check_out.id
  http_method   = "OPTIONS"
  authorization = "NONE"
  depends_on = [
    aws_api_gateway_resource.check_out
  ]
}

resource "aws_api_gateway_integration" "check_out_cors_integration" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  resource_id = aws_api_gateway_resource.check_out.id
  http_method = aws_api_gateway_method.check_out_cors.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = jsonencode(
      {
        statusCode = 200
      }
    )
  }
}

resource "aws_api_gateway_method_response" "check_out_cors_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  resource_id = aws_api_gateway_resource.check_out.id
  http_method = aws_api_gateway_method.check_out_cors.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }
}

resource "aws_api_gateway_integration_response" "check_out_cors_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  resource_id = aws_api_gateway_resource.check_out.id
  http_method = aws_api_gateway_method.check_out_cors.http_method
  status_code = aws_api_gateway_method_response.check_out_cors_response.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Origin,Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,POST,GET'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  response_templates = {
    "application/json" = ""
  }
}

resource "aws_api_gateway_method" "refresh_token_cors" {
  rest_api_id   = aws_api_gateway_rest_api.api_gw.id
  resource_id   = aws_api_gateway_resource.refresh_token.id
  http_method   = "OPTIONS"
  authorization = "NONE"
  depends_on = [
    aws_api_gateway_resource.refresh_token
  ]
}

resource "aws_api_gateway_integration" "refresh_token_cors_integration" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  resource_id = aws_api_gateway_resource.refresh_token.id
  http_method = aws_api_gateway_method.refresh_token_cors.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = jsonencode(
      {
        statusCode = 200
      }
    )
  }
}

resource "aws_api_gateway_method_response" "refresh_token_cors_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  resource_id = aws_api_gateway_resource.refresh_token.id
  http_method = aws_api_gateway_method.refresh_token_cors.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }
}

resource "aws_api_gateway_integration_response" "refresh_token_cors_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  resource_id = aws_api_gateway_resource.refresh_token.id
  http_method = aws_api_gateway_method.refresh_token_cors.http_method
  status_code = aws_api_gateway_method_response.refresh_token_cors_response.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Origin,Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,POST,GET'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  response_templates = {
    "application/json" = ""
  }
}

resource "aws_api_gateway_method" "me_cors" {
  rest_api_id   = aws_api_gateway_rest_api.api_gw.id
  resource_id   = aws_api_gateway_resource.me.id
  http_method   = "OPTIONS"
  authorization = "NONE"
  depends_on = [
    aws_api_gateway_resource.me
  ]
}

resource "aws_api_gateway_integration" "me_cors_integration" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  resource_id = aws_api_gateway_resource.me.id
  http_method = aws_api_gateway_method.me_cors.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = jsonencode(
      {
        statusCode = 200
      }
    )
  }
}

resource "aws_api_gateway_method_response" "me_cors_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  resource_id = aws_api_gateway_resource.me.id
  http_method = aws_api_gateway_method.me_cors.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }
}

resource "aws_api_gateway_integration_response" "me_cors_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  resource_id = aws_api_gateway_resource.me.id
  http_method = aws_api_gateway_method.me_cors.http_method
  status_code = aws_api_gateway_method_response.me_cors_response.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Origin,Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,POST,GET'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  response_templates = {
    "application/json" = ""
  }
}

resource "aws_api_gateway_method" "update_me_cors" {
  rest_api_id   = aws_api_gateway_rest_api.api_gw.id
  resource_id   = aws_api_gateway_resource.update_me.id
  http_method   = "OPTIONS"
  authorization = "NONE"
  depends_on = [
    aws_api_gateway_resource.update_me
  ]
}

resource "aws_api_gateway_integration" "update_me_cors_integration" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  resource_id = aws_api_gateway_resource.update_me.id
  http_method = aws_api_gateway_method.update_me_cors.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = jsonencode(
      {
        statusCode = 200
      }
    )
  }
}

resource "aws_api_gateway_method_response" "update_me_cors_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  resource_id = aws_api_gateway_resource.update_me.id
  http_method = aws_api_gateway_method.update_me_cors.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }
}

resource "aws_api_gateway_integration_response" "update_me_cors_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  resource_id = aws_api_gateway_resource.update_me.id
  http_method = aws_api_gateway_method.update_me_cors.http_method
  status_code = aws_api_gateway_method_response.update_me_cors_response.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Origin,Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,POST,GET'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  response_templates = {
    "application/json" = ""
  }
}

resource "aws_api_gateway_method" "add_survey_cors" {
  rest_api_id   = aws_api_gateway_rest_api.api_gw.id
  resource_id   = aws_api_gateway_resource.add_survey.id
  http_method   = "OPTIONS"
  authorization = "NONE"
  depends_on = [
    aws_api_gateway_resource.add_survey
  ]
}

resource "aws_api_gateway_integration" "add_survey_cors_integration" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  resource_id = aws_api_gateway_resource.add_survey.id
  http_method = aws_api_gateway_method.add_survey_cors.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = jsonencode(
      {
        statusCode = 200
      }
    )
  }
}

resource "aws_api_gateway_method_response" "add_survey_cors_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  resource_id = aws_api_gateway_resource.add_survey.id
  http_method = aws_api_gateway_method.add_survey_cors.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }
}

resource "aws_api_gateway_integration_response" "add_survey_cors_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  resource_id = aws_api_gateway_resource.add_survey.id
  http_method = aws_api_gateway_method.add_survey_cors.http_method
  status_code = aws_api_gateway_method_response.add_survey_cors_response.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Origin,Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,POST,GET'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  response_templates = {
    "application/json" = ""
  }
}

resource "aws_api_gateway_method" "pdf_gen_cors" {
  rest_api_id   = aws_api_gateway_rest_api.api_gw.id
  resource_id   = aws_api_gateway_resource.pdf-gen.id
  http_method   = "OPTIONS"
  authorization = "NONE"
  depends_on = [
    aws_api_gateway_resource.pdf-gen
  ]
}

resource "aws_api_gateway_integration" "pdf_gen_cors_integration" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  resource_id = aws_api_gateway_resource.pdf-gen.id
  http_method = aws_api_gateway_method.pdf_gen_cors.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = jsonencode(
      {
        statusCode = 200
      }
    )
  }
}

resource "aws_api_gateway_method_response" "pdf_gen_cors_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  resource_id = aws_api_gateway_resource.pdf-gen.id
  http_method = aws_api_gateway_method.pdf_gen_cors.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }
}

resource "aws_api_gateway_integration_response" "pdf-gen_cors_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  resource_id = aws_api_gateway_resource.pdf-gen.id
  http_method = aws_api_gateway_method.pdf_gen_cors.http_method
  status_code = aws_api_gateway_method_response.pdf_gen_cors_response.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Origin,Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,POST,GET'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  response_templates = {
    "application/json" = ""
  }
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

resource "aws_lambda_permission" "logout" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "logout"
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = format(
    "%s/*/POST/logout",
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

resource "aws_lambda_permission" "me" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "me"
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = format(
    "%s/*/GET/me",
    aws_api_gateway_rest_api.api_gw.execution_arn
  )
}

resource "aws_lambda_permission" "update_me" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "update-me"
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = format(
    "%s/*/POST/update-me",
    aws_api_gateway_rest_api.api_gw.execution_arn
  )
}

resource "aws_lambda_permission" "pdf-gen" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "pdf-gen"
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = format(
    "%s/*/GET/pdf-gen",
    aws_api_gateway_rest_api.api_gw.execution_arn
  )
}

resource "aws_lambda_permission" "add_survey" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "add-survey"
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = format(
    "%s/*/POST/add-survey",
    aws_api_gateway_rest_api.api_gw.execution_arn
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

resource "aws_s3_bucket" "af-upload-docs" {
  bucket = "af-upload-docs"
  acl    = "private"

  tags = {
    Name = "af-upload-docs"
  }
}

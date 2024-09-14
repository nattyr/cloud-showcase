variable "current_file_path" {
  default = "visitor_api_gateway.tf"
}

resource "aws_api_gateway_rest_api" "visitor" {
  name = "VisitorAPI"
}

resource "aws_api_gateway_resource" "my_resource" {
  rest_api_id = aws_api_gateway_rest_api.visitor.id
  parent_id = aws_api_gateway_rest_api.visitor.root_resource_id
  path_part = "hit"
}

resource "aws_api_gateway_method" "visitor_get" {
  rest_api_id = aws_api_gateway_rest_api.visitor.id
  resource_id = aws_api_gateway_resource.my_resource.id
  http_method = "GET"
  authorization = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "visitor_lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.visitor.id
  resource_id = aws_api_gateway_resource.my_resource.id
  http_method = aws_api_gateway_method.visitor_get.http_method
  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri = aws_lambda_function.log_visitor_lambda.invoke_arn
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id = "AllowAPIGatewayInvoke"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.log_visitor_lambda.function_name
  principal = "apigateway.amazonaws.com"
  source_arn = "${aws_api_gateway_rest_api.visitor.execution_arn}/*/*"
}

resource "aws_api_gateway_method" "visitor_options" {
  rest_api_id = aws_api_gateway_rest_api.visitor.id
  resource_id = aws_api_gateway_resource.my_resource.id
  http_method = "OPTIONS"
  authorization = "NONE"
  api_key_required = false
}

resource "aws_api_gateway_integration" "visitor_options" {
  rest_api_id = aws_api_gateway_rest_api.visitor.id
  resource_id = aws_api_gateway_resource.my_resource.id
  http_method = aws_api_gateway_method.visitor_options.http_method
  type = "MOCK"
  integration_http_method = "OPTIONS"
  passthrough_behavior = "WHEN_NO_MATCH"

  request_templates = {
    "application/json" = <<EOF
    {
      "statusCode": 200
    }
    EOF
  }
}

resource "aws_api_gateway_method_response" "visitor_options" {
  rest_api_id = aws_api_gateway_rest_api.visitor.id
  resource_id = aws_api_gateway_resource.my_resource.id
  http_method = aws_api_gateway_method.visitor_options.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_integration_response" "visitor_options" {
  rest_api_id = aws_api_gateway_rest_api.visitor.id
  resource_id = aws_api_gateway_resource.my_resource.id
  http_method = aws_api_gateway_method.visitor_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'X-Api-Key'"
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'https://nathanrichardson.dev'"
  }

  depends_on = [aws_api_gateway_integration.visitor_options]
}

resource "aws_api_gateway_deployment" "visitor_prod" {
  rest_api_id = aws_api_gateway_rest_api.visitor.id
  stage_name = "prod"

  lifecycle {
    create_before_destroy = true
  }

  triggers = {
    redeploy = filebase64sha512(var.current_file_path)
  }

  depends_on = [
    aws_api_gateway_method.visitor_get,
    aws_api_gateway_integration.visitor_lambda_integration,
    aws_api_gateway_integration.visitor_options
    ]
}

resource "aws_api_gateway_api_key" "visitor" {
  name = "VisitorApiKey"
  description = "API key with rate throttling"
  enabled = true
}

resource "aws_api_gateway_stage" "visitor_prod" {
  stage_name = "prod"
  deployment_id = aws_api_gateway_deployment.visitor_prod.id
  rest_api_id = aws_api_gateway_rest_api.visitor.id
}

resource "aws_api_gateway_method_settings" "visitor_prod_rate_limit" {
  rest_api_id = aws_api_gateway_rest_api.visitor.id
  stage_name  = aws_api_gateway_stage.visitor_prod.stage_name
  method_path = "*/*"

  settings {
    throttling_burst_limit = 7
    throttling_rate_limit  = 3
  }

  depends_on = [aws_api_gateway_stage.visitor_prod]
}

resource "aws_api_gateway_usage_plan" "visitor" {
  name = "VisitorUsagePlan"

  api_stages {
    api_id = aws_api_gateway_rest_api.visitor.id
    stage = aws_api_gateway_stage.visitor_prod.stage_name
  }

  throttle_settings {
    burst_limit = 7
    rate_limit  = 3
  }

  quota_settings {
    limit  = 200
    period = "DAY"
  }

  depends_on = [aws_api_gateway_stage.visitor_prod]
}

resource "aws_api_gateway_usage_plan_key" "visitor_throttle" {
  key_id = aws_api_gateway_api_key.visitor.id
  key_type = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.visitor.id
}
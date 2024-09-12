resource "aws_s3_bucket" "cloud-resume-website" {
  bucket = "cloud-resume-website-nr"
  tags = {
    Name = "cloud-resume-website-nr"
    }
}

resource "aws_acm_certificate" "resume_cert" {
  provider = aws.us_east_1
  domain_name = "nathanrichardson.dev"
  subject_alternative_names = ["*.nathanrichardson.dev"]
  validation_method = "DNS"
  tags = {
    Name = "nathanrichardson.dev_cert"
  }
}

resource "aws_route53_zone" "resume_hosted_zone" {
  name = "nathanrichardson.dev"
}

resource "aws_route53_record" "resume_cert_dns_records" {
  for_each = {
    for dvo in aws_acm_certificate.resume_cert.domain_validation_options : dvo.domain_name => {
      name = dvo.resource_record_name
      record = dvo.resource_record_value
      type = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name = each.value.name
  records = [each.value.record]
  ttl = 60
  type = each.value.type
  zone_id = aws_route53_zone.resume_hosted_zone.zone_id
}

resource "aws_cloudfront_origin_access_control" "resume_oac" {
  name = "resume-cloudfront-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior = "always"
  signing_protocol = "sigv4"
}

resource "aws_cloudfront_distribution" "resume_distribution" {
  origin {
    domain_name = aws_s3_bucket.cloud-resume-website.bucket_regional_domain_name
    origin_id = "S3-resume-bucket"
    origin_access_control_id = aws_cloudfront_origin_access_control.resume_oac.id
  }

  enabled = true
  is_ipv6_enabled = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods = ["GET", "HEAD"]
    cached_methods = ["GET", "HEAD"]
    target_origin_id = "S3-resume-bucket"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl = 0
    default_ttl = 3600
    max_ttl = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  aliases = ["nathanrichardson.dev", "www.nathanrichardson.dev"]

  viewer_certificate {
    cloudfront_default_certificate = false
    acm_certificate_arn = aws_acm_certificate.resume_cert.arn
    ssl_support_method = "sni-only"
    minimum_protocol_version = "TLSv1"
  }
}

resource "aws_route53_record" "cloud_alias_dns_record" {
  zone_id = aws_route53_zone.resume_hosted_zone.zone_id
  name = "nathanrichardson.dev"
  type = "A"

  alias {
    name = aws_cloudfront_distribution.resume_distribution.domain_name
    zone_id = aws_cloudfront_distribution.resume_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "cloud_www_dns_record" {
  zone_id = aws_route53_zone.resume_hosted_zone.zone_id
  name = "www.nathanrichardson.dev"
  type = "CNAME"
  ttl = 300
  records = ["nathanrichardson.dev"]
}

resource "aws_s3_bucket_policy" "resume_bucket_policy" {
  bucket = aws_s3_bucket.cloud-resume-website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = "*"
        Action = "s3:GetObject"
        Resource = "${aws_s3_bucket.cloud-resume-website.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = "${aws_cloudfront_distribution.resume_distribution.arn}"
          }
        }
      }
    ]
  })
}

resource "aws_dynamodb_table" "website_visits_log_db" {
  name = "WebsiteVisitsLog"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "IPAddress"
  range_key = "DateTime"

  attribute {
    name = "IPAddress"
    type = "S"
  }

  attribute {
    name = "DateTime"
    type = "S"
  }
}

resource "aws_dynamodb_table" "website_visits_counter_db" {
  name = "WebsiteVisitsCounter"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "PageName"

  attribute {
    name = "PageName"
    type = "S"
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name = "lambda_policy"
  description = "IAM policy for lambda"

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
      },
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem"
        ],
        Effect   = "Allow",
        Resource = [
          aws_dynamodb_table.website_visits_log_db.arn,
          aws_dynamodb_table.website_visits_counter_db.arn
        ]
          
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

data "archive_file" "log_visitor_zip" {
  type = "zip"
  source_file  = "../lambda/log_visitor.py"
  output_path = "log_visitor.zip"
}

resource "aws_lambda_function" "log_visitor_lambda" {
  function_name = "log_visitor"
  filename = data.archive_file.log_visitor_zip.output_path
  source_code_hash = data.archive_file.log_visitor_zip.output_base64sha512
  role = aws_iam_role.lambda_role.arn
  handler = "log_visitor.hit"
  runtime = "python3.12"
  environment {
    variables = {
      LOG_TABLE_NAME = aws_dynamodb_table.website_visits_log_db.name
      COUNT_TABLE_NAME = aws_dynamodb_table.website_visits_counter_db.name
    }
  }
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

resource "aws_api_gateway_deployment" "visitor_prod" {
  rest_api_id = aws_api_gateway_rest_api.visitor.id

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_api_gateway_method.visitor_get]
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

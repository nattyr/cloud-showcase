resource "aws_s3_bucket" "cloud-resume-website" {
  bucket = "cloud-resume-website-nr"
  tags = {
    Name = "cloud-resume-website-nr"
    }
}

resource "aws_cloudfront_distribution" "resume_distribution" {
  origin {
    domain_name = aws_s3_bucket.cloud-resume-website.bucket_regional_domain_name
    origin_id   = "S3-resume-bucket"
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-resume-bucket"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
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

resource "aws_s3_bucket" "log_bucket" {
  bucket = "log-bucket-nr"
}

resource "aws_s3_bucket_logging" "cloud-resume-website-logging" {
  bucket = aws_s3_bucket.cloud-resume-website.id

  target_bucket = aws_s3_bucket.log_bucket.id
  target_prefix = "cloud-resume-website_log/"
}
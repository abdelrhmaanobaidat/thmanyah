resource "aws_s3_bucket" "player" {
  bucket        = local.player_bucket
  force_destroy = true
  tags          = { Name = local.player_bucket }
}

resource "aws_s3_bucket_public_access_block" "player" {
  bucket                  = aws_s3_bucket.player.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_origin_access_control" "player" {
  name                              = "${local.prefix}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_s3_object" "index" {
  bucket = aws_s3_bucket.player.id
  key    = "index.html"
  content = templatefile("${path.module}/../player/index.html", {
    hls_path   = local.hls_path
    llhls_path = local.llhls_path
  })
  content_type = "text/html"
  etag = md5(templatefile("${path.module}/../player/index.html", {
    hls_path   = local.hls_path
    llhls_path = local.llhls_path
  }))
}

resource "aws_s3_object" "hls_js" {
  bucket       = aws_s3_bucket.player.id
  key          = "hls.min.js"
  source       = "${path.module}/../player/hls.min.js"
  content_type = "application/javascript"
  etag         = filemd5("${path.module}/../player/hls.min.js")
}

# only our cloudfront dist can read the bucket, nobody else
resource "aws_s3_bucket_policy" "player" {
  bucket = aws_s3_bucket.player.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowCloudFrontOAC"
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.player.arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.main.arn
        }
      }
    }]
  })
}

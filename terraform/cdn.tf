locals {
  hls_manifest_url   = awscc_mediapackagev2_origin_endpoint.hls.hls_manifest_urls[0]
  llhls_manifest_url = awscc_mediapackagev2_origin_endpoint.llhls.low_latency_hls_manifest_urls[0]

  # split the mediapackage egress url into host and path so we can front it with cloudfront
  mp_egress_host = regex("^https://([^/]+)/", local.hls_manifest_url)[0]
  hls_path       = regex("^https://[^/]+(/.*)$", local.hls_manifest_url)[0]
  llhls_path     = regex("^https://[^/]+(/.*)$", local.llhls_manifest_url)[0]
}

# barely cache the manifests so the live edge stays fresh
resource "aws_cloudfront_cache_policy" "manifest" {
  name        = "${local.prefix}-manifest"
  min_ttl     = 0
  default_ttl = 1
  max_ttl     = 2

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_gzip = true

    cookies_config { cookie_behavior = "none" }
    headers_config { header_behavior = "none" }
    query_strings_config { query_string_behavior = "none" }
  }
}

# segments don't change, cache them hard
data "aws_cloudfront_cache_policy" "optimized" {
  name = "Managed-CachingOptimized"
}

resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  comment             = "${local.prefix}-cdn"
  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  # player page from s3, locked down with oac
  origin {
    origin_id                = "player-s3"
    domain_name              = aws_s3_bucket.player.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.player.id
  }

  # the stream itself
  origin {
    origin_id   = "mediapackage"
    domain_name = local.mp_egress_host

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # everything by default is the player
  default_cache_behavior {
    target_origin_id       = "player-s3"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = data.aws_cloudfront_cache_policy.optimized.id
  }

  # m3u8 playlists get the short cache
  ordered_cache_behavior {
    path_pattern           = "/out/*.m3u8"
    target_origin_id       = "mediapackage"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = aws_cloudfront_cache_policy.manifest.id
    compress               = true
  }

  # segments and the rest
  ordered_cache_behavior {
    path_pattern           = "/out/*"
    target_origin_id       = "mediapackage"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = data.aws_cloudfront_cache_policy.optimized.id
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = { Name = "${local.prefix}-cdn" }
}

resource "awscc_mediapackagev2_channel_group" "main" {
  channel_group_name = "${local.prefix}-group"
  description        = "thmanyah live channel group"
}

resource "awscc_mediapackagev2_channel" "main" {
  channel_group_name = awscc_mediapackagev2_channel_group.main.channel_group_name
  channel_name       = "${local.prefix}-channel"
  description        = "thmanyah live channel"
}

# let the medialive role push into this channel
resource "awscc_mediapackagev2_channel_policy" "main" {
  channel_group_name = awscc_mediapackagev2_channel_group.main.channel_group_name
  channel_name       = awscc_mediapackagev2_channel.main.channel_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowMediaLiveIngest"
      Effect    = "Allow"
      Principal = { AWS = aws_iam_role.medialive.arn }
      Action    = "mediapackagev2:PutObject"
      Resource  = awscc_mediapackagev2_channel.main.arn
    }]
  })
}

# plain hls
resource "awscc_mediapackagev2_origin_endpoint" "hls" {
  channel_group_name   = awscc_mediapackagev2_channel_group.main.channel_group_name
  channel_name         = awscc_mediapackagev2_channel.main.channel_name
  origin_endpoint_name = "hls"
  container_type       = "CMAF"

  segment = {
    segment_duration_seconds = var.segment_seconds
  }

  hls_manifests = [{
    manifest_name           = "index"
    manifest_window_seconds = 60
  }]

  startover_window_seconds = 300
}

# ll-hls off the same channel
resource "awscc_mediapackagev2_origin_endpoint" "llhls" {
  channel_group_name   = awscc_mediapackagev2_channel_group.main.channel_group_name
  channel_name         = awscc_mediapackagev2_channel.main.channel_name
  origin_endpoint_name = "llhls"
  container_type       = "CMAF"

  segment = {
    segment_duration_seconds = var.segment_seconds
  }

  low_latency_hls_manifests = [{
    manifest_name           = "index"
    manifest_window_seconds = 30
  }]

  startover_window_seconds = 300
}

# endpoints are private until you attach a policy, so open them for read
resource "awscc_mediapackagev2_origin_endpoint_policy" "hls" {
  channel_group_name   = awscc_mediapackagev2_channel_group.main.channel_group_name
  channel_name         = awscc_mediapackagev2_channel.main.channel_name
  origin_endpoint_name = awscc_mediapackagev2_origin_endpoint.hls.origin_endpoint_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowPublicRead"
      Effect    = "Allow"
      Principal = "*"
      Action    = ["mediapackagev2:GetObject", "mediapackagev2:GetHeadObject"]
      Resource  = awscc_mediapackagev2_origin_endpoint.hls.arn
    }]
  })
}

resource "awscc_mediapackagev2_origin_endpoint_policy" "llhls" {
  channel_group_name   = awscc_mediapackagev2_channel_group.main.channel_group_name
  channel_name         = awscc_mediapackagev2_channel.main.channel_name
  origin_endpoint_name = awscc_mediapackagev2_origin_endpoint.llhls.origin_endpoint_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowPublicRead"
      Effect    = "Allow"
      Principal = "*"
      Action    = ["mediapackagev2:GetObject", "mediapackagev2:GetHeadObject"]
      Resource  = awscc_mediapackagev2_origin_endpoint.llhls.arn
    }]
  })
}

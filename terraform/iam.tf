# one role for medialive. the input uses it to pull the flow, the channel to push into mediapackage
resource "aws_iam_role" "medialive" {
  name = "${local.prefix}-medialive-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "medialive.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "medialive" {
  name = "${local.prefix}-medialive-policy"
  role = aws_iam_role.medialive.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "MediaConnect"
        Effect = "Allow"
        Action = [
          "mediaconnect:ManagedDescribeFlow",
          "mediaconnect:ManagedAddOutput",
          "mediaconnect:ManagedRemoveOutput",
          "mediaconnect:DescribeFlow"
        ]
        Resource = "*"
      },
      {
        Sid      = "MediaPackageV2Ingest"
        Effect   = "Allow"
        Action   = ["mediapackagev2:PutObject", "mediapackagev2:GetObject", "mediapackagev2:*"]
        Resource = "*"
      },
      {
        Sid      = "Logs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogGroups", "logs:DescribeLogStreams"]
        Resource = "*"
      }
    ]
  })
}

# medialive checks this role the instant we create the input, and iam is eventually
# consistent, so give it a few seconds or CreateInput 403s
resource "time_sleep" "iam_propagation" {
  depends_on      = [aws_iam_role_policy.medialive]
  create_duration = "20s"
}

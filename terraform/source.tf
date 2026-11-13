resource "aws_security_group" "source" {
  name        = "${local.prefix}-source-sg"
  description = "SRT ingest for the thmanyah source encoder"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SRT (MediaConnect caller dials in)"
    from_port   = var.srt_port
    to_port     = var.srt_port
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.prefix}-source-sg" }
}

locals {
  source_user_data = templatefile("${path.module}/../source/user-data.sh.tftpl", {
    srt_port         = var.srt_port
    srt_latency_us   = var.srt_latency_ms * 1000
    source_video_url = var.source_video_url
    run_source_sh    = file("${path.module}/../source/run-source.sh")
  })
}

resource "aws_instance" "source" {
  ami                         = data.aws_ssm_parameter.ubuntu.value
  instance_type               = var.source_instance_type
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.source.id]
  associate_public_ip_address = true
  user_data                   = local.source_user_data
  user_data_replace_on_change = true

  tags = { Name = "${local.prefix}-source" }
}

resource "aws_eip" "source" {
  instance = aws_instance.source.id
  domain   = "vpc"
  tags     = { Name = "${local.prefix}-source-eip" }
}

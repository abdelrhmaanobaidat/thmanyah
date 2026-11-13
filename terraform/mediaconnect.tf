# srt caller flow, dials out to the source box's listener on its elastic ip
resource "awscc_mediaconnect_flow" "main" {
  name              = "${local.prefix}-flow"
  availability_zone = data.aws_subnet.chosen.availability_zone

  source = {
    name                    = "${local.prefix}-srt-source"
    protocol                = "srt-caller"
    source_listener_address = aws_eip.source.public_ip
    source_listener_port    = var.srt_port
    min_latency             = var.srt_latency_ms
    description             = "SRT caller to the thmanyah source encoder"
  }
}

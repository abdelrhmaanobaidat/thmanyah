output "player_url" {
  description = "Open this in a browser to watch the stream."
  value       = "https://${aws_cloudfront_distribution.main.domain_name}/"
}

output "hls_url" {
  description = "Standard HLS manifest (through CloudFront)."
  value       = "https://${aws_cloudfront_distribution.main.domain_name}${local.hls_path}"
}

output "llhls_url" {
  description = "Low-latency HLS manifest (through CloudFront)."
  value       = "https://${aws_cloudfront_distribution.main.domain_name}${local.llhls_path}"
}

output "channel_id" {
  description = "MediaLive channel id (used by the scripts to start/stop)."
  value       = aws_medialive_channel.main.channel_id
}

output "flow_arn" {
  description = "MediaConnect flow ARN (used by the scripts to start/stop)."
  value       = awscc_mediaconnect_flow.main.flow_arn
}

output "instance_id" {
  description = "Source EC2 instance id (used by the scripts to start/stop)."
  value       = aws_instance.source.id
}

output "source_ip" {
  description = "Source EC2 Elastic IP (SRT listener MediaConnect dials)."
  value       = aws_eip.source.public_ip
}

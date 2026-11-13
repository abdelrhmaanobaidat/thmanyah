variable "region" {
  description = "AWS region. Must offer MediaConnect + MediaLive + MediaPackage v2."
  type        = string
  default     = "eu-west-1"
}

variable "name_prefix" {
  description = "Prefix for every resource name."
  type        = string
  default     = "thmanyah-axzc"
}

variable "srt_port" {
  description = "UDP port the source EC2 SRT listener binds; MediaConnect caller dials it."
  type        = number
  default     = 9000
}

variable "srt_latency_ms" {
  description = "SRT latency in milliseconds (ARQ repair budget)."
  type        = number
  default     = 2000
}

variable "srt_passphrase" {
  description = "SRT encryption passphrase (10-79 chars). Shared by the EC2 listener and the MediaConnect source."
  type        = string
  default     = "thmanyahAxzcSrt2026Passphrase"
  sensitive   = true
}

variable "source_video_url" {
  description = "Public sample the EC2 loops (must have audio). Falls back to a generated test pattern + tone if unreachable."
  type        = string
  default     = "https://download.samplelib.com/mp4/sample-15s.mp4"
}

variable "source_instance_type" {
  description = "Source encoder instance type (x86_64)."
  type        = string
  default     = "t3.small"
}

variable "segment_seconds" {
  description = "HLS segment duration."
  type        = number
  default     = 4
}

variable "aws_region" {
  description = "Primary AWS region for the lab"
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Globally-unique S3 bucket name for all security logs"
  type        = string
  # e.g. "security-logs-yalp-lab" -- must be globally unique across all AWS
}

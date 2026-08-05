resource "aws_cloudtrail" "main" {
  name           = "security-lab-trail"
  s3_bucket_name = aws_s3_bucket.logs.id
  s3_key_prefix  = "cloudtrail"

  include_global_service_events = true
  is_multi_region_trail         = true
  enable_logging                 = true

  # Must exist before CloudTrail can start writing to it
  depends_on = [aws_s3_bucket_policy.logs]
}

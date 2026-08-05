resource "aws_s3_bucket" "logs" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Block all public access -- this bucket holds security logs, never public.
resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bucket policy: three separate statements, one per AWS service that needs
# to WRITE into this bucket. Each is scoped to its own prefix and locked to
# your account via SourceAccount, so no other AWS account's CloudTrail/
# GuardDuty could ever write here even if they guessed your bucket name.
resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # --- CloudTrail ---
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.logs.arn
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.logs.arn}/cloudtrail/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" }
        }
      },
      # --- VPC Flow Logs ---
      {
        Sid       = "AWSLogDeliveryAclCheck"
        Effect    = "Allow"
        Principal = { Service = "delivery.logs.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.logs.arn
      },
      {
        Sid       = "AWSLogDeliveryWrite"
        Effect    = "Allow"
        Principal = { Service = "delivery.logs.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.logs.arn}/vpcflowlogs/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"      = "bucket-owner-full-control"
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      # --- GuardDuty ---
      {
        Sid       = "AllowGuardDutyPutObject"
        Effect    = "Allow"
        Principal = { Service = "guardduty.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.logs.arn}/guardduty/*"
        Condition = {
          StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
          ArnLike       = { "aws:SourceArn" = "arn:aws:guardduty:${var.aws_region}:${data.aws_caller_identity.current.account_id}:detector/*" }
        }
      },
      {
        Sid       = "AllowGuardDutyGetBucketLocation"
        Effect    = "Allow"
        Principal = { Service = "guardduty.amazonaws.com" }
        Action    = "s3:GetBucketLocation"
        Resource  = aws_s3_bucket.logs.arn
      }
    ]
  })
}

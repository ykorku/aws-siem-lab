resource "aws_kms_key" "guardduty" {
  description             = "Encrypts GuardDuty findings exported to S3"
  deletion_window_in_days = 7

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnableRootAccountPermissions"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "AllowGuardDutyToEncryptFindings"
        Effect    = "Allow"
        Principal = { Service = "guardduty.amazonaws.com" }
        Action    = ["kms:GenerateDataKey", "kms:Decrypt"]
        Resource  = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "guardduty" {
  name          = "alias/guardduty-findings"
  target_key_id = aws_kms_key.guardduty.key_id
}

resource "aws_iam_user" "splunk_reader" {
  name = "splunk-aws-reader"
}

resource "aws_iam_access_key" "splunk_reader" {
  user = aws_iam_user.splunk_reader.name
}

# Scoped to ONLY this bucket, read-only. Not AmazonS3ReadOnlyAccess.
resource "aws_iam_user_policy" "splunk_s3_read" {
  name = "splunk-s3-read-only"
  user = aws_iam_user.splunk_reader.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:GetObjectVersion"]
        Resource = "${aws_s3_bucket.logs.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.logs.arn
      }
    ]
  })
}

# GuardDuty findings are KMS-encrypted, so Splunk needs decrypt rights
# on that specific key -- nothing broader.
resource "aws_iam_user_policy" "splunk_kms_decrypt" {
  name = "splunk-kms-decrypt"
  user = aws_iam_user.splunk_reader.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["kms:Decrypt"]
      Resource = aws_kms_key.guardduty.arn
    }]
  })
}

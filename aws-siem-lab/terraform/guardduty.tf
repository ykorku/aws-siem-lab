resource "aws_guardduty_detector" "main" {
  enable = true
}

resource "aws_guardduty_publishing_destination" "s3" {
  detector_id     = aws_guardduty_detector.main.id
  destination_arn = "${aws_s3_bucket.logs.arn}/guardduty"
  kms_key_arn     = aws_kms_key.guardduty.arn

  depends_on = [aws_s3_bucket_policy.logs]
}

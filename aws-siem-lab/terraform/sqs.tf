# One queue per log type. Splunk's SQS-based S3 input is configured
# per-queue, and each queue maps to a distinct sourcetype in Splunk
# (aws:cloudtrail, aws:cloudwatchlogs:vpcflow, aws:guardduty). A single
# shared queue would mix all three log types together and make sourcetype
# assignment unreliable.

resource "aws_sqs_queue" "cloudtrail" {
  name                        = "siem-lab-cloudtrail-notifications"
  message_retention_seconds  = 345600 # 4 days -- enough buffer if Splunk falls behind
  visibility_timeout_seconds = 600    # 10 min -- must exceed how long Splunk takes to process+delete a message, or it gets redelivered and double-ingested

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.cloudtrail_dlq.arn
    maxReceiveCount      = 5
  })
}

resource "aws_sqs_queue" "vpcflowlogs" {
  name                        = "siem-lab-vpcflowlogs-notifications"
  message_retention_seconds  = 345600
  visibility_timeout_seconds = 600

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.vpcflowlogs_dlq.arn
    maxReceiveCount      = 5
  })
}

resource "aws_sqs_queue" "guardduty" {
  name                        = "siem-lab-guardduty-notifications"
  message_retention_seconds  = 345600
  visibility_timeout_seconds = 600

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.guardduty_dlq.arn
    maxReceiveCount      = 5
  })
}

# Each queue needs a policy allowing S3 (specifically THIS bucket, via
# SourceArn condition) to publish notification messages into it.
resource "aws_sqs_queue_policy" "cloudtrail" {
  queue_url = aws_sqs_queue.cloudtrail.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowS3SendMessage"
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.cloudtrail.arn
      Condition = { ArnEquals = { "aws:SourceArn" = aws_s3_bucket.logs.arn } }
    }]
  })
}

resource "aws_sqs_queue_policy" "vpcflowlogs" {
  queue_url = aws_sqs_queue.vpcflowlogs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowS3SendMessage"
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.vpcflowlogs.arn
      Condition = { ArnEquals = { "aws:SourceArn" = aws_s3_bucket.logs.arn } }
    }]
  })
}

resource "aws_sqs_queue_policy" "guardduty" {
  queue_url = aws_sqs_queue.guardduty.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowS3SendMessage"
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.guardduty.arn
      Condition = { ArnEquals = { "aws:SourceArn" = aws_s3_bucket.logs.arn } }
    }]
  })
}

# Tell S3 to publish an event to the right queue whenever a new object
# lands under each prefix. This is the trigger that makes ingestion
# near-real-time instead of Splunk having to poll/list the bucket.
resource "aws_s3_bucket_notification" "logs" {
  bucket = aws_s3_bucket.logs.id

  queue {
    queue_arn     = aws_sqs_queue.cloudtrail.arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "cloudtrail/"
  }

  queue {
    queue_arn     = aws_sqs_queue.vpcflowlogs.arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "vpcflowlogs/"
  }

  queue {
    queue_arn     = aws_sqs_queue.guardduty.arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "guardduty/"
  }

  depends_on = [
    aws_sqs_queue_policy.cloudtrail,
    aws_sqs_queue_policy.vpcflowlogs,
    aws_sqs_queue_policy.guardduty
  ]
}

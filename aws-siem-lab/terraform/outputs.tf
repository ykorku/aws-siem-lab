output "bucket_name" {
  value = aws_s3_bucket.logs.id
}

output "splunk_access_key_id" {
  value = aws_iam_access_key.splunk_reader.id
}

output "splunk_secret_access_key" {
  value     = aws_iam_access_key.splunk_reader.secret
  sensitive = true
}

output "cloudtrail_sqs_queue_url" {
  value = aws_sqs_queue.cloudtrail.url
}

output "vpcflowlogs_sqs_queue_url" {
  value = aws_sqs_queue.vpcflowlogs.url
}

output "guardduty_sqs_queue_url" {
  value = aws_sqs_queue.guardduty.url
}

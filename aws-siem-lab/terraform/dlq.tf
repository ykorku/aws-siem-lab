# Splunk's SQS-based S3 input requires a DLQ on the source queue -- after
# a message fails processing maxReceiveCount times (e.g. a malformed
# object, or a permissions hiccup), it moves here instead of retrying
# forever or getting silently dropped. Worth checking this queue
# periodically -- messages piling up here means something's failing.

resource "aws_sqs_queue" "cloudtrail_dlq" {
  name                       = "siem-lab-cloudtrail-dlq"
  message_retention_seconds = 1209600 # 14 days -- max retention, gives time to notice/debug
}

resource "aws_sqs_queue" "vpcflowlogs_dlq" {
  name                       = "siem-lab-vpcflowlogs-dlq"
  message_retention_seconds = 1209600
}

resource "aws_sqs_queue" "guardduty_dlq" {
  name                       = "siem-lab-guardduty-dlq"
  message_retention_seconds = 1209600
}

# Splunk's SQS-based S3 input polls the queue for notification messages,
# then reads the referenced S3 object, then deletes the message once
# processed. It needs all three permissions to do that full cycle.
resource "aws_iam_user_policy" "splunk_sqs_access" {
  name = "splunk-sqs-consume"
  user = aws_iam_user.splunk_reader.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
        "sqs:GetQueueUrl",
        "sqs:ChangeMessageVisibility"
      ]
      Resource = [
        aws_sqs_queue.cloudtrail.arn,
        aws_sqs_queue.vpcflowlogs.arn,
        aws_sqs_queue.guardduty.arn
      ]
      },
      {
      # ListQueues is an account/region-level action -- AWS does not
      # support scoping it to individual queue ARNs, so this must be "*".
      # Everything else in this policy stays tightly scoped; this is the
      # one necessary exception.
      Effect   = "Allow"
      Action   = ["sqs:ListQueues"]
      Resource = "*"
    }]
  })
}

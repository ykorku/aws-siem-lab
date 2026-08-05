resource "aws_flow_log" "default_vpc" {
  log_destination      = "${aws_s3_bucket.logs.arn}/vpcflowlogs/"
  log_destination_type = "s3"
  traffic_type         = "ALL" # ACCEPT + REJECT -- you need REJECT to see blocked traffic
  vpc_id                = data.aws_vpc.default.id

  depends_on = [aws_s3_bucket_policy.logs]
}

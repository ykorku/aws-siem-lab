# Detection Testing Guide

This document explains how to verify each detection in this lab actually fires on real events, not just that the SPL is syntactically valid. Every detection listed here was tested using this exact procedure.

**General pattern for every test:**
1. Run an AWS CLI command that generates the real event the detection is watching for
2. Wait a few minutes (CloudTrail/Flow Logs/GuardDuty all have their own delivery delay — see `README.md`)
3. Run the matching SPL search in Splunk to confirm the event landed and the detection query returns it
4. Clean up anything you created (delete test policies, revoke test security group rules) so nothing is left lying around in the AWS account

**Where each command type goes:**
- Lines starting with `aws ...` → your terminal (PowerShell/bash), where you're authenticated to AWS
- Blocks under "Verify in Splunk" → Splunk's Search & Reporting app, in the browser, pasted into the search bar. Never the terminal — SPL is not a shell command.

---

## 1. GuardDuty findings triage

**Trigger** (terminal):
```bash
aws guardduty create-sample-findings \
  --detector-id <your-detector-id> \
  --finding-types "Backdoor:EC2/C&CActivity.B!DNS" "UnauthorizedAccess:EC2/SSHBruteForce"
```
Get your detector ID if you don't have it handy: `aws guardduty list-detectors`

**Verify in Splunk** (wait ~15 min — GuardDuty's own S3 export interval):
```spl
index=aws_security sourcetype="aws:guardduty" | stats count by type, severity
```
Expect to see the two finding types listed above.

**No cleanup needed** — sample findings don't create real AWS resources.

---

## 2. CloudTrail root account usage

No manual trigger needed if you've ever run AWS CLI commands under root credentials — check what you already have:

**Verify in Splunk**:
```spl
index=aws_security sourcetype="aws:cloudtrail" userIdentity.type="Root"
| table _time, eventName, userIdentity.arn, sourceIPAddress
```

---

## 3. CloudTrail IAM policy changes

**Trigger** (terminal):
```powershell
'{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":"s3:ListBucket","Resource":"*"}]}' | Out-File -Encoding ascii policy.json

aws iam put-user-policy --user-name splunk-aws-reader --policy-name test-detection-policy --policy-document file://policy.json
```
(Note: PowerShell's JSON escaping is unreliable inline — writing to a file first and referencing it with `file://` avoids quoting issues.)

**Verify in Splunk** (wait ~3-5 min):
```spl
index=aws_security sourcetype="aws:cloudtrail" eventName="PutUserPolicy"
| table _time, eventName, requestParameters.policyName
```

**Clean up** (terminal):
```powershell
aws iam delete-user-policy --user-name splunk-aws-reader --policy-name test-detection-policy
Remove-Item policy.json
```

---

## 4. CloudTrail security group opened to the internet

**Trigger** (terminal):
```powershell
# Get your default VPC ID
aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query "Vpcs[0].VpcId" --output text

# Get a security group ID in that VPC (swap in the VPC ID from above)
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=<vpc-id>" --query "SecurityGroups[0].GroupId" --output text

# Open a port to the world (swap in the security group ID from above)
aws ec2 authorize-security-group-ingress --group-id <sg-id> --protocol tcp --port 8080 --cidr 0.0.0.0/0
```

**Verify in Splunk** (wait ~3-5 min):
```spl
index=aws_security sourcetype="aws:cloudtrail" eventName="AuthorizeSecurityGroupIngress"
| table _time, requestParameters.groupId, requestParameters.ipPermissions.items{}.ipRanges{}.cidrIp
```

**Clean up** (terminal — use the same security group ID):
```powershell
aws ec2 revoke-security-group-ingress --group-id <sg-id> --protocol tcp --port 8080 --cidr 0.0.0.0/0
```

---

## 5. VPC Flow Logs potential port scan

No safe way to synthetically trigger this without generating real scan-like traffic against your own infrastructure (e.g. running Nmap against your own EC2 instance). Verified in this lab by confirming the query runs cleanly and returns nothing when no scan-like traffic exists — a correct negative result, not a broken detection.

**Verify query runs clean in Splunk**:
```spl
index=aws_security sourcetype="aws:cloudwatchlogs:vpcflow" action="blocked"
| stats dc(dest_port) as unique_ports_attempted, count as attempts by src_ip, dest_ip
| where unique_ports_attempted > 15
| sort -unique_ports_attempted
```

To actually fire this detection (optional): run an Nmap scan against your own EC2 instance's private IP from another host in the same VPC, then re-run the search above.

---

## 6. VPC Flow Logs SSH reachable from the internet

Same as #5 — depends on real network traffic existing. Verify the query runs clean:
```spl
index=aws_security sourcetype="aws:cloudwatchlogs:vpcflow" dest_port=22 action="allowed"
| eval src_type=if(match(src_ip, "^(10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.)"), "internal", "external")
| where src_type="external"
| stats count as connections by src_ip, dest_ip
| sort -connections
```

---

## Pipeline health checks (not detection-specific)

Useful any time something seems off:

```spl
| eventcount summarize=false index=*
index=aws_security | stats count by sourcetype
index=_internal source=*ta_aws* (ERROR OR WARN)
index=_internal source=*sqs_based_s3* earliest=-15m
```

```bash
# Data actually landing in S3
aws s3 ls s3://<bucket>/cloudtrail/ --recursive
aws s3 ls s3://<bucket>/vpcflowlogs/ --recursive
aws s3 ls s3://<bucket>/guardduty/ --recursive

# Messages waiting in a queue vs. stuck in its DLQ
aws sqs get-queue-attributes --queue-url <queue-url> --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible
```

## Known gotcha: CIM field normalization

The Splunk Add-on for AWS silently renames VPC Flow Log fields to Splunk's Common Information Model vocabulary. If you're debugging a VPC Flow Log detection that returns nothing, check field names first:

```spl
index=aws_security sourcetype="aws:cloudwatchlogs:vpcflow" | stats count by action
```

Raw AWS values are `ACCEPT`/`REJECT` on fields `srcaddr`/`dstaddr`/`dstport`. Splunk's normalized values are `allowed`/`blocked` on fields `src_ip`/`dest_ip`/`dest_port`. All queries in this repo use the normalized names — this bit us once during development (see `README.md`).

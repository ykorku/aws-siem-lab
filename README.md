# AWS SIEM Detection Lab

A cloud-native SIEM pipeline built on AWS and Splunk: infrastructure-as-code log source provisioning, event-driven ingestion, and MITRE ATT&CK-mapped detections spanning identity, network, and threat-intelligence data.

## What this is

Three AWS log sources (CloudTrail, VPC Flow Logs, GuardDuty) are provisioned via Terraform, land in a single S3 bucket, and are ingested into Splunk Cloud in near real-time via S3 event notifications → SQS → Splunk's SQS-based S3 input. Six detections span all three sources, each mapped to a MITRE ATT&CK technique, backed by a dashboard for at-a-glance triage.

This project was built to close a specific gap: strong existing AWS/IaC/automation experience, but no prior hands-on SIEM exposure. The goal was to demonstrate that a cloud security background transfers directly into SIEM operations, rather than treating them as separate skill sets.

## Architecture

```
CloudTrail ─┐
VPC Flow Logs ─┼──▶ S3 bucket ──▶ S3 event notification ──▶ SQS (+ DLQ) ──▶ Splunk (SQS-based S3 input) ──▶ Index ──▶ Detections & Dashboard
GuardDuty ──┘
```

- **Event-driven, not polling-based.** S3 notifies SQS the instant a new log file lands, instead of Splunk periodically listing the bucket. Chosen deliberately over Splunk's simpler "Generic S3" polling input to reflect how this is actually done in production.
- **Least-privilege IAM.** The Splunk-facing IAM user is scoped to exactly the permissions needed: `s3:GetObject`/`GetObjectVersion` on this one bucket, `sqs:ReceiveMessage`/`DeleteMessage`/`ChangeMessageVisibility`/`GetQueueUrl` on these three queues, `sqs:ListQueues` (necessarily unscoped, per AWS's own permission model), and `kms:Decrypt` on the one key used for GuardDuty's encrypted export.
- **Dead-letter queues** on every SQS queue, so a message that fails processing repeatedly surfaces for investigation instead of retrying forever or silently vanishing.

## Repo structure

```
├── terraform/              # All AWS log source infrastructure
│   ├── providers.tf
│   ├── s3.tf                # Bucket + policy allowing CloudTrail/Flow Logs/GuardDuty to write
│   ├── cloudtrail.tf
│   ├── vpc_flow_logs.tf
│   ├── guardduty.tf
│   ├── kms.tf                # Required for GuardDuty's S3 export
│   ├── sqs.tf                 # Queues + S3 event notifications
│   ├── dlq.tf
│   ├── iam.tf                 # Splunk-facing IAM user + S3 read policy
│   ├── iam_sqs.tf             # SQS consume permissions
│   ├── variables.tf
│   └── outputs.tf
├── splunk/
│   ├── detections/            # One .spl file per detection, with header comments
│   └── dashboards/
│       └── aws-security-dashboard.xml
└── docs/
    └── mitre-mapping.md       # Every detection mapped to its MITRE ATT&CK technique
```

## Detections

| Detection | Log Source | MITRE Technique |
|---|---|---|
| GuardDuty findings triage by severity | GuardDuty | Varies (see mapping doc) |
| Root account usage | CloudTrail | T1078.004 |
| IAM policy changes | CloudTrail | T1098 |
| Security group opened to 0.0.0.0/0 | CloudTrail | T1562.007 |
| Potential port scan | VPC Flow Logs | T1595 / T1046 |
| SSH reachable from the internet | VPC Flow Logs | T1021.004 |

Full technique details, tactics, and a documented coverage-gap section: [`docs/mitre-mapping.md`](docs/mitre-mapping.md)

## Notable engineering decisions / debugging

A few things that came up building this, worth knowing if you're replicating it:

- **GuardDuty's S3 export requires KMS encryption** — not optional, unlike CloudTrail/Flow Logs. Missing this means findings silently never leave GuardDuty.
- **GuardDuty has no native decoder in Splunk's SQS-based S3 input.** The option exists in the UI but isn't wired to a working parser (confirmed via Splunk's own community forum — this isn't unique to this setup). Ingested instead via the `CustomLogs` decoder with a manually-set sourcetype, parsed at search time with `spath`.
- **S3 bucket versioning requires `s3:GetObjectVersion`** as a separate IAM permission from `s3:GetObject` — easy to miss since most tutorials only grant the latter.
- **SQS's `ChangeMessageVisibility` permission is required** by Splunk's input even though it's not immediately obvious why a *consumer* needs to modify message visibility (it's how the consumer extends its own processing lock while working).
- **The Splunk Add-on for AWS silently renames VPC Flow Log fields/values** to Splunk's CIM vocabulary (`ACCEPT`/`REJECT` → `allowed`/`blocked`, `srcaddr`/`dstaddr`/`dstport` → `src_ip`/`dest_ip`/`dest_port`). Two detections initially used AWS's raw field names, passed a syntax check, and silently matched zero events for days until caught during manual verification by deliberately firing the events they were meant to catch. All 6 detections in this repo have since been confirmed against real triggering events, not just validated for syntax.

## Cost

Designed to run at effectively zero cost at lab scale: CloudTrail management events are free, SQS/S3 usage stays within free tier, GuardDuty is free for 30 days then billed per GB analyzed (negligible at this traffic volume). The one guaranteed recurring cost is the KMS key (~$1/month flat) as long as it exists.

**To tear down:** `cd terraform && terraform destroy`

## What I'd add with more time

- CloudTrail-disabled detection (an attacker's likely first move to evade logging)
- New IAM user/role creation detection (T1136)
- Account access removal detection (T1531)
- SNS-based ingestion path as an alternative to direct S3→SQS, to compare tradeoffs
- Automated response actions (e.g. Lambda-triggered isolation) wired to high-severity alerts, extending the detection layer into response — similar in spirit to an existing GuardDuty→EventBridge→Lambda incident response project

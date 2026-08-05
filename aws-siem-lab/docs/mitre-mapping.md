# MITRE ATT&CK Mapping

This document maps each detection in this lab to the MITRE ATT&CK technique(s) it covers. Detections span three log sources (CloudTrail, VPC Flow Logs, GuardDuty) to demonstrate defense-in-depth — several techniques are covered by more than one detection using different data sources.

| # | Detection | Log Source | MITRE Technique | Tactic |
|---|---|---|---|---|
| 1 | GuardDuty findings triage by severity | GuardDuty | Varies by finding type (see below) | Varies |
| 2 | CloudTrail root account usage | CloudTrail | [T1078.004](https://attack.mitre.org/techniques/T1078/004/) — Valid Accounts: Cloud Accounts | Defense Evasion, Persistence, Privilege Escalation, Initial Access |
| 3 | CloudTrail IAM policy changes | CloudTrail | [T1098](https://attack.mitre.org/techniques/T1098/) — Account Manipulation | Persistence, Privilege Escalation |
| 4 | CloudTrail security group opened to 0.0.0.0/0 | CloudTrail | [T1562.007](https://attack.mitre.org/techniques/T1562/007/) — Impair Defenses: Disable or Modify Cloud Firewall | Defense Evasion |
| 5 | VPC Flow Logs potential port scan | VPC Flow Logs | [T1595](https://attack.mitre.org/techniques/T1595/) — Active Scanning / [T1046](https://attack.mitre.org/techniques/T1046/) — Network Service Discovery | Reconnaissance, Discovery |
| 6 | VPC Flow Logs SSH reachable from internet | VPC Flow Logs | [T1021.004](https://attack.mitre.org/techniques/T1021/004/) — Remote Services: SSH | Lateral Movement |

## GuardDuty finding types observed in this lab

| Finding Type | MITRE Technique | Tactic |
|---|---|---|
| `UnauthorizedAccess:EC2/SSHBruteForce` | [T1110](https://attack.mitre.org/techniques/T1110/) — Brute Force | Credential Access |
| `Backdoor:EC2/C&CActivity.B!DNS` | [T1071.004](https://attack.mitre.org/techniques/T1071/004/) — Application Layer Protocol: DNS | Command and Control |
| `Policy:IAMUser/RootCredentialUsage` | [T1078.004](https://attack.mitre.org/techniques/T1078/004/) — Valid Accounts: Cloud Accounts | Defense Evasion, Persistence, Privilege Escalation, Initial Access |

## Defense-in-depth note

Detection 2 (CloudTrail root usage) and the GuardDuty `Policy:IAMUser/RootCredentialUsage` finding both cover **T1078.004** using independent data sources — one built from raw CloudTrail events, the other from AWS's own managed detection service. This overlap is intentional: it demonstrates that the same malicious/risky behavior is catchable even if one data source or detection were to fail, rather than relying on a single point of detection.

## Coverage gaps (documented, not built)

For transparency, techniques this lab does *not* currently cover, which would be reasonable next additions:
- **T1531** (Account Access Removal) — no detection for user/role deletion events
- **T1136** (Create Account) — no detection for new IAM user creation
- **T1531/T1108** — no detection for CloudTrail logging being disabled (an attacker's likely first move to evade detection)

# Cloud Security Audit Report

**Date:** 2026-05-29
**Time Window:** 2026-05-27T23:40Z -- 2026-05-28T23:40Z (24h)
**Account:** 043470661424 (yamansener)
**Organization:** Gradyent
**Cluster:** gradyent-prod (EKS 1.35)
**Auditor:** Claude Security Audit Engine

---

## Account Details

| Provider | Account | Alias | Region(s) Scanned | Total Events |
|---|---|---|---|---|
| AWS | 043470661424 | yamansener | eu-central-1, us-east-1, eu-west-1, us-west-2 | 248 |

**IAM Users:** 4 (yamansener, ulucvarat, pipeline-user, cirevo-backend-user)
**IAM Roles:** 52
**Root MFA:** Enabled (yaman-phone)

---

## Threat Summary

| Category | Critical | High | Medium | Total |
|---|---|---|---|---|
| 1. Identity & Access | 0 | 2 | 1 | 3 |
| 2. IAM Mutations | 0 | 0 | 0 | 0 |
| 3. Defense Evasion | 1 | 1 | 0 | 2 |
| 4. Data Exfiltration | 0 | 1 | 0 | 1 |
| 5. Network Tampering | 0 | 0 | 0 | 0 |
| 6. Resource Hijacking | 0 | 0 | 0 | 0 |
| 7. Anomaly Detection | 0 | 1 | 2 | 3 |
| 8. Service-Specific | 0 | 1 | 2 | 3 |
| **TOTAL** | **1** | **6** | **5** | **12** |

---

## Detailed Findings

### Category 1: Identity & Access

#### [HIGH] F1-1: Root Account Console Login Detected

- **What was observed:** The root account successfully logged into the AWS Console at 2026-05-28T08:18:55Z from IP 185.165.242.199 (WorldStream B.V., Rotterdam, NL). MFA was used (device: `arn:aws:iam::043470661424:mfa/yaman-phone`).
- **Why suspicious:** Root account usage should be avoided for day-to-day operations. AWS best practice mandates using IAM users/roles instead. The login IP is a datacenter/VPN IP (WorldStream B.V.), not a residential ISP, which adds a layer of concern though it may be a legitimate corporate VPN.
- **What to verify:** Confirm this login was performed by an authorized administrator. Confirm the VPN/datacenter IP is an expected corporate egress point. Implement an SCP or CloudWatch alarm to alert on any root login.

#### [HIGH] F1-2: Failed Root Console Login Attempts

- **What was observed:** Two failed root console login attempts occurred at 2026-05-28T20:34:20Z and 2026-05-28T20:34:46Z (26 seconds apart) from the same IP 185.165.242.199. Both attempts had `MFAUsed: Yes` but resulted in `Failed authentication`. The target was the ECS console for the `socia-cirevo-dev-cluster`.
- **Why suspicious:** Failed MFA attempts on the root account within rapid succession could indicate an MFA device synchronization issue, or an attacker who has the password but is failing on the MFA step. However, since MFA was attempted (not skipped), this likely indicates a legitimate user with a temporary MFA issue.
- **What to verify:** Confirm with the root account holder that they experienced MFA failures at this time. Check if the MFA device clock is synchronized. Consider if the root password has been compromised and the MFA is protecting the account.

#### [MEDIUM] F1-3: IAM Users Without MFA

- **What was observed:** None of the 4 IAM users (yamansener, ulucvarat, pipeline-user, cirevo-backend-user) have MFA configured. Only the root account has MFA enabled.
- **Why suspicious:** Without MFA, a compromised access key or password provides full access to the user's permissions. This is a fundamental security hygiene gap.
- **What to verify:** Enable MFA for all human users (yamansener, ulucvarat) immediately. For service users (pipeline-user, cirevo-backend-user), consider using IAM roles with temporary credentials instead of long-lived access keys.

---

### Category 2: IAM Mutations

No IAM mutation events (CreateUser, CreateAccessKey, AttachPolicy, PutPolicy, DeactivateMFA, etc.) were detected in the 24-hour window.

**Status: CLEAN**

---

### Category 3: Defense Evasion

#### [CRITICAL] F3-1: No CloudTrail Trail Configured

- **What was observed:** No CloudTrail trails are configured in any of the 4 scanned regions (eu-central-1, us-east-1, eu-west-1, us-west-2). Only the default 90-day Event History (which cannot be disabled) is available. Event History is limited to management events, does not cover data events, and retains only 90 days.
- **Why suspicious:** Without a dedicated CloudTrail trail, there is no persistent, tamper-proof audit log. An attacker could operate for 90 days and all evidence would auto-expire. Data-plane events (S3 object access, Lambda invocations) are not recorded at all.
- **What to verify:** This is a confirmed gap, not suspicious activity. Immediately create a multi-region CloudTrail trail with S3 delivery and log file validation enabled.

#### [HIGH] F3-2: No AWS Config Recorder

- **What was observed:** AWS Config is not enabled. No configuration recorders exist in eu-central-1.
- **Why suspicious:** Without AWS Config, there is no continuous recording of resource configuration changes. Configuration drift, unauthorized changes, and compliance violations cannot be detected or audited.
- **What to verify:** Enable AWS Config with a recorder covering all resource types.

---

### Category 4: Data Exfiltration

#### [HIGH] F4-1: No Account-Level S3 Public Access Block

- **What was observed:** The account-level S3 Public Access Block is not configured (`NoSuchPublicAccessBlockConfiguration`). This means individual S3 buckets can be made publicly accessible without an account-level guardrail.
- **Why suspicious:** Without the account-level public access block, a misconfigured bucket policy or ACL could expose data publicly. This is a common vector for data breaches.
- **What to verify:** Enable the account-level S3 Public Access Block immediately. Audit all existing S3 buckets for public access.

No PutBucketPolicy, PutBucketAcl, ModifySnapshotAttribute, or ModifyImageAttribute events were detected.

---

### Category 5: Network Tampering

#### No findings requiring alert.

- **What was observed:** Two `AuthorizeSecurityGroupIngress` events by yamansener at 2026-05-28T15:16:38Z and 2026-05-28T15:17:37Z. Both added ingress rules to `sg-07065295fba2dd8c9` (socia-cirevo-social-tracker-sg) allowing TCP port 8002 from `sg-0b0738b9601831b96` (sc-int-alb-sg, internal ALB). No 0.0.0.0/0 or ::/0 rules were added.
- **Assessment:** These are properly scoped security group changes (SG-to-SG references for internal ALB traffic). This is normal operational activity.

**Status: CLEAN**

---

### Category 6: Resource Hijacking

No RunInstances, CreateKeyPair, or ImportKeyPair events were detected in the 24-hour window.

**Status: CLEAN**

---

### Category 7: Anomaly Detection

#### [HIGH] F7-1: Root and IAM User Access from Datacenter IP

- **What was observed:** Both root console login and yamansener CLI/console activity originate from `185.165.242.199`, a datacenter IP belonging to WorldStream B.V. (AS49981) in Rotterdam, Netherlands. This is a hosting/VPN provider, not a residential ISP.
- **Why suspicious:** Datacenter IPs are commonly used by VPN services, which is legitimate for privacy-conscious users, but also used by attackers to mask origin. The same IP is used for both root and yamansener activities, suggesting the same person/VPN controls both.
- **What to verify:** Confirm this is an authorized VPN endpoint. If it is, document it as a known-good IP. If not, investigate whether yamansener's credentials may have been compromised.

#### [MEDIUM] F7-2: pipeline-user Operating from 19 Different Microsoft Azure IPs

- **What was observed:** The `pipeline-user` IAM user performed 19 CloudFront cache invalidations from 19 different Microsoft (AS8075) IPs across US cities (Washington, Cheyenne, San Jose, Des Moines, Phoenix, Boydton). The user agent is `aws-cli/2.34.53` running on `linux#6.17.0-1015-azure`.
- **Why suspicious:** While this pattern is consistent with Azure DevOps hosted agents (which use ephemeral VMs with different IPs), it means the `pipeline-user` access key is distributed across many Azure compute instances.
- **What to verify:** Confirm the pipeline-user access key is properly stored in Azure DevOps as a secret variable. Consider migrating to OIDC federation (AWS IAM Identity Provider for Azure AD) to eliminate long-lived access keys.

#### [MEDIUM] F7-3: ECS Task Role Repeated AccessDenied on ListBuckets

- **What was observed:** The `socia-cirevo-media-task-role` (assumed by ECS task `28797177e4ea44adb1bd06bfdca2e16f`) generated 7 `AccessDenied` errors on `ListBuckets` within 35 seconds (23:39:03Z to 23:39:34Z) from IP `3.126.131.253` (AWS eu-central-1).
- **Why suspicious:** Repeated permission failures from an application role may indicate a misconfigured application attempting to access resources beyond its permissions, or potentially a compromised container probing for accessible resources. The high frequency in a short window suggests automated behavior.
- **What to verify:** Review the `socia-cirevo-media-task-role` IAM policy. If the application needs ListBuckets access, grant it. If not, investigate why the application is making these calls -- this could indicate a supply chain compromise or misconfigured SDK.

---

### Category 8: Service-Specific

#### [HIGH] F8-1: No GuardDuty Enabled

- **What was observed:** GuardDuty has no detectors configured in eu-central-1. This means AWS's threat detection service is not monitoring for malicious activity, unauthorized behavior, or compromised credentials.
- **Why suspicious:** Without GuardDuty, the account has no automated threat detection. Cryptocurrency mining, credential compromise, and data exfiltration attacks would go undetected.
- **What to verify:** Enable GuardDuty in all regions. It is a low-effort, high-value security control.

#### [MEDIUM] F8-2: EBS Default Encryption Disabled

- **What was observed:** EBS default encryption is not enabled in eu-central-1 (`EbsEncryptionByDefault: false`). New EBS volumes will be created unencrypted unless explicitly specified.
- **Why suspicious:** Unencrypted EBS volumes expose data at rest. If a volume snapshot is shared or an instance is compromised, data can be read directly.
- **What to verify:** Enable EBS default encryption in all regions.

#### [MEDIUM] F8-3: No VPC Flow Logs

- **What was observed:** No VPC Flow Logs are configured in eu-central-1.
- **Why suspicious:** Without flow logs, there is no visibility into network traffic patterns. Lateral movement, data exfiltration via network, and port scanning cannot be detected or investigated.
- **What to verify:** Enable VPC Flow Logs for all VPCs, publishing to CloudWatch Logs or S3.

---

## Human Activity Timeline

All times in UTC. Only interactive (non-service) events shown.

| Time (UTC) | User | Event | Source IP | Region | Status |
|---|---|---|---|---|---|
| 2026-05-28T06:52:33Z | yamansener | CreateInvalidation | 185.165.242.199 | us-east-1 | OK |
| 2026-05-28T07:49:30Z | yamansener | CreateInvalidation | 185.165.242.199 | us-east-1 | OK |
| 2026-05-28T08:01:53Z | pipeline-user | CreateInvalidation | 20.115.94.230 (Azure/US) | us-east-1 | OK |
| 2026-05-28T08:13:17Z | pipeline-user | CreateInvalidation | 52.161.45.226 (Azure/US) | us-east-1 | OK |
| 2026-05-28T08:18:19Z | pipeline-user | CreateInvalidation | 20.109.36.234 (Azure/US) | us-east-1 | OK |
| 2026-05-28T08:18:55Z | **root** | **ConsoleLogin (SUCCESS)** | 185.165.242.199 | us-east-1 | MFA: Yes |
| 2026-05-28T08:27:32Z | pipeline-user | CreateInvalidation | 52.154.132.187 (Azure/US) | us-east-1 | OK |
| 2026-05-28T08:48:19Z | pipeline-user | CreateInvalidation | 172.215.211.17 (Azure/US) | us-east-1 | OK |
| 2026-05-28T08:58:01Z | pipeline-user | CreateInvalidation | 52.234.41.66 (Azure/US) | us-east-1 | OK |
| 2026-05-28T09:18:26Z | pipeline-user | CreateInvalidation | 172.208.158.196 (Azure/US) | us-east-1 | OK |
| 2026-05-28T09:29:43Z | pipeline-user | CreateInvalidation | 9.234.151.114 (Azure/US) | us-east-1 | OK |
| 2026-05-28T10:20:41Z | pipeline-user | CreateInvalidation | 13.88.85.241 (Azure/US) | us-east-1 | OK |
| 2026-05-28T11:12:14Z | yamansener | CreateInvalidation | 185.165.242.199 | us-east-1 | OK |
| 2026-05-28T12:08:58Z | yamansener | CreateInvalidation | 185.165.242.199 | us-east-1 | OK |
| 2026-05-28T12:15:16Z | yamansener | CreateInvalidation | 185.165.242.199 | us-east-1 | OK |
| 2026-05-28T12:23:22Z | yamansener | CreateInvalidation | 185.165.242.199 | us-east-1 | OK |
| 2026-05-28T12:41:30Z | yamansener | CreateInvalidation | 185.165.242.199 | us-east-1 | OK |
| 2026-05-28T12:47:48Z | yamansener | CreateInvalidation | 185.165.242.199 | us-east-1 | OK |
| 2026-05-28T13:25:03Z | yamansener | CreateInvalidation | 185.165.242.199 | us-east-1 | OK |
| 2026-05-28T13:31:29Z | yamansener | CreateInvalidation | 185.165.242.199 | us-east-1 | OK |
| 2026-05-28T13:40:35Z | yamansener | CreateInvalidation | 185.165.242.199 | us-east-1 | OK |
| 2026-05-28T13:45:55Z | yamansener | CreateInvalidation | 185.165.242.199 | us-east-1 | OK |
| 2026-05-28T13:49:20Z | yamansener | CreateInvalidation | 185.165.242.199 | us-east-1 | OK |
| 2026-05-28T15:16:38Z | yamansener | AuthorizeSecurityGroupIngress | 185.165.242.199 | eu-central-1 | OK |
| 2026-05-28T15:17:37Z | yamansener | AuthorizeSecurityGroupIngress | 185.165.242.199 | eu-central-1 | OK |
| 2026-05-28T16:17:38Z | pipeline-user | CreateInvalidation | 172.178.118.81 (Azure/US) | us-east-1 | OK |
| 2026-05-28T17:29:47Z | pipeline-user | CreateInvalidation | 172.182.224.200 (Azure/US) | us-east-1 | OK |
| 2026-05-28T18:33:37Z | pipeline-user | CreateInvalidation | 52.165.251.171 (Azure/US) | us-east-1 | OK |
| 2026-05-28T18:44:09Z | pipeline-user | CreateInvalidation | 13.83.233.100 (Azure/US) | us-east-1 | OK |
| 2026-05-28T18:54:50Z | pipeline-user | CreateInvalidation | 20.55.127.232 (Azure/US) | us-east-1 | OK |
| 2026-05-28T19:53:47Z | pipeline-user | CreateInvalidation | 52.161.208.122 (Azure/US) | us-east-1 | OK |
| 2026-05-28T20:03:48Z | pipeline-user | CreateInvalidation | 57.151.128.102 (Azure/US) | us-east-1 | OK |
| 2026-05-28T20:18:34Z | pipeline-user | CreateInvalidation | 20.62.255.17 (Azure/US) | us-east-1 | OK |
| 2026-05-28T20:34:20Z | **root** | **ConsoleLogin (FAILURE)** | 185.165.242.199 | us-east-1 | MFA: Yes (failed) |
| 2026-05-28T20:34:46Z | **root** | **ConsoleLogin (FAILURE)** | 185.165.242.199 | us-east-1 | MFA: Yes (failed) |
| 2026-05-28T20:40:14Z | pipeline-user | CreateInvalidation | 20.83.174.50 (Azure/US) | us-east-1 | OK |
| 2026-05-28T21:15:46Z | pipeline-user | CreateInvalidation | 20.106.198.169 (Azure/US) | us-east-1 | OK |
| 2026-05-28T23:26:48Z | yamansener | ListFoundationModels | 88.230.227.239 | us-east-1 | OK |
| 2026-05-28T23:36:18Z | yamansener | ListFoundationModels | 88.230.227.239 | us-east-1 | OK |
| 2026-05-28T23:37:06Z | yamansener | ListFoundationModels | 88.230.227.239 | us-east-1 | OK |
| 2026-05-28T23:38:15Z | yamansener | GetCallerIdentity | 88.230.227.239 | us-east-1 | OK |
| 2026-05-28T23:39:06Z | yamansener | GetTrailStatus | 88.230.227.239 | eu-central-1 | TrailNotFound |
| 2026-05-28T23:39:07Z | yamansener | GetTrailStatus | 88.230.227.239 | us-east-1 | TrailNotFound |
| 2026-05-28T23:39:13Z | yamansener | LookupEvents | 88.230.227.239 | eu-central-1 | OK |
| 2026-05-28T23:39:22Z | yamansener | DescribeVpcs | 88.230.227.239 | eu-central-1 | OK |
| 2026-05-28T23:39:28Z | yamansener | DescribeSubnets | 88.230.227.239 | eu-central-1 | OK |
| 2026-05-28T23:39:33Z | yamansener | DescribeInternetGateways | 88.230.227.239 | eu-central-1 | OK |
| 2026-05-28T23:39:39Z | yamansener | DescribeNatGateways | 88.230.227.239 | eu-central-1 | OK |
| 2026-05-28T23:39-23:40Z | yamansener | LookupEvents (x9) | 88.230.227.239 | us-east-1 | OK |

---

## Anomalous IPs

| IP | Geo | ISP/Org | User | Events | Risk |
|---|---|---|---|---|---|
| 185.165.242.199 | Rotterdam, NL | AS49981 WorldStream B.V. | root, yamansener | 16 | **HIGH** -- Datacenter/VPN IP, not residential. Used for root login + yamansener CloudFront invalidations + SG changes. Consistent user agent (macOS/Chrome). |
| 88.230.227.239 | Izmir, TR | AS9121 Turk Telekom | yamansener | 24 | **LOW** -- Residential ISP (Turk Telekom). Used for CLI operations (aws-cli, aws-sdk-js). Consistent with a developer working from home in Turkey. |
| 3.126.131.253 | Frankfurt, DE | AS16509 Amazon (EC2) | socia-cirevo-media-task-role | 7 | **LOW** -- AWS EC2 instance in eu-central-1. ECS task generating AccessDenied on ListBuckets. Expected for workload in same region. |
| 20.x.x.x / 52.x.x.x / etc. (19 IPs) | Various US cities | AS8075 Microsoft Corp. | pipeline-user | 19 | **LOW** -- Azure DevOps hosted agent IPs. Consistent with CI/CD pipeline pattern. |

---

## Infrastructure Security Posture

| Control | Status | Severity |
|---|---|---|
| CloudTrail (dedicated trail) | NOT CONFIGURED | CRITICAL |
| GuardDuty | NOT ENABLED | HIGH |
| AWS Config | NOT ENABLED | HIGH |
| S3 Account Public Access Block | NOT CONFIGURED | HIGH |
| VPC Flow Logs | NOT CONFIGURED | HIGH |
| IAM Password Policy | NOT CONFIGURED | MEDIUM |
| EBS Default Encryption | DISABLED | MEDIUM |
| Root MFA | ENABLED | OK |
| EC2 IMDSv2 | Required (1 stopped instance) | OK |
| IAM User MFA (human users) | NOT CONFIGURED (0/2) | HIGH |

---

## Verdict

### SUSPICIOUS -- Posture Gaps with No Active Compromise Evidence

**Justification:**

There is **no evidence of active compromise** in the 24-hour window. No IAM mutations, no defense evasion attempts, no data exfiltration actions, no public security group rules, and no resource hijacking were detected. All observed human activity (CloudFront invalidations, security group changes, Bedrock model browsing, security audit activities) is consistent with normal development and operations workflows.

However, the account has **significant security posture deficiencies** that would make compromise detection extremely difficult:

1. **No CloudTrail trail** -- Only 90-day event history; no data events; no tamper protection
2. **No GuardDuty** -- No automated threat detection
3. **No AWS Config** -- No configuration change tracking
4. **No VPC Flow Logs** -- No network visibility
5. **No S3 Public Access Block** -- No guardrail against public bucket exposure
6. **No IAM user MFA** -- Access keys are the only barrier to account takeover
7. **Root account active usage** -- Root used for console login during the audit window

The root account login from a datacenter/VPN IP (WorldStream B.V.) warrants verification but is not conclusive evidence of compromise, especially since MFA was used successfully. The two failed root logins later in the day appear to be the same user experiencing MFA issues.

The `yamansener` user operating from two different IPs (Netherlands VPN and Turkey residential) is notable but explainable if the user switched from VPN to direct connection during the day.

---

## Actionable Follow-ups

### Priority 1 -- Immediate (within 24 hours)

1. **Enable CloudTrail:** Create a multi-region trail in eu-central-1 with S3 delivery, log file validation, and KMS encryption. Enable both management and data events.
2. **Enable GuardDuty:** Activate in all active regions (eu-central-1, us-east-1 at minimum). Enable all finding types including S3, EKS, and RDS protection.
3. **Enable S3 Account-Level Public Access Block:** Set all four block options to true at the account level.

### Priority 2 -- Within 48 hours

4. **Enable MFA for IAM users:** Require MFA for yamansener and ulucvarat. These are human users with console/CLI access.
5. **Enable AWS Config:** Set up a recorder covering all resource types with an S3 delivery channel.
6. **Enable VPC Flow Logs:** Configure for all VPCs in eu-central-1, delivering to CloudWatch Logs.
7. **Set IAM Password Policy:** Configure minimum length (14+), complexity requirements, and password rotation.

### Priority 3 -- Within 1 week

8. **Stop using root account:** Create an IAM admin user/role. Lock root credentials. Set up CloudWatch alarm for root login.
9. **Enable EBS Default Encryption:** In all regions.
10. **Migrate pipeline-user to OIDC:** Replace long-lived access keys with Azure AD OIDC federation for the CI/CD pipeline.
11. **Investigate ECS task AccessDenied:** Review why `socia-cirevo-media-task-role` is calling `ListBuckets` 7 times in 35 seconds. Fix the IAM policy or the application code.
12. **Rotate access keys:** The yamansener access key (AKIA****FCWL) was created 2025-12-23 and is 5+ months old. The pipeline-user key (AKIA****74EU) is also 4+ months old. Implement a 90-day key rotation policy.
13. **Document known-good IPs:** Create a baseline of expected source IPs for human users and CI/CD systems to enable future anomaly detection.
14. **Verify the VPN IP:** Confirm 185.165.242.199 (WorldStream, Rotterdam) is an authorized corporate VPN egress point.

---

*Report generated by Cloud Security Audit Engine on 2026-05-29.*
*Event data source: CloudTrail Event History (no dedicated trail configured).*
*Regions scanned: eu-central-1, us-east-1, eu-west-1, us-west-2.*
*Events analyzed: 248 unique events (97 write, 100 management, 3 login, 52 service-specific).*

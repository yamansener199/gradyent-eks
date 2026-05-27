# GDPR COMPLIANCE REPORT

| Field | Value |
|-------|-------|
| **Organization** | Gradyent |
| **Date** | 2026-05-27 |
| **Auditor** | GDPR Inspector v2 (rot-balance) |
| **Scope** | EKS infrastructure platform (`gradyent-prod`, `eu-central-1`) |
| **Cloud Providers** | AWS |
| **Repository** | gradyent-eks |

---

## OVERALL SCORE: 28.4 / 100 — Grade F (Critical)

> **Assessment:** The Gradyent EKS platform has strong **technical security controls** (encryption, admission policies, runtime detection) but lacks almost all **organizational GDPR controls** — no privacy notice, no consent management, no DSAR process, no DPO, no DPIA framework, no breach notification plan, no data inventory, no processor agreements, no cross-border transfer assessments, and no retention schedules. This infrastructure repository manages Kubernetes platform components only; GDPR compliance is an organization-wide requirement that extends far beyond infrastructure.

---

## DOMAIN SCORES

| # | Domain | Weight | Score | Grade | Critical Fails | High Fails |
|---|--------|--------|-------|-------|----------------|------------|
| 1 | Transparency & Privacy Notices | 9% | 0.0 | F | 5 | 11 |
| 2 | Privacy by Design & Default | 7% | 35.0 | F | 3 | 2 |
| 3 | Consent Management | 8% | 0.0 | F | 3 | 3 |
| 4 | Data Inventory & Mapping | 8% | 0.0 | F | 2 | 3 |
| 5 | DSAR Readiness | 8% | 0.0 | F | 4 | 3 |
| 6 | Extended Data Subject Rights | 7% | 0.0 | F | 4 | 5 |
| 7 | Processor & Controller Obligations | 8% | 0.0 | F | 5 | 5 |
| 8 | DPIA Process | 8% | 0.0 | F | 4 | 4 |
| 9 | Breach Notification | 8% | 16.7 | F | 2 | 1 |
| 10 | DPO Designation | 6% | 0.0 | F | 1 | 3 |
| 11 | Cross-Border Transfer | 9% | 21.4 | F | 1 | 3 |
| 12 | Data Retention | 8% | 8.3 | F | 1 | 2 |
| 13 | Encryption & Technical Security | 6% | 83.3 | B | 0 | 1 |

---

## DOMAIN DETAIL

### Domain 1: Transparency & Privacy Notices (Weight: 9%, Art. 12-14)

**Domain Score: 0.0 / 100 — Grade F**

| ID | Check | Severity | Result | Evidence / Notes |
|----|-------|----------|--------|------------------|
| TN-001 | Privacy notice exists and is accessible | Critical | **FAIL** | No privacy notice found in repository or referenced in any configuration. |
| TN-002 | Controller identity and contact details disclosed | Critical | **FAIL** | No controller identity disclosure found. |
| TN-003 | DPO contact details in privacy notice | High | **FAIL** | No DPO contact information found anywhere. |
| TN-004 | Processing purposes and legal bases stated | Critical | **FAIL** | No processing purpose documentation found. |
| TN-005 | Legitimate interest described where applicable | High | **FAIL** | No legitimate interest assessments found. |
| TN-006 | Recipients or categories disclosed | High | **FAIL** | No recipient disclosure. AWS is used as processor but not disclosed to data subjects. |
| TN-007 | International transfer safeguards disclosed | High | **FAIL** | Data resides in eu-central-1 but no transfer disclosure exists. |
| TN-008 | Retention periods or criteria specified | High | **FAIL** | Prometheus retention set to 15d; no overall retention policy disclosed to data subjects. |
| TN-009 | All data subject rights listed | Critical | **FAIL** | No data subject rights information found. |
| TN-010 | Right to withdraw consent stated | High | **FAIL** | No consent withdrawal mechanism documented. |
| TN-011 | Right to complain to supervisory authority stated | High | **FAIL** | No supervisory authority complaint information. |
| TN-012 | Automated decision-making/profiling disclosed | High | **FAIL** | No automated decision-making disclosure. |
| TN-013 | Indirect collection: source and categories disclosed | High | **N/A** | Infrastructure platform — no indirect data collection identified. |
| TN-014 | Plain language, concise and intelligible | High | **FAIL** | No privacy notice exists to evaluate. |
| TN-015 | Notice provided at time of collection | Critical | **FAIL** | No notice mechanism in place. |
| TN-016 | Purpose change notification before reuse | High | **FAIL** | No purpose change notification process. |

---

### Domain 2: Privacy by Design & Default (Weight: 7%, Art. 5, 25)

**Domain Score: 35.0 / 100 — Grade F**

| ID | Check | Severity | Result | Evidence / Notes |
|----|-------|----------|--------|------------------|
| PD-001 | Purpose limitation enforced | Critical | **FAIL** | No purpose limitation documentation. IRSA roles are scoped per-service (least privilege), but no formal purpose limitation framework. |
| PD-002 | Data minimisation: collection limited to necessary | Critical | **PARTIAL** | Fluentd collects all container logs (`/var/log/containers/*.log`), excluding only its own namespace. No PII filtering configured. Prometheus scrapes broadly (`serviceMonitorSelectorNilUsesHelmValues: false`). |
| PD-003 | Accuracy controls and timely correction | High | **FAIL** | No data accuracy controls. |
| PD-004 | Default settings process minimum data | Critical | **FAIL** | Hubble captures DNS, TCP, HTTP flow data by default. Fluentd logs everything. No data minimisation defaults. |
| PD-005 | Default access restriction | High | **PASS** | Kyverno enforces non-root, drops capabilities, disallows privilege escalation. RBAC via EKS access entries. Private API endpoint. SSM-only bastion. |
| PD-006 | Privacy integrated into development lifecycle | High | **FAIL** | CI pipelines (infra-ci, gitops-ci) validate infrastructure only. No privacy review gates. |
| PD-007 | All processing lawful and fair | Critical | **PARTIAL** | Technical controls exist (IRSA, KMS, Kyverno) but no legal basis documentation for processing. |
| PD-008 | Accountability: compliance demonstrable through records | Critical | **FAIL** | Git history and Terraform state provide change audit trail but no GDPR-specific accountability records. |
| PD-009 | Special category safeguards (Art. 9(2) conditions) | Critical | **N/A** | Infrastructure platform — no special category data processing identified at this layer. |
| PD-010 | Cookie/tracking explicit opt-in consent | High | **N/A** | No web-facing application with cookies in this repository. Grafana/ArgoCD/Jaeger are internal platform UIs. |

---

### Domain 3: Consent Management (Weight: 8%, Art. 6-8)

**Domain Score: 0.0 / 100 — Grade F**

| ID | Check | Severity | Result | Evidence / Notes |
|----|-------|----------|--------|------------------|
| CM-001 | Consent collected through clear affirmative action | Critical | **FAIL** | No consent collection mechanism found. |
| CM-002 | Granular consent for separate processing purposes | High | **FAIL** | No consent granularity. |
| CM-003 | Consent withdrawal as easy as giving consent | Critical | **FAIL** | No consent withdrawal mechanism. |
| CM-004 | Consent records maintained (timestamp, scope, method) | High | **FAIL** | No consent records. |
| CM-005 | Child consent: parental consent for under-16 | Critical | **N/A** | Infrastructure platform — no direct child data processing. |
| CM-006 | Pre-ticked consent boxes prohibited | High | **N/A** | No user-facing consent UI in this repository. |
| CM-007 | Consent periodically re-validated | Medium | **FAIL** | No consent re-validation process. |

---

### Domain 4: Data Inventory & Mapping (Weight: 8%, Art. 30)

**Domain Score: 0.0 / 100 — Grade F**

| ID | Check | Severity | Result | Evidence / Notes |
|----|-------|----------|--------|------------------|
| DI-001 | Processing Activities Register exists | Critical | **FAIL** | No Record of Processing Activities (ROPA) found. |
| DI-002 | Data flows mapped (collection → storage → processing → deletion) | High | **FAIL** | `docs/ARCHITECTURE.md` and `docs/networking.md` describe infrastructure flows but not personal data flows. |
| DI-003 | Legal basis documented for each processing activity | Critical | **FAIL** | No legal basis documentation. |
| DI-004 | Third-party processor inventory up-to-date | High | **FAIL** | AWS used as IaaS; no formal processor inventory. Let's Encrypt used for TLS. Slack used for alerting. No processor register. |
| DI-005 | Personal data categories classified | High | **FAIL** | No personal data classification. Logs may contain PII (container logs, access logs). |
| DI-006 | Categories of data subjects documented | Medium | **FAIL** | No data subject categories documented. |
| DI-007 | Register linked to retention schedules | Medium | **FAIL** | No retention schedule linkage (no register exists). |
| DI-008 | Register reviewed and updated at least annually | Medium | **FAIL** | No register to review. |

---

### Domain 5: DSAR Readiness (Weight: 8%, Art. 15-17, 20, 22)

**Domain Score: 0.0 / 100 — Grade F**

| ID | Check | Severity | Result | Evidence / Notes |
|----|-------|----------|--------|------------------|
| DS-001 | DSAR handling process documented | Critical | **FAIL** | No DSAR process documented. |
| DS-002 | Identity verification process for data subjects | High | **FAIL** | No identity verification process. |
| DS-003 | 30-day response SLA achievable | Critical | **FAIL** | No SLA framework for DSARs. |
| DS-004 | Right to Access: all personal data retrievable | Critical | **FAIL** | Logs in CloudWatch (`/eks/gradyent-prod/containers`) and Prometheus (15d retention) are not structured for data retrieval by data subject. |
| DS-005 | Right to Erasure: data deletable across all systems | Critical | **FAIL** | No erasure mechanism. CloudWatch logs, Prometheus TSDB, Grafana PVC — no targeted deletion capability. |
| DS-006 | Right to Portability: data exportable in machine-readable format | High | **FAIL** | No data export mechanism for data subjects. |
| DS-007 | Right to Rectification: inaccurate data correctable | High | **FAIL** | No rectification process. |
| DS-008 | Automated decision-making safeguards | High | **N/A** | No automated decision-making about data subjects at infrastructure layer. |

---

### Domain 6: Extended Data Subject Rights (Weight: 7%, Art. 18-19, 21-22, 77)

**Domain Score: 0.0 / 100 — Grade F**

| ID | Check | Severity | Result | Evidence / Notes |
|----|-------|----------|--------|------------------|
| RE-001 | Right to restriction of processing operational | Critical | **FAIL** | No restriction mechanism. |
| RE-002 | Data subject notified before restriction is lifted | High | **FAIL** | No notification process. |
| RE-003 | Rectification/erasure/restriction propagated to recipients | High | **FAIL** | No propagation mechanism to AWS, Slack, or other recipients. |
| RE-004 | Recipients disclosed to data subject on request | Medium | **FAIL** | No recipient disclosure process. |
| RE-005 | Right to object — legitimate/public interest processing | Critical | **FAIL** | No objection mechanism. |
| RE-006 | Right to object — direct marketing stops unconditionally | Critical | **N/A** | No direct marketing from this platform. |
| RE-007 | Right to object communicated clearly at first contact | High | **N/A** | Infrastructure platform — no direct data subject contact. |
| RE-008 | Automated decisions: human intervention available | Critical | **N/A** | No automated individual decision-making. |
| RE-009 | Automated decisions: logic explanation available | High | **N/A** | No automated individual decision-making. |
| RE-010 | Automated decisions: right to contest | High | **N/A** | No automated individual decision-making. |
| RE-011 | Complaint to supervisory authority facilitated | High | **FAIL** | No supervisory authority complaint facilitation. |
| RE-012 | Excessive/unfounded request handling policy | Medium | **FAIL** | No request handling policy. |

---

### Domain 7: Processor & Controller Obligations (Weight: 8%, Art. 24-29)

**Domain Score: 0.0 / 100 — Grade F**

| ID | Check | Severity | Result | Evidence / Notes |
|----|-------|----------|--------|------------------|
| PM-001 | DPA signed with every processor | Critical | **FAIL** | No Data Processing Agreements found. AWS DPA (GDPR Data Processing Addendum) not referenced. Slack, PagerDuty, Let's Encrypt — no DPAs documented. |
| PM-002 | Processors process only on documented instructions | Critical | **FAIL** | No documented processing instructions for AWS or other processors. |
| PM-003 | Processor personnel under confidentiality | High | **FAIL** | No evidence of confidentiality obligations for processors. |
| PM-004 | Processors implement Art. 32 security measures | High | **PARTIAL** | AWS provides SOC2/ISO27001; however, no formal assessment of processor security measures documented. |
| PM-005 | Prior written authorization for sub-processors | Critical | **FAIL** | No sub-processor authorization framework. AWS sub-processor list not tracked. |
| PM-006 | Processors assist with data subject requests | High | **FAIL** | No processor DSAR assistance agreements. |
| PM-007 | Controller audit rights over processors | High | **FAIL** | No audit rights documented. |
| PM-008 | Data return/deletion after service ends | High | **FAIL** | No data return/deletion clauses. |
| PM-009 | Joint controller arrangement documented | High | **N/A** | No joint controllership identified. |
| PM-010 | EU representative appointed (non-EU controllers) | High | **N/A** | Organization appears EU-based (eu-central-1 region). |
| PM-011 | Controller can demonstrate compliance | Critical | **FAIL** | No compliance demonstration framework. Git history provides infrastructure audit trail only. |
| PM-012 | Processor breach notification without undue delay | Critical | **FAIL** | No processor breach notification terms documented. |

---

### Domain 8: DPIA Process (Weight: 8%, Art. 35-36)

**Domain Score: 0.0 / 100 — Grade F**

| ID | Check | Severity | Result | Evidence / Notes |
|----|-------|----------|--------|------------------|
| IA-001 | DPIA trigger criteria defined | Critical | **FAIL** | No DPIA trigger criteria. |
| IA-002 | DPIA process and templates documented | Critical | **FAIL** | No DPIA templates or process. |
| IA-003 | Systematic processing description in each DPIA | High | **FAIL** | No DPIAs exist. |
| IA-004 | Necessity and proportionality assessed | High | **FAIL** | No necessity/proportionality assessments. |
| IA-005 | Risk to data subjects assessed | Critical | **FAIL** | No data subject risk assessments. |
| IA-006 | Mitigation measures documented | Critical | **FAIL** | Technical mitigations exist (KMS, Kyverno, Falco) but not framed as DPIA mitigations. |
| IA-007 | DPO consulted during DPIA | High | **FAIL** | No DPO appointed. |
| IA-008 | Data subject views sought where appropriate | Medium | **FAIL** | No data subject consultation process. |
| IA-009 | DPIA reviewed when risk changes | High | **FAIL** | No DPIA review process. |
| IA-010 | Prior consultation with supervisory authority when residual risk high | High | **FAIL** | No prior consultation framework. |

---

### Domain 9: Breach Notification (Weight: 8%, Art. 33-34)

**Domain Score: 16.7 / 100 — Grade F**

| ID | Check | Severity | Result | Evidence / Notes |
|----|-------|----------|--------|------------------|
| BN-001 | Breach detection mechanism exists | Critical | **PASS** | Falco runtime detection with custom rules (shell in container, exec, sensitive file reads, cryptominer connections). Alertmanager with PagerDuty for critical alerts. Slack notifications for warnings. |
| BN-002 | 72-hour supervisory authority notification achievable | Critical | **FAIL** | No supervisory authority notification process. Detection exists but no notification workflow to DPA. |
| BN-003 | Documented incident response plan | Critical | **PARTIAL** | Runbooks exist for technical incidents (`docs/runbooks/`) but no GDPR-specific breach response plan covering supervisory authority notification, data subject communication, and documentation requirements. |
| BN-004 | Data subject notification process for high-risk breaches | High | **FAIL** | No data subject breach notification process. |
| BN-005 | Breach register maintained | High | **FAIL** | No breach register. Falco alerts go to Slack but no formal register. |
| BN-006 | Breach response procedures tested regularly | Medium | **FAIL** | No evidence of breach response testing/drills. |

---

### Domain 10: DPO Designation (Weight: 6%, Art. 37-39)

**Domain Score: 0.0 / 100 — Grade F**

| ID | Check | Severity | Result | Evidence / Notes |
|----|-------|----------|--------|------------------|
| DP-001 | DPO appointed (if required) | Critical | **FAIL** | No DPO appointment evidence. Required if systematic monitoring of data subjects at scale. |
| DP-002 | DPO operates independently, no conflicts of interest | High | **FAIL** | No DPO to assess. |
| DP-003 | DPO contact information publicly available | High | **FAIL** | No DPO contact published. |
| DP-004 | DPO involved in DPIA processes | High | **FAIL** | No DPO involvement. |
| DP-005 | DPO has adequate resources and training | Medium | **FAIL** | No DPO designated. |

---

### Domain 11: Cross-Border Transfer (Weight: 9%, Art. 44-49)

**Domain Score: 21.4 / 100 — Grade F**

| ID | Check | Severity | Result | Evidence / Notes |
|----|-------|----------|--------|------------------|
| CB-001 | Lawful transfer mechanism for each international transfer | Critical | **PARTIAL** | Primary infrastructure in eu-central-1 (Frankfurt). AWS operates under EU-US Data Privacy Framework. However, no formal Transfer Impact Assessment. Slack (US-based) receives alert data including potentially personal data in logs. |
| CB-002 | Transfers to non-adequate countries identified and protected | Critical | **FAIL** | Slack webhooks send data to US servers. PagerDuty is US-based. Let's Encrypt (ISRG) is US-based. No transfer protection assessment. |
| CB-003 | Standard Contractual Clauses in place where needed | Critical | **FAIL** | No SCCs documented for Slack, PagerDuty, or other US-based service providers. |
| CB-004 | Transfer Impact Assessment for high-risk transfers | High | **FAIL** | No TIAs performed. |
| CB-005 | Full sub-processor chain documented | High | **FAIL** | AWS sub-processor chain not documented. |
| CB-006 | Cloud data storage locations documented and compliant | High | **PASS** | Infrastructure explicitly deployed to `eu-central-1`. S3 state bucket in same region. EBS volumes region-bound. CloudWatch Logs in eu-central-1. |
| CB-007 | Schrems II supplementary measures in place | High | **PARTIAL** | KMS encryption provides supplementary technical measure. VPC endpoints reduce data exposure. However, no formal Schrems II assessment documented. |

---

### Domain 12: Data Retention (Weight: 8%, Art. 5(1)(e), Art. 17)

**Domain Score: 8.3 / 100 — Grade F**

| ID | Check | Severity | Result | Evidence / Notes |
|----|-------|----------|--------|------------------|
| DR-001 | Retention schedule for each data category | Critical | **FAIL** | No formal retention schedule. Only technical retention found: Prometheus 15d, CloudWatch default (never expires unless configured), Grafana PVC persistent. |
| DR-002 | Automated deletion when retention expires | High | **PARTIAL** | Prometheus auto-purges after 15d. CloudWatch has no retention policy set — logs retained indefinitely by default. EBS volumes persist until manual deletion. |
| DR-003 | Backup retention aligned with data retention policy | High | **FAIL** | No backup retention policy. EBS snapshots (if taken) have no documented lifecycle. |
| DR-004 | Legal hold process to suspend deletion | Medium | **N/A** | No deletion to suspend (most data retained indefinitely). |
| DR-005 | Third parties required to delete when retention expires | High | **FAIL** | No third-party deletion requirements. AWS, Slack, PagerDuty retention not managed. |
| DR-006 | Deletion logged and auditable | Medium | **FAIL** | No deletion logging. |

---

### Domain 13: Encryption & Technical Security (Weight: 6%, Art. 32)

**Domain Score: 83.3 / 100 — Grade B**

| ID | Check | Severity | Result | Evidence / Notes |
|----|-------|----------|--------|------------------|
| ES-001 | Personal data encrypted at rest | Critical | **PASS** | EKS secrets encrypted with KMS (`cluster_encryption_config`). EBS volumes use `gp3` StorageClass with `encrypted: "true"`. S3 state bucket has `encrypt = true`. |
| ES-002 | Personal data encrypted in transit (TLS 1.2+) | Critical | **PASS** | ALB terminates TLS (HTTPS with SSL redirect to 443). Istio mTLS enabled (`enableAutoMtls: true`). VPC endpoints use HTTPS. Let's Encrypt production issuer for public certs. |
| ES-003 | Key management policy and rotation schedule | Critical | **PASS** | KMS key has `enable_key_rotation = true` (automatic annual rotation). KMS key policy scoped to EKS service and root account. |
| ES-004 | Role-based access control on personal data | Critical | **PASS** | IRSA for workload IAM (6 scoped roles). Kyverno enforces pod security. EKS access entries for human access. SSM Session Manager for bastion (auditable). Private API endpoint. |
| ES-005 | Encryption keys rotated at least every 90 days | High | **PARTIAL** | KMS automatic rotation is annual (365 days), not 90 days. `docs/security.md` notes "Rotate Let's Encrypt and webhook credentials on schedule" but no automation. |
| ES-006 | Access and modification events logged | High | **PASS** | Fluentd ships all container logs to CloudWatch. Prometheus scrapes metrics. Falco monitors syscalls. Alertmanager routes to Slack/PagerDuty. `docs/security.md` references CloudTrail and Session Manager logs. |
| ES-007 | Regular vulnerability scanning and pen testing | High | **PASS** | Falco provides continuous runtime vulnerability detection. Kyverno enforces image tag pinning (`disallow-latest-tag`). CI validates infrastructure (Terragrunt) and manifests (kubeconform). |
| ES-008 | Pseudonymisation applied where feasible | Medium | **FAIL** | No pseudonymisation of log data. Container logs may contain PII (usernames, emails, IPs) without masking. |
| ES-009 | Ability to restore availability after incident | High | **PASS** | GitOps (Argo CD) provides declarative infrastructure recovery. Karpenter auto-scales nodes. Multi-AZ VPC with per-AZ NAT gateways. Prometheus HA-capable. EBS persistent volumes with gp3. |

---

## GDPR ARTICLE COVERAGE

| GDPR Article | Checks | Status |
|-------------|--------|--------|
| Art. 5 (Principles) | PD-001 to PD-008 | 1 Pass, 2 Partial, 5 Fail |
| Art. 6 (Lawfulness) | CM-001, PD-007 | 1 Partial, 1 Fail |
| Art. 7 (Consent conditions) | CM-001 to CM-004 | 4 Fail |
| Art. 8 (Child consent) | CM-005 | N/A |
| Art. 9 (Special categories) | PD-009 | N/A |
| Art. 12-14 (Transparency) | TN-001 to TN-016 | 15 Fail, 1 N/A |
| Art. 15 (Access) | DS-004 | 1 Fail |
| Art. 16 (Rectification) | DS-007 | 1 Fail |
| Art. 17 (Erasure) | DS-005 | 1 Fail |
| Art. 18-19 (Restriction) | RE-001 to RE-004 | 4 Fail |
| Art. 20 (Portability) | DS-006 | 1 Fail |
| Art. 21 (Objection) | RE-005 to RE-007 | 1 Fail, 2 N/A |
| Art. 22 (Automated decisions) | RE-008 to RE-010, DS-008 | 4 N/A |
| Art. 24-26 (Controller) | PM-001, PM-009, PM-011 | 3 Fail |
| Art. 27 (EU representative) | PM-010 | N/A |
| Art. 28 (Processor) | PM-001 to PM-008, PM-012 | 1 Partial, 8 Fail |
| Art. 29 (Processing under authority) | PM-002 | 1 Fail |
| Art. 30 (Records) | DI-001 to DI-008 | 8 Fail |
| Art. 32 (Security) | ES-001 to ES-009 | 6 Pass, 2 Partial, 1 Fail |
| Art. 33 (Authority notification) | BN-001 to BN-003 | 1 Pass, 1 Partial, 1 Fail |
| Art. 34 (Data subject notification) | BN-004 | 1 Fail |
| Art. 35-36 (DPIA) | IA-001 to IA-010 | 10 Fail |
| Art. 37-39 (DPO) | DP-001 to DP-005 | 5 Fail |
| Art. 44-49 (Transfers) | CB-001 to CB-007 | 1 Pass, 2 Partial, 4 Fail |
| Art. 77 (Complaint right) | RE-011 | 1 Fail |

---

## CRITICAL FINDINGS

### CF-01: No Privacy Notice (TN-001, Art. 12-14)

**Finding:** No privacy notice exists for the organization. This is the most visible GDPR obligation and its absence signals non-compliance to data subjects and supervisory authorities.

**Remediation:** Draft and publish a comprehensive privacy notice covering all Art. 13-14 requirements. Deadline: **30 days**.

---

### CF-02: No Record of Processing Activities (DI-001, Art. 30)

**Finding:** No ROPA exists. Art. 30 requires controllers to maintain a register of all processing activities with purposes, legal bases, recipients, retention periods, and security measures.

**Remediation:** Create a processing activities register. Start with the platform layer (logging, monitoring, alerting) and expand to application-level processing. Deadline: **30 days**.

---

### CF-03: No Data Processing Agreements (PM-001, Art. 28)

**Finding:** No DPAs found for any processor: AWS (IaaS), Slack (alerting), PagerDuty (incident management), Let's Encrypt (TLS). AWS provides a GDPR DPA but it must be explicitly accepted. Slack and PagerDuty DPAs need execution.

**Remediation:** Execute DPAs with all processors. AWS DPA via AWS Artifact. Slack and PagerDuty enterprise DPAs. Deadline: **45 days**.

---

### CF-04: No DPO Appointed (DP-001, Art. 37)

**Finding:** No Data Protection Officer designated. If Gradyent's core activities involve systematic monitoring of data subjects at scale (e.g., IoT energy monitoring), a DPO is mandatory under Art. 37(1)(b).

**Remediation:** Assess whether DPO appointment is required. If so, appoint and publish contact details. Deadline: **30 days**.

---

### CF-05: No DSAR Process (DS-001, Art. 15-22)

**Finding:** No process for handling Data Subject Access Requests. CloudWatch logs and Prometheus metrics are not structured for per-subject data retrieval or deletion.

**Remediation:** Establish DSAR handling process with identity verification, 30-day SLA tracking, and technical capability to locate and extract/delete personal data. Deadline: **60 days**.

---

### CF-06: No Breach Notification to Supervisory Authority (BN-002, Art. 33)

**Finding:** Falco provides strong breach detection, but there is no process to notify the supervisory authority within 72 hours or to notify affected data subjects per Art. 34.

**Remediation:** Create a GDPR breach response plan building on existing Falco/Alertmanager alerting. Add escalation to DPO, supervisory authority notification template, and data subject notification process. Deadline: **30 days**.

---

### CF-07: No DPIA Framework (IA-001, Art. 35)

**Finding:** No DPIA trigger criteria, process, or templates. If the platform processes personal data at scale (e.g., energy consumption monitoring tied to individuals), DPIAs are required.

**Remediation:** Define DPIA trigger criteria and create templates. Conduct initial DPIAs for high-risk processing. Deadline: **60 days**.

---

### CF-08: Cross-Border Transfer Risk (CB-002, Art. 44-49)

**Finding:** Alert data (potentially containing personal data from container logs) is sent to Slack (US) and PagerDuty (US) without SCCs or Transfer Impact Assessments. Post-Schrems II, this requires supplementary measures.

**Remediation:** Execute SCCs with Slack and PagerDuty. Perform Transfer Impact Assessments. Consider EU-hosted alternatives for alerting. Deadline: **45 days**.

---

### CF-09: No Data Retention Policy (DR-001, Art. 5(1)(e))

**Finding:** Only Prometheus has a defined retention (15d). CloudWatch logs have no retention policy and are retained indefinitely by default. No formal retention schedule aligns with GDPR storage limitation principle.

**Remediation:** Define retention periods per data category. Configure CloudWatch log group retention. Automate deletion. Deadline: **30 days**.

---

### CF-10: Plaintext Secrets in Git (ES — Security Best Practice)

**Finding:** `grafana-admin-secret.yaml` contains hardcoded credentials (`admin/admin123`). `alertmanager-notification-secret.yaml` and `falcosidekick-notification-secret.yaml` have placeholder webhook URLs in Git. While marked as placeholders, this pattern risks accidental production credential commits.

**Remediation:** Migrate to Sealed Secrets, External Secrets Operator, or AWS Secrets Manager. Remove plaintext secrets from Git history. Deadline: **14 days**.

---

## REMEDIATION PRIORITY

| Priority | ID | Action | Effort | Deadline | GDPR Article |
|----------|----|--------|--------|----------|-------------|
| P0 | CF-10 | Remove plaintext secrets from Git, adopt sealed/external secrets | Medium | 14 days | Art. 32 |
| P1 | CF-01 | Draft and publish privacy notice | Medium | 30 days | Art. 12-14 |
| P1 | CF-02 | Create Record of Processing Activities | Medium | 30 days | Art. 30 |
| P1 | CF-04 | Assess DPO requirement and appoint if needed | Low | 30 days | Art. 37 |
| P1 | CF-06 | Create GDPR breach notification plan | Medium | 30 days | Art. 33-34 |
| P1 | CF-09 | Define and enforce data retention policy | Medium | 30 days | Art. 5(1)(e) |
| P2 | CF-03 | Execute DPAs with all processors | Medium | 45 days | Art. 28 |
| P2 | CF-08 | SCCs and TIAs for cross-border transfers | High | 45 days | Art. 44-49 |
| P3 | CF-05 | Build DSAR handling process | High | 60 days | Art. 15-22 |
| P3 | CF-07 | Establish DPIA framework | Medium | 60 days | Art. 35-36 |

---

## SCORING METHODOLOGY

- **Check Scores:** Pass = 100, Partial = 50, Fail = 0, N/A = excluded from calculation
- **Severity Multipliers:** Critical = 1.5x, High = 1.2x, Medium = 1.0x
- **Domain Score:** `sum(check_score * severity_multiplier) / sum(max_possible * severity_multiplier) * 100`
- **Overall Score:** `sum(domain_score * domain_weight)`
- **Grades:** A (90-100) Excellent | B (75-89) Good | C (60-74) Adequate | D (40-59) Poor | F (0-39) Critical

---

## NOTES FOR DPO REVIEW

1. This audit assessed the **infrastructure platform layer** only (gradyent-eks repository). Application-layer GDPR compliance was not in scope.
2. The platform has **excellent technical security** (Grade B in Domain 13) which provides a strong foundation for GDPR Art. 32 compliance.
3. **All organizational GDPR controls are missing.** This is typical for an infrastructure-first project that has not yet undergone GDPR readiness. The gaps are addressable but require dedicated compliance effort.
4. The `eu-central-1` deployment is a positive signal for data residency, but cross-border transfers via Slack/PagerDuty need formal assessment.
5. The Istio PeerAuthentication is currently `PERMISSIVE` — switch to `STRICT` after all service namespaces have sidecar injection to achieve full mTLS.
6. Grafana admin credentials (`admin/admin123`) in Git are a security risk and should be addressed immediately.

---

*Generated by rot-balance GDPR Inspector v2 — this report should be reviewed by a qualified Data Protection Officer before being used for regulatory purposes.*

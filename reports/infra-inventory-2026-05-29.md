# Infrastructure Scan Report

**Date:** 2026-05-29
**Provider:** AWS
**Account:** 043470661424
**Region(s):** eu-central-1 (primary), us-east-1 (global services)
**Organization:** Gradyent
**Scanner:** Claude Infrastructure Scanner

---

## Resource Inventory

| Provider | Resource Type | Count | Details |
|---|---|---|---|
| AWS | VPC | 3 | czn-erp-vpc (10.0.0.0/16), socia-cirevo-vpc (10.0.0.0/16), default (172.31.0.0/16) |
| AWS | Subnet | 15 | 4 public, 8 private (app/db/elasticache), 3 default |
| AWS | Internet Gateway | 3 | One per VPC |
| AWS | NAT Gateway | 3 | 2x czn-erp (AZ-a, AZ-b), 1x socia-cirevo (AZ-a) |
| AWS | Route Table | 11 | Public, private, DB, ElastiCache tiers |
| AWS | Security Group | 22 | ALB, ECS, RDS, Redis, proxy groups |
| AWS | VPC Endpoint | 1 | Interface endpoint in czn-erp VPC |
| AWS | EC2 Instance | 1 | i-0a59077c9cb14ae90 (test, t3.micro, stopped) |
| AWS | ECS Cluster | 2 | czn-erp (13 services, 24 tasks), socia-cirevo-dev (11 services, 11 tasks) |
| AWS | ECS Service | 24 | 13 czn-erp + 11 socia-cirevo |
| AWS | ALB | 3 | czn-erp-alb (internet-facing), socia-cirevo-dev-alb (internet-facing), sc-int-alb (internal) |
| AWS | Target Group | 15 | IP-based targets for ECS services |
| AWS | RDS Instance | 2 | czn-erp-db (PostgreSQL 16.10, Multi-AZ), socia-cirevo-dev-postgres (PostgreSQL 15.17) |
| AWS | RDS Proxy | 1 | czn-erp-db-proxy (PostgreSQL) |
| AWS | ElastiCache | 3 | czn-erp-redis (2 nodes, Redis 7.1), socia-cirevo-redis (1 node, Redis 7.0.7) |
| AWS | DynamoDB Table | 3 | Terraform lock tables |
| AWS | S3 Bucket | 19 | Frontend, uploads, generated content, terraform state, audit |
| AWS | CloudFront Distribution | 6 | cirevo.ai, czn-erp.cirevo.ai, socia.cirevo.ai, dev.aura.cirevo.ai, media.socia.cirevo.ai, assets |
| AWS | Route53 Hosted Zone | 5 | cirevo.ai (public), dummy.cool (public), 3x internal/private |
| AWS | SQS Queue | 2 | socia-cirevo-content-generation + DLQ |
| AWS | SNS Topic | 2 | czn-erp-alarms, socia-cirevo-alerts |
| AWS | Secrets Manager | 18 | DB credentials, API keys, JWT secrets, OAuth config |
| AWS | KMS Key | 11 | Encryption keys |

**Total Resources: 164**

---

## Network Topology

### VPC: czn-erp-vpc (vpc-09336a796e8689f86)

| Property | Value |
|---|---|
| CIDR | 10.0.0.0/16 |
| Environment | production |
| Managed By | terraform |
| Internet Gateway | igw-0892b062e83d7c446 |
| NAT Gateways | nat-0dd6222c7c105d74d (AZ-a, 63.178.75.249), nat-0bb69888d3cdeb678 (AZ-b, 18.159.165.251) |
| VPC Peerings | None |
| VPC Endpoints | 1 (Interface: vpce-svc-0873f9f22eaa8b151) |

| Subnet | CIDR | AZ | Type | Route to Internet |
|---|---|---|---|---|
| czn-erp-vpc-public-eu-central-1a | 10.0.1.0/24 | eu-central-1a | Public | via IGW |
| czn-erp-vpc-public-eu-central-1b | 10.0.2.0/24 | eu-central-1b | Public | via IGW |
| czn-erp-vpc-private-eu-central-1a | 10.0.10.0/24 | eu-central-1a | Private (App) | via NAT (AZ-a) |
| czn-erp-vpc-private-eu-central-1b | 10.0.11.0/24 | eu-central-1b | Private (App) | via NAT (AZ-b) |
| czn-erp-vpc-db-eu-central-1a | 10.0.20.0/24 | eu-central-1a | Private (Database) | No internet |
| czn-erp-vpc-db-eu-central-1b | 10.0.21.0/24 | eu-central-1b | Private (Database) | No internet |
| czn-erp-vpc-elasticache-eu-central-1a | 10.0.30.0/24 | eu-central-1a | Private (ElastiCache) | No internet |
| czn-erp-vpc-elasticache-eu-central-1b | 10.0.31.0/24 | eu-central-1b | Private (ElastiCache) | No internet |

### VPC: socia-cirevo-vpc (vpc-0889986dafdab822c)

| Property | Value |
|---|---|
| CIDR | 10.0.0.0/16 |
| Environment | dev |
| Managed By | Terragrunt |
| Internet Gateway | igw-060ea07d4c017a0f8 |
| NAT Gateways | nat-04c30a80849b29666 (AZ-a, 3.126.131.253) |
| VPC Peerings | None |

| Subnet | CIDR | AZ | Type | Route to Internet |
|---|---|---|---|---|
| socia-cirevo-vpc-public-eu-central-1a | 10.0.0.0/20 | eu-central-1a | Public | via IGW |
| socia-cirevo-vpc-public-eu-central-1b | 10.0.16.0/20 | eu-central-1b | Public | via IGW |
| socia-cirevo-vpc-private-eu-central-1a | 10.0.32.0/20 | eu-central-1a | Private | via NAT (AZ-a) |
| socia-cirevo-vpc-private-eu-central-1b | 10.0.48.0/20 | eu-central-1b | Private | via NAT (AZ-a) |

### VPC: default (vpc-05df3888666461210)

| Property | Value |
|---|---|
| CIDR | 172.31.0.0/16 |
| Type | Default VPC |
| Internet Gateway | igw-0c97fd882c3d303c4 |

| Subnet | CIDR | AZ | Type |
|---|---|---|---|
| (default) | 172.31.16.0/20 | eu-central-1a | Public (default) |
| (default) | 172.31.32.0/20 | eu-central-1b | Public (default) |
| (default) | 172.31.0.0/20 | eu-central-1c | Public (default) |

---

## ECS Services Detail

### Cluster: czn-erp (24 Fargate tasks, 13 services)

| Service | Type |
|---|---|
| auth | Authentication |
| gateway | API Gateway |
| core | Core Business Logic |
| finance | Financial Management |
| hr | Human Resources |
| kitchen | Kitchen Management |
| pos | Point of Sale |
| procurement | Procurement |
| reporting | Reporting |
| reservation | Reservations |
| websocket | WebSocket Server |
| workflow | Workflow Engine |
| migration | Database Migrations |

### Cluster: socia-cirevo-dev (11 Fargate tasks, 11 services)

| Service | Type |
|---|---|
| socia-cirevo-dev-api | Main API |
| socia-cirevo-dev-auth | Authentication |
| socia-cirevo-dev-worker | Background Worker |
| socia-cirevo-dev-worker-beat | Scheduled Tasks |
| socia-cirevo-gateway | API Gateway |
| socia-cirevo-media | Media Processing |
| socia-cirevo-payment | Payment Processing |
| socia-cirevo-social-tracker-api | Social Tracker API |
| socia-cirevo-social-tracker-worker | Social Tracker Worker |
| socia-cirevo-social-tracker-beat | Social Tracker Scheduler |
| socia-cirevo-social-tracker-analysis-worker | Social Analysis Worker |

---

## Load Balancer Topology

| Load Balancer | Type | Scheme | VPC | Subnets | Target Groups |
|---|---|---|---|---|---|
| czn-erp-alb | ALB | internet-facing | czn-erp-vpc | public-1a, public-1b | czn-erp-gateway (HTTP:3000), czn-erp-gateway-green (HTTP:3000), czn-erp-websocket (HTTP:3005) |
| socia-cirevo-dev-alb | ALB | internet-facing | socia-cirevo-vpc | public-1a, public-1b | sc-gateway-tg (HTTP:80) |
| sc-int-alb | ALB | internal | socia-cirevo-vpc | private-1a, private-1b | sc-api-int-tg (HTTP:8000), sc-auth-int-tg (HTTP:3002), sc-media-int-tg (HTTP:8001), sc-pay-int-tg (HTTP:8003), sc-st-int-tg (HTTP:8002) |

---

## Database Topology

| Database | Engine | Class | Storage | Multi-AZ | VPC | Subnets | Proxy |
|---|---|---|---|---|---|---|---|
| czn-erp-db | PostgreSQL 16.10 | db.t4g.micro | 150 GB | Yes | czn-erp-vpc | db-1a, db-1b | czn-erp-db-proxy |
| socia-cirevo-dev-postgres | PostgreSQL 15.17 | db.t3.micro | 20 GB | No | socia-cirevo-vpc | private-1a, private-1b | None |

| Cache | Engine | Node Type | Nodes | VPC |
|---|---|---|---|---|
| czn-erp-redis | Redis 7.1.0 | cache.t4g.micro | 2 | czn-erp-vpc (elasticache subnets) |
| socia-cirevo-redis | Redis 7.0.7 | cache.t3.micro | 1 | socia-cirevo-vpc |

---

## CDN & DNS Topology

| CloudFront Distribution | Domain | Origin | Aliases |
|---|---|---|---|
| E1MAO93N7THKA6 | drkyi6edk62vv.cloudfront.net | cirevo.ai (S3) | cirevo.ai |
| E2XCJIQPPSXYK5 | d10mdogqsdmwlq.cloudfront.net | cirevo-assets S3 | (none) |
| E24FZ8OW8NUN1C | d35x9cb7liakyk.cloudfront.net | multi-agent-social-dev-frontend S3 | dev.aura.cirevo.ai |
| E34XVWZV3784K2 | d3if4mkz9fc3ho.cloudfront.net | czn-erp-alb + czn-erp-frontend S3 | czn-erp.cirevo.ai |
| EY3QTGUKOQRAV | d2tm4mx4p45zgp.cloudfront.net | socia-cirevo-frontend S3 | socia.cirevo.ai |
| E1XC1787UPRO3L | d3bikl9cx2t6r9.cloudfront.net | socia-cirevo-generated S3 | media.socia.cirevo.ai |

| Hosted Zone | Domain | Type | Records |
|---|---|---|---|
| Z06746631IWDPRKM8M67G | cirevo.ai | Public | 37 |
| Z0407241941RLCJFW0OJ | dummy.cool | Public | 15 |
| Z06287601CREF2ZPI85DZ | internal.cirevo.local | Private | 6 |
| Z02183001L99YS3W6BEGJ | app.local | Private (Cloud Map) | 26 |
| Z06267822FWKPFTXDGQT7 | internal.cirevo.local | Private | 7 |

---

## Security Observations

| # | Observation | Severity | Resource |
|---|---|---|---|
| 1 | Security groups launch-wizard-1, launch-wizard-2, launch-wizard-3 allow SSH (port 22) from 0.0.0.0/0 | HIGH | sg-03fd208a393adbdd9, sg-0268e0df7feb1fedc, sg-079685e5deb59b59c |
| 2 | Security groups launch-wizard-* also allow HTTP (80) and HTTPS (443) from 0.0.0.0/0 | MEDIUM | sg-03fd208a393adbdd9, sg-0268e0df7feb1fedc, sg-079685e5deb59b59c |
| 3 | S3 bucket "cirevo.ai" has no public access block configured (all 4 settings are False) | HIGH | cirevo.ai |
| 4 | socia-cirevo-dev-postgres is single-AZ (no Multi-AZ) -- risk of AZ failure for dev | LOW | socia-cirevo-dev-postgres |
| 5 | czn-erp-db uses db.t4g.micro for production (150GB storage) -- may be undersized | MEDIUM | czn-erp-db |
| 6 | Default VPC is still present and has an active Internet Gateway | LOW | vpc-05df3888666461210 |
| 7 | Both czn-erp-vpc and socia-cirevo-vpc use overlapping CIDR 10.0.0.0/16 -- prevents VPC peering | MEDIUM | vpc-09336a796e8689f86, vpc-0889986dafdab822c |
| 8 | No EKS clusters found in account (gradyent-prod EKS referenced in config is not in this account) | INFO | N/A |
| 9 | ALB security groups (czn-erp-alb-sg, socia-cirevo-alb-sg) correctly allow only 80/443 from 0.0.0.0/0 | INFO | sg-091a9b451df85f54f, sg-0f6366f739c3e125e |
| 10 | socia-cirevo private subnets in both AZs route through single NAT Gateway (AZ-a) -- AZ failure risk | MEDIUM | nat-04c30a80849b29666 |
| 11 | Stopped EC2 instance "test" in default VPC with launch-wizard SG (SSH open) | LOW | i-0a59077c9cb14ae90 |
| 12 | Duplicate private hosted zones for "internal.cirevo.local" | LOW | Z06287601CREF2ZPI85DZ, Z06267822FWKPFTXDGQT7 |
| 13 | Blue/green deployment configured for czn-erp (gateway + gateway-green target groups) | INFO | czn-erp-alb |
| 14 | ECS tasks run on Fargate (serverless) -- no EC2 instances to patch | INFO | czn-erp, socia-cirevo-dev-cluster |

---

## Architecture Summary

This AWS account hosts two primary applications:

1. **czn-erp** (Production): A restaurant/hospitality ERP system with 13 microservices running on ECS Fargate. Uses PostgreSQL (Multi-AZ) with RDS Proxy, Redis cluster (2 nodes), and is fronted by CloudFront + ALB. Managed by Terraform.

2. **socia-cirevo** (Dev): A social media management platform with 11 microservices on ECS Fargate. Uses PostgreSQL (single-AZ), Redis (1 node), and has both internet-facing and internal ALBs. Managed by Terragrunt.

Both applications use the cirevo.ai domain with CloudFront distributions serving static frontends and ALBs handling API traffic. Service discovery is handled via AWS Cloud Map (app.local hosted zone).

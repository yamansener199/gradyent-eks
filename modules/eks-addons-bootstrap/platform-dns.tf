# Route 53 alias for Argo CD once the ALB exists (external-dns also manages this when it can reach Route 53 API).
data "aws_route53_zone" "platform" {
  count = var.bootstrap_ingress_dns_before_argocd ? 1 : 0

  name         = var.platform_domain
  private_zone = false
}

resource "null_resource" "argocd_platform_dns" {
  count = var.bootstrap_ingress_dns_before_argocd ? 1 : 0

  depends_on = [
    helm_release.argocd,
    helm_release.cilium_bootstrap,
    aws_acm_certificate_validation.platform,
  ]

  triggers = {
    zone_id      = data.aws_route53_zone.platform[0].zone_id
    hostname     = "argocd.${var.platform_domain}"
    cluster_name = var.cluster_name
    aws_region   = var.aws_region
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      aws eks update-kubeconfig --name "${var.cluster_name}" --region "${var.aws_region}" >/dev/null
      HOSTNAME="argocd.${var.platform_domain}"
      ZONE_ID="${data.aws_route53_zone.platform[0].zone_id}"
      ALB_DNS=""
      for _ in $(seq 1 90); do
        ALB_DNS=$(kubectl get ingress argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
        [[ -n "$ALB_DNS" ]] && break
        sleep 10
      done
      if [[ -z "$ALB_DNS" ]]; then
        echo "Timed out waiting for argocd-server Ingress load balancer hostname" >&2
        exit 1
      fi
      LB_ZONE=$(aws elbv2 describe-load-balancers --region "${var.aws_region}" \
        --query "LoadBalancers[?DNSName=='$ALB_DNS'].CanonicalHostedZoneId | [0]" --output text)
      aws route53 change-resource-record-sets --hosted-zone-id "$ZONE_ID" --change-batch "$(cat <<EOF
{
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "$HOSTNAME",
      "Type": "A",
      "AliasTarget": {
        "HostedZoneId": "$LB_ZONE",
        "DNSName": "dualstack.$ALB_DNS.",
        "EvaluateTargetHealth": true
      }
    }
  }]
}
EOF
)"
      echo "Route 53 alias $HOSTNAME -> $ALB_DNS"
    EOT
  }
}

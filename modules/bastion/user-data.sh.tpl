#!/bin/bash
set -euo pipefail

dnf install -y jq git

# AWS CLI v2 (AL2023 minimal may already include aws cli)
if ! command -v aws &>/dev/null; then
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
  unzip -q /tmp/awscliv2.zip -d /tmp
  /tmp/aws/install
fi

# kubectl matching cluster version
K8S_VERSION="${eks_version}"
curl -fsSL -o /usr/local/bin/kubectl \
  "https://dl.k8s.io/release/v$${K8S_VERSION}.0/bin/linux/amd64/kubectl"
chmod +x /usr/local/bin/kubectl

mkdir -p /etc/profile.d
cat >/etc/profile.d/gradyent-bastion.sh <<EOF
export AWS_REGION="${aws_region}"
export CLUSTER_NAME="${cluster_name}"
alias k='kubectl'
EOF

cat >/usr/local/bin/update-eks-kubeconfig <<'SCRIPT'
#!/bin/bash
set -euo pipefail
: "$${AWS_REGION:?}"
: "$${CLUSTER_NAME:?}"
aws eks update-kubeconfig --region "$${AWS_REGION}" --name "$${CLUSTER_NAME}"
SCRIPT
chmod +x /usr/local/bin/update-eks-kubeconfig

/usr/local/bin/update-eks-kubeconfig || true

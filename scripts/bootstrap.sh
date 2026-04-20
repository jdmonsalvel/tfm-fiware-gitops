#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
err() { echo "[ERROR] $*" >&2; exit 1; }

command -v terraform &>/dev/null || err "terraform not found"
command -v kubectl   &>/dev/null || err "kubectl not found"
command -v helm      &>/dev/null || err "helm not found"
command -v aws       &>/dev/null || err "aws-cli not found"

AWS_REGION="${AWS_REGION:-eu-west-1}"
TF_DIR="${REPO_ROOT}/infrastructure/terraform"

log "=== FASE 1: Terraform — VPC + EKS ==="
cd "$TF_DIR"
terraform init \
  -backend-config="region=${AWS_REGION}"
terraform apply -auto-approve -var="aws_region=${AWS_REGION}"

CLUSTER_NAME=$(terraform output -raw cluster_name)
log "Cluster creado: ${CLUSTER_NAME}"

log "=== Configurando kubectl ==="
aws eks update-kubeconfig --region "${AWS_REGION}" --name "${CLUSTER_NAME}"
kubectl cluster-info

log "=== FASE 2: Bootstrap namespaces ==="
kubectl apply -f "${REPO_ROOT}/gitops/bootstrap/argocd-namespace.yaml"

log "=== FASE 3: Instalando ArgoCD ==="
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --version '7.*.*' \
  --wait --timeout 10m

log "Esperando a que ArgoCD esté listo..."
kubectl wait --for=condition=available deployment/argocd-server \
  --namespace argocd --timeout=300s

log "=== FASE 4: Desplegando App of Apps ==="
EXTERNAL_SECRETS_ROLE_ARN=$(cd "$TF_DIR" && terraform output -raw external_secrets_role_arn)
sed -i "s|PLACEHOLDER_EXTERNAL_SECRETS_ROLE_ARN|${EXTERNAL_SECRETS_ROLE_ARN}|g" \
  "${REPO_ROOT}/gitops/apps/external-secrets/application.yaml"

kubectl apply -f "${REPO_ROOT}/gitops/bootstrap/app-of-apps.yaml"

log "=== Bootstrap completado ==="
log "ArgoCD UI: kubectl port-forward svc/argocd-server -n argocd 8080:443"
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
log "ArgoCD admin password: ${ARGOCD_PASSWORD}"

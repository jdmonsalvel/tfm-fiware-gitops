#!/usr/bin/env bash
# bootstrap.sh — Capa 2: instala addons Helm en un cluster EKS ya provisionado
#
# Uso: bootstrap.sh <cluster_name> <bootstrap_dir> <tfvars_json>
#
# Prerrequisitos:
#   - terraform >= 1.5.0 en PATH
#   - aws cli >= 2.x configurado con permisos sobre el cluster
#   - kubectl en PATH

set -euo pipefail

CLUSTER_NAME="${1:?cluster_name requerido}"
BOOTSTRAP_DIR="${2:?bootstrap_dir requerido}"
TFVARS_JSON="${3:?tfvars_json requerido}"

log() { echo "[bootstrap] $*" >&2; }

# ── Extrae valores del tfvars JSON ───────────────────────────────────────────
CLUSTER_REGION=$(jq -r '.cluster_region'   "$TFVARS_JSON")
CLUSTER_ENDPOINT=$(jq -r '.cluster_endpoint' "$TFVARS_JSON")
BACKEND_BUCKET=$(jq -r '.backend_bucket'   "$TFVARS_JSON")
BACKEND_REGION=$(jq -r '.backend_region'   "$TFVARS_JSON")
ASSUME_ROLE=$(jq -r '.assume_role_arn // ""' "$TFVARS_JSON")

log "Cluster: ${CLUSTER_NAME} | Región: ${CLUSTER_REGION}"
log "Bootstrap dir: ${BOOTSTRAP_DIR}"

# ── Actualiza kubeconfig ─────────────────────────────────────────────────────
log "Actualizando kubeconfig..."
if [[ -n "$ASSUME_ROLE" ]]; then
  aws eks update-kubeconfig \
    --name "$CLUSTER_NAME" \
    --region "$CLUSTER_REGION" \
    --role-arn "$ASSUME_ROLE" \
    --alias "$CLUSTER_NAME" 2>/dev/null || true
else
  aws eks update-kubeconfig \
    --name "$CLUSTER_NAME" \
    --region "$CLUSTER_REGION" \
    --alias "$CLUSTER_NAME" 2>/dev/null || true
fi

# ── Espera a que los nodos estén Ready ───────────────────────────────────────
log "Esperando nodos Ready (timeout 10 min)..."
TIMEOUT=600
ELAPSED=0
until kubectl get nodes --context="$CLUSTER_NAME" 2>/dev/null | grep -q " Ready"; do
  if [[ $ELAPSED -ge $TIMEOUT ]]; then
    log "ERROR: Timeout esperando nodos Ready"
    exit 1
  fi
  sleep 15
  ELAPSED=$((ELAPSED + 15))
done
log "Nodos Ready."

# ── Backend remoto para el state del bootstrap ───────────────────────────────
BACKEND_KEY="eks-bootstrap/${CLUSTER_NAME}/terraform.tfstate"

# ── Terraform init ───────────────────────────────────────────────────────────
log "Inicializando módulo bootstrap..."
terraform -chdir="$BOOTSTRAP_DIR" init \
  -backend-config="bucket=${BACKEND_BUCKET}" \
  -backend-config="key=${BACKEND_KEY}" \
  -backend-config="region=${BACKEND_REGION}" \
  -reconfigure \
  -input=false \
  -no-color 1>&2

# ── Terraform apply ──────────────────────────────────────────────────────────
log "Aplicando addons (Capa 2)..."
terraform -chdir="$BOOTSTRAP_DIR" apply \
  -var-file="$TFVARS_JSON" \
  -auto-approve \
  -input=false \
  -no-color 1>&2

log "Bootstrap completado para cluster: ${CLUSTER_NAME}"

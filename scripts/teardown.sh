#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
TF_DIR="${REPO_ROOT}/infrastructure/terraform"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
err() { echo "[ERROR] $*" >&2; exit 1; }

if [[ "${FORCE_TEARDOWN:-false}" != "true" ]]; then
  echo "ADVERTENCIA: Esto destruirá TODA la infraestructura AWS del TFM."
  echo "Para continuar, ejecuta: FORCE_TEARDOWN=true ./scripts/teardown.sh"
  exit 1
fi

log "=== Eliminando aplicaciones ArgoCD (evitar race conditions) ==="
kubectl delete application --all -n argocd --ignore-not-found=true || true
kubectl delete namespace fiware monitoring platform --ignore-not-found=true || true
sleep 30

log "=== Terraform Destroy ==="
cd "$TF_DIR"
terraform destroy -auto-approve

log "=== Teardown completado. Coste AWS detenido. ==="

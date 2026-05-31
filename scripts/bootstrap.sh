#!/usr/bin/env bash
# bootstrap.sh — Instala ArgoCD y despliega el App of Apps en el clúster EKS.
# Prerrequisito: kubectl configurado con acceso al clúster.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
log() { echo "[$(date '+%H:%M:%S')] $*"; }
err() { echo "[ERROR] $*" >&2; exit 1; }

command -v kubectl &>/dev/null || err "kubectl no encontrado"
command -v helm    &>/dev/null || err "helm no encontrado"

# ─── Verificar conectividad al clúster ────────────────────────────────────────
log "Verificando conexión al clúster..."
kubectl cluster-info --request-timeout=10s > /dev/null 2>&1 || err "kubectl no puede conectar al clúster. Ejecuta: aws eks update-kubeconfig --name tfm-dev-fiware-gitops --region eu-west-1"

# ─── Instalar ArgoCD ──────────────────────────────────────────────────────────
log "Instalando ArgoCD..."
helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
helm repo update argo

helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --version "7.*" \
  --set server.service.type=ClusterIP \
  --wait --timeout 8m

log "Esperando deployment argocd-server..."
kubectl wait --for=condition=available deployment/argocd-server \
  --namespace argocd --timeout=300s

# ─── App of Apps ──────────────────────────────────────────────────────────────
log "Aplicando App of Apps..."
kubectl apply -f "${REPO_ROOT}/gitops/app-of-apps.yaml"

log "=== Bootstrap completado ==="
echo ""
echo "  ArgoCD UI (local):   kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  URL:                 https://localhost:8080"
echo "  Usuario:             admin"
echo "  Password:            $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo 'ver: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath={.data.password} | base64 -d')"
echo ""
echo "  Sigue la sincronización: kubectl get applications -n argocd -w"

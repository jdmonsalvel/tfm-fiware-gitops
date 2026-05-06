#!/usr/bin/env bash
# Bootstrap completo del entorno LOCAL (kind) para la demo del TFM.
# Independiente del scripts/bootstrap.sh (AWS/EKS).
#
# Prerequisitos: kind, helm, kubectl
# Uso: bash scripts/bootstrap-kind.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER_NAME="fiware-gitops"
ARGOCD_NS="argocd"

log()  { echo "[$(date +%H:%M:%S)] $*"; }
step() { echo ""; echo "=========================================="; echo "  $*"; echo "=========================================="; }

command -v kind    &>/dev/null || { echo "ERROR: kind no encontrado"; exit 1; }
command -v kubectl &>/dev/null || { echo "ERROR: kubectl no encontrado"; exit 1; }
command -v helm    &>/dev/null || { echo "ERROR: helm no encontrado"; exit 1; }

# -- 1. Cluster kind ----------------------------------------------------------
step "1/5 Cluster kind '${CLUSTER_NAME}'"
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  log "Cluster ya existe, omitiendo creacion."
else
  kind create cluster \
    --name "${CLUSTER_NAME}" \
    --config "${REPO_ROOT}/kind/cluster-config.yaml"
fi
kubectl config use-context "kind-${CLUSTER_NAME}"
kubectl wait --for=condition=Ready node --all --timeout=120s
log "Nodos listos: $(kubectl get nodes --no-headers | wc -l)"

# -- 2. NGINX Ingress Controller ----------------------------------------------
step "2/5 NGINX Ingress Controller (hostPort 80/443)"
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
helm repo update ingress-nginx
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=NodePort \
  --set controller.hostPort.enabled=true \
  --set controller.hostPort.ports.http=80 \
  --set controller.hostPort.ports.https=443 \
  --set 'controller.nodeSelector.ingress-ready=true' \
  --set 'controller.tolerations[0].key=node-role.kubernetes.io/control-plane' \
  --set 'controller.tolerations[0].operator=Equal' \
  --set 'controller.tolerations[0].effect=NoSchedule' \
  --wait --timeout=5m
log "NGINX ingress listo."

# -- 3. ArgoCD ----------------------------------------------------------------
step "3/5 ArgoCD (namespace: ${ARGOCD_NS})"
helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
helm repo update argo
helm upgrade --install argocd argo/argo-cd \
  --namespace "${ARGOCD_NS}" --create-namespace \
  --set server.insecure=true \
  --set 'server.ingress.enabled=true' \
  --set 'server.ingress.ingressClassName=nginx' \
  --set 'server.ingress.hosts[0]=argocd.127.0.0.1.nip.io' \
  --wait --timeout=5m
log "ArgoCD listo."

# -- 4. K8s Secrets (fuera de Git) --------------------------------------------
step "4/5 Secrets (no gestionados por GitOps)"
bash "${REPO_ROOT}/scripts/create-secrets.sh"

# -- 5. App of Apps -----------------------------------------------------------
step "5/5 App of Apps -> ArgoCD sincroniza FIWARE"
kubectl apply -f "${REPO_ROOT}/gitops/apps/app-of-apps.yaml"

# -- Resumen ------------------------------------------------------------------
PASS=$(kubectl -n "${ARGOCD_NS}" get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" 2>/dev/null | base64 -d \
  || echo "<ver: kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d>")

echo ""
echo "======================================================"
echo "  Bootstrap local completado"
echo "======================================================"
echo "  ArgoCD UI:   http://argocd.127.0.0.1.nip.io"
echo "  Usuario:     admin"
echo "  Contrasena:  ${PASS}"
echo ""
echo "  Monitoriza la sincronizacion:"
echo "    watch kubectl get applications -n argocd"
echo ""
echo "  URLs FIWARE (disponibles tras Healthy):"
echo "    Keyrock:  http://keyrock.127.0.0.1.nip.io"
echo "    TIL:      http://til.127.0.0.1.nip.io"
echo "    Orion-LD: http://orion.127.0.0.1.nip.io"
echo ""
echo "  Smoke test E2E:"
echo "    bash tests/smoke-test.sh"
echo "======================================================"

#!/usr/bin/env bash
# Pre-crea K8s Secrets para la demo local.
# IMPORTANTE: Las contraseñas NUNCA van en Git.
# En AWS (fase 2): estos valores los inyecta External Secrets Operator
# desde AWS Secrets Manager bajo el prefijo /fiware/.
set -euo pipefail

log() { echo "[secrets] $*"; }

log "Creando namespaces..."
kubectl create namespace trust-anchor --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace provider     --dry-run=client -o yaml | kubectl apply -f -

# ── trust-anchor ─────────────────────────────────────────────────────────────
log "MySQL credentials (trust-anchor)..."
# bitnami/mysql espera: mysql-root-password, mysql-password
kubectl create secret generic mysql-credentials \
  --namespace trust-anchor \
  --from-literal=mysql-root-password=rootTfm2026! \
  --from-literal=mysql-password=keyrockTfm2026! \
  --dry-run=client -o yaml | kubectl apply -f -

log "Keyrock credentials (trust-anchor)..."
# fiware/keyrock espera: dbPassword, adminPassword
kubectl create secret generic keyrock-credentials \
  --namespace trust-anchor \
  --from-literal=dbPassword=keyrockTfm2026! \
  --from-literal=adminPassword=adminTfm2026! \
  --dry-run=client -o yaml | kubectl apply -f -

log "Secretos creados correctamente."
log "  Namespace trust-anchor: mysql-credentials, keyrock-credentials"
log "  Namespace provider:      (sin secretos en fase local — MongoDB sin auth)"

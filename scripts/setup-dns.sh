#!/bin/bash
# setup-dns.sh — Obtiene el hostname del NLB de ingress-nginx y actualiza
# el tfvars + aplica terraform para crear los registros CNAME en Cloudflare.
#
# Uso: bash scripts/setup-dns.sh <fw_dir> <tfvars_path>
#   fw_dir       — directorio del framework clonado (con .terraform/ inicializado)
#   tfvars_path  — ruta al terraform.tfvars

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[dns]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[dns]${NC} $1"; }
log_error() { echo -e "${RED}[dns]${NC} $1" >&2; }

FW_DIR="${1:?Uso: $0 <fw_dir> <tfvars_path>}"
TFVARS="${2:?Uso: $0 <fw_dir> <tfvars_path>}"

# ─── Obtener hostname NLB ─────────────────────────────────────────────────────
log_info "Obteniendo hostname del NLB desde ingress-nginx..."

NLB_HOSTNAME=""
for i in $(seq 1 24); do
    NLB_HOSTNAME=$(kubectl get svc ingress-nginx-controller \
        -n platform \
        -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    [ -n "$NLB_HOSTNAME" ] && [ "$NLB_HOSTNAME" != "null" ] && break
    log_warn "NLB aún no disponible, intento $i/24 — esperando 10s..."
    sleep 10
done

[ -z "$NLB_HOSTNAME" ] && {
    log_error "NLB hostname no disponible. Verifica que ingress-nginx esté desplegado:"
    log_error "  kubectl get svc -n platform ingress-nginx-controller"
    exit 1
}

log_info "NLB hostname: $NLB_HOSTNAME"

# ─── Actualizar tfvars con el hostname real ───────────────────────────────────
log_info "Actualizando tfvars..."
sed -i "s|PLACEHOLDER_NLB_HOSTNAME|${NLB_HOSTNAME}|g" "$TFVARS"

# ─── Aplicar Terraform (solo módulo cloudflare_dns) ──────────────────────────
log_info "Aplicando registros DNS en Cloudflare..."
cd "$FW_DIR"
AWS_PROFILE="${AWS_PROFILE:-tfm-account-lab}" \
TF_VAR_account_id="${TF_VAR_account_id:-$(aws sts get-caller-identity --query Account --output text)}" \
TF_VAR_cloudflare_api_token="${TF_VAR_cloudflare_api_token:-${CLOUDFLARE_PERSONAL_ACCESS_TOKEN:-}}" \
terraform apply \
    -var-file="$TFVARS" \
    -target='module.cloudflare_dns[0]' \
    -auto-approve

log_info "Registros DNS creados en Cloudflare."
log_info ""
log_info "Subdominios activos:"
for sub in keyrock orion til tir ccs; do
    echo "  https://${sub}.lab-jdmonsalvel.com → $NLB_HOSTNAME"
done
log_info ""
log_info "cert-manager emitirá los certificados TLS en 1-3 min (Cloudflare DNS-01)."

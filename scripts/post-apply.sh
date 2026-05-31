#!/bin/bash
# post-apply.sh — Actualiza ARNs IRSA en values files y crea secretos en Secrets Manager.
# Ejecutar desde el directorio del framework clonado, tras terraform apply.
#
# Uso: bash <gitops_root>/scripts/post-apply.sh <gitops_root> <region>

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[post-apply]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[post-apply]${NC} $1"; }
log_error() { echo -e "${RED}[post-apply]${NC} $1" >&2; }

[ $# -ne 2 ] && { log_error "Uso: $0 <gitops_root> <region>"; exit 1; }
GITOPS_ROOT="$1"
REGION="$2"

# ─── Leer ARN IRSA de external-secrets desde el bootstrap generado ────────────
# El framework escribe modules/aws/eks/bootstrap/generated/<cluster>.tfvars.json
# con todos los IRSA ARNs después del apply.
BOOTSTRAP_JSON=$(find modules/aws/eks/bootstrap/generated -name "*.tfvars.json" | head -1)

if [ -z "$BOOTSTRAP_JSON" ]; then
    log_error "No se encontró bootstrap tfvars.json en modules/aws/eks/bootstrap/generated/"
    log_error "Verifica que terraform apply completó correctamente."
    exit 1
fi

log_info "Leyendo ARNs desde $BOOTSTRAP_JSON..."
ESO_ARN=$(python3 -c "
import json, sys
with open('$BOOTSTRAP_JSON') as f:
    data = json.load(f)
print(data.get('irsa_roles', {}).get('external_secrets', ''))
")

if [ -z "$ESO_ARN" ] || [ "$ESO_ARN" = "None" ]; then
    log_error "irsa_roles.external_secrets no encontrado en $BOOTSTRAP_JSON"
    cat "$BOOTSTRAP_JSON" | python3 -m json.tool | grep -A2 "irsa" || true
    exit 1
fi

log_info "ESO IRSA ARN: $ESO_ARN"

# ─── Actualizar values file de external-secrets ───────────────────────────────
ESO_VALUES="$GITOPS_ROOT/gitops/values/platform/external-secrets.yaml"
log_info "Actualizando $ESO_VALUES..."
sed -i "s|PLACEHOLDER_EXTERNAL_SECRETS_ROLE_ARN|${ESO_ARN}|g" "$ESO_VALUES"

# ─── Crear secretos en Secrets Manager si no existen ─────────────────────────
log_info "Verificando secretos en Secrets Manager ($REGION)..."

create_secret_if_missing() {
    local name="$1" value="$2" desc="$3"
    if aws secretsmanager describe-secret --secret-id "$name" --region "$REGION" &>/dev/null; then
        log_info "  $name — ya existe"
    else
        log_info "  $name — creando..."
        aws secretsmanager create-secret \
            --region "$REGION" \
            --name "$name" \
            --description "$desc" \
            --secret-string "{\"password\":\"${value}\"}" \
            --tags Key=ManagedBy,Value=terraform Key=Project,Value=tfm
    fi
}

create_secret_if_missing "/fiware/keyrock/admin-password" "adminTfm2026!"   "Keyrock admin password"
create_secret_if_missing "/fiware/keyrock/db-password"    "keyrockTfm2026!" "Keyrock MySQL user password"
create_secret_if_missing "/fiware/mysql/root-password"    "rootTfm2026!"    "MySQL root password"
create_secret_if_missing "/fiware/mongodb/root-password"  "mongoTfm2026!"   "MongoDB root password"

# ─── Commit y push del values file con ARN real ──────────────────────────────
log_info "Committing updated IRSA ARN..."
cd "$GITOPS_ROOT"
git config user.email "ci@github.com"
git config user.name "GitHub Actions"
git add gitops/values/platform/external-secrets.yaml
if git diff --cached --quiet; then
    log_info "Sin cambios (ARN ya actualizado)."
else
    git commit -m "chore(gitops): update external-secrets IRSA ARN [skip ci]"
    git push origin HEAD
    log_info "Pusheado. ArgoCD sincronizará en < 3 min."
fi

log_info "post-apply completado correctamente."

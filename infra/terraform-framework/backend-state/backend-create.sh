#!/bin/bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }

# ─── Argumentos ───────────────────────────────────────────────────────────────
# Uso:  backend-create.sh <profile> <tfvars> [destroy]
# No se usa DynamoDB — locking no necesario para lab de un solo operador.
if [ $# -lt 2 ] || [ $# -gt 3 ]; then
    log_error "Uso: $0 <aws-profile> <tfvars-file> [destroy]"
    exit 1
fi

PROFILE="$1"
TFVARS_FILE="$2"
ACTION="${3:-}"

if [ ! -f "$TFVARS_FILE" ]; then
    log_error "Fichero no encontrado: $TFVARS_FILE"
    exit 1
fi

# ─── Extraer variables del tfvars ─────────────────────────────────────────────
extract_var() {
    grep "^$1" "$TFVARS_FILE" | sed 's/.*=\s*"\(.*\)".*/\1/'
}

ACCOUNT_ID=$(extract_var "account_id")
REGION=$(extract_var "region")
ENVIRONMENT=$(extract_var "environment")
PROJECT=$(extract_var "project")

if [ -z "$ACCOUNT_ID" ] || [ -z "$REGION" ] || [ -z "$ENVIRONMENT" ] || [ -z "$PROJECT" ]; then
    log_error "Faltan variables obligatorias en $TFVARS_FILE (account_id, region, environment, project)"
    exit 1
fi

# Verificar credenciales
CALLER_ACCOUNT=$(aws sts get-caller-identity --profile "$PROFILE" --query Account --output text)
if [ "$CALLER_ACCOUNT" != "$ACCOUNT_ID" ]; then
    log_warn "El profile $PROFILE pertenece a la cuenta $CALLER_ACCOUNT, no a $ACCOUNT_ID definido en el tfvars."
    log_warn "Continuando con la cuenta real del profile: $CALLER_ACCOUNT"
    ACCOUNT_ID="$CALLER_ACCOUNT"
fi

BUCKET_NAME="devops-${ACCOUNT_ID}-terraform-state-bucket"
STATE_KEY="${ACCOUNT_ID}/terraform-aws-${PROJECT}-${ENVIRONMENT}-${REGION}.tfstate"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_TF="${SCRIPT_DIR}/../backend.tf"

log_info "Profile:     $PROFILE"
log_info "Account ID:  $ACCOUNT_ID"
log_info "Region:      $REGION"
log_info "Bucket:      $BUCKET_NAME"
log_info "State key:   $STATE_KEY"

# ─── Destroy ──────────────────────────────────────────────────────────────────
if [ "$ACTION" = "destroy" ]; then
    log_warn "Modo destroy — se eliminarán el state S3 y sus versiones."
    read -rp "¿Confirmas? Escribe 'yes': " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        log_warn "Abortado."
        exit 0
    fi

    # Eliminar objeto de state y todas sus versiones
    BUCKET_EXISTS=$(aws s3 ls --profile "$PROFILE" | grep "$BUCKET_NAME" | awk '{print $3}' || true)
    if [ -n "$BUCKET_EXISTS" ]; then
        log_info "Eliminando state: s3://$BUCKET_NAME/$STATE_KEY"
        aws s3 rm "s3://$BUCKET_NAME/$STATE_KEY" --profile "$PROFILE" || true

        mapfile -t VERSIONS < <(
            aws s3api list-object-versions \
                --bucket "$BUCKET_NAME" --prefix "$STATE_KEY" \
                --profile "$PROFILE" \
                --query 'Versions[].VersionId' --output text 2>/dev/null \
            | tr '\t' '\n' | grep -v '^$' || true
        )
        mapfile -t MARKERS < <(
            aws s3api list-object-versions \
                --bucket "$BUCKET_NAME" --prefix "$STATE_KEY" \
                --profile "$PROFILE" \
                --query 'DeleteMarkers[].VersionId' --output text 2>/dev/null \
            | tr '\t' '\n' | grep -v '^$' || true
        )

        for VID in "${VERSIONS[@]:-}" "${MARKERS[@]:-}"; do
            [ -n "$VID" ] && aws s3api delete-object \
                --bucket "$BUCKET_NAME" --key "$STATE_KEY" --version-id "$VID" \
                --profile "$PROFILE" || true
        done
        log_info "State eliminado."
    else
        log_warn "Bucket $BUCKET_NAME no encontrado."
    fi
    exit 0
fi

# ─── Setup: bucket S3 ─────────────────────────────────────────────────────────
BUCKET_EXISTS=$(aws s3 ls --profile "$PROFILE" | grep "$BUCKET_NAME" | awk '{print $3}' || true)

if [ -z "$BUCKET_EXISTS" ]; then
    log_info "Creando bucket S3: $BUCKET_NAME"
    if [ "$REGION" = "us-east-1" ]; then
        aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$REGION" \
            --profile "$PROFILE"
    else
        aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$REGION" \
            --create-bucket-configuration LocationConstraint="$REGION" \
            --profile "$PROFILE"
    fi
else
    log_info "Bucket ya existe: $BUCKET_NAME"
fi

log_info "Habilitando versionado..."
aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled \
    --profile "$PROFILE"

log_info "Habilitando cifrado AES-256..."
aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"},
            "BucketKeyEnabled": true
        }]
    }' \
    --profile "$PROFILE"

log_info "Bloqueando acceso público..."
aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration \
        BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true \
    --profile "$PROFILE"

# ─── Generar backend.tf ───────────────────────────────────────────────────────
log_info "Generando $BACKEND_TF"
cat > "$BACKEND_TF" <<EOF
terraform {
  backend "s3" {
    bucket  = "$BUCKET_NAME"
    key     = "$STATE_KEY"
    region  = "$REGION"
    encrypt = true
    # Sin DynamoDB — lab de un solo operador, locking no requerido
  }
}
EOF

log_info "Setup completado."
echo -e ""
echo -e "${GREEN}Resumen:${NC}"
echo -e "  Bucket S3:   s3://$BUCKET_NAME"
echo -e "  State key:   $STATE_KEY"
echo -e "  backend.tf:  $BACKEND_TF"
echo -e ""
echo -e "${YELLOW}Próximos pasos:${NC}"
echo -e "  1. Revisar backend.tf generado"
echo -e "  2. terraform init -backend-config='profile=$PROFILE'"
echo -e "  3. terraform plan -var-file=variables/aws-personal.tfvars"

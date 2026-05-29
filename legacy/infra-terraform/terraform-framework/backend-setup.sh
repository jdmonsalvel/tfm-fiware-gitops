#!/bin/bash
# backend-setup.sh — Configura el backend S3 y ejecuta terraform init.
#
# Modos de uso:
#
#   Cuenta única (personal / lab):
#     ./backend-setup.sh single <profile>
#     Crea manager-cicd-role y automate-cicd-role en la misma cuenta si no
#     existen, asume el chain y ejecuta terraform init.
#
#   Multi-cuenta (DevOps hub → cuenta destino):
#     ./backend-setup.sh multi <manager-profile> <managed-profile> <manager-account-id>
#     Asume el chain manager-cicd-role → automate-cicd-role entre cuentas.
#     Los roles deben existir previamente (crearlos con backend-state/backend-create.sh).
#
# En ambos modos:
#   - Sin DynamoDB (lab de un solo operador, locking no necesario).
#   - Selección interactiva del tfvars.
#   - Genera backend.tf y ejecuta terraform init.

set -euo pipefail

# ─── Colores ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

usage() {
    echo "Uso:"
    echo "  $0 single <profile>"
    echo "  $0 multi  <manager-profile> <managed-profile> <manager-account-id>"
    exit 1
}

# ─── Argumentos ───────────────────────────────────────────────────────────────
MODE="${1:-}"
if [ "$MODE" = "single" ]; then
    [ $# -ne 2 ] && usage
    MANAGER_PROFILE="$2"
    MANAGED_PROFILE="$2"
    SINGLE_ACCOUNT=true
elif [ "$MODE" = "multi" ]; then
    [ $# -ne 4 ] && usage
    MANAGER_PROFILE="$2"
    MANAGED_PROFILE="$3"
    MANAGER_ACCOUNT_ID_PARAM="$4"
    SINGLE_ACCOUNT=false
else
    usage
fi

# ─── Selección interactiva del tfvars ─────────────────────────────────────────
VARIABLES_DIR="variables"
[ ! -d "$VARIABLES_DIR" ] && { log_error "Directorio no encontrado: $VARIABLES_DIR"; exit 1; }

mapfile -t TFVARS_FILES < <(find "$VARIABLES_DIR" -maxdepth 1 -name "*.tfvars" -type f | sort)
[ ${#TFVARS_FILES[@]} -eq 0 ] && { log_error "No hay ficheros .tfvars en $VARIABLES_DIR"; exit 1; }

log_info "Ficheros tfvars disponibles:"
for i in "${!TFVARS_FILES[@]}"; do
    echo "  $((i+1))) $(basename "${TFVARS_FILES[$i]}" .tfvars)"
done

read -rp "Selecciona un fichero (número): " SELECTION
SELECTION=$((SELECTION - 1))
[[ "$SELECTION" -lt 0 || "$SELECTION" -ge "${#TFVARS_FILES[@]}" ]] && { log_error "Selección inválida"; exit 1; }

TFVARS_FILE="${TFVARS_FILES[$SELECTION]}"
log_info "Seleccionado: $TFVARS_FILE"

# ─── Extraer variables del tfvars ─────────────────────────────────────────────
extract_var() { grep "^$1" "$TFVARS_FILE" | sed 's/.*=\s*"\(.*\)".*/\1/'; }

ACCOUNT_ID=$(extract_var "account_id")
REGION=$(extract_var "region")
ENVIRONMENT=$(extract_var "environment")
PROJECT=$(extract_var "project")

[ -z "$ACCOUNT_ID" ] || [ -z "$REGION" ] || [ -z "$ENVIRONMENT" ] || [ -z "$PROJECT" ] && {
    log_error "Faltan variables en $TFVARS_FILE (account_id, region, environment, project)"
    exit 1
}

# En modo single el manager y el managed son la misma cuenta
if $SINGLE_ACCOUNT; then
    MANAGER_ACCOUNT_ID=$(aws sts get-caller-identity --profile "$MANAGER_PROFILE" --query Account --output text)
    # Verificar que el profile apunta a la cuenta del tfvars
    if [ "$MANAGER_ACCOUNT_ID" != "$ACCOUNT_ID" ]; then
        log_warn "El profile $MANAGER_PROFILE corresponde a la cuenta $MANAGER_ACCOUNT_ID"
        log_warn "El tfvars define account_id=$ACCOUNT_ID — usando la cuenta real del profile"
        ACCOUNT_ID="$MANAGER_ACCOUNT_ID"
    fi
else
    MANAGER_ACCOUNT_ID="$MANAGER_ACCOUNT_ID_PARAM"
    log_info "Manager account ID: $MANAGER_ACCOUNT_ID"
fi

log_info "Account ID (managed): $ACCOUNT_ID  |  Region: $REGION  |  Project: $PROJECT  |  Env: $ENVIRONMENT"

# ─── Bucket S3 ────────────────────────────────────────────────────────────────
BUCKET_NAME="devops-${MANAGER_ACCOUNT_ID}-terraform-state-bucket"
FOLDER_PATH="${ACCOUNT_ID}/terraform-aws-${PROJECT}-${ENVIRONMENT}-${REGION}"
STATE_KEY="${FOLDER_PATH}.tfstate"

log_info "Bucket S3: $BUCKET_NAME"

BUCKET_EXISTS=$(aws s3 ls --profile "$MANAGER_PROFILE" | awk '{print $3}' | grep "^${BUCKET_NAME}$" || true)
if [ -z "$BUCKET_EXISTS" ]; then
    log_info "Creando bucket..."
    if [ "$REGION" = "us-east-1" ]; then
        aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION" --profile "$MANAGER_PROFILE"
    else
        aws s3api create-bucket \
            --bucket "$BUCKET_NAME" --region "$REGION" \
            --create-bucket-configuration LocationConstraint="$REGION" \
            --profile "$MANAGER_PROFILE"
    fi
    aws s3api put-bucket-versioning \
        --bucket "$BUCKET_NAME" \
        --versioning-configuration Status=Enabled \
        --profile "$MANAGER_PROFILE"
    aws s3api put-bucket-encryption \
        --bucket "$BUCKET_NAME" \
        --server-side-encryption-configuration \
            '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]}' \
        --profile "$MANAGER_PROFILE"
    aws s3api put-public-access-block \
        --bucket "$BUCKET_NAME" \
        --public-access-block-configuration \
            BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true \
        --profile "$MANAGER_PROFILE"
    log_info "Bucket creado y configurado."
else
    log_info "Bucket ya existe."
fi

# ─── IAM roles ────────────────────────────────────────────────────────────────
# manager-cicd-role: se crea en la cuenta manager (o la única cuenta en single)
log_info "Verificando manager-cicd-role en cuenta $MANAGER_ACCOUNT_ID..."
ROLE_EXISTS=$(aws iam get-role --role-name manager-cicd-role --profile "$MANAGER_PROFILE" 2>/dev/null \
    | grep -c RoleName || true)

if [ "$ROLE_EXISTS" -eq 0 ]; then
    log_info "Creando manager-cicd-role..."
    aws iam create-role \
        --role-name manager-cicd-role \
        --profile "$MANAGER_PROFILE" \
        --assume-role-policy-document "{
          \"Version\": \"2012-10-17\",
          \"Statement\": [{
            \"Effect\": \"Allow\",
            \"Principal\": {\"AWS\": \"arn:aws:iam::${MANAGER_ACCOUNT_ID}:root\"},
            \"Action\": \"sts:AssumeRole\"
          }]
        }" \
        --tags Key=Name,Value=manager-cicd-role Key=ManagedBy,Value=terraform
    aws iam attach-role-policy \
        --role-name manager-cicd-role \
        --policy-arn arn:aws:iam::aws:policy/AdministratorAccess \
        --profile "$MANAGER_PROFILE"
    log_info "manager-cicd-role creado."
else
    log_info "manager-cicd-role ya existe."
fi

# automate-cicd-role: se crea en la cuenta managed (igual que la manager en single)
log_info "Verificando automate-cicd-role en cuenta $ACCOUNT_ID..."
ROLE_MANAGED=$(aws iam get-role --role-name automate-cicd-role --profile "$MANAGED_PROFILE" 2>/dev/null \
    | grep -c RoleName || true)

if [ "$ROLE_MANAGED" -eq 0 ]; then
    log_info "Creando automate-cicd-role..."
    if $SINGLE_ACCOUNT; then
        # Single-account: el usuario IAM asume automate-cicd-role directamente.
        # Se usa el ARN del caller actual (no el rol, que aún puede no estar propagado).
        CALLER_ARN=$(aws sts get-caller-identity --profile "$MANAGED_PROFILE" --query Arn --output text)
        AUTOMATE_PRINCIPAL="$CALLER_ARN"
    else
        AUTOMATE_PRINCIPAL="arn:aws:iam::${MANAGER_ACCOUNT_ID}:role/manager-cicd-role"
    fi
    aws iam create-role \
        --role-name automate-cicd-role \
        --profile "$MANAGED_PROFILE" \
        --assume-role-policy-document "{
          \"Version\": \"2012-10-17\",
          \"Statement\": [{
            \"Effect\": \"Allow\",
            \"Principal\": {\"AWS\": \"${AUTOMATE_PRINCIPAL}\"},
            \"Action\": \"sts:AssumeRole\"
          }]
        }" \
        --tags Key=Name,Value=automate-cicd-role Key=ManagedBy,Value=terraform
    aws iam attach-role-policy \
        --role-name automate-cicd-role \
        --policy-arn arn:aws:iam::aws:policy/AdministratorAccess \
        --profile "$MANAGED_PROFILE"
    log_info "automate-cicd-role creado."
else
    log_info "automate-cicd-role ya existe."
fi

# ─── Asumir role chain ────────────────────────────────────────────────────────
if $SINGLE_ACCOUNT; then
    # Single-account: el usuario del profile asume automate-cicd-role directamente.
    # No se necesita el chain manager → automate; Terraform's provider hace el assume
    # internamente con las credenciales del profile cuando ejecuta plan/apply.
    log_info "Modo single-account: asumiendo automate-cicd-role directamente..."
    AUTOMATE_CREDS=$(aws sts assume-role \
        --profile "$MANAGER_PROFILE" \
        --role-arn "arn:aws:iam::${ACCOUNT_ID}:role/automate-cicd-role" \
        --role-session-name "terraform-init-$(date +%s)" \
        --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
        --output text)
    read -r A_KEY A_SECRET A_TOKEN <<< "$AUTOMATE_CREDS"
    export AWS_ACCESS_KEY_ID="$A_KEY"
    export AWS_SECRET_ACCESS_KEY="$A_SECRET"
    export AWS_SESSION_TOKEN="$A_TOKEN"
    log_info "Identidad: $(aws sts get-caller-identity --query Arn --output text)"
else
    # Multi-account: chain manager-cicd-role → automate-cicd-role
    log_info "Asumiendo manager-cicd-role..."
    MANAGER_CREDS=$(aws sts assume-role \
        --profile "$MANAGER_PROFILE" \
        --role-arn "arn:aws:iam::${MANAGER_ACCOUNT_ID}:role/manager-cicd-role" \
        --role-session-name "backend-setup-$(date +%s)" \
        --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
        --output text)
    read -r M_KEY M_SECRET M_TOKEN <<< "$MANAGER_CREDS"
    export AWS_ACCESS_KEY_ID="$M_KEY"
    export AWS_SECRET_ACCESS_KEY="$M_SECRET"
    export AWS_SESSION_TOKEN="$M_TOKEN"
    log_info "Identidad tras manager-cicd-role: $(aws sts get-caller-identity --query Arn --output text)"

    log_info "Asumiendo automate-cicd-role..."
    AUTOMATE_CREDS=$(aws sts assume-role \
        --role-arn "arn:aws:iam::${ACCOUNT_ID}:role/automate-cicd-role" \
        --role-session-name "terraform-init-$(date +%s)" \
        --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
        --output text)
    read -r A_KEY A_SECRET A_TOKEN <<< "$AUTOMATE_CREDS"
    export AWS_ACCESS_KEY_ID="$A_KEY"
    export AWS_SECRET_ACCESS_KEY="$A_SECRET"
    export AWS_SESSION_TOKEN="$A_TOKEN"
    log_info "Identidad tras automate-cicd-role: $(aws sts get-caller-identity --query Arn --output text)"
fi

# ─── Generar backend.tf + terraform init ─────────────────────────────────────
log_info "Generando backend.tf..."
rm -f backend.tf .terraform/terraform.tfstate
cat > backend.tf <<EOF
terraform {
  backend "s3" {
    bucket  = "$BUCKET_NAME"
    key     = "$STATE_KEY"
    region  = "$REGION"
    encrypt = true
    # Sin DynamoDB — lab de un único operador
  }
}
EOF

log_info "Ejecutando terraform init..."
terraform init \
    -backend-config="access_key=${AWS_ACCESS_KEY_ID}" \
    -backend-config="secret_key=${AWS_SECRET_ACCESS_KEY}" \
    -backend-config="token=${AWS_SESSION_TOKEN}"

echo -e ""
echo -e "${GREEN}Setup completado.${NC}"
echo -e ""
echo -e "${GREEN}Resumen:${NC}"
echo -e "  Modo:         $([ "$SINGLE_ACCOUNT" = true ] && echo 'single-account' || echo 'multi-account')"
echo -e "  Manager acct: $MANAGER_ACCOUNT_ID"
echo -e "  Managed acct: $ACCOUNT_ID"
echo -e "  Bucket S3:    s3://$BUCKET_NAME"
echo -e "  State key:    $STATE_KEY"
echo -e "  backend.tf:   $(pwd)/backend.tf"
echo -e ""
echo -e "${YELLOW}Próximos pasos:${NC}"
echo -e "  terraform plan  -var-file=$TFVARS_FILE"
echo -e "  terraform apply -var-file=$TFVARS_FILE"

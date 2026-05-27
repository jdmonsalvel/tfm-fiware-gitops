#!/bin/bash

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# ============================================
# Select tfvars file interactively
# ============================================
VARIABLES_DIR="variables"
if [ ! -d "$VARIABLES_DIR" ]; then
    log_error "Directory not found: $VARIABLES_DIR"
    exit 1
fi

# Find all .tfvars files
TFVARS_FILES=($(find "$VARIABLES_DIR" -maxdepth 1 -name "*.tfvars" -type f | sort))

if [ ${#TFVARS_FILES[@]} -eq 0 ]; then
    log_error "No .tfvars files found in $VARIABLES_DIR"
    exit 1
fi

log_info "Available tfvars files:"
for i in "${!TFVARS_FILES[@]}"; do
    # show filename without .tfvars extension
    echo "  $((i+1))) $(basename "${TFVARS_FILES[$i]}" .tfvars)"
done

read -p "Select a tfvars file (enter number): " SELECTION
SELECTION=$((SELECTION - 1))

if [ "$SELECTION" -lt 0 ] || [ "$SELECTION" -ge "${#TFVARS_FILES[@]}" ]; then
    log_error "Invalid selection"
    exit 1
fi

TFVARS_FILE="${TFVARS_FILES[$SELECTION]}"
log_info "Selected: $TFVARS_FILE"

# Determine manager account id: use first script arg if present, otherwise try to detect via AWS
if [ -n "${1:-}" ]; then
    MANAGER_ACCOUNT_ID="${1}"
else
    MANAGER_ACCOUNT_ID="324037284958"
fi

# ============================================
# Extract variables from tfvars
# ============================================
extract_var() {
    grep "^$1" "$TFVARS_FILE" | sed 's/.*=\s*"\(.*\)".*/\1/'
}

ACCOUNT_ID=$(extract_var "account_id")
REGION=$(extract_var "region")
ENVIRONMENT=$(extract_var "environment")
PROJECT=$(extract_var "project")

if [ -z "$ACCOUNT_ID" ] || [ -z "$REGION" ] || [ -z "$ENVIRONMENT" ] || [ -z "$PROJECT" ]; then
    log_error "Missing required variables in $TFVARS_FILE"
    exit 1
fi

log_info "Extracted variables:"
log_info "  Account ID: $ACCOUNT_ID"
log_info "  Region: $REGION"
log_info "  Environment: $ENVIRONMENT"
log_info "  Project: $PROJECT"

# ============================================
# Assume roles (manager-cicd-role -> automate-cicd-role)
# ============================================
log_info "Assuming role chain: manager-cicd-role -> automate-cicd-role"

# Get current caller identity
CURRENT_CALLER=$(aws sts get-caller-identity --query 'Arn' --output text)
log_info "Current caller: $CURRENT_CALLER (Account: $MANAGER_ACCOUNT_ID)"

# Step 1: Assume manager-cicd-role in manager account
log_info "Assuming manager-cicd-role in manager account ($MANAGER_ACCOUNT_ID)..."
MANAGER_ROLE_ARN="arn:aws:iam::${MANAGER_ACCOUNT_ID}:role/manager-cicd-role"

MANAGER_CREDS=$(aws sts assume-role \
    --role-arn "$MANAGER_ROLE_ARN" \
    --role-session-name "terraform-backend-setup-$(date +%s)" \
    --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
    --output text)

read -r MANAGER_ACCESS_KEY MANAGER_SECRET_KEY MANAGER_SESSION_TOKEN <<< "$MANAGER_CREDS"

export AWS_ACCESS_KEY_ID="$MANAGER_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$MANAGER_SECRET_KEY"
export AWS_SESSION_TOKEN="$MANAGER_SESSION_TOKEN"

log_info "Successfully assumed manager-cicd-role"

# Debug: show caller identity for manager role
MANAGER_IDENTITY=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null || echo "unknown")
log_info "Identity after assuming manager role: $MANAGER_IDENTITY"

# Step 2: Assume automate-cicd-role in managed account using manager-cicd-role credentials
log_info "Assuming automate-cicd-role in managed account ($ACCOUNT_ID)..."
AUTOMATE_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/automate-cicd-role"

AUTOMATE_CREDS=$(aws sts assume-role \
    --role-arn "$AUTOMATE_ROLE_ARN" \
    --role-session-name "terraform-init-$(date +%s)" \
    --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
    --output text)

read -r AUTOMATE_ACCESS_KEY AUTOMATE_SECRET_KEY AUTOMATE_SESSION_TOKEN <<< "$AUTOMATE_CREDS"

export AWS_ACCESS_KEY_ID="$AUTOMATE_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$AUTOMATE_SECRET_KEY"
export AWS_SESSION_TOKEN="$AUTOMATE_SESSION_TOKEN"

log_info "Successfully assumed automate-cicd-role"

# Debug: show caller identity for automate role
AUTOMATE_IDENTITY=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null || echo "unknown")
log_info "Identity after assuming automate role: $AUTOMATE_IDENTITY"

# ============================================
# Fetch backend config from manager account
# ============================================
log_info "Fetching backend configuration..."

# Re-export manager credentials temporarily to fetch config
export AWS_ACCESS_KEY_ID="$MANAGER_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$MANAGER_SECRET_KEY"
export AWS_SESSION_TOKEN="$MANAGER_SESSION_TOKEN"

BUCKET_NAME="devops-${MANAGER_ACCOUNT_ID}-terraform-state-bucket"
TABLE_NAME="${ACCOUNT_ID}-terraform-state-lock-${PROJECT}-${ENVIRONMENT}-${REGION}"

log_info "Backend bucket: $BUCKET_NAME"
log_info "DynamoDB table: $TABLE_NAME"

# Restore automate credentials for terraform
export AWS_ACCESS_KEY_ID="$MANAGER_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$MANAGER_SECRET_KEY"
export AWS_SESSION_TOKEN="$MANAGER_SESSION_TOKEN"

# ============================================
# Generate backend.tf template
# ============================================
rm -rf backend.tf .terraform .terraform.*
BACKEND_FILE="backend.tf"
log_info "Generating $BACKEND_FILE template..."
rm -rf "$BACKEND_FILE"

## Create folder structure in bucket
FOLDER_PATH="${ACCOUNT_ID}/terraform-aws-${PROJECT}-${ENVIRONMENT}-${REGION}"
log_info "Creating folder structure: $FOLDER_PATH"

cat > "$BACKEND_FILE" <<EOF
terraform {
  backend "s3" {
    region         = "$REGION"
    bucket         = "$BUCKET_NAME"
    dynamodb_table = "$TABLE_NAME"
    encrypt        = true
    key            = "$FOLDER_PATH.tfstate"
  }
}
EOF

log_info "Backend configuration saved to: $BACKEND_FILE"

# ============================================
# Run terraform init
# ============================================
log_info "Running terraform init..."
terraform init

# Print summary
echo -e ""
echo -e "${GREEN}Setup completed successfully!${NC}"
echo -e ""
echo -e "${GREEN}Summary:${NC}"
echo -e "  Manager Account ID: $MANAGER_ACCOUNT_ID"
echo -e "  Managed Account ID: $ACCOUNT_ID"
echo -e "  S3 Bucket: $BUCKET_NAME"
echo -e "  DynamoDB Table: $TABLE_NAME"
echo -e "  State File Path: s3://$BUCKET_NAME/$FOLDER_PATH.tfstate"
echo -e "  Backend Config File: $BACKEND_FILE"
echo -e ""
echo -e "${YELLOW}Next Steps:${NC}"
echo -e "  1. Your Terraform backend is now configured"
echo -e "  2. You can now run: terraform plan, terraform apply, etc."

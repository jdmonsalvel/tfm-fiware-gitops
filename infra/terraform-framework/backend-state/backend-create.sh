#!/bin/bash

set -xveuo pipefail

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

# Validate arguments (accept 3 or 4 args; optional 4th: 'destroy')
if [ $# -lt 3 ] || [ $# -gt 4 ]; then
    log_error "Invalid number of arguments"
    echo "Usage: $0 <master-account-profile> <managed-account-profile> <managed-account.tfvars> [destroy]"
    exit 1
fi

MANAGER_PROFILE="$1"
MANAGED_PROFILE="$2"
TFVARS_FILE="$3"
ACTION="${4:-}"

# Validate tfvars file exists
if [ ! -f "$TFVARS_FILE" ]; then
    log_error "File not found: $TFVARS_FILE"
    exit 1
fi

# Extract variables from tfvars
extract_var() {
    grep "^$1" "$TFVARS_FILE" | sed 's/.*=\s*"\(.*\)".*/\1/'
}

ACCOUNT_ID=$(extract_var "account_id")
REGION=$(extract_var "region")
ENVIRONMENT=$(extract_var "environment")
PROJECT=$(extract_var "project")
ACCOUNTABLE=$(extract_var "accountable")

if [ -z "$ACCOUNT_ID" ] || [ -z "$REGION" ] || [ -z "$ENVIRONMENT" ] || [ -z "$PROJECT" ]; then
    log_error "Missing required variables in $TFVARS_FILE"
    exit 1
fi

log_info "Extracted variables:"
log_info "  Account ID: $ACCOUNT_ID"
log_info "  Region: $REGION"
log_info "  Environment: $ENVIRONMENT"
log_info "  Project: $PROJECT"

# Get manager account ID
MANAGER_ACCOUNT_ID=$(aws sts get-caller-identity --profile "$MANAGER_PROFILE" --query Account --output text)
log_info "manager account ID: $MANAGER_ACCOUNT_ID"

# ============================================
# Setup in Manager Account (DevOps CICD)
# ============================================
log_info "Setting up resources in manager account..."

# Check if manager-cicd-role exists in manager account
ROLE_EXISTS=$(aws iam get-role --role-name manager-cicd-role --profile "$MANAGER_PROFILE" 2>/dev/null || echo "")

if [ -z "$ROLE_EXISTS" ]; then
    log_info "Creating manager-cicd-role in manager account..."

    # Create trust policy
    TRUST_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS":  [
            "arn:aws:iam::$MANAGER_ACCOUNT_ID:root",
            "$MANAGER_ACCOUNT_ID"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
)
  
    aws iam create-role \
        --role-name manager-cicd-role \
        --profile "$MANAGER_PROFILE" \
        --assume-role-policy-document "$TRUST_POLICY" \
        --tags Key=Name,Value=manager-cicd-role Key=Accountable,Value="devops"
    
    log_info "Role created successfully"
    # Attach AdministratorAccess policy
    log_info "Attaching AdministratorAccess policy..."
    aws iam attach-role-policy \
        --role-name manager-cicd-role \
        --policy-arn arn:aws:iam::aws:policy/AdministratorAccess \
        --profile "$MANAGER_PROFILE"
else
    log_info "Role manager-cicd-role already exists"
fi

# Create S3 backend bucket
BUCKET_NAME="devops-${MANAGER_ACCOUNT_ID}-terraform-state-bucket"
log_info "Ensuring S3 bucket exists: $BUCKET_NAME"
CHECK_BUCKET=$(aws s3 ls --profile "$MANAGER_PROFILE" |grep $BUCKET_NAME |awk '{print $3}')
if [ -n "$CHECK_BUCKET" ]; then
    log_info "Bucket already exists: $BUCKET_NAME"
else
    log_info "Creating bucket: $BUCKET_NAME"
    aws s3api create-bucket \
        --bucket "$BUCKET_NAME" \
        --region "$REGION" \
        --profile "$MANAGER_PROFILE" \
        $(if [ "$REGION" != "us-east-1" ]; then echo "--create-bucket-configuration LocationConstraint=$REGION"; fi)
fi

# Enable versioning
log_info "Enabling versioning on bucket..."
aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled \
    --profile "$MANAGER_PROFILE"

# Enable encryption
log_info "Enabling encryption on bucket..."
aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            }
        }]
    }' \
    --profile "$MANAGER_PROFILE"

# Block public access
log_info "Blocking public access..."
aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration \
        BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true \
    --profile "$MANAGER_PROFILE"

# Create DynamoDB table for state locking
TABLE_NAME="${ACCOUNT_ID}-terraform-state-lock-${PROJECT}-${ENVIRONMENT}-${REGION}"
log_info "Checking DynamoDB table: $TABLE_NAME"

TABLE_EXISTS=$(aws dynamodb describe-table --table-name "$TABLE_NAME" --region "$REGION" --profile "$MANAGER_PROFILE" 2>/dev/null || echo "")
FOLDER_PATH="${ACCOUNT_ID}/terraform-aws-${PROJECT}-${ENVIRONMENT}-${REGION}"

if [ "$ACTION" = "destroy" ]; then
    # Destruction flow — requires explicit confirmation
    cat <<EOF
You must run "terraform destroy" first to delete the state.
Did you delete the state?
Type 'yes' to confirm: 
EOF
    read -r CONFIRMATION
    if [ "$CONFIRMATION" != "yes" ]; then
        log_warn "Confirmation not 'yes' — aborting destroy. No changes made."
        exit 0
    fi

    log_info "Proceeding to delete state artifacts and managed account role..."

    # Delete state file (including versions) from S3
    S3_KEY="$FOLDER_PATH.tfstate"
    S3_CHECK_BUCKET=$(aws s3 ls --profile "$MANAGER_PROFILE" | grep "$BUCKET_NAME" | awk '{print $3}')
    if [ -n "$S3_CHECK_BUCKET" ]; then
        log_info "Deleting state object: s3://$BUCKET_NAME/$S3_KEY"
        
        # Remove the current object (if exists)
        aws s3 rm "s3://$BUCKET_NAME/$S3_KEY" --profile "$MANAGER_PROFILE" || true

        # Delete all versions and delete markers (FIXED: maneja tabs correctamente)
        VERSIONS_RAW=$(aws s3api list-object-versions --bucket "$BUCKET_NAME" --prefix "$S3_KEY" --profile "$MANAGER_PROFILE" --query 'Versions[].VersionId' --output text 2>/dev/null || echo "")
        DMARKS_RAW=$(aws s3api list-object-versions --bucket "$BUCKET_NAME" --prefix "$S3_KEY" --profile "$MANAGER_PROFILE" --query 'DeleteMarkers[].VersionId' --output text 2>/dev/null || echo "")

        # Convertir tabs/espacios a líneas separadas
        mapfile -t VERSIONS < <(echo "$VERSIONS_RAW" | tr '\t\n ' '\n' | grep -v '^$')
        mapfile -t DMARKS < <(echo "$DMARKS_RAW" | tr '\t\n ' '\n' | grep -v '^$')

        log_info "Found ${#VERSIONS[@]} versions and ${#DMARKS[@]} delete markers to delete"

        # Delete versions
        for VID in "${VERSIONS[@]}"; do
            if [ -n "$VID" ]; then
                log_info "Deleting version: $VID"
                aws s3api delete-object --bucket "$BUCKET_NAME" --key "$S3_KEY" --version-id "$VID" --profile "$MANAGER_PROFILE" || true
            fi
        done
        
        # Delete delete markers
        for VID in "${DMARKS[@]}"; do
            if [ -n "$VID" ]; then
                log_info "Deleting delete marker: $VID"
                aws s3api delete-object --bucket "$BUCKET_NAME" --key "$S3_KEY" --version-id "$VID" --profile "$MANAGER_PROFILE" || true
            fi
        done
        
        log_info "S3 state object and all versions/delete markers cleaned"
    else
        log_warn "Bucket $BUCKET_NAME not found — skipping S3 deletion"
    fi

    # Delete DynamoDB table
    if [ -n "$TABLE_EXISTS" ]; then
        log_info "Deleting DynamoDB table: $TABLE_NAME"
        aws dynamodb delete-table --table-name "$TABLE_NAME" --region "$REGION" --profile "$MANAGER_PROFILE" || true
        # wait for deletion (best-effort)
        aws dynamodb wait table-not-exists --table-name "$TABLE_NAME" --region "$REGION" --profile "$MANAGER_PROFILE" || true
        log_info "DynamoDB table deleted (or not present)"
    else
        log_warn "DynamoDB table $TABLE_NAME does not exist — skipping"
    fi

    # Delete role in managed account (automate-cicd-role)
    ROLE_NAME="automate-cicd-role"
    ROLE_CHECK=$(aws iam get-role --role-name "$ROLE_NAME" --profile "$MANAGED_PROFILE" 2>/dev/null || echo "")
    if [ -n "$ROLE_CHECK" ]; then
        log_info "Deleting role $ROLE_NAME in managed account ($ACCOUNT_ID)"
        # Detach attached managed policies
        mapfile -t ATTACHED < <(aws iam list-attached-role-policies --role-name "$ROLE_NAME" --profile "$MANAGED_PROFILE" --query 'AttachedPolicies[].PolicyArn' --output text || echo "")
        for P in "${ATTACHED[@]:-}"; do
            if [ -n "$P" ]; then
                aws iam detach-role-policy --role-name "$ROLE_NAME" --policy-arn "$P" --profile "$MANAGED_PROFILE" || true
            fi
        done
        # Remove inline policies
        mapfile -t INLINE < <(aws iam list-role-policies --role-name "$ROLE_NAME" --profile "$MANAGED_PROFILE" --query 'PolicyNames[]' --output text || echo "")
        for PN in "${INLINE[@]:-}"; do
            if [ -n "$PN" ]; then
                aws iam delete-role-policy --role-name "$ROLE_NAME" --policy-name "$PN" --profile "$MANAGED_PROFILE" || true
            fi
        done
        # Finally delete the role
        aws iam delete-role --role-name "$ROLE_NAME" --profile "$MANAGED_PROFILE" || true
        log_info "Managed account role deletion attempted"
    else
        log_warn "Role $ROLE_NAME not found in managed account — skipping role deletion"
    fi

    log_info "Destroy flow completed. Exiting."
    exit 0
fi

if [ -z "$TABLE_EXISTS" ]; then
    log_info "Creating DynamoDB table..."
    aws dynamodb create-table \
        --table-name "$TABLE_NAME" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "$REGION" \
        --profile "$MANAGER_PROFILE" \
        --tags Key=Name,Value="$TABLE_NAME"
    
    log_info "Waiting for table to be active..."
    aws dynamodb wait table-exists \
        --table-name "$TABLE_NAME" \
        --region "$REGION" \
        --profile "$MANAGER_PROFILE"
else
    log_info "Table already exists"
fi

# ============================================
# Setup in Managed Account
# ============================================
log_info "Setting up resources in managed account ($ACCOUNT_ID)..."

# Create trust policy for managed account
TRUST_POLICY_MANAGED=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": [
            "arn:aws:iam::${MANAGER_ACCOUNT_ID}:role/manager-cicd-role",
            "arn:aws:iam::${MANAGER_ACCOUNT_ID}:root"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
)

# Check if automate-cicd-role exists in managed account
ROLE_MANAGED=$(aws iam get-role --role-name automate-cicd-role --profile "$MANAGED_PROFILE" 2>/dev/null || echo "")

if [ -z "$ROLE_MANAGED" ]; then
    log_info "Creating automate-cicd-role in managed account..."
    aws iam create-role \
        --role-name automate-cicd-role \
        --assume-role-policy-document "$TRUST_POLICY_MANAGED" \
        --profile "$MANAGED_PROFILE" \
        --tags Key=Name,Value=automate-cicd-role
    log_info "Role created successfully"
    # Attach AdministratorAccess policy to managed account role
    log_info "Attaching AdministratorAccess policy to managed account role..."
    aws iam attach-role-policy \
        --role-name automate-cicd-role \
        --policy-arn arn:aws:iam::aws:policy/AdministratorAccess \
        --profile "$MANAGED_PROFILE"

else
    log_info "Role automate-cicd-role already exists in managed account"
fi

log_info "Setup completed successfully!"

# Print summary using echo -e so color escape sequences are interpreted
echo -e ""
echo -e "${GREEN}Summary:${NC}"
echo -e "  manager account ID: $MANAGER_ACCOUNT_ID"
echo -e "  Managed Account ID: $ACCOUNT_ID"
echo -e "  S3 Bucket: $BUCKET_NAME"
echo -e "  DynamoDB Table: $TABLE_NAME"
echo -e "  State File Path: $(echo "s3://$BUCKET_NAME/$FOLDER_PATH.tfstate")"
echo -e ""
echo -e "${YELLOW}Next Steps:${NC}"
echo -e "  1. Generate backend.tf in your Terraform configuration"
echo -e "  2. Run: terraform init"
echo -e "  3. Verify state is properly stored in S3"
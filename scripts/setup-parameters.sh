#!/bin/bash

# setup-parameters.sh - Create initial SSM parameters and Secrets Manager entries
# Usage: ./setup-parameters.sh [--profile PROFILE_NAME] [--region REGION]

set -e

# Default values
REGION="us-east-1"
APPLICATION_NAME="scheduled-file-writer"
PROFILE=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --profile)
            PROFILE="$2"
            shift 2
            ;;
        --region)
            REGION="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [--profile PROFILE_NAME] [--region REGION]"
            echo ""
            echo "Options:"
            echo "  --profile PROFILE_NAME    AWS profile to use (required)"
            echo "  --region REGION          AWS region (default: us-east-1)"
            echo "  --help, -h               Show this help message"
            echo ""
            echo "This script creates initial SSM parameters and Secrets Manager entries"
            echo "required for the scheduled file writer application."
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$PROFILE" ]]; then
    echo "Error: AWS profile is required. Use --profile to specify the AWS profile."
    echo "Use --help for usage information"
    exit 1
fi

# Set AWS CLI profile
export AWS_PROFILE="$PROFILE"

echo "Setting up parameters for $APPLICATION_NAME in region $REGION using profile $PROFILE"

# Function to create SSM parameter if it doesn't exist
create_ssm_parameter() {
    local param_name="$1"
    local param_value="$2"
    local param_type="$3"
    local description="$4"
    
    echo "Creating SSM parameter: $param_name"
    
    if aws ssm get-parameter --name "$param_name" --region "$REGION" >/dev/null 2>&1; then
        echo "  Parameter $param_name already exists, skipping..."
    else
        aws ssm put-parameter \
            --name "$param_name" \
            --value "$param_value" \
            --type "$param_type" \
            --description "$description" \
            --region "$REGION" \
            --tags "Key=Application,Value=$APPLICATION_NAME" \
            >/dev/null
        echo "  Created parameter: $param_name"
    fi
}

# Function to create Secrets Manager secret if it doesn't exist
create_secret() {
    local secret_name="$1"
    local secret_value="$2"
    local description="$3"
    
    echo "Creating Secrets Manager secret: $secret_name"
    
    if aws secretsmanager describe-secret --secret-id "$secret_name" --region "$REGION" >/dev/null 2>&1; then
        echo "  Secret $secret_name already exists, skipping..."
    else
        aws secretsmanager create-secret \
            --name "$secret_name" \
            --description "$description" \
            --secret-string "$secret_value" \
            --region "$REGION" \
            --tags "Key=Application,Value=$APPLICATION_NAME" \
            >/dev/null
        echo "  Created secret: $secret_name"
    fi
}

# Prompt for SMB credentials
echo ""
echo "Please provide SMB credentials for the Windows file server:"
read -p "SMB Username (default: smbuser): " SMB_USERNAME
SMB_USERNAME=${SMB_USERNAME:-smbuser}

while true; do
    read -s -p "SMB Password (minimum 8 characters): " SMB_PASSWORD
    echo
    if [[ ${#SMB_PASSWORD} -ge 8 ]]; then
        break
    else
        echo "Password must be at least 8 characters long. Please try again."
    fi
done

# Prompt for network configuration
echo ""
echo "Network configuration (press Enter for defaults):"
read -p "VPC CIDR (default: 10.1.0.0/16): " VPC_CIDR
VPC_CIDR=${VPC_CIDR:-10.1.0.0/16}

read -p "Private Subnet CIDR (default: 10.1.1.0/24): " PRIVATE_SUBNET_CIDR
PRIVATE_SUBNET_CIDR=${PRIVATE_SUBNET_CIDR:-10.1.1.0/24}

# Get available AZs and prompt for selection
echo ""
echo "Available Availability Zones in $REGION:"
AZS=($(aws ec2 describe-availability-zones --region "$REGION" --query 'AvailabilityZones[].ZoneName' --output text))
for i in "${!AZS[@]}"; do
    echo "  $((i+1)). ${AZS[$i]}"
done

while true; do
    read -p "Select Availability Zone (1-${#AZS[@]}): " AZ_CHOICE
    if [[ "$AZ_CHOICE" =~ ^[0-9]+$ ]] && [[ "$AZ_CHOICE" -ge 1 ]] && [[ "$AZ_CHOICE" -le "${#AZS[@]}" ]]; then
        AVAILABILITY_ZONE="${AZS[$((AZ_CHOICE-1))]}"
        break
    else
        echo "Invalid choice. Please select a number between 1 and ${#AZS[@]}."
    fi
done

# S3 Configuration for CloudFormation templates
echo ""
echo "S3 Configuration for CloudFormation templates:"
# Get AWS account ID for default bucket name
ACCOUNT_ID=$(aws sts get-caller-identity --profile "$PROFILE" --region "$REGION" --query Account --output text)
if [ -z "$ACCOUNT_ID" ]; then
    echo "❌ Failed to get AWS account ID. Please check your AWS credentials."
    exit 1
fi
echo "Using AWS Account ID: $ACCOUNT_ID"

DEFAULT_S3_BUCKET="cf-templates-${ACCOUNT_ID}-${REGION}-${APPLICATION_NAME}"
read -p "S3 bucket name for CloudFormation templates (default: $DEFAULT_S3_BUCKET): " S3_BUCKET_NAME
S3_BUCKET_NAME=${S3_BUCKET_NAME:-$DEFAULT_S3_BUCKET}
echo "S3 bucket name: $S3_BUCKET_NAME"

echo ""
echo "Creating parameters with the following values:"
echo "  Application: $APPLICATION_NAME"
echo "  Region: $REGION"
echo "  VPC CIDR: $VPC_CIDR"
echo "  Private Subnet CIDR: $PRIVATE_SUBNET_CIDR"
echo "  Availability Zone: $AVAILABILITY_ZONE"
echo "  S3 Bucket Name: $S3_BUCKET_NAME"
echo "  SMB Username: $SMB_USERNAME"
echo ""

# Create SSM Parameters
echo "Creating SSM Parameters..."

create_ssm_parameter \
    "/$APPLICATION_NAME/network/vpc-cidr" \
    "$VPC_CIDR" \
    "String" \
    "VPC CIDR block for $APPLICATION_NAME"

create_ssm_parameter \
    "/$APPLICATION_NAME/network/private-subnet-cidr" \
    "$PRIVATE_SUBNET_CIDR" \
    "String" \
    "Private subnet CIDR block for $APPLICATION_NAME"

create_ssm_parameter \
    "/$APPLICATION_NAME/network/availability-zone" \
    "$AVAILABILITY_ZONE" \
    "String" \
    "Availability zone for $APPLICATION_NAME deployment"

create_ssm_parameter \
    "/$APPLICATION_NAME/s3/bucket-name" \
    "$S3_BUCKET_NAME" \
    "String" \
    "S3 bucket name for CloudFormation templates for $APPLICATION_NAME"

create_ssm_parameter \
    "/$APPLICATION_NAME/smb/domain" \
    "WORKGROUP" \
    "String" \
    "SMB domain/workgroup for file share access"

create_ssm_parameter \
    "/$APPLICATION_NAME/smb/connection-timeout" \
    "30" \
    "String" \
    "SMB connection timeout in seconds"

create_ssm_parameter \
    "/$APPLICATION_NAME/smb/share-path" \
    "\\FileShare" \
    "String" \
    "SMB share path on Windows server"

# Create Secrets Manager secret for SMB credentials
echo ""
echo "Creating Secrets Manager entries..."

SECRET_VALUE=$(cat <<EOF
{
    "username": "$SMB_USERNAME",
    "password": "$SMB_PASSWORD"
}
EOF
)

create_secret \
    "$APPLICATION_NAME/smb-credentials" \
    "$SECRET_VALUE" \
    "SMB credentials for $APPLICATION_NAME file share access"

echo ""
echo "✅ Parameter setup completed successfully!"
echo ""
echo "Created SSM Parameters:"
echo "  /$APPLICATION_NAME/network/vpc-cidr"
echo "  /$APPLICATION_NAME/network/private-subnet-cidr"
echo "  /$APPLICATION_NAME/network/availability-zone"
echo "  /$APPLICATION_NAME/s3/bucket-name"
echo "  /$APPLICATION_NAME/smb/domain"
echo "  /$APPLICATION_NAME/smb/connection-timeout"
echo "  /$APPLICATION_NAME/smb/share-path"
echo ""
echo "Created Secrets Manager entries:"
echo "  $APPLICATION_NAME/smb-credentials"
echo ""
echo "You can now proceed with deploying the CloudFormation stack using deploy-stack.sh"
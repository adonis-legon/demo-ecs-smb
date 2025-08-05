#!/bin/bash

# setup-nested-stacks.sh - Complete setup for CloudFormation nested stacks
# Usage: ./setup-nested-stacks.sh --profile PROFILE_NAME [--region REGION] [--bucket-name BUCKET_NAME]

set -e

# Default values
REGION="us-east-1"
APPLICATION_NAME="scheduled-file-writer"
BUCKET_NAME=""
PROFILE=""
TEMPLATE_DIR="infrastructure/templates"

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
        --bucket-name)
            BUCKET_NAME="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 --profile PROFILE_NAME [--region REGION] [--bucket-name BUCKET_NAME]"
            echo ""
            echo "Options:"
            echo "  --profile PROFILE_NAME    AWS profile to use (required)"
            echo "  --region REGION          AWS region (default: us-east-1)"
            echo "  --bucket-name BUCKET     S3 bucket name for templates (optional)"
            echo "                           If not provided, will auto-generate using account ID and region"
            echo "  --help, -h               Show this help message"
            echo ""
            echo "This script performs complete setup for CloudFormation nested stacks:"
            echo "1. Creates and configures S3 bucket for storing templates"
            echo "2. Uploads nested templates to S3 (if they exist)"
            echo "3. Validates all templates before upload"
            echo "4. Configures bucket policies and lifecycle management"
            echo ""
            echo "Auto-generated bucket name format:"
            echo "  cf-templates-<account-id>-<region>-<application-name>"
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

echo "🚀 Setting up CloudFormation nested stacks infrastructure"
echo "Region: $REGION"
echo "Profile: $PROFILE"
echo ""

# Function to generate bucket name if not provided
generate_bucket_name() {
    if [[ -z "$BUCKET_NAME" ]]; then
        echo "📝 Generating S3 bucket name..."
        
        # Get AWS account ID for the current profile
        local account_id=$(aws sts get-caller-identity --query 'Account' --output text --profile "$PROFILE")
        if [[ -z "$account_id" ]]; then
            echo "❌ Failed to get AWS account ID. Please check your AWS credentials."
            exit 1
        fi
        
        BUCKET_NAME="cf-templates-${account_id}-${REGION}-${APPLICATION_NAME}"
        echo "Generated bucket name: $BUCKET_NAME"
    else
        echo "Using provided bucket name: $BUCKET_NAME"
    fi
}

# Function to check if bucket exists
bucket_exists() {
    aws s3api head-bucket --bucket "$BUCKET_NAME" --region "$REGION" --profile "$PROFILE" 2>/dev/null
}

# Function to create S3 bucket
create_bucket() {
    echo "🪣 Creating S3 bucket: $BUCKET_NAME"
    
    if [[ "$REGION" == "us-east-1" ]]; then
        # us-east-1 doesn't need LocationConstraint
        aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$REGION" \
            --profile "$PROFILE"
    else
        # Other regions need LocationConstraint
        aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$REGION" \
            --profile "$PROFILE" \
            --create-bucket-configuration LocationConstraint="$REGION"
    fi
    
    echo "✅ S3 bucket created successfully"
}

# Function to configure bucket settings
configure_bucket() {
    echo "⚙️  Configuring S3 bucket settings..."
    
    # Enable versioning
    echo "  - Enabling versioning..."
    aws s3api put-bucket-versioning \
        --bucket "$BUCKET_NAME" \
        --versioning-configuration Status=Enabled \
        --region "$REGION" \
        --profile "$PROFILE"
    
    # Configure encryption
    echo "  - Configuring server-side encryption..."
    aws s3api put-bucket-encryption \
        --bucket "$BUCKET_NAME" \
        --server-side-encryption-configuration '{
            "Rules": [
                {
                    "ApplyServerSideEncryptionByDefault": {
                        "SSEAlgorithm": "AES256"
                    },
                    "BucketKeyEnabled": true
                }
            ]
        }' \
        --region "$REGION" \
        --profile "$PROFILE"
    
    # Configure bucket policy
    echo "  - Setting up bucket policy for CloudFormation access..."
    local account_id=$(aws sts get-caller-identity --query 'Account' --output text --profile "$PROFILE")
    
    if [ -z "$account_id" ]; then
        echo "❌ Failed to get AWS account ID for bucket policy"
        return 1
    fi
    
    echo "  - Using account ID: $account_id"
    
    cat > /tmp/bucket-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowCloudFormationAccess",
            "Effect": "Allow",
            "Principal": {
                "Service": "cloudformation.amazonaws.com"
            },
            "Action": [
                "s3:GetObject",
                "s3:GetObjectVersion"
            ],
            "Resource": "arn:aws:s3:::${BUCKET_NAME}/*"
        },
        {
            "Sid": "AllowAccountAccess",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::${account_id}:root"
            },
            "Action": [
                "s3:GetObject",
                "s3:GetObjectVersion",
                "s3:PutObject",
                "s3:DeleteObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::${BUCKET_NAME}",
                "arn:aws:s3:::${BUCKET_NAME}/*"
            ]
        }
    ]
}
EOF
    
    if aws s3api put-bucket-policy \
        --bucket "$BUCKET_NAME" \
        --policy file:///tmp/bucket-policy.json \
        --region "$REGION" \
        --profile "$PROFILE"; then
        echo "  ✅ Bucket policy applied successfully"
    else
        echo "  ❌ Failed to apply bucket policy"
        echo "  💡 This might be due to insufficient permissions or policy syntax issues"
        echo "  📋 Policy content:"
        cat /tmp/bucket-policy.json
        return 1
    fi
    
    # Configure lifecycle policy
    echo "  - Setting up lifecycle policy..."
    cat > /tmp/lifecycle-policy.json << EOF
{
    "Rules": [
        {
            "ID": "DeleteOldVersions",
            "Status": "Enabled",
            "Filter": {
                "Prefix": ""
            },
            "NoncurrentVersionExpiration": {
                "NoncurrentDays": 30
            }
        },
        {
            "ID": "DeleteIncompleteMultipartUploads",
            "Status": "Enabled",
            "Filter": {
                "Prefix": ""
            },
            "AbortIncompleteMultipartUpload": {
                "DaysAfterInitiation": 7
            }
        }
    ]
}
EOF
    
    aws s3api put-bucket-lifecycle-configuration \
        --bucket "$BUCKET_NAME" \
        --lifecycle-configuration file:///tmp/lifecycle-policy.json \
        --region "$REGION" \
        --profile "$PROFILE"
    
    # Clean up temporary files
    rm -f /tmp/bucket-policy.json /tmp/lifecycle-policy.json
    
    echo "✅ Bucket configuration completed"
}

# Function to create directory structure
create_directory_structure() {
    echo "📁 Creating directory structure..."
    
    # Create local directory structure
    mkdir -p infrastructure/templates
    mkdir -p infrastructure/scripts
    mkdir -p infrastructure/config
    
    # Create README if it doesn't exist
    if [[ ! -f "$TEMPLATE_DIR/README.md" ]]; then
        cat > "$TEMPLATE_DIR/README.md" << EOF
# CloudFormation Nested Templates

This directory contains the nested CloudFormation templates for the $APPLICATION_NAME application.

## Template Structure

- \`main-template.yaml\` - Main orchestration template
- \`networking-stack.yaml\` - VPC, subnets, security groups, and VPC endpoints
- \`compute-stack.yaml\` - Windows EC2 instance, EBS volumes, and IAM roles
- \`application-stack.yaml\` - ECS cluster, task definitions, and EventBridge rules

## Scripts Structure

- \`windows-smb-setup.ps1\` - PowerShell script for Windows SMB configuration

## Deployment

Use the updated \`deploy-stack.sh\` script which will automatically upload these templates and scripts to S3 before deployment.

## S3 Bucket

Templates are stored in: s3://$BUCKET_NAME/templates/
Scripts are stored in: s3://$BUCKET_NAME/scripts/

Generated on: $(date)
EOF
    fi
    
    # Upload README to establish the directory structure
    aws s3 cp "$TEMPLATE_DIR/README.md" "s3://$BUCKET_NAME/README.md" --region "$REGION" --profile "$PROFILE"
    
    echo "✅ Directory structure created"
}

# Function to validate CloudFormation template
validate_template() {
    local template_file="$1"
    local template_name=$(basename "$template_file")
    
    echo "  📋 Validating: $template_name"
    
    if aws cloudformation validate-template --template-body "file://$template_file" --region "$REGION" --profile "$PROFILE" >/dev/null 2>&1; then
        echo "    ✅ Validation successful"
        return 0
    else
        echo "    ❌ Validation failed"
        aws cloudformation validate-template --template-body "file://$template_file" --region "$REGION" --profile "$PROFILE"
        return 1
    fi
}

# Function to check template size
check_template_size() {
    local template_file="$1"
    local template_name=$(basename "$template_file")
    local size=$(wc -c < "$template_file")
    local max_size=51200  # CloudFormation limit
    
    echo "  📏 Size check: $template_name = $size bytes"
    
    if [[ $size -gt $max_size ]]; then
        echo "    ⚠️  Warning: Exceeds CloudFormation limit ($max_size bytes)"
        return 1
    else
        echo "    ✅ Size is within limits"
        return 0
    fi
}

# Function to upload template to S3
upload_template() {
    local template_file="$1"
    local template_name=$(basename "$template_file")
    local s3_key="$template_name"
    
    echo "  📤 Uploading: $template_name"
    
    # Upload with metadata to templates/ subdirectory
    aws s3 cp "$template_file" "s3://$BUCKET_NAME/templates/$s3_key" \
        --region "$REGION" \
        --profile "$PROFILE" \
        --metadata "application=$APPLICATION_NAME,upload-date=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --content-type "text/yaml" \
        --quiet
    
    # Verify upload
    if aws s3api head-object --bucket "$BUCKET_NAME" --key "templates/$s3_key" --region "$REGION" --profile "$PROFILE" >/dev/null 2>&1; then
        echo "    ✅ Upload successful"
        echo "    🔗 URL: https://s3.amazonaws.com/$BUCKET_NAME/templates/$s3_key"
        return 0
    else
        echo "    ❌ Upload verification failed"
        return 1
    fi
}

# Function to upload script to S3
upload_script() {
    local script_file="$1"
    local script_name=$(basename "$script_file")
    local s3_key="$script_name"
    
    echo "  📤 Uploading: $script_name"
    
    # Upload script to scripts/ subdirectory
    aws s3 cp "$script_file" "s3://$BUCKET_NAME/scripts/$s3_key" \
        --region "$REGION" \
        --profile "$PROFILE" \
        --metadata "application=$APPLICATION_NAME,upload-date=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --content-type "text/plain" \
        --quiet
    
    # Verify upload
    if aws s3api head-object --bucket "$BUCKET_NAME" --key "scripts/$s3_key" --region "$REGION" --profile "$PROFILE" >/dev/null 2>&1; then
        echo "    ✅ Upload successful"
        echo "    🔗 URL: https://s3.amazonaws.com/$BUCKET_NAME/scripts/$s3_key"
        return 0
    else
        echo "    ❌ Upload verification failed"
        return 1
    fi
}

# Function to process scripts
process_scripts() {
    echo "📜 Processing PowerShell scripts..."
    
    local scripts_dir="infrastructure/scripts"
    local found_scripts=0
    local upload_errors=0
    
    if [[ ! -d "$scripts_dir" ]]; then
        echo "ℹ️  Scripts directory not found: $scripts_dir"
        echo "No scripts to upload"
        return 0
    fi
    
    # Process PowerShell scripts
    local scripts=(
        "windows-smb-setup.ps1"
    )
    
    for script in "${scripts[@]}"; do
        local script_path="$scripts_dir/$script"
        
        if [[ -f "$script_path" ]]; then
            ((found_scripts++))
            echo ""
            echo "Processing: $script"
            echo "----------------------------------------"
            
            # Check script size
            local size=$(wc -c < "$script_path")
            echo "  📏 Size check: $script = $size bytes"
            
            # Upload script
            if ! upload_script "$script_path"; then
                ((upload_errors++))
            fi
        fi
    done
    
    echo ""
    if [[ $found_scripts -eq 0 ]]; then
        echo "ℹ️  No PowerShell scripts found in $scripts_dir"
    else
        echo "📊 Script Processing Summary:"
        echo "  Scripts found: $found_scripts"
        echo "  Upload errors: $upload_errors"
        
        if [[ $upload_errors -gt 0 ]]; then
            echo "  ❌ Some scripts had upload errors"
        else
            echo "  ✅ All scripts uploaded successfully"
        fi
    fi
}

# Function to process templates
process_templates() {
    echo "📦 Processing CloudFormation templates..."
    
    if [[ ! -d "$TEMPLATE_DIR" ]]; then
        echo "⚠️  Template directory not found: $TEMPLATE_DIR"
        echo "Templates will need to be uploaded later using this script"
        return 0
    fi
    
    # Process main template (located at infrastructure root)
    local main_template="infrastructure/main-template.yaml"
    local found_templates=0
    local validation_errors=0
    local size_warnings=0
    local upload_errors=0
    
    if [[ -f "$main_template" ]]; then
        ((found_templates++))
        echo ""
        echo "Processing: main-template.yaml"
        echo "----------------------------------------"
        
        # Validate template
        if ! validate_template "$main_template"; then
            ((validation_errors++))
        else
            # Check size
            if ! check_template_size "$main_template"; then
                ((size_warnings++))
            fi
            
            # Upload main template to S3 root (not templates/ subdirectory)
            echo "  📤 Uploading: main-template.yaml"
            if aws s3 cp "$main_template" "s3://$BUCKET_NAME/main-template.yaml" \
                --region "$REGION" \
                --profile "$PROFILE" \
                --metadata "application=$APPLICATION_NAME,upload-date=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                --content-type "text/yaml" \
                --quiet; then
                
                # Verify upload
                if aws s3api head-object --bucket "$BUCKET_NAME" --key "main-template.yaml" --region "$REGION" --profile "$PROFILE" >/dev/null 2>&1; then
                    echo "    ✅ Upload successful"
                    echo "    🔗 URL: https://s3.amazonaws.com/$BUCKET_NAME/main-template.yaml"
                else
                    echo "    ❌ Upload verification failed"
                    ((upload_errors++))
                fi
            else
                echo "    ❌ Upload failed"
                ((upload_errors++))
            fi
        fi
    fi
    
    # Process nested templates (located in templates/ directory)
    local nested_templates=(
        "networking-stack.yaml"
        "compute-stack.yaml"
        "application-stack.yaml"
    )
    
    for template in "${nested_templates[@]}"; do
        local template_path="$TEMPLATE_DIR/$template"
        
        if [[ -f "$template_path" ]]; then
            ((found_templates++))
            echo ""
            echo "Processing: $template"
            echo "----------------------------------------"
            
            # Validate template
            if ! validate_template "$template_path"; then
                ((validation_errors++))
                continue
            fi
            
            # Check size
            if ! check_template_size "$template_path"; then
                ((size_warnings++))
            fi
            
            # Upload template
            if ! upload_template "$template_path"; then
                ((upload_errors++))
            fi
        fi
    done
    
    echo ""
    if [[ $found_templates -eq 0 ]]; then
        echo "ℹ️  No nested stack templates found in $TEMPLATE_DIR"
        echo "Create the templates and run this script again to upload them"
    else
        echo "📊 Template Processing Summary:"
        echo "  Templates found: $found_templates"
        echo "  Validation errors: $validation_errors"
        echo "  Size warnings: $size_warnings"
        echo "  Upload errors: $upload_errors"
        
        if [[ $validation_errors -gt 0 || $upload_errors -gt 0 ]]; then
            echo "  ❌ Some templates had errors"
        elif [[ $size_warnings -gt 0 ]]; then
            echo "  ⚠️  Some templates may still be too large"
        else
            echo "  ✅ All templates processed successfully"
        fi
    fi
}

# Function to test bucket access
test_bucket_access() {
    echo "🧪 Testing bucket access..."
    
    # Create a test file
    echo "Test file created on $(date)" > /tmp/test-file.txt
    
    # Upload test file
    aws s3 cp /tmp/test-file.txt "s3://$BUCKET_NAME/test-file.txt" --region "$REGION" --profile "$PROFILE" --quiet
    
    # Download test file
    aws s3 cp "s3://$BUCKET_NAME/test-file.txt" /tmp/test-download.txt --region "$REGION" --profile "$PROFILE" --quiet
    
    # Verify content
    if diff /tmp/test-file.txt /tmp/test-download.txt >/dev/null 2>&1; then
        echo "✅ Bucket access test successful"
    else
        echo "❌ Bucket access test failed"
        exit 1
    fi
    
    # Clean up test files
    aws s3 rm "s3://$BUCKET_NAME/test-file.txt" --region "$REGION" --profile "$PROFILE" --quiet
    rm -f /tmp/test-file.txt /tmp/test-download.txt
}

# Configuration is now stored in SSM Parameter Store
# No need for local config file

# Function to display final summary
display_summary() {
    echo ""
    echo "🎯 Setup Complete!"
    echo "=================="
    echo "S3 Bucket: $BUCKET_NAME"
    echo "Region: $REGION"
    echo "Bucket URL: https://s3.amazonaws.com/$BUCKET_NAME"
    echo ""
    echo "✅ Features Configured:"
    echo "  • Versioning enabled"
    echo "  • Server-side encryption (AES256)"
    echo "  • CloudFormation access policy"
    echo "  • Lifecycle policy (30-day version retention)"
    echo "  • Directory structure created"
    echo ""
    echo "📋 Next Steps:"
    echo "1. Create your nested stack templates in: $TEMPLATE_DIR/"
    echo "2. Create your PowerShell scripts in: infrastructure/scripts/"
    echo "3. Run this script again to upload new/updated templates and scripts"
    echo "4. Update your deploy-stack.sh to use the main-template.yaml"
    echo ""
    echo "💡 Useful Commands:"
    echo "  # Re-upload templates and scripts after changes:"
    echo "  ./scripts/setup-nested-stacks.sh --profile $PROFILE --region $REGION"
    echo ""
    echo "  # List bucket contents:"
    echo "  aws s3 ls s3://$BUCKET_NAME/ --profile $PROFILE"
    echo "  aws s3 ls s3://$BUCKET_NAME/templates/ --profile $PROFILE"
    echo "  aws s3 ls s3://$BUCKET_NAME/scripts/ --profile $PROFILE"
    echo ""
    echo "✅ S3 bucket name stored in SSM Parameter Store: /$APPLICATION_NAME/s3/bucket-name"
}

# Main execution
echo "Starting nested stacks setup process..."
echo ""

generate_bucket_name

if bucket_exists; then
    echo "🔄 S3 bucket already exists: $BUCKET_NAME"
    echo "Updating configuration and processing templates..."
    configure_bucket
else
    create_bucket
    configure_bucket
fi

create_directory_structure
test_bucket_access
process_scripts
process_templates
display_summary

echo ""
echo "🎉 Nested stacks setup completed successfully!"
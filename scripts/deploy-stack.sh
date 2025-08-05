#!/bin/bash

# deploy-stack.sh - Deploy CloudFormation stack for scheduled file writer with nested stacks
# Usage: ./deploy-stack.sh --profile PROFILE_NAME [--region REGION] [--ecr-uri ECR_URI]

set -e

# Default values
REGION="us-east-1"
APPLICATION_NAME="scheduled-file-writer"
STACK_NAME="$APPLICATION_NAME-stack"
TEMPLATE_FILE="infrastructure/main-template.yaml"
NESTED_TEMPLATE_DIR="infrastructure/templates"
PROFILE=""
ECR_URI=""

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
        --ecr-uri)
            ECR_URI="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 --profile PROFILE_NAME [--region REGION] [--ecr-uri ECR_URI]"
            echo ""
            echo "Options:"
            echo "  --profile PROFILE_NAME    AWS profile to use (required)"
            echo "  --region REGION          AWS region (default: us-east-1)"
            echo "  --ecr-uri ECR_URI        ECR repository URI for the application image (optional)"
            echo "                           If not provided, will auto-generate using account ID and region"
            echo "  --help, -h               Show this help message"
            echo ""
            echo "This script deploys the CloudFormation nested stack architecture for the scheduled file writer application."
            echo "Make sure to run setup-parameters.sh first to create required parameters."
            echo "Make sure to run setup-nested-stacks.sh first to create S3 bucket and upload templates."
            echo ""
            echo "ECR Repository:"
            echo "  The script will automatically create an ECR repository named '$APPLICATION_NAME'"
            echo "  in your AWS account if it doesn't exist. The ECR URI will be auto-generated as:"
            echo "  <account-id>.dkr.ecr.<region>.amazonaws.com/$APPLICATION_NAME:latest"
            echo ""
            echo "Nested Stack Architecture:"
            echo "  This deployment uses a nested stack architecture with the following components:"
            echo "  - Main Template: Orchestrates all nested stacks"
            echo "  - Networking Stack: VPC, subnets, security groups, VPC endpoints"
            echo "  - Compute Stack: Windows EC2 instance, EBS volumes, IAM roles"
            echo "  - Application Stack: ECS cluster, task definitions, EventBridge rules"
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

echo "Deploying $APPLICATION_NAME stack in region $REGION using profile $PROFILE"

# Validate template file exists
if [[ ! -f "$TEMPLATE_FILE" ]]; then
    echo "Error: CloudFormation template not found at $TEMPLATE_FILE"
    echo ""
    echo "Make sure you are running this script from the project root directory:"
    echo "  ./scripts/deploy-stack.sh --profile YOUR_PROFILE"
    echo ""
    echo "Expected project structure:"
    echo "  project-root/"
    echo "  ├── infrastructure/"
    echo "  │   └── cloudformation-template.yaml"
    echo "  └── scripts/"
    echo "      └── deploy-stack.sh"
    exit 1
fi

# Function to get SSM parameter value
get_ssm_parameter() {
    local param_name="$1"
    aws ssm get-parameter --name "$param_name" --region "$REGION" --query 'Parameter.Value' --output text 2>/dev/null || echo ""
}

# Function to validate required parameters exist
validate_parameters() {
    echo "Validating required parameters..."
    
    local required_params=(
        "/$APPLICATION_NAME/network/vpc-cidr"
        "/$APPLICATION_NAME/network/private-subnet-cidr"
        "/$APPLICATION_NAME/network/availability-zone"
        "/$APPLICATION_NAME/smb/domain"
        "/$APPLICATION_NAME/smb/connection-timeout"
        "/$APPLICATION_NAME/smb/share-path"
    )
    
    local missing_params=()
    
    for param in "${required_params[@]}"; do
        if [[ -z "$(get_ssm_parameter "$param")" ]]; then
            missing_params+=("$param")
        fi
    done
    
    # Check if SMB credentials secret exists
    if ! aws secretsmanager describe-secret --secret-id "$APPLICATION_NAME/smb-credentials" --region "$REGION" >/dev/null 2>&1; then
        missing_params+=("$APPLICATION_NAME/smb-credentials (Secrets Manager)")
    fi
    
    if [[ ${#missing_params[@]} -gt 0 ]]; then
        echo "Error: Missing required parameters:"
        for param in "${missing_params[@]}"; do
            echo "  - $param"
        done
        echo ""
        echo "Please run setup-parameters.sh first to create the required parameters."
        exit 1
    fi
    
    echo "✅ All required parameters found"
}

# Function to load S3 configuration
load_s3_config() {
    echo "Loading S3 bucket configuration..."
    
    # Get S3 bucket name from SSM Parameter Store
    BUCKET_NAME=$(aws ssm get-parameter --name "/$APPLICATION_NAME/s3/bucket-name" --query 'Parameter.Value' --output text --profile "$PROFILE" --region "$REGION" 2>/dev/null)
    
    if [[ -z "$BUCKET_NAME" ]] || [[ "$BUCKET_NAME" == "None" ]]; then
        echo "❌ S3 bucket name not found in SSM Parameter Store"
        echo ""
        echo "Please run setup-parameters.sh first to create the required parameters:"
        echo "  ./scripts/setup-parameters.sh --profile $PROFILE --region $REGION"
        echo ""
        echo "Then run setup-nested-stacks.sh to create the S3 bucket:"
        echo "  ./scripts/setup-nested-stacks.sh --profile $PROFILE --region $REGION"
        exit 1
    fi
    
    echo "✅ S3 configuration loaded (from SSM): $BUCKET_NAME"
}

# Function to validate individual CloudFormation template with detailed error reporting
validate_single_template() {
    local template_file="$1"
    local template_name=$(basename "$template_file")
    
    echo "  📋 Validating: $template_name"
    
    # Check if template file exists and is readable
    if [[ ! -f "$template_file" ]]; then
        echo "    ❌ Template file not found: $template_file"
        return 1
    fi
    
    if [[ ! -r "$template_file" ]]; then
        echo "    ❌ Template file not readable: $template_file"
        return 1
    fi
    
    # Check if template is not empty
    if [[ ! -s "$template_file" ]]; then
        echo "    ❌ Template file is empty: $template_file"
        return 1
    fi
    
    # Note: Skip Python YAML validation as it doesn't understand CloudFormation intrinsic functions
    # CloudFormation validation below will catch any actual YAML syntax issues
    
    # Validate template syntax with AWS CloudFormation
    local validation_output
    local validation_error
    if validation_output=$(aws cloudformation validate-template --template-body "file://$template_file" --region "$REGION" 2>&1); then
        echo "    ✅ Validation successful"
        
        # Extract and display template description if available
        local description=$(echo "$validation_output" | jq -r '.Description // empty' 2>/dev/null)
        if [[ -n "$description" ]]; then
            echo "    📝 Description: $description"
        fi
        
        # Display parameter count
        local param_count=$(echo "$validation_output" | jq '.Parameters | length' 2>/dev/null || echo "0")
        echo "    📊 Parameters: $param_count"
        
        # Check for common CloudFormation issues
        if grep -q "AWS::CloudFormation::Stack" "$template_file"; then
            echo "    🔗 Contains nested stack references"
            # Validate S3 URLs in nested stack references
            if grep -q "s3.amazonaws.com" "$template_file"; then
                echo "    ✅ S3 template URLs detected"
            else
                echo "    ⚠️  No S3 URLs found in nested stack template"
            fi
        fi
        
        return 0
    else
        echo "    ❌ Validation failed"
        echo "    📋 Template validation error for $template_name:"
        echo "$validation_output" | sed 's/^/      /'
        
        # Provide specific guidance for common errors
        if echo "$validation_output" | grep -q "Template format error"; then
            echo "    💡 Suggestion: Check YAML syntax and CloudFormation template structure"
        elif echo "$validation_output" | grep -q "Invalid template property"; then
            echo "    💡 Suggestion: Verify all CloudFormation resource properties are correct"
        elif echo "$validation_output" | grep -q "Unresolved resource dependencies"; then
            echo "    💡 Suggestion: Check resource references and dependencies"
        fi
        
        return 1
    fi
}

# Function to validate all nested stack templates with comprehensive reporting
validate_nested_templates() {
    echo "Validating all nested stack templates..."
    echo "========================================"
    
    local templates=(
        "$NESTED_TEMPLATE_DIR/networking-stack.yaml"
        "$NESTED_TEMPLATE_DIR/compute-stack.yaml"
        "$NESTED_TEMPLATE_DIR/application-stack.yaml"
    )
    
    local validation_errors=0
    local missing_templates=0
    local successful_validations=0
    local total_templates=${#templates[@]}
    
    echo "Found $total_templates templates to validate"
    echo ""
    
    for template in "${templates[@]}"; do
        local template_name=$(basename "$template")
        
        if [[ -f "$template" ]]; then
            echo "Validating: $template_name"
            echo "----------------------------------------"
            if validate_single_template "$template"; then
                ((successful_validations++))
            else
                ((validation_errors++))
            fi
            echo ""
        else
            echo "❌ Template not found: $template_name"
            echo "   Expected location: $template"
            ((missing_templates++))
            ((validation_errors++))
            echo ""
        fi
    done
    
    echo "📊 Validation Summary:"
    echo "  Total templates: $total_templates"
    echo "  Successful validations: $successful_validations"
    echo "  Missing templates: $missing_templates"
    echo "  Validation errors: $validation_errors"
    echo ""
    
    if [[ $missing_templates -gt 0 ]]; then
        echo "❌ Missing templates detected"
        echo "Please ensure all nested stack templates exist before deployment"
        echo ""
        echo "Expected template structure:"
        echo "  infrastructure/"
        echo "  ├── main-template.yaml"
        echo "  └── templates/"
        echo "      ├── networking-stack.yaml"
        echo "      ├── compute-stack.yaml"
        echo "      └── application-stack.yaml"
        exit 1
    fi
    
    if [[ $validation_errors -gt 0 ]]; then
        echo "❌ $validation_errors template validation error(s) found"
        echo "Please fix the template errors before deploying"
        exit 1
    fi
    
    if [[ $successful_validations -eq $total_templates ]]; then
        echo "✅ All template validations successful"
    else
        echo "⚠️  Validation completed with warnings"
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
        echo "    ❌ Error: Exceeds CloudFormation limit ($max_size bytes)"
        return 1
    else
        echo "    ✅ Size is within limits"
        return 0
    fi
}

# Function to upload template to S3 with enhanced error handling
upload_template_to_s3() {
    local template_file="$1"
    local template_name=$(basename "$template_file")
    local s3_key="$template_name"
    
    echo "  📤 Uploading: $template_name"
    
    # Check if template file exists and is readable
    if [[ ! -f "$template_file" ]]; then
        echo "    ❌ Template file not found: $template_file"
        return 1
    fi
    
    if [[ ! -r "$template_file" ]]; then
        echo "    ❌ Template file not readable: $template_file"
        return 1
    fi
    
    # Get file size for progress indication (trim whitespace)
    local file_size=$(wc -c < "$template_file" | tr -d ' \t\n\r')
    echo "    📏 File size: $file_size bytes"
    
    # Pre-upload validation: ensure S3 bucket is accessible
    if ! aws s3api head-bucket --bucket "$BUCKET_NAME" --region "$REGION" 2>/dev/null; then
        echo "    ❌ S3 bucket not accessible: $BUCKET_NAME"
        echo "    💡 Suggestion: Run setup-nested-stacks.sh to create/configure the bucket"
        return 1
    fi
    
    # Attempt upload with detailed error capture
    local upload_output
    local upload_error
    
    if upload_output=$(aws s3 cp "$template_file" "s3://$BUCKET_NAME/templates/$s3_key" \
        --region "$REGION" \
        --metadata "application=$APPLICATION_NAME,upload-date=$(date -u +%Y-%m-%dT%H:%M:%SZ),file-size=$file_size" \
        --content-type "text/yaml" \
        --no-progress 2>&1); then
        
        echo "    ✅ Upload completed"
        
        # Verify upload with detailed check
        if aws s3api head-object --bucket "$BUCKET_NAME" --key "templates/$s3_key" --region "$REGION" >/dev/null 2>&1; then
            # Get uploaded object details
            local uploaded_size=$(aws s3api head-object --bucket "$BUCKET_NAME" --key "templates/$s3_key" --region "$REGION" --query 'ContentLength' --output text)
            local last_modified=$(aws s3api head-object --bucket "$BUCKET_NAME" --key "templates/$s3_key" --region "$REGION" --query 'LastModified' --output text)
            
            echo "    ✅ Upload verification successful"
            echo "    📊 Uploaded size: $uploaded_size bytes"
            echo "    🕒 Last modified: $last_modified"
            echo "    🔗 URL: https://s3.amazonaws.com/$BUCKET_NAME/templates/$s3_key"
            
            # Verify file integrity (trim whitespace from both values)
            local local_size_trimmed=$(echo "$file_size" | tr -d ' \t\n\r')
            local s3_size_trimmed=$(echo "$uploaded_size" | tr -d ' \t\n\r')
            
            if [[ "$local_size_trimmed" == "$s3_size_trimmed" ]]; then
                echo "    ✅ File integrity verified"
                
                # Additional validation: ensure template is accessible via HTTPS
                local https_url="https://s3.amazonaws.com/$BUCKET_NAME/templates/$s3_key"
                if curl -s --head "$https_url" | grep -q "200 OK"; then
                    echo "    ✅ Template accessible via HTTPS"
                    return 0
                else
                    echo "    ⚠️  Template uploaded but may not be publicly accessible"
                    echo "    💡 This may cause CloudFormation deployment issues"
                    return 0  # Don't fail here, but warn
                fi
            else
                echo "    ❌ File size mismatch (local: '$local_size_trimmed', S3: '$s3_size_trimmed')"
                echo "    🔍 Debug: local raw='$file_size', S3 raw='$uploaded_size'"
                return 1
            fi
        else
            echo "    ❌ Upload verification failed - object not found in S3"
            return 1
        fi
    else
        echo "    ❌ Upload failed"
        echo "    📋 Error details:"
        echo "$upload_output" | sed 's/^/      /'
        
        # Analyze common error patterns and provide specific guidance
        if echo "$upload_output" | grep -q "NoSuchBucket"; then
            echo "    💡 Suggestion: Run setup-nested-stacks.sh to create the S3 bucket"
            echo "    💡 Command: ./scripts/setup-nested-stacks.sh --profile $PROFILE --region $REGION"
        elif echo "$upload_output" | grep -q "AccessDenied"; then
            echo "    💡 Suggestion: Check AWS credentials and S3 permissions"
            echo "    💡 Verify your AWS profile has s3:PutObject permissions"
        elif echo "$upload_output" | grep -q "InvalidRequest"; then
            echo "    💡 Suggestion: Verify template file format and content"
        elif echo "$upload_output" | grep -q "RequestTimeout"; then
            echo "    💡 Suggestion: Network timeout - retry the upload"
        fi
        
        return 1
    fi
}

# Function to upload all nested templates to S3
upload_nested_templates() {
    echo "Uploading nested templates to S3..."
    
    # Check if S3 bucket exists
    if ! aws s3api head-bucket --bucket "$BUCKET_NAME" --region "$REGION" 2>/dev/null; then
        echo "❌ S3 bucket does not exist: $BUCKET_NAME"
        echo ""
        echo "Please run setup-nested-stacks.sh first to create the S3 bucket:"
        echo "  ./scripts/setup-nested-stacks.sh --profile $PROFILE --region $REGION"
        exit 1
    fi
    
    local templates=(
        "$NESTED_TEMPLATE_DIR/networking-stack.yaml"
        "$NESTED_TEMPLATE_DIR/compute-stack.yaml"
        "$NESTED_TEMPLATE_DIR/application-stack.yaml"
    )
    
    local upload_errors=0
    local size_errors=0
    
    for template in "${templates[@]}"; do
        if [[ -f "$template" ]]; then
            local template_name=$(basename "$template")
            echo ""
            echo "Processing: $template_name"
            echo "----------------------------------------"
            
            # Check template size
            if ! check_template_size "$template"; then
                ((size_errors++))
                continue
            fi
            
            # Upload template
            if ! upload_template_to_s3 "$template"; then
                ((upload_errors++))
            fi
        else
            echo "❌ Template not found: $template"
            ((upload_errors++))
        fi
    done
    
    echo ""
    if [[ $size_errors -gt 0 ]]; then
        echo "❌ $size_errors template(s) exceed size limits"
        exit 1
    fi
    
    if [[ $upload_errors -gt 0 ]]; then
        echo "❌ $upload_errors template upload error(s) occurred"
        exit 1
    fi
    
    echo "✅ All templates uploaded successfully to S3"
}

# Function to handle S3 upload failures with retry logic
retry_s3_upload() {
    local template_file="$1"
    local max_retries=3
    local retry_count=0
    
    while [[ $retry_count -lt $max_retries ]]; do
        if upload_template_to_s3 "$template_file"; then
            return 0
        fi
        
        ((retry_count++))
        if [[ $retry_count -lt $max_retries ]]; then
            echo "    🔄 Retrying upload (attempt $((retry_count + 1))/$max_retries)..."
            sleep $((retry_count * 2))  # Exponential backoff
        fi
    done
    
    echo "    ❌ Failed to upload after $max_retries attempts"
    return 1
}

# Function to upload all nested templates with enhanced error handling
upload_nested_templates_with_retry() {
    echo "Uploading all templates to S3 with retry logic..."
    
    # Check if S3 bucket exists
    if ! aws s3api head-bucket --bucket "$BUCKET_NAME" --region "$REGION" 2>/dev/null; then
        echo "❌ S3 bucket does not exist: $BUCKET_NAME"
        echo ""
        echo "Please run setup-nested-stacks.sh first to create the S3 bucket:"
        echo "  ./scripts/setup-nested-stacks.sh --profile $PROFILE --region $REGION"
        exit 1
    fi
    
    # Upload main template to root
    echo ""
    echo "Processing: main-template.yaml"
    echo "----------------------------------------"
    
    if ! check_template_size "$TEMPLATE_FILE"; then
        echo "    ⚠️  Skipping upload due to size constraint"
        return 1
    fi
    
    # Upload main template to S3 root
    if aws s3 cp "$TEMPLATE_FILE" "s3://$BUCKET_NAME/main-template.yaml" \
        --region "$REGION" \
        --metadata "application=$APPLICATION_NAME,upload-date=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --content-type "text/yaml" \
        --quiet; then
        echo "    ✅ Successfully uploaded: main-template.yaml"
    else
        echo "    ❌ Failed to upload: main-template.yaml"
        return 1
    fi
    
    # Upload nested templates to templates/ subdirectory
    local templates=(
        "$NESTED_TEMPLATE_DIR/networking-stack.yaml"
        "$NESTED_TEMPLATE_DIR/compute-stack.yaml"
        "$NESTED_TEMPLATE_DIR/application-stack.yaml"
    )
    
    local upload_errors=0
    local size_errors=0
    local successful_uploads=0
    
    for template in "${templates[@]}"; do
        if [[ -f "$template" ]]; then
            local template_name=$(basename "$template")
            echo ""
            echo "Processing: $template_name"
            echo "----------------------------------------"
            
            # Check template size
            if ! check_template_size "$template"; then
                ((size_errors++))
                echo "    ⚠️  Skipping upload due to size constraint"
                continue
            fi
            
            # Upload template with retry logic
            if retry_s3_upload "$template"; then
                ((successful_uploads++))
                echo "    ✅ Successfully uploaded: $template_name"
            else
                ((upload_errors++))
                echo "    ❌ Failed to upload: $template_name"
            fi
        else
            echo "❌ Template not found: $template"
            ((upload_errors++))
        fi
    done
    
    echo ""
    echo "📊 Upload Summary:"
    echo "  Successful uploads: $successful_uploads"
    echo "  Size constraint errors: $size_errors"
    echo "  Upload failures: $upload_errors"
    
    if [[ $size_errors -gt 0 ]]; then
        echo "❌ $size_errors template(s) exceed size limits"
        echo "Please refactor templates to reduce size before deployment"
        exit 1
    fi
    
    if [[ $upload_errors -gt 0 ]]; then
        echo "❌ $upload_errors template upload error(s) occurred"
        echo "Cannot proceed with deployment due to missing templates"
        exit 1
    fi
    
    if [[ $successful_uploads -eq 0 ]]; then
        echo "❌ No templates were uploaded successfully"
        echo "Cannot proceed with deployment"
        exit 1
    fi
    
    echo "✅ All templates uploaded successfully to S3"
}

# Function to verify S3 bucket accessibility and template availability
verify_s3_access() {
    echo "Verifying S3 bucket access and template availability..."
    echo "====================================================="
    
    # Test bucket access with a simple list operation
    echo "🔍 Testing bucket access..."
    if aws s3 ls "s3://$BUCKET_NAME/" --region "$REGION" >/dev/null 2>&1; then
        echo "✅ S3 bucket is accessible: $BUCKET_NAME"
    else
        echo "❌ Cannot access S3 bucket: $BUCKET_NAME"
        echo ""
        echo "Possible issues:"
        echo "1. Bucket does not exist - run setup-nested-stacks.sh"
        echo "2. Insufficient permissions - check AWS credentials"
        echo "3. Bucket is in a different region - verify region setting"
        echo ""
        echo "To fix this, run:"
        echo "  ./scripts/setup-nested-stacks.sh --profile $PROFILE --region $REGION"
        return 1
    fi
    
    echo ""
    echo "📋 Verifying template availability in S3..."
    
    # Check main template (in root)
    echo "  🔍 Checking: main-template.yaml"
    local missing_templates=0
    local available_templates=0
    
    if aws s3api head-object --bucket "$BUCKET_NAME" --key "main-template.yaml" --region "$REGION" >/dev/null 2>&1; then
        local last_modified=$(aws s3api head-object --bucket "$BUCKET_NAME" --key "main-template.yaml" --region "$REGION" --query 'LastModified' --output text)
        local size=$(aws s3api head-object --bucket "$BUCKET_NAME" --key "main-template.yaml" --region "$REGION" --query 'ContentLength' --output text)
        echo "    ✅ Available (Size: $size bytes, Modified: $last_modified)"
        ((available_templates++))
    else
        echo "    ❌ Not found in S3"
        ((missing_templates++))
    fi
    
    # Check nested templates (in templates/ subdirectory)
    local nested_templates=(
        "networking-stack.yaml"
        "compute-stack.yaml"
        "application-stack.yaml"
    )
    
    for template in "${nested_templates[@]}"; do
        echo "  🔍 Checking: $template"
        
        if aws s3api head-object --bucket "$BUCKET_NAME" --key "templates/$template" --region "$REGION" >/dev/null 2>&1; then
            local last_modified=$(aws s3api head-object --bucket "$BUCKET_NAME" --key "templates/$template" --region "$REGION" --query 'LastModified' --output text)
            local size=$(aws s3api head-object --bucket "$BUCKET_NAME" --key "templates/$template" --region "$REGION" --query 'ContentLength' --output text)
            
            echo "    ✅ Available (Size: $size bytes, Modified: $last_modified)"
            ((available_templates++))
        else
            echo "    ❌ Not found in S3"
            ((missing_templates++))
        fi
    done
    
    echo ""
    echo "📊 S3 Template Summary:"
    echo "  Available templates: $available_templates"
    echo "  Missing templates: $missing_templates"
    
    if [[ $missing_templates -gt 0 ]]; then
        echo ""
        echo "❌ $missing_templates template(s) missing from S3"
        echo "Templates will be uploaded during deployment process"
        echo ""
        echo "To pre-upload templates, run:"
        echo "  ./scripts/setup-nested-stacks.sh --profile $PROFILE --region $REGION"
        return 1
    else
        echo ""
        echo "✅ All required templates are available in S3"
        return 0
    fi
}

# Function to validate main CloudFormation template and S3 references
validate_main_template() {
    echo "Validating main CloudFormation template..."
    echo "=========================================="
    
    if [[ ! -f "$TEMPLATE_FILE" ]]; then
        echo "❌ Main template not found: $TEMPLATE_FILE"
        echo ""
        echo "Expected nested stack structure:"
        echo "  infrastructure/"
        echo "  ├── main-template.yaml"
        echo "  └── templates/"
        echo "      ├── networking-stack.yaml"
        echo "      ├── compute-stack.yaml"
        echo "      └── application-stack.yaml"
        echo "  └── config/"
        echo "      └── s3-bucket.conf"
        return 1
    fi
    
    echo "📋 Validating main template as primary deployment template..."
    
    # Ensure we're using the main template as the primary template
    if [[ "$(basename "$TEMPLATE_FILE")" != "main-template.yaml" ]]; then
        echo "❌ Primary template should be main-template.yaml"
        echo "   Current template: $(basename "$TEMPLATE_FILE")"
        echo "   Expected: main-template.yaml"
        return 1
    fi
    
    echo "✅ Using main-template.yaml as primary deployment template"
    
    echo ""
    echo "📋 Validating main template syntax..."
    local validation_output
    if validation_output=$(aws cloudformation validate-template --template-body "file://$TEMPLATE_FILE" --region "$REGION" 2>&1); then
        echo "✅ Main template syntax validation successful"
        
        # Extract template information
        local description=$(echo "$validation_output" | jq -r '.Description // empty' 2>/dev/null)
        if [[ -n "$description" ]]; then
            echo "📝 Template description: $description"
        fi
        
        local param_count=$(echo "$validation_output" | jq '.Parameters | length' 2>/dev/null || echo "0")
        echo "📊 Template parameters: $param_count"
        
    else
        echo "❌ Main template syntax validation failed"
        echo "📋 Template validation error:"
        echo "$validation_output" | sed 's/^/  /'
        return 1
    fi
    
    echo ""
    echo "🔗 Validating S3 template references..."
    
    # Check if main template contains proper S3 references
    local s3_references=$(grep -c "s3.amazonaws.com.*\.yaml" "$TEMPLATE_FILE" || echo "0")
    if [[ $s3_references -gt 0 ]]; then
        echo "✅ Found $s3_references S3 template references in main template"
        
        # Validate that S3 references use parameter substitution (not hardcoded bucket names)
        if grep -q '${S3BucketName}' "$TEMPLATE_FILE"; then
            echo "✅ S3 references use parameter substitution (secure approach)"
            echo "   Bucket name will be: $BUCKET_NAME"
            
            # Validate specific nested stack references
            local expected_templates=("networking-stack.yaml" "compute-stack.yaml" "application-stack.yaml")
            local missing_refs=0
            
            for template in "${expected_templates[@]}"; do
                if grep -q "$template" "$TEMPLATE_FILE"; then
                    echo "  ✅ Reference found: $template"
                else
                    echo "  ❌ Missing reference: $template"
                    ((missing_refs++))
                fi
            done
            
            if [[ $missing_refs -gt 0 ]]; then
                echo "⚠️  Warning: $missing_refs expected template reference(s) missing"
            fi
            
        else
            echo "❌ S3 references do not use parameter substitution"
            echo "   Template should use \${S3BucketName} parameter instead of hardcoded bucket names"
            echo "   This is required for security and cross-account compatibility"
            return 1
        fi
    else
        echo "❌ No S3 template references found in main template"
        echo "   This template is not properly configured for nested stack architecture"
        return 1
    fi
    
    echo ""
    echo "📊 Main template analysis:"
    local template_size=$(wc -c < "$TEMPLATE_FILE")
    echo "  Template size: $template_size bytes"
    
    if [[ $template_size -gt 51200 ]]; then
        echo "  ❌ Template exceeds CloudFormation size limit (51,200 bytes)"
        return 1
    else
        echo "  ✅ Template size is within CloudFormation limits"
    fi
    
    # Count nested stack resources
    local nested_stacks=$(grep -c "AWS::CloudFormation::Stack" "$TEMPLATE_FILE" || echo "0")
    echo "  Nested stacks: $nested_stacks"
    
    if [[ $nested_stacks -eq 0 ]]; then
        echo "  ❌ No nested stack resources found"
        echo "     This template is not configured for nested stack architecture"
        return 1
    elif [[ $nested_stacks -ne 3 ]]; then
        echo "  ⚠️  Warning: Expected 3 nested stacks (Networking, Compute, Application), found $nested_stacks"
    else
        echo "  ✅ Correct number of nested stack resources detected"
    fi
    
    # Validate dependency order
    echo ""
    echo "🔄 Validating nested stack dependencies..."
    if grep -A 5 "ComputeStack:" "$TEMPLATE_FILE" | grep -q "DependsOn.*NetworkingStack"; then
        echo "  ✅ ComputeStack properly depends on NetworkingStack"
    else
        echo "  ⚠️  Warning: ComputeStack dependency on NetworkingStack not found"
    fi
    
    if grep -A 10 "ApplicationStack:" "$TEMPLATE_FILE" | grep -q "DependsOn"; then
        echo "  ✅ ApplicationStack has dependency declarations"
    else
        echo "  ⚠️  Warning: ApplicationStack dependencies not clearly defined"
    fi
    
    echo ""
    echo "✅ Main template validation completed successfully"
    return 0
}

# Function to get ECR repository URI if not provided
get_ecr_uri() {
    if [[ -z "$ECR_URI" ]]; then
        echo "ECR URI not provided, auto-generating ECR repository URI..."
        
        # Get AWS account ID for the current profile
        local account_id=$(aws sts get-caller-identity --query 'Account' --output text)
        if [[ -z "$account_id" ]]; then
            echo "❌ Failed to get AWS account ID. Please check your AWS credentials."
            exit 1
        fi
        
        local repo_name="$APPLICATION_NAME"
        local expected_uri="${account_id}.dkr.ecr.${REGION}.amazonaws.com/${repo_name}"
        
        echo "Expected ECR URI: ${expected_uri}:latest"
        
        # Check if repository exists
        if aws ecr describe-repositories --repository-names "$repo_name" --region "$REGION" >/dev/null 2>&1; then
            ECR_URI=$(aws ecr describe-repositories --repository-names "$repo_name" --region "$REGION" --query 'repositories[0].repositoryUri' --output text)
            echo "✅ Found existing ECR repository: $ECR_URI"
        else
            echo "Creating ECR repository: $repo_name"
            ECR_URI=$(aws ecr create-repository --repository-name "$repo_name" --region "$REGION" --query 'repository.repositoryUri' --output text)
            echo "✅ Created ECR repository: $ECR_URI"
        fi
        
        # Verify the URI matches expected format
        if [[ "$ECR_URI" != "$expected_uri" ]]; then
            echo "⚠️  Warning: Generated ECR URI doesn't match expected format"
            echo "   Expected: $expected_uri"
            echo "   Actual:   $ECR_URI"
        fi
    else
        echo "Using provided ECR URI: $ECR_URI"
    fi
    
    # Add latest tag if not present
    if [[ "$ECR_URI" != *:* ]]; then
        ECR_URI="$ECR_URI:latest"
        echo "Added 'latest' tag to ECR URI: $ECR_URI"
    fi
}

# Function to build parameter overrides
build_parameters() {
    echo "Building CloudFormation parameters..."
    
    local vpc_cidr=$(get_ssm_parameter "/$APPLICATION_NAME/network/vpc-cidr")
    local subnet_cidr=$(get_ssm_parameter "/$APPLICATION_NAME/network/private-subnet-cidr")
    local az=$(get_ssm_parameter "/$APPLICATION_NAME/network/availability-zone")
    
    # Get SMB credentials from Secrets Manager
    local smb_creds=$(aws secretsmanager get-secret-value --secret-id "$APPLICATION_NAME/smb-credentials" --region "$REGION" --query 'SecretString' --output text)
    local smb_username=$(echo "$smb_creds" | jq -r '.username')
    local smb_password=$(echo "$smb_creds" | jq -r '.password')
    
    PARAMETERS="ParameterKey=VpcCidr,ParameterValue=$vpc_cidr"
    PARAMETERS="$PARAMETERS ParameterKey=PrivateSubnetCidr,ParameterValue=$subnet_cidr"
    PARAMETERS="$PARAMETERS ParameterKey=AvailabilityZone,ParameterValue=$az"
    PARAMETERS="$PARAMETERS ParameterKey=ApplicationName,ParameterValue=$APPLICATION_NAME"
    PARAMETERS="$PARAMETERS ParameterKey=SMBUsername,ParameterValue=$smb_username"
    PARAMETERS="$PARAMETERS ParameterKey=SMBPassword,ParameterValue=$smb_password"
    PARAMETERS="$PARAMETERS ParameterKey=ECRRepositoryURI,ParameterValue=$ECR_URI"
    PARAMETERS="$PARAMETERS ParameterKey=S3BucketName,ParameterValue=$BUCKET_NAME"
    
    echo "Parameters configured successfully"
    echo "S3 Bucket for templates: $BUCKET_NAME"
    echo "Note: Compute stack uses embedded SMB setup (no S3 dependency for SMB scripts)"
}

# Function to get stack status
get_stack_status() {
    aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "NOT_FOUND"
}

# Function to delete stack in ROLLBACK_COMPLETE state
delete_failed_stack() {
    echo "⚠️  Stack is in ROLLBACK_COMPLETE state and cannot be updated."
    echo "The stack needs to be deleted before creating a new one."
    echo ""
    
    read -p "Do you want to delete the failed stack and create a new one? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Deleting failed stack..."
        aws cloudformation delete-stack --stack-name "$STACK_NAME" --region "$REGION"
        
        echo "Waiting for stack deletion to complete..."
        if aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME" --region "$REGION" 2>/dev/null; then
            echo "✅ Stack deleted successfully"
            return 0
        else
            echo "❌ Stack deletion failed or timed out"
            echo "Please check the CloudFormation console and try again"
            exit 1
        fi
    else
        echo "Operation cancelled. Please delete the stack manually or use destroy-stack.sh"
        exit 1
    fi
}

# Function to deploy or update stack
deploy_stack() {
    echo "Checking stack status..."
    
    STACK_STATUS=$(get_stack_status)
    echo "Current stack status: $STACK_STATUS"
    
    case "$STACK_STATUS" in
        "NOT_FOUND")
            echo "Stack does not exist, creating..."
            OPERATION="create-stack"
            WAIT_CONDITION="stack-create-complete"
            ;;
        "CREATE_COMPLETE"|"UPDATE_COMPLETE"|"UPDATE_ROLLBACK_COMPLETE")
            echo "Stack exists and can be updated, updating..."
            OPERATION="update-stack"
            WAIT_CONDITION="stack-update-complete"
            ;;
        "ROLLBACK_COMPLETE")
            delete_failed_stack
            echo "Creating new stack after deletion..."
            OPERATION="create-stack"
            WAIT_CONDITION="stack-create-complete"
            ;;
        "CREATE_IN_PROGRESS"|"UPDATE_IN_PROGRESS"|"DELETE_IN_PROGRESS")
            echo "❌ Stack is currently in progress: $STACK_STATUS"
            echo "Please wait for the current operation to complete before deploying"
            exit 1
            ;;
        "ROLLBACK_IN_PROGRESS"|"UPDATE_ROLLBACK_IN_PROGRESS")
            echo "❌ Stack is currently rolling back: $STACK_STATUS"
            echo "Please wait for the rollback to complete before deploying"
            exit 1
            ;;
        "CREATE_FAILED"|"DELETE_FAILED"|"UPDATE_ROLLBACK_FAILED")
            echo "❌ Stack is in a failed state: $STACK_STATUS"
            echo "Please check the CloudFormation console and resolve the issues"
            echo "You may need to delete the stack manually"
            exit 1
            ;;
        *)
            echo "❌ Unknown stack status: $STACK_STATUS"
            echo "Please check the CloudFormation console"
            exit 1
            ;;
    esac
    
    echo "Executing CloudFormation $OPERATION..."
    
    aws cloudformation "$OPERATION" \
        --stack-name "$STACK_NAME" \
        --template-body "file://$TEMPLATE_FILE" \
        --parameters $PARAMETERS \
        --capabilities CAPABILITY_NAMED_IAM \
        --region "$REGION" \
        --tags "Key=Application,Value=$APPLICATION_NAME" "Key=Environment,Value=production" \
        >/dev/null
    
    echo "Waiting for stack operation to complete..."
    echo "This may take several minutes..."
    
    if aws cloudformation wait "$WAIT_CONDITION" --stack-name "$STACK_NAME" --region "$REGION"; then
        echo "✅ Stack operation completed successfully!"
    else
        echo "❌ Stack operation failed!"
        echo "Check the CloudFormation console for details:"
        echo "https://console.aws.amazon.com/cloudformation/home?region=$REGION#/stacks"
        exit 1
    fi
}

# Function to display stack outputs
display_outputs() {
    echo ""
    echo "Stack Outputs:"
    echo "=============="
    
    aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$REGION" \
        --query 'Stacks[0].Outputs[?OutputKey!=`null`].[OutputKey,OutputValue,Description]' \
        --output table
}

# Function to display next steps
display_next_steps() {
    echo ""
    echo "Next Steps:"
    echo "==========="
    echo "1. Build and push your Docker image to ECR:"
    echo "   ./build-and-push.sh --profile $PROFILE --region $REGION"
    echo ""
    echo "2. The EventBridge rule will automatically start triggering ECS tasks every 5 minutes"
    echo ""
    echo "3. Monitor the application logs in CloudWatch:"
    echo "   Log Group: /ecs/$APPLICATION_NAME"
    echo ""
    echo "4. Check ECS task execution in the AWS Console:"
    echo "   https://console.aws.amazon.com/ecs/home?region=$REGION#/clusters/$APPLICATION_NAME-cluster"
    echo ""
    echo "5. Monitor nested stack status in CloudFormation:"
    echo "   https://console.aws.amazon.com/cloudformation/home?region=$REGION#/stacks"
    echo ""
    echo "Nested Stack Architecture:"
    echo "========================="
    echo "✅ Main Stack: $STACK_NAME"
    echo "   ├── 📡 Networking Stack: VPC, Security Groups, VPC Endpoints"
    echo "   ├── 💻 Compute Stack: Windows EC2 with Embedded SMB Setup, EBS Volume, IAM Roles"
    echo "   └── 🚀 Application Stack: ECS Cluster, Task Definition, EventBridge"
    echo ""
    echo "S3 Template Storage: s3://$BUCKET_NAME/"
    echo "SMB Setup: Embedded in EC2 UserData (no S3 dependency)"
}

# Main execution
# Function to validate template size constraints
validate_template_sizes() {
    echo "🔍 Validating template size constraints..."
    echo "========================================"
    
    local templates=(
        "$TEMPLATE_FILE"
        "$NESTED_TEMPLATE_DIR/networking-stack.yaml"
        "$NESTED_TEMPLATE_DIR/compute-stack.yaml"
        "$NESTED_TEMPLATE_DIR/application-stack.yaml"
    )
    
    local size_errors=0
    local total_size=0
    local max_size=51200  # CloudFormation limit
    local recommended_max=30000  # Recommended limit for nested stacks
    
    for template in "${templates[@]}"; do
        if [[ -f "$template" ]]; then
            local template_name=$(basename "$template")
            local size=$(wc -c < "$template")
            ((total_size += size))
            
            echo "  📏 $template_name: $size bytes"
            
            if [[ $size -gt $max_size ]]; then
                echo "    ❌ Exceeds CloudFormation limit ($max_size bytes)"
                ((size_errors++))
            elif [[ $size -gt $recommended_max ]]; then
                echo "    ⚠️  Exceeds recommended limit ($recommended_max bytes)"
                echo "    💡 Consider refactoring to reduce size for future growth"
            else
                echo "    ✅ Size is within recommended limits"
            fi
        else
            echo "  ❌ Template not found: $(basename "$template")"
            ((size_errors++))
        fi
    done
    
    echo ""
    echo "📊 Size Summary:"
    echo "  Total combined size: $total_size bytes"
    echo "  Size validation errors: $size_errors"
    
    if [[ $size_errors -gt 0 ]]; then
        echo "❌ Template size validation failed with $size_errors error(s)"
        return 1
    else
        echo "✅ All templates pass size validation"
        return 0
    fi
}

# Function to validate cross-stack parameter passing
validate_cross_stack_parameters() {
    echo "🔍 Validating cross-stack parameter passing..."
    echo "============================================="
    
    local main_template="$TEMPLATE_FILE"
    local parameter_errors=0
    
    if [[ ! -f "$main_template" ]]; then
        echo "❌ Main template not found: $main_template"
        return 1
    fi
    
    echo "📋 Analyzing parameter passing between stacks..."
    
    # Check networking stack parameters
    echo "  🔍 Validating NetworkingStack parameters..."
    local required_networking_params=("VpcCidr" "PrivateSubnetCidr" "AvailabilityZone" "ApplicationName")
    
    for param in "${required_networking_params[@]}"; do
        if grep -A 10 "NetworkingStack:" "$main_template" | grep -q "$param:"; then
            echo "    ✅ $param - Parameter passed"
        else
            echo "    ❌ $param - Parameter not passed"
            ((parameter_errors++))
        fi
    done
    
    # Check compute stack parameters (note: S3BucketName no longer required for compute stack)
    echo "  🔍 Validating ComputeStack parameters..."
    local required_compute_params=("ApplicationName" "WindowsInstanceType" "SMBUsername" "SMBPassword" "AvailabilityZone")
    
    for param in "${required_compute_params[@]}"; do
        if grep -A 20 "ComputeStack:" "$main_template" | grep -q "$param:"; then
            echo "    ✅ $param - Parameter passed"
        else
            echo "    ❌ $param - Parameter not passed"
            ((parameter_errors++))
        fi
    done
    
    # Check if networking outputs are passed to compute stack
    local networking_to_compute=("VPCId" "PrivateSubnetId" "WindowsEC2SecurityGroupId")
    
    for output in "${networking_to_compute[@]}"; do
        if grep -A 20 "ComputeStack:" "$main_template" | grep -q "$output.*GetAtt.*NetworkingStack"; then
            echo "    ✅ $output - Networking output passed to ComputeStack"
        else
            echo "    ❌ $output - Networking output not passed to ComputeStack"
            ((parameter_errors++))
        fi
    done
    
    # Check application stack parameters
    echo "  🔍 Validating ApplicationStack parameters..."
    local required_app_params=("ApplicationName" "ECRRepositoryURI" "CPUArchitecture")
    
    for param in "${required_app_params[@]}"; do
        if grep -A 30 "ApplicationStack:" "$main_template" | grep -q "$param:"; then
            echo "    ✅ $param - Parameter passed"
        else
            echo "    ❌ $param - Parameter not passed"
            ((parameter_errors++))
        fi
    done
    
    # Check if networking and compute outputs are passed to application stack
    local dependency_outputs=("VPCId" "PrivateSubnetId" "ECSTaskSecurityGroupId" "WindowsEC2PrivateIP")
    
    for output in "${dependency_outputs[@]}"; do
        if grep -A 30 "ApplicationStack:" "$main_template" | grep -q "$output.*GetAtt"; then
            echo "    ✅ $output - Dependency output passed to ApplicationStack"
        else
            echo "    ❌ $output - Dependency output not passed to ApplicationStack"
            ((parameter_errors++))
        fi
    done
    
    echo ""
    if [[ $parameter_errors -eq 0 ]]; then
        echo "✅ All cross-stack parameter passing validation passed"
        return 0
    else
        echo "❌ Cross-stack parameter validation failed with $parameter_errors error(s)"
        return 1
    fi
}

# Function to validate export/import name consistency
validate_export_import_consistency() {
    echo "🔍 Validating export/import name consistency..."
    echo "=============================================="
    
    local templates=(
        "$NESTED_TEMPLATE_DIR/networking-stack.yaml"
        "$NESTED_TEMPLATE_DIR/compute-stack.yaml"
        "$NESTED_TEMPLATE_DIR/application-stack.yaml"
    )
    
    local main_template="$TEMPLATE_FILE"
    local consistency_errors=0
    
    echo "📤 Analyzing exports from nested stacks..."
    
    # Check that each nested stack has proper outputs for cross-stack references
    for template in "${templates[@]}"; do
        if [[ -f "$template" ]]; then
            local template_name=$(basename "$template" .yaml)
            echo "  📋 Checking: $template_name"
            
            # Check if template has Outputs section
            if grep -q "^Outputs:" "$template"; then
                echo "    ✅ Has Outputs section"
                
                # Count outputs
                local output_count=$(grep -A 1000 "^Outputs:" "$template" | grep -c "^  [A-Za-z]" || echo "0")
                echo "    📊 Number of outputs: $output_count"
                
                # Check for Export sections in outputs
                local export_count=$(grep -A 1000 "^Outputs:" "$template" | grep -c "Export:" || echo "0")
                if [[ $export_count -gt 0 ]]; then
                    echo "    ✅ Has $export_count exported output(s)"
                else
                    echo "    ⚠️  No exported outputs found"
                    echo "    💡 Consider adding exports for cross-stack references"
                fi
            else
                echo "    ❌ Missing Outputs section"
                ((consistency_errors++))
            fi
        else
            echo "  ❌ Template not found: $(basename "$template")"
            ((consistency_errors++))
        fi
    done
    
    echo ""
    echo "📥 Analyzing GetAtt references in main template..."
    
    if [[ -f "$main_template" ]]; then
        # Check GetAtt references to nested stack outputs
        local getatt_count=$(grep -c "GetAtt.*\.Outputs\." "$main_template" || echo "0")
        echo "  📊 GetAtt references found: $getatt_count"
        
        if [[ $getatt_count -gt 0 ]]; then
            echo "  ✅ Main template uses GetAtt for cross-stack references"
            
            # Validate specific GetAtt patterns
            local expected_patterns=(
                "NetworkingStack.Outputs"
                "ComputeStack.Outputs"
                "ApplicationStack.Outputs"
            )
            
            for pattern in "${expected_patterns[@]}"; do
                if grep -q "$pattern" "$main_template"; then
                    echo "    ✅ $pattern - Reference pattern found"
                else
                    echo "    ⚠️  $pattern - Reference pattern not found"
                fi
            done
        else
            echo "  ❌ No GetAtt references found in main template"
            echo "  💡 Main template should use GetAtt to access nested stack outputs"
            ((consistency_errors++))
        fi
    else
        echo "  ❌ Main template not found: $main_template"
        ((consistency_errors++))
    fi
    
    echo ""
    if [[ $consistency_errors -eq 0 ]]; then
        echo "✅ Export/import consistency validation passed"
        return 0
    else
        echo "❌ Export/import consistency validation failed with $consistency_errors error(s)"
        return 1
    fi
}

# Function to validate S3 template accessibility for CloudFormation
validate_s3_template_accessibility() {
    echo "🔍 Validating S3 template accessibility..."
    echo "========================================"
    
    if [[ -z "$BUCKET_NAME" ]]; then
        echo "❌ S3 bucket name not configured"
        return 1
    fi
    
    echo "📋 S3 Configuration: $BUCKET_NAME"
    
    # Test S3 bucket accessibility
    if ! aws s3api head-bucket --bucket "$BUCKET_NAME" --region "$REGION" 2>/dev/null; then
        echo "❌ Cannot access S3 bucket: $BUCKET_NAME"
        echo "Please run setup-nested-stacks.sh to create the bucket"
        return 1
    fi
    
    echo "✅ S3 bucket is accessible"
    
    # Test individual template accessibility
    local s3_errors=0
    
    echo ""
    echo "📄 Testing individual template accessibility..."
    
    # Test main template (in root)
    echo "  🔗 Testing: main-template.yaml"
    if aws s3api head-object --bucket "$BUCKET_NAME" --key "main-template.yaml" --region "$REGION" >/dev/null 2>&1; then
        local size=$(aws s3api head-object --bucket "$BUCKET_NAME" --key "main-template.yaml" --region "$REGION" --query 'ContentLength' --output text)
        local last_modified=$(aws s3api head-object --bucket "$BUCKET_NAME" --key "main-template.yaml" --region "$REGION" --query 'LastModified' --output text)
        
        echo "    ✅ Object exists in S3"
        echo "    📊 Size: $size bytes"
        echo "    🕒 Last modified: $last_modified"
        
        local s3_url="https://s3.amazonaws.com/$BUCKET_NAME/main-template.yaml"
        if curl -s --head "$s3_url" | grep -q "200 OK"; then
            echo "    ✅ HTTPS accessible"
        else
            echo "    ⚠️  HTTPS access may be restricted"
        fi
    else
        echo "    ❌ Not found in S3"
        ((s3_errors++))
    fi
    
    # Test nested templates (in templates/ subdirectory)
    local nested_s3_templates=(
        "networking-stack.yaml"
        "compute-stack.yaml"
        "application-stack.yaml"
    )
    
    for template_name in "${nested_s3_templates[@]}"; do
        echo "  🔗 Testing: $template_name"
        
        if aws s3api head-object --bucket "$BUCKET_NAME" --key "templates/$template_name" --region "$REGION" >/dev/null 2>&1; then
            local size=$(aws s3api head-object --bucket "$BUCKET_NAME" --key "templates/$template_name" --region "$REGION" --query 'ContentLength' --output text)
            local last_modified=$(aws s3api head-object --bucket "$BUCKET_NAME" --key "templates/$template_name" --region "$REGION" --query 'LastModified' --output text)
            
            echo "    ✅ Object exists in S3"
            echo "    📊 Size: $size bytes"
            echo "    🕒 Last modified: $last_modified"
            
            local s3_url="https://s3.amazonaws.com/$BUCKET_NAME/templates/$template_name"
            if command -v curl &> /dev/null; then
                if curl -s --head "$s3_url" | grep -q "200 OK"; then
                    echo "    ✅ HTTPS accessible for CloudFormation"
                else
                    echo "    ⚠️  HTTPS accessibility issue"
                    echo "    💡 Template may not be publicly accessible for CloudFormation"
                fi
            else
                echo "    ℹ️  curl not available - HTTPS test skipped"
            fi
        else
            echo "    ❌ Object not found in S3"
            ((s3_errors++))
        fi
        echo ""
    done
    
    if [[ $s3_errors -eq 0 ]]; then
        echo "✅ All templates are accessible in S3"
        return 0
    else
        echo "❌ S3 accessibility validation failed with $s3_errors error(s)"
        return 1
    fi
}

# Function to perform comprehensive cross-stack reference validation
perform_cross_stack_validation() {
    echo "🔍 Comprehensive Cross-Stack Reference Validation"
    echo "================================================"
    echo ""
    
    local validation_errors=0
    
    # Step 1: Template size validation
    echo "Step 1: Template Size Validation"
    echo "--------------------------------"
    if ! validate_template_sizes; then
        ((validation_errors++))
    fi
    echo ""
    
    # Step 2: Cross-stack parameter passing validation
    echo "Step 2: Cross-Stack Parameter Passing Validation"
    echo "------------------------------------------------"
    if ! validate_cross_stack_parameters; then
        ((validation_errors++))
    fi
    echo ""
    
    # Step 3: Export/import consistency validation
    echo "Step 3: Export/Import Consistency Validation"
    echo "--------------------------------------------"
    if ! validate_export_import_consistency; then
        ((validation_errors++))
    fi
    echo ""
    
    # Step 4: S3 template accessibility validation
    echo "Step 4: S3 Template Accessibility Validation"
    echo "--------------------------------------------"
    if ! validate_s3_template_accessibility; then
        ((validation_errors++))
    fi
    echo ""
    
    # Summary
    echo "📊 Cross-Stack Validation Summary"
    echo "================================="
    echo "Total validation errors: $validation_errors"
    
    if [[ $validation_errors -eq 0 ]]; then
        echo ""
        echo "🎉 All cross-stack reference validations passed!"
        echo "✅ The nested stack architecture is properly configured"
        echo "✅ Ready for deployment"
        return 0
    else
        echo ""
        echo "❌ Cross-stack reference validation failed with $validation_errors error(s)"
        echo "Please fix the issues above before proceeding with deployment"
        return 1
    fi
}

# Function to validate deployment configuration
validate_deployment_config() {
    echo "Validating deployment configuration..."
    echo "===================================="
    
    echo "📋 Deployment Configuration:"
    echo "  Application: $APPLICATION_NAME"
    echo "  Stack Name: $STACK_NAME"
    echo "  Region: $REGION"
    echo "  Profile: $PROFILE"
    echo "  Template: $TEMPLATE_FILE"
    echo "  S3 Bucket: $BUCKET_NAME"
    echo ""
    
    # Verify we're using the main template
    if [[ "$TEMPLATE_FILE" != *"main-template.yaml" ]]; then
        echo "❌ Error: Not using main template for nested stack deployment"
        echo "   Current template: $TEMPLATE_FILE"
        echo "   Expected: infrastructure/main-template.yaml"
        echo ""
        echo "The nested stack architecture requires using main-template.yaml as the primary template."
        exit 1
    fi
    
    echo "✅ Using correct main template: $(basename "$TEMPLATE_FILE")"
    
    # Verify nested template directory exists
    if [[ ! -d "$NESTED_TEMPLATE_DIR" ]]; then
        echo "❌ Nested template directory not found: $NESTED_TEMPLATE_DIR"
        exit 1
    fi
    
    echo "✅ Nested template directory exists: $NESTED_TEMPLATE_DIR"
    
    # S3 configuration is now retrieved from SSM Parameter Store
    echo "✅ S3 configuration will be loaded from SSM Parameter Store"
    echo ""
    echo "✅ Deployment configuration validated successfully"
}

echo "🚀 Starting nested stack deployment process..."
echo "=============================================="
echo ""

# Step 0: Validate deployment configuration
validate_deployment_config

# Step 1: Load S3 configuration and validate setup
load_s3_config

# Check S3 access and template availability (non-blocking)
if ! verify_s3_access; then
    echo "⚠️  Some templates may need to be uploaded to S3"
    echo "Continuing with template upload process..."
fi

# Step 2: Validate all templates before uploading
validate_nested_templates
validate_main_template

# Step 2.5: Perform comprehensive cross-stack reference validation
echo ""
echo "🔍 Step 2.5: Cross-Stack Reference Validation"
echo "============================================="
if ! perform_cross_stack_validation; then
    echo "❌ Cross-stack validation failed - cannot proceed with deployment"
    exit 1
fi

# Step 3: Upload nested templates to S3 with enhanced error handling
upload_nested_templates_with_retry

# Step 4: Validate parameters and prepare deployment
validate_parameters
get_ecr_uri
build_parameters

# Function to perform final pre-deployment validation
final_pre_deployment_validation() {
    echo "Performing final pre-deployment validation..."
    echo "============================================="

    # Verify all templates are now in S3
    echo "🔍 Final S3 template verification..."
    local final_check_failed=0
    
    # Check main template (in root)
    if ! aws s3api head-object --bucket "$BUCKET_NAME" --key "main-template.yaml" --region "$REGION" >/dev/null 2>&1; then
        echo "❌ Template not found in S3: main-template.yaml"
        ((final_check_failed++))
    else
        echo "✅ Confirmed in S3: main-template.yaml"
    fi
    
    # Check nested templates (in templates/ subdirectory)
    local nested_templates=("networking-stack.yaml" "compute-stack.yaml" "application-stack.yaml")
    for template_name in "${nested_templates[@]}"; do
        if ! aws s3api head-object --bucket "$BUCKET_NAME" --key "templates/$template_name" --region "$REGION" >/dev/null 2>&1; then
            echo "❌ Template not found in S3: $template_name"
            ((final_check_failed++))
        else
            echo "✅ Confirmed in S3: $template_name"
        fi
    done

    if [[ $final_check_failed -gt 0 ]]; then
        echo "❌ $final_check_failed template(s) missing from S3"
        echo "Cannot proceed with deployment"
        exit 1
    fi

    echo "✅ All templates confirmed in S3 and ready for deployment"
    echo ""
}

# Step 5: Final pre-deployment validation
final_pre_deployment_validation

# Step 6: Deploy the main stack
deploy_stack

# Step 7: Display results
display_outputs
display_next_steps

echo ""
echo "🎉 Nested stack deployment completed successfully!"
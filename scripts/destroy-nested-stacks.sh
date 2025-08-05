#!/bin/bash

# destroy-nested-stacks.sh - Clean up CloudFormation nested stacks infrastructure
# Usage: ./destroy-nested-stacks.sh --profile PROFILE_NAME [--region REGION] [--bucket-name BUCKET_NAME]

set -e

# Default values
REGION="us-east-1"
APPLICATION_NAME="scheduled-file-writer"
BUCKET_NAME=""
PROFILE=""
FORCE_DELETE=false

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
        --force)
            FORCE_DELETE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 --profile PROFILE_NAME [--region REGION] [--bucket-name BUCKET_NAME] [--force]"
            echo ""
            echo "Options:"
            echo "  --profile PROFILE_NAME    AWS profile to use (required)"
            echo "  --region REGION          AWS region (default: us-east-1)"
            echo "  --bucket-name BUCKET     S3 bucket name to destroy (optional)"
            echo "                           If not provided, will read from config file"
            echo "  --force                  Skip confirmation prompts"
            echo "  --help, -h               Show this help message"
            echo ""
            echo "This script destroys the CloudFormation nested stacks infrastructure:"
            echo "1. Deletes all objects from the S3 bucket (including versions)"
            echo "2. Removes the S3 bucket"
            echo "3. Cleans up local configuration files"
            echo ""
            echo "⚠️  WARNING: This action is irreversible!"
            echo "Make sure you have backups of your templates before running this script."
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

echo "🗑️  Destroying CloudFormation nested stacks infrastructure"
echo "Region: $REGION"
echo "Profile: $PROFILE"
echo ""

# Function to load bucket configuration
load_bucket_config() {
    local config_file="infrastructure/config/s3-bucket.conf"
    
    if [[ -z "$BUCKET_NAME" ]]; then
        # First try to load from SSM Parameter Store (new approach)
        echo "📖 Loading bucket configuration from SSM Parameter Store..."
        local ssm_param="/$APPLICATION_NAME/s3/bucket-name"
        
        if BUCKET_NAME=$(aws ssm get-parameter --name "$ssm_param" --query 'Parameter.Value' --output text --region "$REGION" 2>/dev/null); then
            echo "Found bucket in SSM: $BUCKET_NAME"
        else
            # Fallback to old config file approach
            if [[ -f "$config_file" ]]; then
                echo "📖 Loading bucket configuration from $config_file"
                source "$config_file"
                echo "Found bucket: $BUCKET_NAME"
            else
                # If neither SSM nor config file exists, try to generate bucket name like setup script does
                echo "📝 Generating bucket name using same logic as setup script..."
                local account_id=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null)
                if [[ -n "$account_id" ]]; then
                    BUCKET_NAME="cf-templates-${account_id}-${REGION}-${APPLICATION_NAME}"
                    echo "Generated bucket name: $BUCKET_NAME"
                else
                    echo "❌ Bucket name not provided and could not be determined automatically"
                    echo "Please provide --bucket-name parameter"
                    echo ""
                    echo "💡 You can find the bucket name by running:"
                    echo "  aws ssm get-parameter --name /$APPLICATION_NAME/s3/bucket-name --query 'Parameter.Value' --output text --profile $PROFILE"
                    echo "  OR"
                    echo "  aws s3 ls --profile $PROFILE | grep cf-templates"
                    exit 1
                fi
            fi
        fi
    fi
}

# Function to check if bucket exists
bucket_exists() {
    aws s3api head-bucket --bucket "$BUCKET_NAME" --region "$REGION" 2>/dev/null
}

# Function to confirm destruction
confirm_destruction() {
    if [[ "$FORCE_DELETE" == "true" ]]; then
        echo "🚨 Force delete enabled - skipping confirmation"
        return 0
    fi
    
    echo "⚠️  WARNING: You are about to destroy the nested stacks infrastructure!"
    echo ""
    echo "This will:"
    echo "  • Delete ALL objects in S3 bucket: $BUCKET_NAME"
    echo "  • Delete ALL object versions (if versioning is enabled)"
    echo "  • Remove the S3 bucket completely"
    echo "  • Clean up local configuration files"
    echo ""
    echo "This action is IRREVERSIBLE!"
    echo ""
    
    read -p "Are you sure you want to continue? Type 'DELETE' to confirm: " -r
    echo
    
    if [[ "$REPLY" != "DELETE" ]]; then
        echo "❌ Destruction cancelled"
        exit 0
    fi
    
    echo "✅ Destruction confirmed"
}

# Function to list bucket contents
list_bucket_contents() {
    echo "📋 Listing bucket contents..."
    
    local object_count=$(aws s3api list-objects-v2 --bucket "$BUCKET_NAME" --region "$REGION" --query 'length(Contents)' --output text 2>/dev/null || echo "0")
    local version_count=$(aws s3api list-object-versions --bucket "$BUCKET_NAME" --region "$REGION" --query 'length(Versions)' --output text 2>/dev/null || echo "0")
    
    echo "  Objects: $object_count"
    echo "  Versions: $version_count"
    
    if [[ "$object_count" != "0" ]] || [[ "$version_count" != "0" ]]; then
        echo ""
        echo "📄 Current objects:"
        aws s3 ls "s3://$BUCKET_NAME/" --region "$REGION" --recursive || true
    fi
}

# Function to delete all object versions
delete_all_versions() {
    echo "🗂️  Deleting all object versions..."
    
    # Get all versions and delete markers
    local versions=$(aws s3api list-object-versions --bucket "$BUCKET_NAME" --region "$REGION" --output json 2>/dev/null || echo '{}')
    
    # Delete all versions
    local version_keys=$(echo "$versions" | jq -r '.Versions[]? | {Key: .Key, VersionId: .VersionId}' 2>/dev/null || echo "")
    if [[ -n "$version_keys" ]]; then
        echo "$version_keys" | jq -s '.' | jq '{Objects: [.[] | {Key: .Key, VersionId: .VersionId}], Quiet: true}' > /tmp/delete-versions.json
        
        if [[ -s /tmp/delete-versions.json ]]; then
            echo "  Deleting object versions..."
            aws s3api delete-objects --bucket "$BUCKET_NAME" --delete file:///tmp/delete-versions.json --region "$REGION" >/dev/null
            echo "  ✅ Object versions deleted"
        fi
        
        rm -f /tmp/delete-versions.json
    fi
    
    # Delete all delete markers
    local delete_markers=$(echo "$versions" | jq -r '.DeleteMarkers[]? | {Key: .Key, VersionId: .VersionId}' 2>/dev/null || echo "")
    if [[ -n "$delete_markers" ]]; then
        echo "$delete_markers" | jq -s '.' | jq '{Objects: [.[] | {Key: .Key, VersionId: .VersionId}], Quiet: true}' > /tmp/delete-markers.json
        
        if [[ -s /tmp/delete-markers.json ]]; then
            echo "  Deleting delete markers..."
            aws s3api delete-objects --bucket "$BUCKET_NAME" --delete file:///tmp/delete-markers.json --region "$REGION" >/dev/null
            echo "  ✅ Delete markers removed"
        fi
        
        rm -f /tmp/delete-markers.json
    fi
}

# Function to delete all objects (current versions)
delete_all_objects() {
    echo "📦 Deleting all current objects..."
    
    # Use S3 sync with delete to remove all objects
    aws s3 rm "s3://$BUCKET_NAME/" --recursive --region "$REGION" --quiet
    
    echo "✅ All objects deleted"
}

# Function to delete the bucket
delete_bucket() {
    echo "🪣 Deleting S3 bucket: $BUCKET_NAME"
    
    # Remove bucket policy first (if it exists)
    aws s3api delete-bucket-policy --bucket "$BUCKET_NAME" --region "$REGION" 2>/dev/null || true
    
    # Remove bucket lifecycle configuration (if it exists)
    aws s3api delete-bucket-lifecycle --bucket "$BUCKET_NAME" --region "$REGION" 2>/dev/null || true
    
    # Remove bucket encryption (if it exists)
    aws s3api delete-bucket-encryption --bucket "$BUCKET_NAME" --region "$REGION" 2>/dev/null || true
    
    # Delete the bucket
    aws s3api delete-bucket --bucket "$BUCKET_NAME" --region "$REGION"
    
    echo "✅ S3 bucket deleted successfully"
}

# Function to clean up local files and SSM parameters
cleanup_local_files() {
    echo "🧹 Cleaning up local configuration files and SSM parameters..."
    
    local config_file="infrastructure/config/s3-bucket.conf"
    local readme_file="infrastructure/nested-stacks/README.md"
    
    # Clean up SSM parameter
    local ssm_param="/$APPLICATION_NAME/s3/bucket-name"
    if aws ssm get-parameter --name "$ssm_param" --region "$REGION" >/dev/null 2>&1; then
        aws ssm delete-parameter --name "$ssm_param" --region "$REGION" >/dev/null 2>&1
        echo "  ✅ Removed SSM parameter: $ssm_param"
    fi
    
    # Clean up old config file if it exists
    if [[ -f "$config_file" ]]; then
        rm -f "$config_file"
        echo "  ✅ Removed: $config_file"
    fi
    
    # Remove empty config directory if it exists
    if [[ -d "infrastructure/config" ]] && [[ -z "$(ls -A infrastructure/config)" ]]; then
        rmdir infrastructure/config
        echo "  ✅ Removed empty directory: infrastructure/config"
    fi
    
    # Remove auto-generated README if it exists and contains our marker
    if [[ -f "$readme_file" ]] && grep -q "Generated on:" "$readme_file" 2>/dev/null; then
        rm -f "$readme_file"
        echo "  ✅ Removed auto-generated: $readme_file"
    fi
    
    # Remove empty nested-stacks directory if it only contains auto-generated files
    if [[ -d "infrastructure/nested-stacks" ]]; then
        local remaining_files=$(find infrastructure/nested-stacks -type f | wc -l)
        if [[ "$remaining_files" -eq 0 ]]; then
            rmdir infrastructure/nested-stacks
            echo "  ✅ Removed empty directory: infrastructure/nested-stacks"
        else
            echo "  ℹ️  Kept directory with user files: infrastructure/nested-stacks"
        fi
    fi
}

# Function to verify destruction
verify_destruction() {
    echo "🔍 Verifying destruction..."
    
    if bucket_exists; then
        echo "❌ Bucket still exists - destruction may have failed"
        return 1
    else
        echo "✅ Bucket successfully removed"
    fi
    
    # Check SSM parameter
    local ssm_param="/$APPLICATION_NAME/s3/bucket-name"
    if aws ssm get-parameter --name "$ssm_param" --region "$REGION" >/dev/null 2>&1; then
        echo "⚠️  SSM parameter still exists: $ssm_param"
    else
        echo "✅ SSM parameter cleaned up"
    fi
    
    # Check old config file
    local config_file="infrastructure/config/s3-bucket.conf"
    if [[ -f "$config_file" ]]; then
        echo "⚠️  Configuration file still exists: $config_file"
    else
        echo "✅ Configuration files cleaned up"
    fi
    
    return 0
}

# Function to display summary
display_summary() {
    echo ""
    echo "🎯 Destruction Complete!"
    echo "======================="
    echo "✅ S3 bucket removed: $BUCKET_NAME"
    echo "✅ All objects and versions deleted"
    echo "✅ Local configuration cleaned up"
    echo ""
    echo "📋 What was destroyed:"
    echo "  • S3 bucket and all contents"
    echo "  • All object versions and delete markers"
    echo "  • Bucket policies and configurations"
    echo "  • SSM parameter: /$APPLICATION_NAME/s3/bucket-name"
    echo "  • Local configuration files"
    echo ""
    echo "💡 To recreate the infrastructure:"
    echo "  ./scripts/setup-nested-stacks.sh --profile $PROFILE --region $REGION"
    echo ""
    echo "⚠️  Remember to recreate your nested stack templates if needed!"
}

# Function to handle errors
handle_error() {
    local exit_code=$?
    echo ""
    echo "❌ Error occurred during destruction (exit code: $exit_code)"
    echo ""
    echo "🔧 Troubleshooting:"
    echo "  • Check AWS credentials and permissions"
    echo "  • Verify bucket name and region"
    echo "  • Some resources may have been partially deleted"
    echo "  • You may need to clean up remaining resources manually"
    echo ""
    echo "🔍 Manual cleanup commands:"
    echo "  # List remaining objects:"
    echo "  aws s3 ls s3://$BUCKET_NAME/ --recursive --profile $PROFILE"
    echo ""
    echo "  # Force delete bucket (if empty):"
    echo "  aws s3api delete-bucket --bucket $BUCKET_NAME --region $REGION --profile $PROFILE"
    
    exit $exit_code
}

# Set up error handling
trap handle_error ERR

# Main execution
echo "Starting nested stacks destruction process..."
echo ""

load_bucket_config

if ! bucket_exists; then
    echo "ℹ️  S3 bucket does not exist: $BUCKET_NAME"
    echo "Nothing to destroy in AWS, cleaning up local files..."
    cleanup_local_files
    echo ""
    echo "✅ Local cleanup completed"
    exit 0
fi

list_bucket_contents
confirm_destruction

echo ""
echo "🚀 Starting destruction process..."

delete_all_versions
delete_all_objects
delete_bucket
cleanup_local_files
verify_destruction
display_summary

echo ""
echo "🎉 Nested stacks infrastructure destroyed successfully!"
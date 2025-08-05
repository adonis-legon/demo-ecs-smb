#!/bin/bash

# destroy-stack.sh - Safely destroy CloudFormation stack and cleanup resources
# Usage: ./destroy-stack.sh --profile PROFILE_NAME [--region REGION] [--force]

set -e

# Default values
REGION="us-east-1"
APPLICATION_NAME="scheduled-file-writer"
STACK_NAME="$APPLICATION_NAME-stack"
PROFILE=""
FORCE=false

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
        --force)
            FORCE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 --profile PROFILE_NAME [--region REGION] [--force]"
            echo ""
            echo "Options:"
            echo "  --profile PROFILE_NAME    AWS profile to use (required)"
            echo "  --region REGION          AWS region (default: us-east-1)"
            echo "  --force                  Skip confirmation prompts"
            echo "  --help, -h               Show this help message"
            echo ""
            echo "This script safely destroys the CloudFormation stack and cleans up resources."
            echo "WARNING: This will permanently delete all infrastructure and data!"
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

echo "Preparing to destroy $APPLICATION_NAME stack in region $REGION using profile $PROFILE"

# Function to check if stack exists
check_stack_exists() {
    if aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to get stack status
get_stack_status() {
    aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "NOT_FOUND"
}

# Function to stop running ECS tasks
stop_ecs_tasks() {
    echo "Checking for running ECS tasks..."
    
    local cluster_name="$APPLICATION_NAME-cluster"
    
    # Check if cluster exists
    if ! aws ecs describe-clusters --clusters "$cluster_name" --region "$REGION" --query 'clusters[0].status' --output text 2>/dev/null | grep -q "ACTIVE"; then
        echo "ECS cluster not found or not active, skipping task cleanup"
        return 0
    fi
    
    # Get running tasks
    local running_tasks=$(aws ecs list-tasks --cluster "$cluster_name" --region "$REGION" --query 'taskArns' --output text 2>/dev/null || echo "")
    
    if [[ -n "$running_tasks" && "$running_tasks" != "None" ]]; then
        echo "Found running ECS tasks, stopping them..."
        for task in $running_tasks; do
            echo "  Stopping task: $(basename "$task")"
            aws ecs stop-task --cluster "$cluster_name" --task "$task" --region "$REGION" >/dev/null 2>&1 || true
        done
        
        echo "Waiting for tasks to stop..."
        sleep 10
    else
        echo "No running ECS tasks found"
    fi
}

# Function to disable EventBridge rule
disable_eventbridge_rule() {
    echo "Disabling EventBridge rule..."
    
    local rule_name="$APPLICATION_NAME-schedule"
    
    if aws events describe-rule --name "$rule_name" --region "$REGION" >/dev/null 2>&1; then
        echo "  Disabling rule: $rule_name"
        aws events disable-rule --name "$rule_name" --region "$REGION" >/dev/null 2>&1 || true
        echo "  EventBridge rule disabled"
    else
        echo "  EventBridge rule not found, skipping"
    fi
}

# Function to empty ECR repository
empty_ecr_repository() {
    echo "Checking ECR repository..."
    
    local repo_name="$APPLICATION_NAME"
    
    if aws ecr describe-repositories --repository-names "$repo_name" --region "$REGION" >/dev/null 2>&1; then
        echo "  Found ECR repository: $repo_name"
        
        # Get all image tags
        local image_tags=$(aws ecr list-images --repository-name "$repo_name" --region "$REGION" --query 'imageIds[].imageTag' --output text 2>/dev/null || echo "")
        
        if [[ -n "$image_tags" && "$image_tags" != "None" ]]; then
            echo "  Deleting images from ECR repository..."
            for tag in $image_tags; do
                echo "    Deleting image with tag: $tag"
                aws ecr batch-delete-image --repository-name "$repo_name" --image-ids imageTag="$tag" --region "$REGION" >/dev/null 2>&1 || true
            done
        fi
        
        # Delete untagged images
        local untagged_images=$(aws ecr list-images --repository-name "$repo_name" --filter tagStatus=UNTAGGED --region "$REGION" --query 'imageIds[].imageDigest' --output text 2>/dev/null || echo "")
        
        if [[ -n "$untagged_images" && "$untagged_images" != "None" ]]; then
            echo "  Deleting untagged images..."
            for digest in $untagged_images; do
                aws ecr batch-delete-image --repository-name "$repo_name" --image-ids imageDigest="$digest" --region "$REGION" >/dev/null 2>&1 || true
            done
        fi
        
        echo "  ECR repository cleaned"
    else
        echo "  ECR repository not found, skipping"
    fi
}

# Function to delete CloudFormation stack
delete_stack() {
    echo "Deleting CloudFormation stack..."
    
    aws cloudformation delete-stack --stack-name "$STACK_NAME" --region "$REGION"
    
    echo "Waiting for stack deletion to complete..."
    echo "This may take several minutes..."
    
    if aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME" --region "$REGION" 2>/dev/null; then
        echo "✅ Stack deleted successfully!"
    else
        echo "❌ Stack deletion may have failed or timed out"
        echo "Check the CloudFormation console for details:"
        echo "https://console.aws.amazon.com/cloudformation/home?region=$REGION#/stacks"
        
        local status=$(get_stack_status)
        if [[ "$status" == "DELETE_FAILED" ]]; then
            echo ""
            echo "Stack deletion failed. You may need to:"
            echo "1. Check for resources that couldn't be deleted"
            echo "2. Manually delete problematic resources"
            echo "3. Retry stack deletion"
            exit 1
        fi
    fi
}

# Function to cleanup parameters and secrets (optional)
cleanup_parameters() {
    if [[ "$FORCE" == true ]]; then
        local cleanup_params=true
    else
        echo ""
        read -p "Do you want to delete SSM parameters and Secrets Manager entries? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cleanup_params=true
        else
            cleanup_params=false
        fi
    fi
    
    if [[ "$cleanup_params" == true ]]; then
        echo "Cleaning up parameters and secrets..."
        
        # Delete SSM parameters
        local ssm_params=(
            "/$APPLICATION_NAME/network/vpc-cidr"
            "/$APPLICATION_NAME/network/private-subnet-cidr"
            "/$APPLICATION_NAME/network/availability-zone"
            "/$APPLICATION_NAME/smb/domain"
            "/$APPLICATION_NAME/smb/connection-timeout"
            "/$APPLICATION_NAME/smb/share-path"
        )
        
        for param in "${ssm_params[@]}"; do
            if aws ssm get-parameter --name "$param" --region "$REGION" >/dev/null 2>&1; then
                echo "  Deleting SSM parameter: $param"
                aws ssm delete-parameter --name "$param" --region "$REGION" >/dev/null 2>&1 || true
            fi
        done
        
        # Delete Secrets Manager secret
        local secret_name="$APPLICATION_NAME/smb-credentials"
        if aws secretsmanager describe-secret --secret-id "$secret_name" --region "$REGION" >/dev/null 2>&1; then
            echo "  Deleting secret: $secret_name"
            aws secretsmanager delete-secret --secret-id "$secret_name" --force-delete-without-recovery --region "$REGION" >/dev/null 2>&1 || true
        fi
        
        echo "  Parameters and secrets cleanup completed"
    else
        echo "Skipping parameters and secrets cleanup"
    fi
}

# Function to display confirmation
display_confirmation() {
    echo ""
    echo "⚠️  WARNING: This will permanently delete the following resources:"
    echo "   - CloudFormation stack: $STACK_NAME"
    echo "   - ECS cluster and all tasks"
    echo "   - Windows EC2 instance and EBS volume"
    echo "   - VPC and all networking resources"
    echo "   - IAM roles and policies"
    echo "   - CloudWatch log groups"
    echo "   - EventBridge rules"
    echo "   - ECR repository images"
    echo ""
    echo "This action cannot be undone!"
    echo ""
    
    if [[ "$FORCE" == true ]]; then
        echo "Force mode enabled, proceeding without confirmation..."
        return 0
    fi
    
    read -p "Are you sure you want to continue? Type 'DELETE' to confirm: " -r
    echo
    if [[ "$REPLY" == "DELETE" ]]; then
        return 0
    else
        echo "Operation cancelled"
        exit 0
    fi
}

# Main execution
echo "Starting destruction process..."
echo ""

# Check if stack exists
if ! check_stack_exists; then
    echo "Stack $STACK_NAME does not exist in region $REGION"
    echo "Nothing to delete"
    exit 0
fi

# Get current stack status
STACK_STATUS=$(get_stack_status)
echo "Current stack status: $STACK_STATUS"

# Check if stack is in a state that can be deleted
case "$STACK_STATUS" in
    "CREATE_IN_PROGRESS"|"UPDATE_IN_PROGRESS"|"DELETE_IN_PROGRESS")
        echo "Stack is currently in progress. Please wait for the operation to complete before deleting."
        exit 1
        ;;
    "ROLLBACK_IN_PROGRESS"|"UPDATE_ROLLBACK_IN_PROGRESS")
        echo "Stack is currently rolling back. Please wait for the rollback to complete before deleting."
        exit 1
        ;;
esac

display_confirmation

echo "Proceeding with stack destruction..."
echo ""

stop_ecs_tasks
disable_eventbridge_rule
empty_ecr_repository
delete_stack
cleanup_parameters

echo ""
echo "🎉 Destruction completed successfully!"
echo ""
echo "All resources have been cleaned up. You can now:"
echo "1. Verify in the AWS Console that all resources are deleted"
echo "2. Check your AWS bill to ensure no unexpected charges"
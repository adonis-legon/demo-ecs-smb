#!/bin/bash

# Build Docker image for Scheduled File Writer with optional push to registry
# Usage: ./build-docker.sh [OPTIONS]
# Examples:
#   ./build-docker.sh                    # Build only (default behavior)
#   ./build-docker.sh --push             # Build and push to ECR
#   ./build-docker.sh --version 2.0.0    # Build with specific version
#   ./build-docker.sh --push --ecr-registry 123...  # Build and push to specific ECR

set -e  # Exit on any error

# Get script directory for relative imports
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common Docker/Podman detection script
if [ -f "$SCRIPT_DIR/scripts/docker-common.sh" ]; then
    source "$SCRIPT_DIR/scripts/docker-common.sh"
else
    echo "Error: docker-common.sh not found. Please ensure scripts/docker-common.sh exists."
    exit 1
fi

# Configuration
IMAGE_NAME="scheduled-file-writer"
AWS_REGION="${AWS_REGION:-us-east-1}"
ECR_REGISTRY=""
PUSH_TO_ECR=false
DRY_RUN=false
SKIP_TESTS=false
VERSION_OVERRIDE=""  # Will be set if --version is provided
AWS_PROFILE=""  # Will be set if --profile is provided

# Function to extract version from pom.xml
get_pom_version() {
    local pom_file="pom.xml"
    
    if [ ! -f "$pom_file" ]; then
        print_error "pom.xml not found in current directory"
        exit 1
    fi
    
    # Extract version using grep and sed
    local version=$(grep -m1 '<version>' "$pom_file" | sed 's/.*<version>\(.*\)<\/version>.*/\1/' | tr -d '[:space:]')
    
    if [ -z "$version" ]; then
        print_error "Could not extract version from pom.xml"
        exit 1
    fi
    
    echo "$version"
}

# Function to get the final version to use
get_version() {
    if [ -n "$VERSION_OVERRIDE" ]; then
        echo "$VERSION_OVERRIDE"
    elif [ -n "${VERSION:-}" ] && [ "${VERSION:-}" != "" ]; then
        echo "$VERSION"
    else
        get_pom_version
    fi
}

# Function to check if Maven is available
check_maven() {
    if ! command -v mvn &> /dev/null; then
        print_error "Maven is not installed or not in PATH. Please install Maven to run tests."
        exit 1
    fi
}

# Function to run Maven tests
run_maven_tests() {
    if [ "$SKIP_TESTS" = true ]; then
        print_warning "⚠️  Skipping tests (--skip-tests flag provided)"
        return 0
    fi
    
    print_status "🧪 Running Maven tests..."
    
    if [ "$DRY_RUN" = true ]; then
        print_status "[DRY RUN] Would run: mvn test"
        return 0
    fi
    
    # Check if Maven is available
    check_maven
    
    # Run tests with proper error handling
    print_status "Executing: mvn test"
    if mvn test; then
        print_status "✅ All tests passed successfully!"
        return 0
    else
        print_error "❌ Tests failed! Docker build and push will be aborted."
        print_error "Please fix the failing tests before building the Docker image."
        exit 1
    fi
}

# Function to check if AWS CLI is available
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it to push to ECR."
        exit 1
    fi
}

# Function to get AWS account ID
get_aws_account_id() {
    local aws_cmd="aws sts get-caller-identity --query Account --output text"
    if [ -n "$AWS_PROFILE" ]; then
        aws_cmd="$aws_cmd --profile $AWS_PROFILE"
    fi
    
    eval "$aws_cmd" 2>/dev/null || {
        print_error "Failed to get AWS account ID. Please check your AWS credentials."
        if [ -n "$AWS_PROFILE" ]; then
            print_error "Make sure the AWS profile '$AWS_PROFILE' exists and has valid credentials."
        fi
        exit 1
    }
}

# Function to authenticate with ECR
ecr_login() {
    print_status "Authenticating with ECR..."
    
    local aws_cmd="aws ecr get-login-password --region $AWS_REGION"
    if [ -n "$AWS_PROFILE" ]; then
        aws_cmd="$aws_cmd --profile $AWS_PROFILE"
        print_status "Using AWS profile: $AWS_PROFILE"
    fi
    
    if ! eval "$aws_cmd" | $CONTAINER_RUNTIME login --username AWS --password-stdin "$ECR_REGISTRY"; then
        print_error "Failed to authenticate with ECR"
        if [ -n "$AWS_PROFILE" ]; then
            print_error "Make sure the AWS profile '$AWS_PROFILE' has ECR permissions."
        fi
        exit 1
    fi
    
    print_status "Successfully authenticated with ECR"
}

# Function to create ECR repository if it doesn't exist
create_ecr_repository() {
    print_status "Checking if ECR repository exists..."
    
    local aws_describe_cmd="aws ecr describe-repositories --repository-names $IMAGE_NAME --region $AWS_REGION"
    local aws_create_cmd="aws ecr create-repository --repository-name $IMAGE_NAME --region $AWS_REGION"
    
    if [ -n "$AWS_PROFILE" ]; then
        aws_describe_cmd="$aws_describe_cmd --profile $AWS_PROFILE"
        aws_create_cmd="$aws_create_cmd --profile $AWS_PROFILE"
    fi
    
    if eval "$aws_describe_cmd" > /dev/null 2>&1; then
        print_status "ECR repository '$IMAGE_NAME' already exists"
    else
        print_status "Creating ECR repository '$IMAGE_NAME'..."
        eval "$aws_create_cmd" > /dev/null
        print_status "ECR repository created successfully"
    fi
}

# Function to generate version tag
generate_version_tag() {
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local git_hash=""
    
    # Try to get git commit hash
    if git rev-parse --short HEAD > /dev/null 2>&1; then
        git_hash="-$(git rev-parse --short HEAD)"
    fi
    
    echo "${VERSION}-${timestamp}${git_hash}"
}

# Function to build the Docker image
build_image() {
    local base_tag="$1"
    print_status "Building Docker image: $base_tag"
    
    if [ "$DRY_RUN" = true ]; then
        print_status "[DRY RUN] Would build: $CONTAINER_RUNTIME build -t $base_tag ."
        return 0
    fi
    
    if $CONTAINER_RUNTIME build -t "$base_tag" .; then
        print_status "Successfully built image: $base_tag"
    else
        print_error "Failed to build Docker image"
        exit 1
    fi
}

# Function to tag image with multiple tags
tag_image() {
    local base_image="$1"
    local target_tag="$2"
    
    print_status "Tagging image $base_image as $target_tag"
    
    if [ "$DRY_RUN" = true ]; then
        print_status "[DRY RUN] Would tag: $CONTAINER_RUNTIME tag $base_image $target_tag"
        return 0
    fi
    
    $CONTAINER_RUNTIME tag "$base_image" "$target_tag"
}

# Function to push image to registry
push_image() {
    local image_tag="$1"
    print_status "Pushing image: $image_tag"
    
    if [ "$DRY_RUN" = true ]; then
        print_status "[DRY RUN] Would push: $CONTAINER_RUNTIME push $image_tag"
        return 0
    fi
    
    if $CONTAINER_RUNTIME push "$image_tag"; then
        print_status "Successfully pushed: $image_tag"
    else
        print_error "Failed to push: $image_tag"
        exit 1
    fi
}

# Function to validate local image
validate_image() {
    local image_tag="$1"
    print_status "Validating image: $image_tag"
    
    if [ "$DRY_RUN" = true ]; then
        print_status "[DRY RUN] Would validate image"
        return 0
    fi
    
    # Check if image exists
    if ! $CONTAINER_RUNTIME images "$image_tag" --format "{{.Repository}}:{{.Tag}}" | grep -q "$image_tag"; then
        print_error "Image $image_tag not found locally"
        return 1
    fi
    
    # Test run the container (quick validation)
    print_status "Testing container startup..."
    if $CONTAINER_RUNTIME run --rm "$image_tag" --help > /dev/null 2>&1; then
        print_status "Container validation passed"
    else
        print_warning "Container validation failed, but this might be expected for this application"
    fi
}

# Function to display image information
show_image_info() {
    local image="$1"
    print_status "Image information for $image:"
    
    if [ "$DRY_RUN" = true ]; then
        print_status "[DRY RUN] Would show image info"
        return 0
    fi
    
    $CONTAINER_RUNTIME images "$image" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
}

# Function to show help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Build Docker image for Scheduled File Writer with optional push to registry"
    echo ""
    echo "Options:"
    echo "  --push                     Push to ECR registry after building"
    echo "  --profile PROFILE_NAME     AWS profile to use for ECR operations (required when using --push)"
    echo "  --ecr-registry REGISTRY    ECR registry URL (e.g., 123456789012.dkr.ecr.us-east-1.amazonaws.com)"
    echo "  --version VERSION          Override image version (default: read from pom.xml)"
    echo "  --region REGION            AWS region (default: us-east-1)"
    echo "  --skip-tests               Skip Maven tests (not recommended for production)"
    echo "  --dry-run                  Show what would be done without executing"
    echo "  --help, -h                 Show this help message"
    echo ""
    echo "Environment variables:"
    echo "  ECR_REGISTRY              ECR registry URL"
    echo "  VERSION                   Override image version (default: read from pom.xml)"
    echo "  AWS_REGION                AWS region"
    echo ""
    echo "Examples:"
    echo "  $0                                           # Run tests, then build image locally"
    echo "  $0 --push --profile myprofile               # Run tests, then build and push to ECR using AWS profile"
    echo "  $0 --skip-tests                             # Build image without running tests"
    echo "  $0 --push --profile myprofile --region us-west-2  # Build and push to specific region"
    echo "  $0 --dry-run --push --profile myprofile     # Show what would be done (including test run)"
    echo "  $0 --version 2.0.0 --push --profile myprofile    # Build and push with custom version"
}

# Main execution
main() {
    # Determine version source before getting the version
    local version_source="pom.xml"
    if [ -n "$VERSION_OVERRIDE" ]; then
        version_source="command line"
    elif [ -n "${VERSION:-}" ] && [ "${VERSION:-}" != "" ]; then
        version_source="environment"
    fi
    
    # Get the version to use (from pom.xml by default, or override)
    VERSION=$(get_version)
    print_status "📋 Using version: $VERSION (from $version_source)"
    
    if [ "$PUSH_TO_ECR" = true ]; then
        print_status "🚀 Building and pushing Docker image for $IMAGE_NAME"
    else
        print_status "🔨 Building Docker image for $IMAGE_NAME"
    fi
    
    # Initialize container runtime
    if ! init_container_runtime; then
        exit 1
    fi
    
    if [ "$PUSH_TO_ECR" = true ]; then
        check_aws_cli
        
        # Validate AWS profile is provided when pushing
        if [ -z "$AWS_PROFILE" ]; then
            print_error "AWS profile is required when using --push. Use --profile PROFILE_NAME"
            exit 1
        fi
        
        # Set AWS profile environment variable for all AWS CLI commands
        export AWS_PROFILE="$AWS_PROFILE"
        print_status "Using AWS profile: $AWS_PROFILE"
        
        # Set ECR registry if not provided
        if [ -z "$ECR_REGISTRY" ]; then
            local account_id=$(get_aws_account_id)
            ECR_REGISTRY="${account_id}.dkr.ecr.${AWS_REGION}.amazonaws.com"
            print_status "Using ECR registry: $ECR_REGISTRY"
        fi
        
        # Authenticate and create repository
        if [ "$DRY_RUN" = false ]; then
            ecr_login
            create_ecr_repository
        fi
    fi
    
    # Run Maven tests before building Docker image
    run_maven_tests
    
    # Generate tags
    local base_tag="${IMAGE_NAME}:${VERSION}"
    local versioned_tag="${IMAGE_NAME}:$(generate_version_tag)"
    local latest_tag="${IMAGE_NAME}:latest"
    
    # Build base image
    build_image "$base_tag"
    
    # Create additional local tags
    tag_image "$base_tag" "$versioned_tag"
    tag_image "$base_tag" "$latest_tag"
    
    # Validate image
    validate_image "$base_tag"
    
    # Create ECR tags and push if requested
    if [ "$PUSH_TO_ECR" = true ]; then
        local ecr_base_tag="${ECR_REGISTRY}/${IMAGE_NAME}:${VERSION}"
        local ecr_versioned_tag="${ECR_REGISTRY}/${IMAGE_NAME}:$(generate_version_tag)"
        local ecr_latest_tag="${ECR_REGISTRY}/${IMAGE_NAME}:latest"
        
        # Tag for ECR
        tag_image "$base_tag" "$ecr_base_tag"
        tag_image "$base_tag" "$ecr_versioned_tag"
        tag_image "$base_tag" "$ecr_latest_tag"
        
        # Push to ECR
        push_image "$ecr_base_tag"
        push_image "$ecr_versioned_tag"
        push_image "$ecr_latest_tag"
        
        print_status "🎉 ECR images pushed successfully:"
        echo "  - $ecr_base_tag"
        echo "  - $ecr_versioned_tag"
        echo "  - $ecr_latest_tag"
    fi
    
    # Show final image information
    print_status "✅ Build completed successfully!"
    show_image_info "$IMAGE_NAME"
    
    print_status "📦 Local tags created:"
    echo "  - $base_tag"
    echo "  - $versioned_tag"
    echo "  - $latest_tag"
    
    if [ "$PUSH_TO_ECR" = false ]; then
        print_status "💡 To push to ECR, run:"
        echo "  $0 --push --profile YOUR_AWS_PROFILE"
    fi
    
    print_status "🚀 To run the container locally:"
    echo "  $CONTAINER_RUNTIME run --rm $base_tag"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --ecr-registry)
            ECR_REGISTRY="$2"
            shift 2
            ;;
        --push)
            PUSH_TO_ECR=true
            shift
            ;;
        --profile)
            AWS_PROFILE="$2"
            shift 2
            ;;
        --version)
            VERSION_OVERRIDE="$2"
            shift 2
            ;;
        --region)
            AWS_REGION="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Set ECR registry from environment if not set via command line
if [ -z "$ECR_REGISTRY" ] && [ -n "${ECR_REGISTRY_ENV:-}" ]; then
    ECR_REGISTRY="$ECR_REGISTRY_ENV"
fi

# Run main function
main
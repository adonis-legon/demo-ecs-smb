#!/bin/bash

# Common Docker/Podman utilities for the Scheduled File Writer project
# This script provides container runtime detection and common functions

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored status messages
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_debug() {
    if [ "${DEBUG:-false}" = "true" ]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# Function to detect container runtime (Docker or Podman)
detect_container_runtime() {
    if command -v docker &> /dev/null; then
        echo "docker"
    elif command -v podman &> /dev/null; then
        echo "podman"
    else
        print_error "Neither Docker nor Podman is installed or available in PATH"
        print_error "Please install Docker or Podman to build container images"
        exit 1
    fi
}

# Set the container runtime
CONTAINER_RUNTIME=$(detect_container_runtime)
print_debug "Using container runtime: $CONTAINER_RUNTIME"

# Function to check if container runtime is working
check_container_runtime() {
    print_debug "Checking if $CONTAINER_RUNTIME is working..."
    
    if ! $CONTAINER_RUNTIME version &> /dev/null; then
        print_error "$CONTAINER_RUNTIME is not working properly"
        print_error "Please ensure $CONTAINER_RUNTIME daemon is running and accessible"
        exit 1
    fi
    
    print_debug "$CONTAINER_RUNTIME is working correctly"
}

# Function to clean up dangling images
cleanup_dangling_images() {
    print_status "Cleaning up dangling images..."
    
    # Get dangling images
    local dangling_images=$($CONTAINER_RUNTIME images -f "dangling=true" -q)
    
    if [ -n "$dangling_images" ]; then
        print_status "Removing dangling images..."
        $CONTAINER_RUNTIME rmi $dangling_images || true
        print_status "Dangling images cleaned up"
    else
        print_status "No dangling images to clean up"
    fi
}

# Function to get image size
get_image_size() {
    local image="$1"
    $CONTAINER_RUNTIME images "$image" --format "{{.Size}}" | head -n1
}

# Function to get image ID
get_image_id() {
    local image="$1"
    $CONTAINER_RUNTIME images "$image" --format "{{.ID}}" | head -n1
}

# Function to check if image exists locally
image_exists_locally() {
    local image="$1"
    $CONTAINER_RUNTIME images "$image" --format "{{.Repository}}:{{.Tag}}" | grep -q "^${image}$"
}

# Function to validate image name format
validate_image_name() {
    local image_name="$1"
    
    # Basic validation for image name format
    if [[ ! "$image_name" =~ ^[a-z0-9]([a-z0-9._-]*[a-z0-9])?$ ]]; then
        print_error "Invalid image name format: $image_name"
        print_error "Image names must be lowercase and can contain letters, numbers, dots, dashes, and underscores"
        return 1
    fi
    
    return 0
}

# Function to validate tag format
validate_tag() {
    local tag="$1"
    
    # Basic validation for tag format
    if [[ ! "$tag" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        print_error "Invalid tag format: $tag"
        print_error "Tags can contain letters, numbers, dots, dashes, and underscores"
        return 1
    fi
    
    return 0
}

# Function to initialize container runtime (called by build scripts)
init_container_runtime() {
    print_debug "Initializing container runtime..."
    
    # Container runtime is already detected and set in CONTAINER_RUNTIME variable
    print_status "Using container runtime: $CONTAINER_RUNTIME"
    
    # Check if container runtime is working
    check_container_runtime
    
    return 0
}

# Initialize container runtime check
check_container_runtime

print_debug "docker-common.sh loaded successfully"
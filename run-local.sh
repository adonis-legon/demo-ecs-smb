#!/bin/bash

# Local development script for Scheduled File Writer
# This script manages the Docker Compose environment for local testing

set -e  # Exit on any error

# Source common Docker/Podman detection script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/scripts/docker-common.sh" ]; then
    source "$SCRIPT_DIR/scripts/docker-common.sh"
else
    echo "Error: docker-common.sh not found. Please ensure scripts/docker-common.sh exists."
    exit 1
fi

# Configuration
COMPOSE_FILE="docker-compose.yml"
ENV_FILE="local-dev/.env.local"
LOG_DIR="./logs"
SAMBA_CONTAINER="scheduled-file-writer-samba"
APP_CONTAINER="scheduled-file-writer-app"
TEST_CONTAINER="scheduled-file-writer-test"

# Set compose command based on container runtime
if [ "$CONTAINER_RUNTIME" = "podman" ]; then
    COMPOSE_COMMAND="podman-compose"
else
    COMPOSE_COMMAND="docker-compose"
fi

print_debug "Using compose command: $COMPOSE_COMMAND"

# Additional color for headers
BLUE='\033[0;34m'

print_header() {
    echo -e "${BLUE}[HEADER]${NC} $1"
}

# Function to check if a service is running
is_service_running() {
    local service_name="$1"
    # For podman-compose, check both the service name and container name
    $COMPOSE_COMMAND ps | grep -E "($service_name|scheduled-file-writer-samba)" | grep -q -E "(Up|healthy)"
}

# Function to create necessary directories
setup_directories() {
    print_status "Setting up directories..."
    mkdir -p "$LOG_DIR"
    mkdir -p "local-dev/samba-config"
}

# Function to copy environment file
setup_env() {
    if [ ! -f ".env" ] && [ -f "$ENV_FILE" ]; then
        print_status "Copying environment file..."
        cp "$ENV_FILE" ".env"
    fi
}

# Function to build the application image
build_app() {
    print_status "Building application Docker image..."
    $CONTAINER_RUNTIME build -t scheduled-file-writer:latest .
}

# Function to start the SMB server
start_samba() {
    print_status "Starting Samba server..."
    $COMPOSE_COMMAND up -d samba-server
    
    print_status "Waiting for Samba server to be ready..."
    local max_attempts=60  # Increased timeout
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        # Check if container is running first
        if ! is_service_running "samba-server"; then
            print_error "Samba container is not running"
            $COMPOSE_COMMAND logs samba-server
            return 1
        fi
        
        # Test SMB connection
        if $COMPOSE_COMMAND exec -T samba-server smbclient -L localhost -U testuser%testpass123 -m SMB3 > /dev/null 2>&1; then
            print_status "Samba server is ready!"
            
            # Additional verification - check if share is accessible
            if $COMPOSE_COMMAND exec -T samba-server smbclient //localhost/fileshare -U testuser%testpass123 -c "ls" > /dev/null 2>&1; then
                print_status "File share is accessible!"
                return 0
            else
                print_warning "Samba server is up but file share is not accessible yet..."
            fi
        fi
        
        if [ $((attempt % 10)) -eq 0 ]; then
            print_status "Still waiting... (attempt $attempt/$max_attempts)"
        else
            echo -n "."
        fi
        
        sleep 2
        attempt=$((attempt + 1))
    done
    
    print_error "Samba server failed to start within expected time"
    print_status "Showing recent logs for debugging:"
    $COMPOSE_COMMAND logs --tail=20 samba-server
    return 1
}

# Function to run a single test
run_test() {
    print_status "Running application test..."
    $COMPOSE_COMMAND --profile test run --rm test-runner
}

# Function to run the application manually
run_app() {
    print_status "Running application manually..."
    $COMPOSE_COMMAND --profile manual run --rm scheduled-file-writer
}

# Function to show logs
show_logs() {
    local service="${1:-}"
    if [ -n "$service" ]; then
        print_status "Showing logs for $service..."
        $COMPOSE_COMMAND logs -f "$service"
    else
        print_status "Showing all logs..."
        $COMPOSE_COMMAND logs -f
    fi
}

# Function to check SMB share contents
check_share() {
    print_status "Checking SMB share contents..."
    if $COMPOSE_COMMAND exec -T samba-server smbclient //localhost/fileshare -U testuser%testpass123 -c "ls" 2>/dev/null; then
        print_status "SMB share is accessible and contains the above files"
    else
        print_warning "Could not access SMB share or it's empty"
    fi
}

# Function to debug SMB connectivity
debug_smb() {
    print_header "SMB Connectivity Debug Information"
    
    # Check if samba container is running
    print_status "Checking Samba container status..."
    $COMPOSE_COMMAND ps | grep samba-server || print_warning "Samba container not found"
    
    # Check samba server logs
    print_status "Recent Samba server logs:"
    $COMPOSE_COMMAND logs --tail=20 samba-server
    
    # Check network connectivity
    print_status "Testing network connectivity to Samba server..."
    if $COMPOSE_COMMAND exec -T samba-server ping -c 2 localhost > /dev/null 2>&1; then
        print_status "✓ Localhost connectivity works"
    else
        print_error "✗ Localhost connectivity failed"
    fi
    
    # Check SMB ports
    print_status "Checking SMB ports..."
    $COMPOSE_COMMAND exec -T samba-server netstat -tlnp | grep -E "(445|139)" || print_warning "SMB ports not found"
    
    # Test SMB connection from within container
    print_status "Testing SMB connection from within Samba container..."
    if $COMPOSE_COMMAND exec -T samba-server smbclient -L localhost -U testuser%testpass123 -m SMB3; then
        print_status "✓ SMB connection works from within container"
    else
        print_error "✗ SMB connection failed from within container"
    fi
    
    # Check share permissions
    print_status "Checking share directory permissions..."
    $COMPOSE_COMMAND exec -T samba-server ls -la /shared
    
    # Test from app container perspective
    print_status "Testing connectivity from app container perspective..."
    if $COMPOSE_COMMAND run --rm test-runner ping -c 2 samba-server > /dev/null 2>&1; then
        print_status "✓ App can reach Samba server via hostname"
    else
        print_error "✗ App cannot reach Samba server via hostname"
    fi
}

# Function to clean up containers and volumes
cleanup() {
    print_status "Cleaning up containers and volumes..."
    $COMPOSE_COMMAND down -v
    $COMPOSE_COMMAND --profile test down -v
    $COMPOSE_COMMAND --profile manual down -v
    
    # Clean up any orphaned containers
    $CONTAINER_RUNTIME container prune -f > /dev/null 2>&1 || true
    
    print_status "Cleanup completed"
}

# Function to monitor application execution
monitor() {
    print_status "Starting monitoring mode..."
    print_status "Press Ctrl+C to stop monitoring"
    
    # Start samba server
    start_samba
    
    # Monitor loop
    while true; do
        print_header "Running scheduled test at $(date)"
        
        if run_test; then
            print_status "Test completed successfully"
        else
            print_warning "Test failed"
        fi
        
        print_status "Checking share contents:"
        check_share
        
        print_status "Waiting 30 seconds before next run..."
        sleep 30
    done
}

# Function to show help
show_help() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Local development script for Scheduled File Writer"
    echo ""
    echo "Commands:"
    echo "  start       Start the Samba server"
    echo "  test        Run a single test of the application"
    echo "  run         Run the application manually"
    echo "  monitor     Start monitoring mode (runs test every 30 seconds)"
    echo "  logs        Show logs from all services"
    echo "  logs <svc>  Show logs from specific service"
    echo "  check       Check SMB share contents"
    echo "  debug       Show SMB connectivity debug information"
    echo "  cleanup     Stop all containers and clean up volumes"
    echo "  build       Build the application Docker image"
    echo "  help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 start          # Start Samba server"
    echo "  $0 test           # Run single test"
    echo "  $0 monitor        # Start monitoring mode"
    echo "  $0 logs samba-server  # Show Samba server logs"
    echo "  $0 cleanup        # Clean up everything"
}

# Main execution
main() {
    local command="${1:-help}"
    
    case "$command" in
        start)
            if ! init_container_runtime; then
                exit 1
            fi
            setup_directories
            setup_env
            build_app
            start_samba
            print_status "Environment is ready! Use '$0 test' to run a test."
            ;;
        test)
            if ! init_container_runtime; then
                exit 1
            fi
            setup_directories
            setup_env
            if ! is_service_running "samba-server"; then
                print_status "Samba server not running, starting it first..."
                build_app
                start_samba
            fi
            run_test
            print_status "Checking results:"
            check_share
            ;;
        run)
            if ! init_container_runtime; then
                exit 1
            fi
            setup_directories
            setup_env
            if ! is_service_running "samba-server"; then
                print_status "Samba server not running, starting it first..."
                build_app
                start_samba
            fi
            run_app
            ;;
        monitor)
            if ! init_container_runtime; then
                exit 1
            fi
            setup_directories
            setup_env
            build_app
            monitor
            ;;
        logs)
            if ! init_container_runtime; then
                exit 1
            fi
            show_logs "$2"
            ;;
        check)
            if ! init_container_runtime; then
                exit 1
            fi
            check_share
            ;;
        debug)
            if ! init_container_runtime; then
                exit 1
            fi
            debug_smb
            ;;
        cleanup)
            if ! init_container_runtime; then
                exit 1
            fi
            cleanup
            ;;
        build)
            if ! init_container_runtime; then
                exit 1
            fi
            build_app
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Handle Ctrl+C gracefully
trap 'print_status "Interrupted by user"; cleanup; exit 0' INT

# Run main function
main "$@"
#!/bin/bash

# Script to run DRP, DRP Adapter, and RGD data source services
# Usage: ./run-services.sh [drp|adapter|rgd|all]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRP_DIR="${SCRIPT_DIR}/drp/data-sources/drp-api"
DRP_ADAPTER_DIR="${SCRIPT_DIR}/drp/data-sources/drp-api-adapter"
RGD_DIR="${SCRIPT_DIR}/rgd/data-sources/rgd-api"

# Function to print colored messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to check if required commands exist
check_requirements() {
    local missing_deps=false

    if [ "$1" == "drp" ] || [ "$1" == "adapter" ] || [ "$1" == "all" ]; then
        if ! command -v bal &> /dev/null; then
            print_error "Ballerina is not installed. Please install it to run DRP services."
            print_info "Visit: https://ballerina.io/downloads/"
            missing_deps=true
        fi
    fi

    if [ "$1" == "rgd" ] || [ "$1" == "all" ]; then
        if ! command -v python3 &> /dev/null; then
            print_error "Python 3 is not installed. Please install it to run RGD service."
            missing_deps=true
        fi
    fi

    if [ "$missing_deps" = true ]; then
        exit 1
    fi
}

# Function to run DRP service
run_drp() {
    print_info "Starting DRP API service..."

    if [ ! -d "$DRP_DIR" ]; then
        print_error "DRP directory not found at: $DRP_DIR"
        exit 1
    fi

    cd "$DRP_DIR"

    if [ ! -f "Config.toml" ]; then
        print_error "Config.toml not found in DRP directory"
        exit 1
    fi

    print_info "Running Ballerina service on port 9090..."
    print_success "DRP API starting at http://localhost:9090"
    bal run
}

# Function to run DRP Adapter service
run_drp_adapter() {
    print_info "Starting DRP API Adapter service..."

    if [ ! -d "$DRP_ADAPTER_DIR" ]; then
        print_error "DRP Adapter directory not found at: $DRP_ADAPTER_DIR"
        exit 1
    fi

    cd "$DRP_ADAPTER_DIR"

    if [ ! -f "Config.toml" ]; then
        print_error "Config.toml not found in DRP Adapter directory"
        exit 1
    fi

    print_info "Running Ballerina adapter service on port 9091..."
    print_success "DRP API Adapter starting at http://localhost:9091"
    print_info "GraphQL endpoint: http://localhost:9091/graphql"
    bal run
}

# Function to run RGD service
run_rgd() {
    print_info "Starting RGD API service..."

    if [ ! -d "$RGD_DIR" ]; then
        print_error "RGD directory not found at: $RGD_DIR"
        exit 1
    fi

    cd "$RGD_DIR"

    # Check if virtual environment exists, if not create it
    if [ ! -d "venv" ]; then
        print_info "Virtual environment not found. Creating one..."
        python3 -m venv venv
    fi

    # Activate virtual environment
    print_info "Activating virtual environment..."
    source venv/bin/activate

    # Install/update dependencies
    if [ -f "requirements.txt" ]; then
        print_info "Installing/updating dependencies..."
        pip install -q -r requirements.txt
    fi

    print_info "Running Python FastAPI/GraphQL service on port 8080..."
    print_success "RGD API starting at http://localhost:8080"
    print_info "GraphQL endpoint: http://localhost:8080/graphql"
    print_info "API docs: http://localhost:8080/docs"
    python3 main.py
}

# Function to run all services in parallel
run_all() {
    print_info "Starting DRP, DRP Adapter, and RGD services..."
    print_warning "Running services in parallel. Press Ctrl+C to stop all services."

    # Create a trap to kill all background processes on exit
    trap 'kill $(jobs -p) 2>/dev/null; print_info "Stopping all services..."; exit' INT TERM EXIT

    # Run DRP in background
    (
        print_info "[DRP] Starting in background..."
        run_drp
    ) &
    DRP_PID=$!

    # Wait a moment before starting the adapter
    sleep 2

    # Run DRP Adapter in background
    (
        print_info "[DRP Adapter] Starting in background..."
        run_drp_adapter
    ) &
    DRP_ADAPTER_PID=$!

    # Wait a moment before starting RGD
    sleep 2

    # Run RGD in background
    (
        print_info "[RGD] Starting in background..."
        run_rgd
    ) &
    RGD_PID=$!

    print_success "All services started!"
    print_info "DRP API: http://localhost:9090"
    print_info "DRP Adapter (GraphQL): http://localhost:9091"
    print_info "RGD API: http://localhost:8080"
    print_info "Press Ctrl+C to stop all services"

    # Wait for all processes
    wait $DRP_PID $DRP_ADAPTER_PID $RGD_PID
}

# Function to display usage
show_usage() {
    echo "Usage: $0 [drp|adapter|rgd|all]"
    echo ""
    echo "Commands:"
    echo "  drp      - Run only the DRP API service (Ballerina, port 9090)"
    echo "  adapter  - Run only the DRP API Adapter (Ballerina/GraphQL, port 9091)"
    echo "  rgd      - Run only the RGD API service (Python/FastAPI, port 8080)"
    echo "  all      - Run all services in parallel (default)"
    echo ""
    echo "Examples:"
    echo "  $0 drp       # Run only DRP service"
    echo "  $0 adapter   # Run only DRP Adapter service"
    echo "  $0 rgd       # Run only RGD service"
    echo "  $0 all       # Run all services"
    echo "  $0           # Run all services (same as 'all')"
}

# Main script logic
main() {
    local command="${1:-all}"

    case "$command" in
        drp)
            check_requirements "drp"
            run_drp
            ;;
        adapter)
            check_requirements "adapter"
            run_drp_adapter
            ;;
        rgd)
            check_requirements "rgd"
            run_rgd
            ;;
        all)
            check_requirements "all"
            run_all
            ;;
        -h|--help|help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown command: $command"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
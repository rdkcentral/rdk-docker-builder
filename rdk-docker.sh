#!/bin/bash
# Copyright 2025 RDK Management
# SPDX-License-Identifier: Apache-2.0

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DEFAULT_TARGET="raspberrypi"
DEFAULT_LAYER="vendor"
DEFAULT_BRANCH="develop"
IMAGE_NAME="rdk-layer-builder"
CONTAINER_NAME="${CONTAINER_NAME:-rdk-layer-builder}"

# CLI variables
LAYER=""
LAYER_REPOS=""

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"
}

get_input() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    
    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " input
        if [ -z "$input" ]; then
            input="$default"
        fi
    else
        read -p "$prompt: " input
    fi
    
    eval "$var_name='$input'"
}

show_usage() {
    cat << EOF
RDK Docker Builder (Unofficial Community Tool)

Usage: $0 [OPTIONS] <command>

Commands:
    create_image      Create the RDK Layer Builder Docker Image
    setup             Runs generate-rdk-build-env to create RDK layer build config: build.env (runs outside container)
    run               Run the RDK Layer Build Process (runs inside container using build.env from setup step)
    run dependency    Generate dependency graph instead of building (inside container)
    run bolt-package  Build/sign Bolt package only
    sync              Sync the configured layer without building (inside container)
    shell             Drop into a shell in a container instance
    help              Show this help

Options:
    -l, --layer LAYER                  Specify the layer to build (oss/vendor/middleware/application/image-assembler)
    -b, --branch BRANCH                Specify the manifest branch (default: develop)
    -r, --layer-repos REPOS            Specify repository types per layer (e.g., "oss:remote,vendor:local,...")
    --genBoltPackages                  Enable Bolt package build
    --bolt-pkg-script-branch           Specify Bolt branch (default: develop)
    --include-bolt-package             To include bolt packages in IA build.

Examples:
    $0 create_image
    $0 setup                           # Interactive mode
    $0 setup -l oss -b develop         # Build OSS layer with develop branch
    $0 setup --genBoltPackages --bolt-pkg-script-branch develop # Build bolt package with develop branch
    $0 -l application -r "oss:remote,vendor:remote,middleware:local,application:local" setup
    $0 setup -l image-assembler -b develop --include-bolt-package # To include bolt packages in IA build.
    $0 setup -l image-assembler -b develop --include-bolt-package --boltappconfig </home/rdk/workspace/factory-app-version.json>  # Uses a local JSON file and the file path must be accessible inside the Docker container.
    $0 setup -l image-assembler -b develop --include-bolt-package --boltappconfig <https://abc.json> # Uses a user-provided remote JSON URL. The JSON file is downloaded and used during the IA build.
    $0 run                             # Run build process
    $0 run dependency                  # Generate dependency graph
    $0 run bolt-package                # Build/sign Bolt package only
EOF
}

create_image() {
    print_info "Building RDK Docker image ..."
    
    local user_id=$(id -u)
    local group_id=$(id -g)
    
    docker build \
        --build-arg USER_ID="$user_id" \
        --build-arg GROUP_ID="$group_id" \
        --build-arg USERNAME="rdk" \
        --platform linux/amd64 \
        -t "$IMAGE_NAME" .
    
    print_success "RDK Docker image built: $IMAGE_NAME"
}

# Helper function to check if local IPK directory exists and has content
check_local_ipk_available() {
    local layer=$1
    local ipk_path=""

    # Read config to get the ipk directory path
    local ipk_dir=$(grep "ipk-dir:" config.yaml | awk -F': ' '{print $2}' | tr -d '"' | envsubst)

    case "$layer" in
        "oss")
            ipk_path="$ipk_dir/rdk-arm64-oss/${OSS_IPK_VERSION}/ipk"
            ;;
        "vendor")
            ipk_path="$ipk_dir/raspberrypi4-64-rdke-vendor/${VENDOR_IPK_VERSION}/ipk"
            ;;
        "middleware")
            ipk_path="$ipk_dir/raspberrypi4-64-rdke-middleware/${MIDDLEWARE_IPK_VERSION}/ipk"
            ;;
        "application")
            ipk_path="$ipk_dir/raspberrypi4-64-rdke-application/${APPLICATION_IPK_VERSION}/ipk"
            ;;
    esac

    if [ -d "$ipk_path" ] && [ "$(ls -A "$ipk_path" 2>/dev/null)" ]; then
        return 0  # Local available
    else
        return 1  # Local not available
    fi
}


python_setup() {
    print_info "Installing python dependencies (outside container)..."

    # Ensure Mako is installed
    if python3 -c "import mako" 2>/dev/null; then
        print_info "Mako is already installed."
    else
        print_info "Mako not found. Installing..."
        pip3 install mako || {
            print_error "Failed to install Mako."
            exit 1
        }
    fi

    # Ensure jsonschema is installed
    if python3 -c "import jsonschema" 2>/dev/null; then
        print_info "jsonschema  is already installed."
    else
        print_info "jsonschema not found. Installing..."
        pip3 install jsonschema || {
            print_error "Failed to install jsonschema."
            exit 1
        }
    fi

    # Ensure PyYaml is installed
    if python3 -c "import pyyaml" 2>/dev/null; then
        print_info "pyyaml  is already installed."
    else
        print_info "PyYaml not found. Installing..."
        pip3 install pyyaml || {
            print_error "Failed to install pyyaml."
            exit 1
        }
    fi

     export PATH="$PATH:$HOME/.local/bin"
}

# function: setup()
setup() {
    print_info "Running RDK setup (outside container)..."

    # setup python venv
    if [ ! -d .venv ]; then
         # requires python3-venv
         print_info "Creating python venv"
         python3 -m venv .venv
    fi

    # activate python venv
    . .venv/bin/activate
    python_setup
    
    if [ "$GEN_BOLT_PACKAGES" = "true" ]; then

        print_info "Generating build.env for Bolt package build..."

        LAYER="${LAYER:-image-assembler}"
        REPO_MANIFEST_BRANCH="${REPO_MANIFEST_BRANCH:-develop}"

        eval "./generate-rdk-build-env --layer $LAYER --branch \"$REPO_MANIFEST_BRANCH\" > build.env" || {
            print_error "Failed to generate build.env for Bolt packages"
            exit 1
        }

        print_success "Setup completed for building Bolt script packages"
        return
    fi

    # Get layer if not provided via CLI
    if [ -z "$LAYER" ]; then
        get_input "Enter layer to build (oss/vendor/middleware/application/image-assembler)" "$DEFAULT_LAYER" "LAYER"
    fi

    # Get branch if not provided via CLI
    if [ -z "$REPO_MANIFEST_BRANCH" ]; then
        get_input "Enter branch to build (develop, feature, hotfix, tags)" "$DEFAULT_BRANCH" "REPO_MANIFEST_BRANCH"
    fi

    # Handle per-layer repository selection
    local layer_repos_arg=""
    if [ -n "$LAYER_REPOS" ]; then
        # Use provided layer repos from CLI
        layer_repos_arg="--layer-repos \"$LAYER_REPOS\""
    else
        # Interactive mode: always ask for each layer
        local repo_config=""
        for layer in oss vendor middleware application; do
            # Default to local
            local use_local=true

            # Inform if local IPKs are available (optional)
            if check_local_ipk_available "$layer"; then
                print_info "Local IPK packages available for $layer layer"
            fi

            # Append to repo_config
            if [ -n "$repo_config" ]; then
                repo_config="${repo_config},"
            fi
            if [ "$use_local" = "true" ]; then
                repo_config="${repo_config}${layer}:local"
            else
                repo_config="${repo_config}${layer}:remote"
            fi
        done

        if [ -n "$repo_config" ]; then
            layer_repos_arg="--layer-repos \"$repo_config\""
        fi
    fi

    # Generate build.env
    eval "./generate-rdk-build-env --layer $LAYER --branch "$REPO_MANIFEST_BRANCH" $layer_repos_arg > build.env"
    
    # deactivate python venv
    deactivate

    print_success "Setup completed for $LAYER layer"
 
}


docker_run_command() {
    local command="$1"
    local description="$2"
    local interactive="${3:-false}"

    [ "$interactive" = "false" ] && print_info "$description"

    # Check if build.env exists (except for shell command)
    if [ "$command" != "shell" ] && [ ! -f "build.env" ]; then
        print_error "build.env not found. Please run '$0 setup' first"
        exit 1
    fi

    # Ensure image name
    IMAGE_NAME="${IMAGE_NAME:-rdk-layer-builder:latest}"
    if [ -z "$IMAGE_NAME" ]; then
        print_error "IMAGE_NAME is not set. Export IMAGE_NAME or set a default."
        exit 1
    fi

    # Provide a safe default container name (or remove --name entirely)
    if [ -z "$CONTAINER_NAME" ] || [ "$CONTAINER_NAME" = "rdk-layer-builder" ]; then
        CONTAINER_NAME="rdk-layer-builder-$(date +%Y-%m-%d_%H.%M.%S)"
    fi

    local user_id group_id workspace docker_opts
    user_id="$(id -u)"
    group_id="$(id -g)"
    workspace="$(pwd)"

    if [ "$interactive" = "true" ]; then
        docker_opts="-it --rm --name $CONTAINER_NAME --user $user_id:$group_id"
    else
        docker_opts="--rm --name $CONTAINER_NAME --user $user_id:$group_id"
    fi

    docker run $docker_opts \
        -v "$workspace:/home/rdk/workspace" \
        -v "$HOME/.ssh:/home/rdk/.ssh:ro" \
        -v "$HOME/.gitconfig:/home/rdk/.gitconfig:ro" \
        -v "$HOME/.netrc:/home/rdk/.netrc:ro" \
        -v "$HOME/ipks:/home/rdk/ipks" \
        -e USER_ID="$user_id" \
        -e GROUP_ID="$group_id" \
        -e REPO_MANIFEST_BRANCH="${REPO_MANIFEST_BRANCH:-}" \
        -e MANIFEST_FILE="${MANIFEST_FILE:-}" \
        -e LAYER="${LAYER:-}" \
        --platform linux/amd64 \
        "$IMAGE_NAME" "$command"
}

run() {
    docker_run_command "build" "Running RDK build (inside container)..."
}

run_dependency() {
    docker_run_command "dependency" "Running RDK dependency graph generation (inside container)..."
}

run_bolt_package() {
    docker_run_command "bolt-package" "Running Bolt package build (inside container)..."
}

sync() {
    docker_run_command "sync" "Running RDK layer sync (inside container)..."
}

shell() {
    print_info "Shell in RDK container..."
    docker_run_command "shell" "Starting shell in RDK container..." "true"
}

cleanup() {
    print_info "Received interrupt signal, cleaning up..."
    docker stop "$CONTAINER_NAME" >/dev/null
    exit 130
}

trap cleanup SIGINT SIGTERM

USE_BOLT_PACKAGE=false
# Parse command line options
while [[ $# -gt 0 ]]; do
    case $1 in
        setup|run|create_image|shell|sync|help)
            COMMAND="$1"
            shift
            ;;
        -l|--layer)
            LAYER="$2"
            shift 2
            ;;
        -b|--branch)
            REPO_MANIFEST_BRANCH="$2"
            shift 2
            ;;
        -r|--layer-repos)
            LAYER_REPOS="$2"
            shift 2
            ;;
        --genBoltPackages)
            GEN_BOLT_PACKAGES=true
            shift
            ;;
        --bolt-pkg-script-branch)
            BOLT_PKG_SCRIPT_BRANCH="$2"
            shift 2
            ;;
        --include-bolt-package)

            USE_BOLT_PACKAGE=true

            if [ "$2" = "--boltappconfig" ] && [ -n "$3" ]; then
                INCLUDE_BOLT_PACKAGE="$3"
                shift 3
            else
                unset INCLUDE_BOLT_PACKAGE
                shift 1
            fi
	    ;;
        *)
            break
            ;;
    esac
done

export GEN_BOLT_PACKAGES
export BOLT_PKG_SCRIPT_BRANCH
export USE_BOLT_PACKAGE
export INCLUDE_BOLT_PACKAGE

# If no command was provided, show usage
if [ -z "$COMMAND" ]; then
    show_usage
    exit 0
fi

case "$COMMAND" in
    create_image)
        create_image
        ;;
    setup)
        setup
        ;;
    run)
    case "$1" in
        dependency)
            run_dependency
            ;;
        bolt-package)
            run_bolt_package
            ;;
        *)
            run
	    ;;
        esac
        ;;
    sync)
        sync
        ;;
    shell)
        shell
        ;;
    help|--help)
        show_usage
        ;;
    *)
        print_warning "Unknown command: $COMMAND"
        show_usage
        exit 1
        ;;
esac

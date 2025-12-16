#!/bin/bash
# Copyright 2025 RDK Management
# SPDX-License-Identifier: Apache-2.0

set -e 

# Color output functions
print_info() { echo -e "\033[1;34m[INFO]\033[0m $1"; }
print_success() { echo -e "\033[1;32m[SUCCESS]\033[0m $1"; }
print_warning() { echo -e "\033[1;33m[WARNING]\033[0m $1"; }
print_error() { echo -e "\033[1;31m[ERROR]\033[0m $1"; }

extract_bitbake_envs() {
    local recipe=$1
    [ -z "$recipe" ] && { echo "Error: Recipe name is required" >&2; return 1; }
    
    local env=$(bitbake -e "$recipe")
    BUILD_IPK_DIR=$(echo "$env" | grep "^DEPLOY_DIR_IPK=" | cut -d'=' -f2 | tr -d '"')
    IPK_ARCH=$(echo "$env" | grep "^SSTATE_PKGARCH=" | cut -d'=' -f2 | tr -d '"')
    PACKAGE_ARCH=$(echo "$env" | grep "^PACKAGE_ARCH=" | cut -d'=' -f2 | tr -d '"')
    OPKG_MAKE_INDEX=$(ls "$BUILDDIR"/tmp/work/x86_64-linux/opkg-utils-native/*/git/opkg-make-index 2>/dev/null | head -1)

    ls "$BUILDDIR"/tmp/work/x86_64-linux/opkg-utils-native/*/git/opkg-make-index
}

setup_git_config() {
    for config in "user.name:.git_user" "user.email:.git_email"; do
        IFS=':' read -r git_key file_name <<< "$config"
        if [ -z "$(git config --global $git_key)" ]; then
            if [ -f "/home/rdk/workspace/$file_name" ]; then
                value=$(cat "/home/rdk/workspace/$file_name")
            else
                read -p "Enter your git ${git_key#user.}: " value
                echo "$value" > "/home/rdk/workspace/$file_name"
            fi
            git config --global $git_key "$value"
        fi
    done
}

setup_credentials() {
    if [ ! -f /home/rdk/workspace/.netrc ] && [ ! -f ~/.netrc ]; then
        print_info "Setting up RDK credentials..."
        read -p "Setup RDK Central credentials? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            read -p "Enter your RDK Central email: " RDK_EMAIL
            read -s -p "Enter your RDK Central PAT: " RDK_PAT
            echo
            cat > /home/rdk/workspace/.netrc << EOF
machine code.rdkcentral.com
    login $RDK_EMAIL
    password $RDK_PAT
machine github.com
    login $RDK_EMAIL
    password $RDK_PAT
EOF
            chmod 600 /home/rdk/workspace/.netrc
            cp /home/rdk/workspace/.netrc ~/.netrc
            print_success "Credentials saved to /home/rdk/workspace/.netrc"
        fi
    elif [ -f /home/rdk/workspace/.netrc ] && [ ! -f ~/.netrc ]; then
        cp /home/rdk/workspace/.netrc ~/.netrc && chmod 600 ~/.netrc
    fi
}

# Get layer configuration details
get_layer_config() {
    local layer_name=$1
    local layer_prefix=${1//-/_}
    layer_prefix=${layer_prefix^^}


    manifest_url_var="${layer_prefix}_MANIFEST_URL"
    manifest_file_var="${layer_prefix}_MANIFEST_FILE"
    ipk_path_var="${layer_prefix}_IPK_PATH"

    package_name="lib32-packagegroup-${layer_name}-layer"
    image_name="lib32-${layer_name}-test-image"

    # Layer-specific defaults and branch variable mapping
    case "$layer_name" in
        "oss")
            branch_var="OSS_BRANCH"
            manifest_dir="rdke-oss-manifest"
            image_name="core-image-minimal"
            ;;
        "vendor")
            branch_var="MANIFEST_BRANCH"
            manifest_dir="vendor-manifest-raspberrypi"
            ;;
        "middleware")
            branch_var="MANIFEST_BRANCH"
            manifest_dir="middleware-manifest-rdke"
            ;;
        "application")
            branch_var="MANIFEST_BRANCH"
            manifest_dir="application-manifest-rdke"
            ;;
        "image-assembler")
            branch_var="MANIFEST_BRANCH"
            manifest_dir="image-assembler-manifest-rdke"
            package_name=
            image_name="lib32-rdk-fullstack-image"
            ;;
        *)
            branch_var="MANIFEST_BRANCH"
            manifest_dir="${layer_name}-manifest-rdke"
            ;;
    esac
}

# Initialize or sync layer repository

init_or_sync_layer() {

    local layer_name="${1:?layer_name is required}"

    # Load per-layer config (must set branch_var, manifest_dir, manifest_url_var, manifest_file_var, etc.)
    get_layer_config "$layer_name"

    local layer_dir="/home/rdk/workspace/${layer_name}-layer"
    mkdir -p "$layer_dir" && cd "$layer_dir"

    # --- Validate required variables provided by get_layer_config() ---
    if [ -z "${branch_var:-}" ] || [ -z "${manifest_url_var:-}" ] || [ -z "${manifest_file_var:-}" ]; then
        echo "[ERROR] branch_var/manifest_url_var/manifest_file_var not set by get_layer_config()" >&2
        exit 1
    fi
    if [ -z "${!branch_var:-}" ]; then
        echo "[ERROR] ${branch_var} is empty. For '${layer_name}', export OSS_BRANCH (oss) or MANIFEST_BRANCH (others)." >&2
        exit 1
    fi
    if [ -z "${!manifest_url_var:-}" ]; then
        echo "[ERROR] ${manifest_url_var} is empty. Ensure your environment/build.env provides per-layer manifest URLs." >&2
        exit 1
    fi

    # --- Resolve manifest file ---
    local manifest_file=""
    if [ -n "${MANIFEST_FILE:-}" ]; then
        manifest_file="${MANIFEST_FILE}"
    elif [ -n "${!manifest_file_var:-}" ]; then
        manifest_file="${!manifest_file_var}"
    else
        echo "[ERROR] No manifest file resolved for layer '${layer_name}'. Tried: MANIFEST_FILE and ${manifest_file_var}." >&2
        exit 1
    fi

    # validate manifest file exists
    if [[ -f "$manifest_file" ]]; then
        : # ok, local file
    else
        if [[ "$manifest_file" == */* ]] && [[ ! -f "$manifest_file" ]]; then
            echo "[WARN] Manifest '$manifest_file' not found locally; assuming repo manifest name." >&2
        fi
    fi

    # --- Compute revision (tag or branch) ---
    local REVISION_MODE_LOCAL="${REVISION_MODE:-tag}"
    local revision=""
    case "${REVISION_MODE_LOCAL}" in
        tag)    revision="refs/tags/${!branch_var}" ;;
        branch) revision="${!branch_var}" ;;
        *)      echo "[ERROR] REVISION_MODE must be 'tag' or 'branch' (got: '${REVISION_MODE_LOCAL}')." >&2; exit 1 ;;
    esac

    # --- Determine init vs sync ---
    local repo_dir="$layer_dir/.repo"
    local existing_dir=""
    if [ -d "$repo_dir" ]; then
        existing_dir="$repo_dir"
    elif [ -n "${manifest_dir:-}" ] && [ -d "${manifest_dir}" ]; then
        existing_dir="${manifest_dir}"
    fi

    # --- Layer Config Logging ---
    echo "[INFO] Layer: ${layer_name}"
    echo "  REVISION_MODE=${REVISION_MODE_LOCAL}"
    echo "  branch_var=${branch_var} → ${!branch_var}"
    echo "  manifest_url_var=${manifest_url_var} → ${!manifest_url_var}"
    echo "  manifest_file_var=${manifest_file_var} → ${!manifest_file_var:-<unset>}"
    echo "  MANIFEST_FILE (override)=${MANIFEST_FILE:-<unset>}"
    echo "  manifest_file (effective)=${manifest_file}"
    echo "  manifest_dir (configured)=${manifest_dir:-<unset>}"
    echo "  using existing_dir=${existing_dir:-<none>}"
    echo "  revision=${revision}"

    # --- Ensure 'repo' tool is available ---
    if ! command -v repo >/dev/null 2>&1; then
        echo "[ERROR] 'repo' tool not found in PATH. Ensure the container image installs Android repo." >&2
        exit 1
    fi

    # --- Init or Sync ---
    if [ -z "$existing_dir" ]; then
        echo "[INFO] Initializing ${layer_name} manifest..."
        # Use -b "${revision}" with 'repo init' (supports branches and refs/tags/..)
        repo init -u "${!manifest_url_var}" -b "${revision}" -m "${manifest_file}" || {
            echo "[ERROR] repo init failed" >&2; exit 1;
        }
        repo sync --no-clone-bundle --no-tags -j"$(nproc 2>/dev/null || echo 8)" || {
            echo "[ERROR] repo sync failed" >&2; exit 1;
        }
    else
        echo "[INFO] Syncing existing ${layer_name} repositories..."
        cd "$existing_dir" || { echo "[ERROR] Cannot cd to $existing_dir" >&2; exit 1; }
        repo sync --no-clone-bundle --no-tags -j"$(nproc 2>/dev/null || echo 8)" || {
            echo "[ERROR] repo sync failed" >&2; exit 1;
        }
    fi
}


build_layer() {
    local layer_name="$1"

    # Get layer configuration
    get_layer_config "$layer_name"

    echo "Building layer: ${layer_name}"
    print_info "Building $layer_name layer..."

    # Initialize or sync repositories
    init_or_sync_layer "$layer_name"

    # Return to the layer workdir before sourcing env
    local layer_dir="/home/rdk/workspace/${layer_name}-layer"
    cd "$layer_dir" || { print_error "Cannot cd to $layer_dir"; exit 1; }

    # Configure and build
    configure_ipk_feeds "$layer_name"

    print_info "Setting up $layer_name build environment..."
    MACHINE="$MACHINE" source ./scripts/setup-environment "$BUILD_DIR"
    echo "BUILDDIR=$BUILDDIR"

    # Add DEPLOY_IPK_FEED for non-OSS layers
    if [ "$layer_name" != "oss" ]; then
        echo 'DEPLOY_IPK_FEED = "1"' >> conf/local.conf
    fi

    if [ "$layer_name" = "oss" ]; then
       cat >> conf/local.conf <<EOF

# Fix error when building OSS core-image-minimal image, where
# custom-rootfs-creation.bbclass is throwing Python exceptions
# See https://github.com/rdkcentral/meta-stack-layering-support/pull/84
IMAGE_CLASSES:remove = "custom-rootfs-creation"
ROOTFS_POSTPROCESS_COMMAND:remove = "pull_license_frm_artifactory"
USER_CLASSES:remove = "create_fw_version_file"
EOF
    fi

    print_info "Building $layer_name packages..."

    local package_build_status=0

    if [ -z "$package_name" ]; then
        print_error "No package name configured for layer: $layer_name. Check get_layer_config function."
        package_build_status=1
    else
        print_info "Building $layer_name packages..."
        bitbake "$package_name"
        package_build_status=$?
    fi

    # Handle package build result
    if [ "$package_build_status" -ne 0 ]; then
        print_error "Package build failed or package name was empty — continuing to image build."
    else
        print_success "Package build succeeded."
    fi
    
    local image_build_status=0

    if [ -z "$image_name" ]; then
        print_error "No image name configured for layer: $layer_name. Check get_layer_config() function."
        image_build_status=1
    else
        print_info "Building $layer_name image..."
        bitbake "$image_name"
        image_build_status=$?
    fi

    # Handle test image build result
    if [ "$image_build_status" -ne 0 ]; then
        print_error "Image build failed or image name was empty. "
    else
        print_success "Image build succeeded for layer: $layer_name"
    fi

    if [ "$layer_name" != "image-assembler" ]; then
        extract_bitbake_envs "$package_name"
        create_ipk_feed "$layer_name"
    else
        print_info "Final image will be in your IA build output."
    fi

    print_success "$layer_name layer build completed!"
}


# TODO: this needs to be simplified the IPK paths should be set using site.conf

configure_ipk_feeds() {
    local layer=$1
    
    # Determine which paths to use based on per-layer REPO_TYPE
    local oss_path vendor_path middleware_path application_path
    
    if [ "$OSS_REPO_TYPE" = "remote" ]; then
        oss_path="$OSS_IPK_SERVER_URL"
    else
        oss_path="file:/$OSS_IPK_PATH"
    fi
    
    if [ "$VENDOR_REPO_TYPE" = "remote" ]; then
        vendor_path="$VENDOR_IPK_SERVER_URL"
    else
        vendor_path="file:/$VENDOR_IPK_PATH"
    fi
    
    if [ "$MIDDLEWARE_REPO_TYPE" = "remote" ]; then
        middleware_path="$MIDDLEWARE_IPK_SERVER_URL"
    else
        middleware_path="file:/$MIDDLEWARE_IPK_PATH"
    fi
    
    if [ "$APPLICATION_REPO_TYPE" = "remote" ]; then
        application_path="$APPLICATION_IPK_SERVER_URL"
    else
        application_path="file:/$APPLICATION_IPK_PATH"
    fi
    
    print_info "Configuring IPK feeds (OSS:$OSS_REPO_TYPE, Vendor:$VENDOR_REPO_TYPE, MW:$MIDDLEWARE_REPO_TYPE, App:$APPLICATION_REPO_TYPE)"
    
    case "$layer" in
        "oss") 
            ;;  # No dependencies
        "vendor")
            sed -i "s|OSS_IPK_SERVER_PATH = \".*\"|OSS_IPK_SERVER_PATH = \"$oss_path\"|" \
                rdke/common/meta-oss-reference-release/conf/machine/include/oss.inc
            ;;
        "middleware")
            sed -i "s|OSS_IPK_SERVER_PATH = \".*\"|OSS_IPK_SERVER_PATH = \"$oss_path\"|" \
                rdke/common/meta-oss-reference-release/conf/machine/include/oss.inc
	    sed -i "s|VENDOR_IPK_SERVER_PATH ?= \".*\"|VENDOR_IPK_SERVER_PATH = \"$vendor_path\"|" \
		rdke/vendor/meta-vendor-release/conf/machine/include/vendor.inc
            sed -i "s|VENDOR_IPK_SERVER_PATH = \".*\"|VENDOR_IPK_SERVER_PATH = \"$vendor_path\"|" \
                rdke/vendor/meta-vendor-release/conf/machine/include/vendor.inc
            ;;
        "application")
            sed -i "s|OSS_IPK_SERVER_PATH = \".*\"|OSS_IPK_SERVER_PATH = \"$oss_path\"|" \
                rdke/common/meta-oss-reference-release/conf/machine/include/oss.inc
            sed -i "s|VENDOR_IPK_SERVER_PATH = \".*\"|VENDOR_IPK_SERVER_PATH = \"$vendor_path\"|" \
                rdke/vendor/meta-vendor-release/conf/machine/include/vendor.inc
	    sed -i "s|MW_IPK_SERVER_PATH ?= \".*\"|MW_IPK_SERVER_PATH = \"$middleware_path\"|" \
                rdke/middleware/meta-middleware-release/conf/machine/include/middleware.inc
            sed -i "s|MW_IPK_SERVER_PATH = \".*\"|MW_IPK_SERVER_PATH = \"$middleware_path\"|" \
                rdke/middleware/meta-middleware-release/conf/machine/include/middleware.inc
            ;;
        "image-assembler")
            sed -i "s|OSS_IPK_SERVER_PATH = \".*\"|OSS_IPK_SERVER_PATH = \"$oss_path\"|" \
                rdke/common/meta-oss-reference-release/conf/machine/include/oss.inc
            sed -i "s|VENDOR_IPK_SERVER_PATH = \".*\"|VENDOR_IPK_SERVER_PATH = \"$vendor_path\"|" \
                rdke/vendor/meta-vendor-release/conf/machine/include/vendor.inc
	    sed -i "s|MW_IPK_SERVER_PATH ?= \".*\"|MW_IPK_SERVER_PATH = \"$middleware_path\"|" \
                rdke/middleware/meta-middleware-release/conf/machine/include/middleware.inc
            sed -i "s|MW_IPK_SERVER_PATH = \".*\"|MW_IPK_SERVER_PATH = \"$middleware_path\"|" \
                rdke/middleware/meta-middleware-release/conf/machine/include/middleware.inc
	    sed -i "s|APPLICATION_IPK_SERVER_PATH ?= \".*\"|APPLICATION_IPK_SERVER_PATH = \"$application_path\"|" \
                rdke/application/meta-application-release/conf/machine/include/application.inc
            sed -i "s|APPLICATION_IPK_SERVER_PATH = \".*\"|APPLICATION_IPK_SERVER_PATH = \"$application_path\"|" \
                rdke/application/meta-application-release/conf/machine/include/application.inc
            ;;
    esac
}

create_ipk_feed() {
    local layer=$1
    local ipk_path_var="${layer^^}_IPK_PATH"
    local ipk_path="${!ipk_path_var}"
    
    print_info "Creating $layer IPK feed..."
    print_info "Starting IPK feed creation"
    print_info "Layer           : ${layer}"
    print_info "IPK path var    : ${ipk_path_var}"
    print_info "Resolved IPK dir: ${ipk_path}"

    if [ -d "${ipk_path}" ]; then
        print_info "Directory already exists: ${ipk_path}"
    else
        print_info "Creating directory: ${ipk_path}"
        if mkdir -p "${ipk_path}"; then
            print_info "Successfully created: ${ipk_path}"
        else
            print_warning "Failed to create directory: ${ipk_path}"
            return 1
        fi
    fi

    print_info "BUILD_IPK_DIR   : ${BUILD_IPK_DIR}"
    print_info "PACKAGE_ARCH    : ${PACKAGE_ARCH}"
    print_info "OPKG_MAKE_INDEX : ${OPKG_MAKE_INDEX}"
    
    if [ "$layer" = "oss" ]; then
        # OSS layer has special handling
        if [ -f "$OPKG_MAKE_INDEX" ]; then
	    print_info "Creating package index at ${BUILD_IPK_DIR}/${PACKAGE_ARCH}"
            (
             cd "${BUILD_IPK_DIR}/${PACKAGE_ARCH}" || exit 1
             "${OPKG_MAKE_INDEX}" > Packages .
             gzip -c9 Packages > Packages.gz
            )

            # Sync the arch directory to the destination feed
            rsync -av "${BUILD_IPK_DIR}/${PACKAGE_ARCH}/" "${ipk_path}/"
            print_info "Synced ${BUILD_IPK_DIR}/${PACKAGE_ARCH}/ -> ${ipk_path}/"
        else
            print_warning "opkg-make-index not found, skipping package index creation"
        fi
    else
        # Other layers
	print_info "==> Non-OSS layer handling"
        print_info "Source directory        : ${BUILD_IPK_DIR}/${PACKAGE_ARCH}/"
        print_info "Destination feed directory: ${ipk_path}"
        rsync -av "$BUILD_IPK_DIR/$PACKAGE_ARCH/" "$ipk_path"
    fi
}

sync_layer() {
    local layer_name=$1
    
    # Get layer configuration
    get_layer_config "$layer_name"
    
    echo "Syncing layer: ${layer_name}"
    print_info "Syncing $layer_name layer..."
    
    # Initialize or sync repositories
    init_or_sync_layer "$layer_name"
    
    print_success "$layer_name layer sync completed!"
}

generate_dependency_graph() {
    local layer_name=$1
    local layer_prefix=${1//-/_}
    layer_prefix=${layer_prefix^^}

    local image_name="lib32-${layer_name}-test-image"
    
    # Handle special cases
    case "$layer_name" in
        "oss")
              image_name="core-image-minimal"
              ;;
        "image-assembler")
            local image_name="lib32-rdk-fullstack-image"
            ;;
    esac
    
    print_info "Generating dependency graph for $layer_name layer..."
    
    # Setup directory and environment
    local layer_dir="/home/rdk/workspace/${layer_name}-layer"
    cd "$layer_dir"
    
    print_info "Setting up $layer_name build environment..."
    MACHINE="$MACHINE" source ./scripts/setup-environment $BUILD_DIR
    
    print_info "Generating dependency graph for $image_name..."
    bitbake -g "$image_name"
    
    print_info "Creating reduced dependency graph"
    oe-depends-dot -r task-depends.dot
    print_info "Creating package layer list: package-layers.txt"
    bitbake-layers show-recipes > package-layers.txt

    print_success "Dependency graph generation completed for layer: $layer_name"
}

run_dependency() {
    [ ! -f /home/rdk/workspace/build.env ] && {
        print_error "No build.env found. Please run setup first"
        exit 1
    }
    
    print_info "Sourcing build environment..."
    source /home/rdk/workspace/build.env
    print_info "Generating dependency graph for layer: $LAYER"
    
    case "$LAYER" in
        "oss"|"vendor"|"middleware"|"application"|"image-assembler")
            generate_dependency_graph "$LAYER"
            ;;
        *)
            print_error "Unsupported layer: $LAYER"
            exit 1
            ;;
    esac
}

run_sync() {
    [ ! -f /home/rdk/workspace/build.env ] && {
        print_error "No build.env found. Please run setup first"
        exit 1
    }
    
    print_info "Sourcing build environment..."
    source /home/rdk/workspace/build.env
    print_info "Syncing RDK for layer: $LAYER"
    
    case "$LAYER" in
        "oss"|"vendor"|"middleware"|"application"|"image-assembler")
            sync_layer "$LAYER"
            ;;
        *)
            print_error "Unsupported layer: $LAYER"
            exit 1
            ;;
    esac
}

run_build() {
    [ ! -f /home/rdk/workspace/build.env ] && {
        print_error "No build.env found. Please run setup first"
        exit 1
    }
    
    print_info "Sourcing build environment..."
    source /home/rdk/workspace/build.env
    print_info "Building RDK for layer: $LAYER"
    
    case "$LAYER" in
        "oss"|"vendor"|"middleware"|"application"|"image-assembler")
            build_layer "$LAYER"
            ;;
        *)
            print_error "Unsupported layer: $LAYER"
            exit 1
            ;;
    esac
    
    print_success "RDK build completed for layer: $LAYER"
}

main() {
    print_info "RDK Docker Builder Environment"
    print_info "Workspace: /home/rdk/workspace"
    print_info "User: $(whoami) (UID: $(id -u), GID: $(id -g))"
    
    if [ $# -gt 0 ]; then
        print_info "Running in unsupervised mode"
        case "$1" in
            "build") run_build ;;
            "dependency") run_dependency ;;
            "sync") run_sync ;;
            "shell") exec /bin/bash ;;
            *) print_info "Executing command: $@"; exec "$@" ;;
        esac
    else
        print_info "Running in interactive mode"
        setup_git_config
        setup_credentials
        
        if [ -f /home/rdk/workspace/build.env ]; then
            print_info "Build environment found. You can source it with: source build.env"
            print_info "Or run the build with: ./entrypoint.sh build"
        else
            print_warning "No build.env found. Please run setup first"
        fi
        
        print_info "Starting interactive shell..."
        print_info "Available commands:"
        print_info "  source build.env - Source the build environment (if available)"
        print_info "  ./entrypoint.sh build - Run the build process"
        print_info "  bitbake <target> - Run bitbake commands"
        print_info "  repo <command> - Run repo commands"
        print_info "  exit - Exit the container"
        echo
        
        exec /bin/bash
    fi
}

main "$@"

# Copyright 2025 RDK Management
# SPDX-License-Identifier: Apache-2.0
#
# RDK Build Environment Configuration
# Generated on ${timestamp.isoformat()}
<%
    import os
    import re

    # For the OSS layer, use rdk-oss.xml for develop/feature branches and for version tags >= 4.9.0; otherwise use rdk-arm.xml.
    OSS_VERSION_CUTOFF = (4, 9, 0)
    ARM_MANIFEST = 'rdk-arm.xml'
    OSS_MANIFEST = 'rdk-oss.xml'

    def get_oss_manifest(manifest_branch):
        if not manifest_branch:
            return ARM_MANIFEST

        branch = manifest_branch.lower()

        # OSS branches
        if branch == 'develop' or branch.startswith('feature'):
            return OSS_MANIFEST

        # Version check
        match = re.search(r'(\d+)\.(\d+)\.(\d+)', branch)
        if match:
            major, minor, patch = map(int, match.groups())
            if (major, minor, patch) >= OSS_VERSION_CUTOFF:
                return OSS_MANIFEST

        return ARM_MANIFEST

    # Target/LAYER (env-first)
    target_env = os.environ.get('TARGET', build['target'])
    layer_env  = os.environ.get('LAYER', target_layer)

    # Branches (env-first)
    manifest_branch_env = os.environ.get('REPO_MANIFEST_BRANCH', target_branch)

    # OSS can be consumed as either source (new consumption model) or IPK feed (existing consumption model)
    if layer_env == "oss":
        enable_oss_source = "false"
    elif manifest_branch_env.startswith(("RDK7", "refs/tags/RDK7")) or manifest_branch_env in ["support/rdk7-main", "2026-M1", "2026-M2", "2025-Q3", "2025-Q4"]:
        enable_oss_source = "false"
    else:
        enable_oss_source = os.environ.get("ENABLE_OSS_SOURCE", "true")

    # ENABLE_APPLICATION_LAYER to manage application layer dependencies from IA builds.
    if layer_env == "image-assembler":
        clean_branch = manifest_branch_env.replace("refs/tags/", "")
        match = re.fullmatch(r'(\d+)\.(\d+)\.(\d+)', clean_branch)

        if (
            manifest_branch_env.startswith(("RDK7", "refs/tags/RDK7")) or
            manifest_branch_env in ["support/rdk7-main", "2026-M1", "2026-M2", "2025-Q3", "2025-Q4"] or
            (not clean_branch.startswith("RDK") and match and tuple(map(int, clean_branch.split("."))) <= (4, 1, 1))
        ):
            enable_application_layer = "true"
        else:
            enable_application_layer = os.environ.get("ENABLE_APPLICATION_LAYER", "false")
    else:
        # For non-image-assembler layers, application layer dependencies are not managed
        enable_application_layer = "false"

    # Manifest files: check for global override from environment variable MANIFEST_FILE, if this is set, it will take priority over defaults
    manifest_file_env = os.environ.get('MANIFEST_FILE')

    # Per-layer default manifest filenames when MANIFEST_FILE is not provided.
    manifest_defaults = {
        'vendor': 'rdke-raspberrypi.xml',
        'middleware': 'raspberrypi4-64.xml',
        'application': 'raspberrypi4-64.xml',
        'image-assembler': 'raspberrypi4-64.xml',
    }

    # Use MANIFEST_FILE from env if defined. 
    # Otherwise, use the per-layer default based on layer_env
    if manifest_file_env:
        manifest_file_get = manifest_file_env
    elif layer_env == 'oss':
        manifest_file_get = get_oss_manifest(manifest_branch_env)
    else:
        manifest_file_get = manifest_defaults.get(layer_env)

    # To configure IPK path
    oss_ipk_env = os.environ.get('OSS_IPK_VERSION', '')
    vendor_ipk_env = os.environ.get('VENDOR_IPK_VERSION', '')
    middleware_ipk_env = os.environ.get('MIDDLEWARE_IPK_VERSION', '')
    application_ipk_env = os.environ.get('APPLICATION_IPK_VERSION', '')

    # To Configure bolt-package build
    genBoltPackages  = os.environ.get('GEN_BOLT_PACKAGES', 'false')
    bolt_repo   = os.environ.get('BOLT_REPO', 'https://github.com/rdkcentral/bolt-pkg-build-scripts.git')
    bolt_pkg_script_branch = os.environ.get('BOLT_PKG_SCRIPT_BRANCH', 'develop')
    bolt_dir    = os.environ.get('BOLT_DIR', 'bolt-pkg-build-scripts')
    bolt_engg_certs_repo = os.environ.get('BOLT_ENGG_CERTS_REPO', 'https://github.com/rdkcentral/bolt-engineering-certificates.git')
    bolt_engg_certs_branch = os.environ.get('BOLT_ENGG_CERTS_BRANCH', 'develop')

    # To include bolt packages
    include_bolt_package = os.environ.get('INCLUDE_BOLT_PACKAGE', 'https://osspackages.code.rdkcentral.com/apps/bolt/1.0.3/factory_app_version.json')
    dac_appstore_url_user_input = os.environ.get('DAC_APPSTORE_URL_USER_INPUT', '')
    use_bolt_package = os.environ.get('USE_BOLT_PACKAGE', 'false')
%>

# Target configuration
export TARGET="${target_env}"
export LAYER="${layer_env}"
export IPK_DIR="${build['ipk-dir']}"
export OSS_IPK_DIR="${build['oss-ipk-dir']}"

# If ENABLE_OSS_SOURCE isn't set, default to true.
export ENABLE_OSS_SOURCE="${enable_oss_source}"

# If ENABLE_APPLICATION_LAYER isn't set, default to false.
export ENABLE_APPLICATION_LAYER="${enable_application_layer}"

# Mode, Branches and Manifest
export REPO_MANIFEST_BRANCH="${manifest_branch_env}"
export MANIFEST_FILE="${manifest_file_get}"

# Variable REPO_MANIFEST_BRANCH cannot contain '/'
# '/' breaks builds, so replace it with '-'
# Remove refs/tags/ from REPO_MANIFEST_BRANCH since it is relevant only to git
<%
REPO_MANIFEST_REF = manifest_branch_env.replace('refs/tags/', '').replace('/', '-')
%>
export REPO_MANIFEST_REF="${REPO_MANIFEST_REF}"

# Bolt package build configuration
export GEN_BOLT_PACKAGES="${genBoltPackages}"
export BOLT_REPO="${bolt_repo}"
export BOLT_PKG_SCRIPT_BRANCH="${bolt_pkg_script_branch}"
export BOLT_DIR="${bolt_dir}"
export RALFPACK_URL="https://osspackages.code.rdkcentral.com/apps/bolt/1.0.3/ralfpack-ubuntu-focal-20.04-linux-amd64"
export RALFPACK_BIN_DIR="${bolt_dir}/bin"
export BOLT_ENGG_CERTS_REPO="${bolt_engg_certs_repo}"
export BOLT_ENGG_CERTS_BRANCH="${bolt_engg_certs_branch}"
export BOLT_ENGG_CERTS_DIR="${bolt_dir}/keys"

# To include bolt package configuration
export INCLUDE_BOLT_PACKAGE="${include_bolt_package}"
export DAC_APPSTORE_URL_USER_INPUT="${dac_appstore_url_user_input}"
export USE_BOLT_PACKAGE="${use_bolt_package}"

# Bolt scripts packages path changes
export RALFPACK_BIN_VERIFY_DIR="${build['workspace-dir']}/${bolt_dir}/bin/ralfpack"
export BOLT_DL_DIR="${build['workspace-dir']}/${bolt_dir}/downloads"
export BOLT_SSTATE_DIR="${build['workspace-dir']}/${bolt_dir}/sstate-cache"

# IPK Path
export OSS_IPK_VERSION="${oss_ipk_env}"
export VENDOR_IPK_VERSION="${vendor_ipk_env}"
export MIDDLEWARE_IPK_VERSION="${middleware_ipk_env}"
export APPLICATION_IPK_VERSION="${application_ipk_env}"

# IPK Layer
export OSS_IPK_LAYER="${build['machine']['arch']}"
export NON_OSS_IPK_LAYER="${build['machine']['model']}"

# Layer directories (uses container paths)
% for layer_name, layer in layers.items():
export ${env_prefix[layer_name]}_DIR="${build['workspace-dir']}/${REPO_MANIFEST_REF}/${layer_name}-layer"
% endfor

# IPK feed paths (uses container paths)
% for layer_name, layer in layers.items():
% if layer_name == 'oss':
export ${env_prefix[layer_name]}_IPK_PATH="${build['ipk-dir']}/${build['machine']['arch']}-${layer_name}/${oss_ipk_env}/ipk"
% elif layer_name == 'vendor':
export ${env_prefix[layer_name]}_IPK_PATH="${build['ipk-dir']}/${build['machine']['model']}-${layer_name}/${vendor_ipk_env}/ipk"
export ${env_prefix[layer_name]}_OSS_IPK_PATH="${build['ipk-dir']}/${build['oss-ipk-dir']}-${layer_name}/${build['machine']['model']}-${layer_name}/${vendor_ipk_env}/ipk"
% elif layer_name == 'middleware':
export ${env_prefix[layer_name]}_IPK_PATH="${build['ipk-dir']}/${build['machine']['model']}-${layer_name}/${middleware_ipk_env}/ipk"
export ${env_prefix[layer_name]}_OSS_IPK_PATH="${build['ipk-dir']}/${build['oss-ipk-dir']}-${layer_name}/${build['machine']['model']}-${layer_name}/${middleware_ipk_env}/ipk"
% elif layer_name == 'application':
export ${env_prefix[layer_name]}_IPK_PATH="${build['ipk-dir']}/${build['machine']['model']}-${layer_name}/${application_ipk_env}/ipk"
export ${env_prefix[layer_name]}_OSS_IPK_PATH="${build['ipk-dir']}/${build['oss-ipk-dir']}-${layer_name}/${build['machine']['model']}-${layer_name}/${application_ipk_env}/ipk"
% endif
% endfor

# Repository configuration
export REPO_TYPE="${repository['type']}"
export REPO_BASE_URL="${repository['base-url']}"

# Layer-specific repository types
% for layer_name, layer in layers.items():
% if layer_name != 'image-assembler':
<% repo_type = layer.get('repository-type', repository['type']) %>
export ${env_prefix[layer_name]}_REPO_TYPE="${repo_type}"
% endif
% endfor

# IPK server URLs (remote paths matching local structure)
% for layer_name, layer in layers.items():
% if layer_name == 'oss':
export ${env_prefix[layer_name]}_IPK_SERVER_URL="${repository['base-url']}/${build['machine']['arch']}-${layer_name}/${build['branch']['oss']}/ipk"
% elif layer_name != 'image-assembler':
export ${env_prefix[layer_name]}_IPK_SERVER_URL="${repository['base-url']}/${build['machine']['model']}-${layer_name}/${build['branch']['manifest']}/ipk"
% endif
% endfor

# Build setup (uses container paths)
% if target_layer == 'oss':
export MACHINE="${build['machine']['arch']}"
% else:
export MACHINE="${build['machine']['model']}"
% endif
export BUILD_COMMAND="${layers[target_layer]['build-command']}"
export BUILD_DIR="build-$MACHINE"
export WORK_DIR="$${env_prefix[target_layer]}_DIR"

<%
    from urllib.parse import urlparse
    from pathlib import Path
%>
# Manifest URLs and files
% for layer_name, layer in layers.items():
<%
    url = urlparse(layer['manifest'])
    path = Path(url.path)
%>
export ${env_prefix[layer_name]}_MANIFEST_URL="${url.scheme}://${url.netloc}${path.parent}"
export ${env_prefix[layer_name]}_MANIFEST_FILE="${path.name}"
% endfor

% if os.environ.get('GEN_BOLT_PACKAGES', 'false') != 'true':
echo "RDK build environment loaded for $TARGET/$LAYER"
echo "Work directory: $WORK_DIR"
echo "Build directory: $BUILDDIR"
echo "Machine: $MACHINE"
echo "Build command: $BUILD_COMMAND"
echo ""
echo "Repository configuration:"
% for layer_name in ['oss', 'vendor', 'middleware', 'application']:
% if layer_name in layers:
echo "  ${layer_name}: $(eval echo \$${env_prefix[layer_name]}_REPO_TYPE)"
% endif
% endfor
% endif

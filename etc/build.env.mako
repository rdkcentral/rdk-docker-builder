# Copyright 2025 RDK Management
# SPDX-License-Identifier: Apache-2.0
#
# RDK Build Environment Configuration
# Generated on ${timestamp.isoformat()}

<%
    import os

    # Target/LAYER (env-first)
    target_env = os.environ.get('TARGET', build['target'])
    layer_env  = os.environ.get('LAYER', target_layer)

    # Branches (env-first)
    manifest_branch_env = os.environ.get('REPO_MANIFEST_BRANCH', build['branch']['manifest'])

    # Manifest files (env-first; defaults from your config)
    manifest_file_env              = os.environ.get('MANIFEST_FILE', build.get('manifest_file', 'default.xml'))

    # To configure IPK path
    oss_ipk_env = os.environ.get('OSS_IPK_VERSION', '')
    vendor_ipk_env = os.environ.get('VENDOR_IPK_VERSION', '')
    middleware_ipk_env = os.environ.get('MIDDLEWARE_IPK_VERSION', '')
    application_ipk_env = os.environ.get('APPLICATION_IPK_VERSION', '')

%>

# Target configuration
export TARGET="${target_env}"
export LAYER="${layer_env}"
export SHARED_DIR="${build['shared-dir']}"

# Mode, Branches and Manifest
export REPO_MANIFEST_BRANCH="${manifest_branch_env}"
export MANIFEST_FILE="${manifest_file_env}"

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
export ${env_prefix[layer_name]}_DIR="${build['workspace-dir']}/${layer_name}-layer"
% endfor

# IPK feed paths (uses container paths)
% for layer_name, layer in layers.items():
% if layer_name == 'oss':
export ${env_prefix[layer_name]}_IPK_PATH="${build['shared-dir']}/${build['machine']['arch']}-${layer_name}/${oss_ipk_env}/ipk"
% elif layer_name == 'vendor':
export ${env_prefix[layer_name]}_IPK_PATH="${build['shared-dir']}/${build['machine']['model']}-${layer_name}/${vendor_ipk_env}/ipk"
% elif layer_name == 'middleware':
export ${env_prefix[layer_name]}_IPK_PATH="${build['shared-dir']}/${build['machine']['model']}-${layer_name}/${middleware_ipk_env}/ipk"
% elif layer_name == 'application':
export ${env_prefix[layer_name]}_IPK_PATH="${build['shared-dir']}/${build['machine']['model']}-${layer_name}/${application_ipk_env}/ipk"
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

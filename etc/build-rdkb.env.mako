# If not stated otherwise in this file or this component's LICENSE file the
# following copyright and licenses apply:
#
# Copyright 2026 RDK Management
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# RDK Build Environment Configuration
# Generated on ${timestamp.isoformat()}

<%
    import os
    import re

    target_env = os.environ.get("TARGET", build["target"])
    build_target_env = os.environ.get("BUILD_TARGET", build_target)
    product_env = os.environ.get("PRODUCT", product)

    manifest_branch_env = os.environ.get("REPO_MANIFEST_BRANCH", target_branch)

    manifest_file_env = os.environ.get("MANIFEST_FILE")

    manifest_defaults = {
        "bpi-r4-broadband": "rdkb-bpi-extsrc.xml",
        "bpi-r4-easymesh-controller": "rdkb-bpi-extsrc.xml",
        "bpi-r4-broadband-wifiagent": "rdkb-bpi-extsrc.xml",
        "bpi-r4-easymesh-extender": "rdkb-bpi-ap-extsrc.xml",
    }

    if manifest_file_env:
        manifest_file = manifest_file_env
    else:
        manifest_file = manifest_defaults.get(build_target_env)
%>

# Target configuration
export PRODUCT="${product_env}"
export TARGET="${target_env}"
export BUILD_TARGET="${build_target_env}"

# Branch configuration
export REPO_MANIFEST_BRANCH="${manifest_branch_env}"
export MANIFEST_FILE="${manifest_file}"

# Variable REPO_MANIFEST_BRANCH cannot contain '/'
# '/' breaks builds, so replace it with '-'
# Remove refs/tags/ from REPO_MANIFEST_BRANCH since it is relevant only to git
<%
REPO_MANIFEST_REF = manifest_branch_env.replace('refs/tags/', '').replace('/', '-')
%>
export REPO_MANIFEST_REF="${REPO_MANIFEST_REF}"

# Build setup
% if build_target == 'bpi-r4-easymesh-extender':
export MACHINE="${build['machine']['extender']}"
% else:
export MACHINE="${build['machine']['model']}"
% endif

export BUILD_COMMAND="${build_targets[build_target]['build-command']}"
export BUILD_DIR="build-$MACHINE"
export WORK_DIR="$${env_prefix[build_target]}_DIR"

# Manifest URLs and files
<%
    from urllib.parse import urlparse
    from pathlib import Path
%>

% for target_name, target in build_targets.items():
<%
    url = urlparse(target["manifest"])
    path = Path(url.path)
%>
export ${env_prefix[target_name]}_MANIFEST_URL="${url.scheme}://${url.netloc}${path.parent}"
export ${env_prefix[target_name]}_MANIFEST_FILE="${path.name}"
% endfor

echo "RDK-B build environment loaded"
echo "Target         : $TARGET"
echo "Build Target   : $BUILD_TARGET"
echo "Manifest Branch: $REPO_MANIFEST_BRANCH"
echo "Machine        : $MACHINE"
echo "Build Command  : $BUILD_COMMAND"
echo "Work Directory : $WORK_DIR"

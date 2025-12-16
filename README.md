# RDK Docker Builder

Docker environment for RDK Yocto development with user mapping and layered build support.

## Quick Start

```bash
# 1. Build Docker image
./rdk-docker.sh create_container

```

### OSS Layer Build
```bash
# Set environment variables for OSS layer build
export IMAGE_NAME=rdk-target-builder:latest    # Docker image name for the build environment
export REVISION_MODE=tag                       # Revision mode: can be 'branch' or 'tag'
export OSS_BRANCH=4.9.0                        # Branch or tag name for OSS layer (matches REVISION_MODE)
export MANIFEST_FILE=rdk-oss.xml               # Manifest file specifying repositories and revisions
export LAYER=oss                               # Layer to build (options: oss, vendor, middleware, application, image-assembler)
export OSS_IPK_VERSION=4.9.0                   # OSS IPK version for packaging
```

### Vendor Layer Build
```bash
# Set environment variables for Vendor layer build
export IMAGE_NAME=rdk-target-builder:latest    # Docker image name for the build environment
export REVISION_MODE=branch                    # Revision mode: can be 'branch' or 'tag'
export MANIFEST_BRANCH=develop                 # Branch or tag name for vendor manifest (matches REVISION_MODE)
export MANIFEST_FILE=rdke-raspberrypi.xml      # Manifest file specifying vendor repositories and revisions
export LAYER=vendor                            # Layer to build (options: oss, vendor, middleware, application, image-assembler)
export OSS_IPK_VERSION=4.9.0                   # OSS IPK version for packaging
export VENDOR_IPK_VERSION=develop              # Vendor IPK version for packaging
```

### Middleware Layer Build
```bash
# Set environment variables for Middleware layer build
export IMAGE_NAME=rdk-target-builder:latest    # Docker image name for the build environment
export REVISION_MODE=branch                    # Revision mode: can be 'branch' or 'tag' 
export MANIFEST_BRANCH=develop                 # Branch or tag name for middleware manifest (matches REVISION_MODE)
export MANIFEST_FILE=raspberrypi4-64.xml       # Manifest file specifying middleware repositories and revisions
export LAYER=middleware                        # Layer to build (options: oss, vendor, middleware, application, image-assembler)
export OSS_IPK_VERSION=4.9.0                   # OSS IPK version for packaging
export VENDOR_IPK_VERSION=develop              # Vendor IPK version for packaging
export MIDDLEWARE_IPK_VERSION=develop          # Middleware IPK version for packaging
```

### Application Layer Build
```bash
# Set environment variables for Application layer build
export IMAGE_NAME=rdk-target-builder:latest    # Docker image name for the build environment
export REVISION_MODE=branch                    # Revision mode: can be 'branch' or 'tag'
export MANIFEST_BRANCH=develop                 # Branch or tag name for application manifest (matches REVISION_MODE)
export MANIFEST_FILE=raspberrypi4-64.xml       # Manifest file specifying application repositories and revisions
export LAYER=application                       # Layer to build (options: oss, vendor, middleware, application, image-assembler)
export OSS_IPK_VERSION=4.9.0                   # OSS IPK version for packaging
export VENDOR_IPK_VERSION=develop              # Vendor IPK version for packaging
export MIDDLEWARE_IPK_VERSION=develop          # Middleware IPK version for packaging
export APPLICATION_IPK_VERSION=develop         # Application IPK version for Packaging
```

### Image-Assembler Build
```bash
# Set environment variables for Image-Assembler layer build
export IMAGE_NAME=rdk-target-builder:latest    # Docker image name for the build environment
export REVISION_MODE=branch                    # Revision mode: can be 'branch' or 'tag'
export MANIFEST_BRANCH=develop                 # Branch or tag name for image-assembler manifest (matches REVISION_MODE)
export MANIFEST_FILE=raspberrypi4-64.xml       # Manifest file specifying image-assembler repositories and revisions
export LAYER=image-assembler                   # Layer to build (options: oss, vendor, middleware, application, image-assembler)
export OSS_IPK_VERSION=4.9.0                   # OSS IPK version for packaging
export VENDOR_IPK_VERSION=develop              # Vendor IPK version for packaging
export MIDDLEWARE_IPK_VERSION=develop          # Middleware IPK version for packaging
export APPLICATION_IPK_VERSION=develop         # Application IPK version for Packaging
```

```bash
# 2. Configure build environment (select layer: oss/vendor/middleware/application/image-assembler)
./rdk-docker.sh setup

# 3. Run the build process
./rdk-docker.sh run
```

## Configuration

The build process uses:
- `config.yaml` - Main build configuration
- `generate-rdk-build-env` - Python script to generate build environment

### Supported Layers
- **oss**: Open Source Software layer
- **vendor**: Vendor-specific layer
- **middleware**: RDK middleware layer
- **application**: Application layer
- **image-assembler**: Final image assembly


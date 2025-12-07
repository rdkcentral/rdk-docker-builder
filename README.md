# RDK-7 Docker Builder

Docker environment for RDK-7 Yocto development with user mapping and layered build support.

## Quick Start

```bash
# 1. Build Docker image
./rdk7-docker.sh create_container

# 2. Configure build environment (select layer: oss/vendor/middleware/application/image-assembler)
./rdk7-docker.sh setup

# 3. Run the build process
./rdk7-docker.sh run
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

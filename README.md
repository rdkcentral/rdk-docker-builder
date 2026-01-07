# RDK Docker Builder

Docker RDK Yocto development environment for building RDK-E RPI OSS, VENDOR, MIDDLEWARE, APPLICATION and IMAGE ASSEMBLER Layer Images.

It is assumed the user is familiar with the RDK-E Layered Architeture. If not please see the latest RDK-E release for an overview:
[RDK-E Code Releases](https://wiki.rdkcentral.com/spaces/CMF/pages/414065624/RDK-E+Video+Code+Releases)

---
## Prequesites

The following must be installed on your host system

```bash
docker 
python 3.8 
```

- You will need enought storage space to perform the builds and store the IPK's generated.
    - the IPK's can be stored on a locally mounted or a remote filesystem

NOTE this docker setup has only been tested on UBUNTU 20.04 

```
TODO - give detailed storage requirements, lets check what other python version we can use
```

---
## Quick Start

```bash
# identify an IPK storage location accessible on your filesystem and softlink it from your /home/<user> directory
cd $HOME
ln -s <PATH TO IPK STORAGE> community

cd <WORKSPACE>
# clone the docker repo
git clone https://github.com/rdkcentral/rdk-docker-builder.git
cd rdk-docker-builder

# create the docker image
./rdk-docker.sh create_image

# configure the layer build environment 
./rdk-docker.sh setup

# build the layer and generate the layer IPK's and layer images
./rdk-docker.sh run
```

The source code and build output for the layer will be stored in a `<layer>-layer/` directory within your git clone, e.g. for a vendor layer build:
```bash
<WORKSPACE>/rdk-docker-builder/vendor-layer

ls <WORKSPACE>/rdk-docker-builder/vendor-layer
build-raspberrypi4-64-rdke # build output directory
downloads                  # build downloads directory
rdke                       # layer source directory
scripts                    # layer scripts directory
sstate-cache               # build sstate cache directory

```

---
## RDK Layer Build Docker Overview
```
TODO add pic showing how it all fits together
``` 

---
## IPK Storage Setup 

Before creating your RDK Layer Docker Builder Image you will need to identify a location to store the IPK's created by the different RDK Layer Builds.
This location needs to have enough storage space to hold the IPK's. Once identified you then need to create a softlink from your $HOME directory to this IPK location as follows:

```bash
cd $HOME
ln -s <PATH TO IPK STORAGE> community
```

example:
```bash
ls -al $HOME
lrwxrwxrwx  1 jenkins jenkins    45 Jan  7 10:37 community -> /home/jenkins/jenkinsroot/workspace/community
```

---
## Create the RDK Layer Docker Build Image
```bash
# clone the rdk layer build repo
git clone https://github.com/rdkcentral/rdk-docker-builder.git

# create the RDK Layer Build Docker Image
./rdk-docker.sh create_image
```

---
## Build the RDK Layer and Generate the IPK's

There are two phases to the layer build process 
- *setup*
    - configures the layer build environment parameters e.g. manifest branch/tag, IPK paths etc
    - creates a `build.env` file which is used as input to the *run* phase
- *run* 
   - runs the docker which in turns automatically triggers the layer build 
   - once complete will store the IPK's as per your `~/$HOME/community` directory location
   - the image can be retreived from the build output directory


```bash
# clone the docker if it doesn't exist
git clone https://github.com/rdkcentral/rdk-docker-builder.git

cd rdk-docker-builder

# setup: configure the build environment (select layer: oss/vendor/middleware/application/image-assembler)
./rdk-docker.sh setup

# run: build the layer and generate the IPK's and Layer Images
./rdk-docker.sh run
```

NOTES
- You must build the layers in order 
    - OSS, VENDOR, MIDDLEWARE, APPLICATION, IMAGE ASSEMBLER
- If you want to build a different layer you must re-run setup before running run 
- If you want to rebuild the same layer using a different manifest branch then you must move/rename or delete the existing `<layer>-layer` directory
    - alternatively you could do the build in a new clone  path of the docker repo
- If you wish to override the default versions of IPK used for a layer you must set them explicitly before you do the *setup* phase
```bash

# vendor
export OSS_IPK_VERSION=4.9.0                   # OSS IPK version for packaging

# middleware 
export OSS_IPK_VERSION=4.9.0                   # OSS IPK version for packaging
export VENDOR_IPK_VERSION=develop              # Vendor IPK version for packaging

# application 
export OSS_IPK_VERSION=4.9.0                   # OSS IPK version for packaging
export VENDOR_IPK_VERSION=develop              # Vendor IPK version for packaging
export MIDDLEWARE_IPK_VERSION=develop          # Middleware IPK version for packaging

# image assembler
export OSS_IPK_VERSION=4.9.0                   # OSS IPK version for packaging
export VENDOR_IPK_VERSION=develop              # Vendor IPK version for packaging
export MIDDLEWARE_IPK_VERSION=develop          # Middleware IPK version for packaging
export APPLICATION_IPK_VERSION=develop         # Application IPK version for Packaging

# once you set the overrides then run setup
./rdk-docker.sh setup
```

---
## Usage Notes

### Default IPK Versions

If you do not explicity set the IPK versions before you build then the DEFAULT IPK versions from `<layer>.inc` files will be used.

However in this case unless you have built the dependant layer default version the build will fail.

Note the default version of the layer may and most likely will be different depending on the BRANCH or TAG of the layer manifest you are building for that layer.

```
TODO explain how to identity the default versions from the .inc files 

```
### Overriding Default Parameters
```bash
# Set environment variables for OSS layer build
export IMAGE_NAME=rdk-layer-builder:latest     # Docker image name for the build environment
export REPO_MANIFEST_BRANCH=4.9.0              # Branch or tag name for OSS layer (matches REVISION_MODE)
```

### Using Remote Versus Local IPK's
```
TODO
```

### Building Different Layer Versions
```
TODO
```

### Running multiple docker builds at same time
```
TODO
```

### How to view build logs and build output
All build output for your layer is accessible form your local filesystem, i.e. you do not need to have the container running to view logs and retrieve images.
The layer build output available in your clone in the following location.

```
<WORKSPACE>/rdk-docker-builder/<layer>-layer/build-raspberrypi4-64-rdke
```

### How to make changes in your build environment
All source code changes in your layer can be made on your local filesystem, i.e. you do not need to have the container running to make changes.
The layer source code is available in your clone in the following location.

```
<WORKSPACE>/rdk-docker-builder/<layer>-layer/rdke
```

### How to get a shell within the docker environment
```
TODO
```

### Docker Runtime Info
The docker runtime user is `rdk` and home directory is `/home/rdk`
The external IPK location is mounted in the following location `/home/rdk/community`

---
## Configuration

The build process uses:
- `config.yaml` - Main build configuration
- `generate-rdk-build-env` - Python script to generate build environment (build.env)

### Supported Layers
- **oss**: Open Source Software Layer
- **vendor**: Vendor Layer
- **middleware**: Middleware Layer
- **application**: Application Layer
- **image-assembler**: Image Assembly Layer (Final Image)
---

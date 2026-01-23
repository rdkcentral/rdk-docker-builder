# RDK Docker Builder

Docker RDK Yocto development environment for building RDK-E RPI OSS, VENDOR, MIDDLEWARE, APPLICATION and IMAGE ASSEMBLER Layer Images.

It is assumed the user is familiar with the RDK-E Layered Architeture. If not please see the latest RDK-E release for an overview:
[RDK-E Code Releases](https://wiki.rdkcentral.com/spaces/CMF/pages/414065624/RDK-E+Video+Code+Releases)

---
## Prequesites

[Docker](https://www.docker.com/get-started/) must be installed on your host system

- You will need enought storage space to perform the builds and store the IPK's generated.
    - the IPK's can be stored on a local or a remotely mounted filesystem

Estimated OSS and RPI Layer storage requirements per IPK Feed and Layer Build:

| Layer | IPK Size | Build Size |
| ----------- | ----------- | ----------- |
| OSS | 873 MB | 84 GB |
| Vendor | 144 MB | 52 GB |
| Middleware | 394 MB| 121 GB |
| Application | 6.3 MB | 57 GB |
| Image Assembler | NA | 28 GB |

NOTE this docker setup has only been tested on UBUNTU 20.04 

---
## Quick Start

```bash
# identify an IPK storage location accessible on your filesystem and softlink it from your /home/<user> directory
cd $HOME
ln -s <PATH TO IPK STORAGE> ipks

cd <WORKSPACE>
# clone the docker repo
git clone https://github.com/rdkcentral/rdk-docker-builder.git
cd rdk-docker-builder

# create the docker image
./rdk-docker.sh create_image

# configure the layer build environment 
./rdk-docker.sh setup -l <layer> -b <manifest branch or tag>

# build the layer and generate the layer IPK's and layer images
./rdk-docker.sh run
```

The source code and build output for the layer will be stored in a `<manifest>/<layer>-layer/` directory within your git clone, e.g. for a vendor layer build:
```bash
<WORKSPACE>/rdk-docker-builder/develop/vendor-layer

ls <WORKSPACE>/rdk-docker-builder/develop/vendor-layer
build-raspberrypi4-64-rdke # build output directory
downloads                  # build downloads directory
rdke                       # layer source directory
scripts                    # layer scripts directory
sstate-cache               # build sstate cache directory
```

The IPK Packages Feed for the layer will be stored in `$HOME/ipks`, please refer to the diagram in the next section for IPK Feed output directory structure.

---
## RDK Layer Build Docker Overview
![RDK Docker Builder Overview](assets/rdk-docker-builder.jpg)

---
## IPK Storage Setup 

Before creating your RDK Layer Docker Builder Image you will need to identify a location to store the IPK's created by the different RDK Layer Builds.
This location needs to have enough storage space to hold the IPK's. Once identified you then need to create a softlink from your $HOME directory to this IPK location as follows:

```bash
cd $HOME
ln -s <PATH TO IPK STORAGE> ipks
```

example:
```bash
ls -al $HOME
lrwxrwxrwx  1 jenkins jenkins    45 Jan  7 10:37 ipks -> /home/jenkins/jenkinsroot/workspace/ipks
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
   - once complete will store the IPK's as per your `~/$HOME/ipks` directory location
   - the image can be retreived from the build output directory


```bash
# clone the docker if it doesn't exist
git clone https://github.com/rdkcentral/rdk-docker-builder.git

cd rdk-docker-builder

# setup: configure the build environment (select layer: oss/vendor/middleware/application/image-assembler)
./rdk-docker.sh setup -l oss -b 4.9.0

# run: build the layer and generate the IPK's and Layer Images
./rdk-docker.sh run
```

NOTES
- You must build the layers in order 
    - OSS, VENDOR, MIDDLEWARE, APPLICATION, IMAGE ASSEMBLER
- If you want to build a different layer you must re-run `./rdk-docker.sh setup` before running `./rdk-docker.sh run`
- if the branch name has a `/` it will be replaced with `-` on the filesystem e.g. `feature/test-branch` will be `feature-test-branch`
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
./rdk-docker.sh setup -l <layer> -b <layer manifest branch or tag>
```

---
## Usage Notes

### Default IPK Versions

If you do not explicity set the IPK versions before you build then the DEFAULT IPK versions from `<layer>.inc` files will be used.

The default version of the layer may and most likely will be different depending on the BRANCH or TAG of the layer manifest you are building for that layer. (examplex from develop branch given below)

| Layer | INC File | Meta Layer |
| ----------- | ----------- | ----------- |
| Vendor | [vendor.inc](https://github.com/rdkcentral/meta-vendor-raspberrypi-release/blob/develop/conf/machine/include/vendor.inc) | [meta-vendor-raspberrypi-release](https://github.com/rdkcentral/meta-vendor-raspberrypi-release/) |
| Middleware | [middleware.inc](https://github.com/rdkcentral/meta-middleware-release-rdke/blob/develop/conf/machine/include/middleware.inc)| [meta-middleware-release-rdke](https://github.com/rdkcentral/meta-middleware-release-rdke/) |
| Application | [application.inc](https://github.com/rdkcentral/meta-application-rdke-release/blob/develop/conf/machine/include/application.inc) | [meta-application-rdke-release](https://github.com/rdkcentral/meta-application-rdke-release/) |

*However in this case unless you have built the dependant layer default version the build will fail.*

### Using Remote Versus Local IPK's
```
The current release of rdk-docker-builder does not support using IPK's from a remote location (e.g. artifactory, http server)

This will be supported in the next version due in 2026 Q2 timeframe.
```

### Running multiple docker builds at same time
Each time you call `./rdk-docker.sh run` it creates a new container using the date and time so each layer build will run in its own container, however running multiple builds at the same time may impact on performance.

### How to view build logs and build output
All build output for your layer is accessible form your local filesystem, i.e. you do not need to have the container running to view logs and retrieve images.
The layer build output available in your clone in the following location.

```
<WORKSPACE>/rdk-docker-builder/<manifest branch or tag>/<layer>-layer/build-raspberrypi4-64-rdke
```

### How to make changes in your build environment
All source code changes in your layer can be made on your local filesystem, i.e. you do not need to have the container running to make changes.
The layer source code is available in your clone in the following location.

```
<WORKSPACE>/rdk-docker-builder/<layer>-layer/rdke
```

### How to get a shell within the docker environment
If you wish to work in the container environment which has the build host setup, simply run
```
./rdk-docker.sh shell
```

### Docker Runtime Info
The docker runtime user is `rdk` and home directory is `/home/rdk`
The external IPK location is mounted in the following location `/home/rdk/ipks` which maps to `${HOME}/ipks`

### Supported Layers
- **oss**: Open Source Software Layer
- **vendor**: Vendor Layer
- **middleware**: Middleware Layer
- **application**: Application Layer
- **image-assembler**: Image Assembly Layer (Final Image)
---

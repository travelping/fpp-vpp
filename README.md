# FPP VPP image source repository

FPP-VPP, which stands for a Fast Path Provider using FDio VPP, is a base image to create applications (like User Plane Gateway - UPG)
which process packets in userland, and the traffic intended to be handled by VPP is never handled by Linux kernel network stack at any point.

This repository contains base images for UPG VPP. You can use it to download the upstream version of the `FDio/vpp` code, apply patch series from the `/vpp-patches` directory and build images.

The repository is based on VPP with downstream patches. You can find the downstream patches needed to build the base image in the `/vpp-patches` folder. The code is available in the `vpp` directory.

The current VPP version is `stable/2202`.

## Development

### Download sources

To download source code and apply downstream patches, run:

```
hack/update-vpp.sh
```

### Build the base image

Use `Dockerfile` to build the base image:

```
DOCKER_BUILDKIT=1 docker build --build-arg BUILD_TYPE=debug -f Dockerfile -t fpp-vpp .
```

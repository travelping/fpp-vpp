# FPP VPP image source repository

FPP (Fast Path Provider) VPP image source repository contains code and tools to create a container image for Cennso products
based on the [FD.io VPP](https://s3-docs.fd.io/vpp/22.02/) framework. Cennso, which stands for Cloud-Enabled Network Service
Operators, is a Travelping unique network solution concept for cloud-based network functions (CNF) and applications.

## FPP VPP in Cennso components

FPP VPP is used by these Cennso components:

### FPP Cennso Network Core

FPP Cennso Network Core (FPP CNC) enables high-performance distributed virtual switch networks through the following features:

- Memif interfaces used to connect VPP-based workloads
- VPP's fast tap driver that connect Linux networking workloads
- Infrastructure NICs are used to create overlay networking for interconnections between the required CNFs
- Allows to build solutions based on fast packet processing in user space
- Integration with Kubernetes CNI and CPU Manager

### UPG

User Plane Gateway (UPG) CNF, which implements the required Mobile Core User Plane Function (UPF) features:

- User Plane Function (UPF) in 5G networks
- Packet Data Network Gateway User plane (PGW-U)
- Traffic Detection Function User plane (TDF-U)

## Usage

FPP VPP image runs Ubuntu with the installed patched VPP version. The current VPP version used by FPP VPP is `stable/2202`.
Build images are stored in [this](https://quay.io/repository/travelping/fpp-vpp?tab=tags) repository.

### Build versioning

For the most stable FPP VPP version, use the release images tagged with the `v22.02.1_release` naming schema.
Image tagging uses the following convention: `v<vpp-release>.<internal-build>`, for example `v22.02.1` means that VPP base version is `22.02`
and `.1` is the internal build number.

You can use the FPP VPP images to create containerized applications for packet processing or build custom VPP plugins based on the patched VPP version.

### Create containerized applications for packet processing

You can use FPP VPP as a base image to create containerized applications for packet processing. To create such an application:
1. Prepare a [`startup.conf` file](https://my-vpp-docs.readthedocs.io/en/latest/gettingstarted/users/configuring/startup.html) with a proper configuration.
2. Mount this file inside the container at path `/run/vpp/startup.conf`.

By default, the container launches VPP using configuration provided in the step above.

### Build custom VPP plugins

You can also use FPP VPP to build custom VPP plugins based on the patched VPP version.
Travelping provides such a plugin for the UPG CNF called [UPG VPP](https://github.com/travelping/upg-vpp). It is an out-of-tree plugin for FD.io VPP that provides the implementation of the GTP-U user plane based on 3GPP standards.

Read the official [VPP documentation](https://fdio-vpp.readthedocs.io/en/latest/gettingstarted/developers/add_plugin.html) to learn how to develop VPP plugins.

## Development

FPP VPP enables to build VPP from sources and apply custom patches on top of VPP code base.

### Download sources

Run this script to download FD.io VPP source code to the `vpp` directory and apply downstream patches stored in the `vpp-patches` folder:

```
hack/update-vpp.sh
```

### Add new patch

To add another patch to FPP VPP follow the steps:

1. Run `hack/update-vpp.sh` to download sources and downstream patches stored in `vpp-patches` folder
1. Develop the code in `vpp/` directory provided by above point, commit the output
1. Create a patch using git command: `git format-patch -N -1 HEAD`
1. Add resulting patch to `vpp-patches/` folder
1. Resulting patch can be committed to FPP VPP repo
1. To test the patch, you can build FPP VPP image (see next section) and run modified VPP in a container

### Build the base image

> **Warning**
>
> You need to prepare VPP source code before building FPP VPP image.
> Make sure that `vpp` folder is present by running `hack/update-vpp.sh` first.

Use `Dockerfile` to create Ubuntu-based container image with a patched VPP version installed inside:

```console
$ DOCKER_BUILDKIT=1 docker build --build-arg BUILD_TYPE=debug -f Dockerfile -t fpp-vpp:latest_debug .
```

### Local image with upg-vpp

To integrate locally built VPP with [UPG VPP](https://github.com/travelping/upg-vpp):
1. Build `latest-debug` image from above step
2. Build additional image called `latest_dev_debug`:

```console
$ DOCKER_BUILDKIT=1 docker build --build-arg BUILD_TYPE=debug -f Dockerfile -t fpp-vpp:latest_dev_debug . --target dev-stage
```

3. Clone the [UPG VPP](https://github.com/travelping/upg-vpp) repository
4. After building above 2 images locally, modify [upg-vpp/vpp.spec](https://github.com/travelping/upg-vpp/blob/master/vpp.spec) with:

```
VPP_IMAGE_BASE=fpp-vpp:latest
```

5. Run in `upg-vpp` directory:

```console
$ make image
```

The result will be a UPG VPP image `upg:debug`

# FPP VPP image source repository

FPP (Fast Path Provider) VPP image source repository contains code and tools to create a container image for Cennso products
based on the [FDio VPP](https://s3-docs.fd.io/vpp/22.02/) framework. Cennso, which stands for Cloud-Enabled Network Service
Operators, is a Travelping unique network solution concept for cloud-based network functions (CNF) and applications.

FPP VPP is used by these Cennso components:

- FPP Cennso Network Core (FPP CNC), which creates high-performance distributed virtual switch networks. Such networks are used to connect to
 the infrastructure NICs, interfaces, and external networks, and they create interconnections between the required CNFs. It allows you to build solutions
  based on fast packet processing in user space.
- User Plane Gateway (UPG) CNF, which implements the required Mobile Core User Plane Function (UPF) features, such as User Plane function
  for 2-3G GGSN GTP-U, PGW-U for 4G CUPS and UPF for 5G.

The current VPP version is `stable/2202`.

## Usage

FPP VPP image runs Ubuntu with the installed patched VPP version.
Build images are stored in [this](https://quay.io/repository/travelping/fpp-vpp?tab=tags) repository.

For the most stable FPP VPP version, use the release images tagged with the `_release` suffix.
Image tagging uses the following convention: `v<vpp-release>.<internal-build>`, for example `v22.02.1` means that VPP base version is `22.02`
and `.1` is the internal build number.

### Create containerized applications for packet processing

You can use FPP VPP as a base image to create containerized applications for packet processing. To run such applications:
1. Provide the `startup.conf` file with a proper configuration.
2. Run this file inside the container at path `/run/vpp/startup.conf`.

(^ not sure if it's technically correct, pls check. Also, what is "proper configuration"? 🤔 )

### Build custom VPP plugins

You can also use FPP VPP to build custom VPP plugins based on the patched VPP version.
Travelping provides such a plugin for UPG called [UPG VPP](https://github.com/travelping/upg-vpp). It is an out-of-tree plugin for FD.io VPP that provides the implementation of the GTP-U user plane based on 3GPP standards.

Read the official [VPP documentation](https://fdio-vpp.readthedocs.io/en/latest/gettingstarted/developers/add_plugin.html) to learn how to develop VPP plugins.

## Development

Run the `hack/update-vpp.sh` script to download FDio VPP source code to the `vpp` directory and apply downstream patches that are present
in the `vpp-patches` folder. Next, use the `Dockerfile` to create Ubuntu-based container image with patched VPP version installed inside.

### Download sources

Run this script to download FDio VPP source code to the `vpp` directory and apply downstream patches stored in the `vpp-patches` folder:

```
hack/update-vpp.sh
```

### Build the base image

Use `Dockerfile` to create Ubuntu-based container image with a patched VPP version installed inside:

```
DOCKER_BUILDKIT=1 docker build --build-arg BUILD_TYPE=debug -f Dockerfile -t fpp-vpp .
```

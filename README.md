# FPP VPP image source repository

FPP (Fast Path Provider) VPP image source repository contains code and tools to create a container image for Cennso products
based on the [FDio VPP](https://s3-docs.fd.io/vpp/22.02/) framework. Cennso, which stands for Cloud-Enabled Network Service
Operators, is a Travelping unique network solution concept for cloud-based network functions (CNF) and applications.

FPP VPP is used by these Cennso components:

- FPP Cennso Network Core (FPP CNC), which creates high performance distributed virtual switch network to connect to
  the Infrastructure NICs, interfaces and external Networks and interconnects the required CNFs. This enables to build solutions
  based on fast packets processing in userland, and the traffic intended to be handled by VPP is never handled by Linux kernel
  network stack at any point.
- User Plane Gateway (UPG) CNF, which implementes required Mobile Core User Plane Function (UPF) features like User Plane function
  for 2-3G GGSN GTP-U, PGW-U for 4G CUPS and UPF for 5G.

The current VPP version is `stable/2202`.

## Usage

FPP-VPP image runs Ubuntu with the installed patched VPP version.
Build images are stored in [this](https://quay.io/repository/travelping/fpp-vpp?tab=tags) repository.

For the most stable FPP-VPP version, use the release images tagged with the `_release` suffix.
Image tagging uses the following convention: `v<vpp-release>.<internal-build>`, for example `v22.02.1` means that VPP base is in version `22.02`
and `.1` is internal build numbering.

You can use FPP-VPP as a base image to create containerized applications for packet processing. To run such applications, `startup.conf` with
a proper configuration should be provided to be used inside container at path `/run/vpp/startup.conf`.

FPP VPP can be used to build custom VPP plugin. Travelping provides such plugin implementation for UPG - [UPG-VPP](https://github.com/travelping/upg-vpp).
UPG VPP is an out-of-tree plugin for FD.io VPP with implementation of GTP-U user plane based on 3GPP standards.

Read the official [VPP documentation](https://fdio-vpp.readthedocs.io/en/latest/gettingstarted/developers/add_plugin.html) to learn how to develop VPP plugins
by your own.

## Development

Run the `hack/update-vpp.sh` script to download FDio VPP source code to the `vpp` directory and apply downstream patches that are present
in the `vpp-patches` folder. Next, use the `Dockerfile` to create Ubuntu-based container image with patched VPP version installed inside.

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

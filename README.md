# FPP VPP image source repository

FPP (Fast Path Provider) VPP image source repository contains code with [FD.io VPP](https://s3-docs.fd.io/vpp/22.02/)
patches and tools to create a container image running a modified version of VPP.

## FPP VPP in UPG-VPP

User Plane Gateway ([UPG-VPP](https://github.com/travelping/upg-vpp)) CNF uses FPP VPP with its patched VPP version,
to implement the required Mobile Core User Plane Function (UPF) features:

- User Plane Function (UPF) in 5G networks
- Packet Data Network Gateway User plane (PGW-U)
- Traffic Detection Function User plane (TDF-U)

## Usage

FPP VPP provides a [Dockerfile](./Dockerfile) that creates an Ubuntu image with the installed patched VPP version.
FPP VPP is currently based on VPP version `stable/2202`.

Build images are stored in [Travelping's quay](https://quay.io/repository/travelping/fpp-vpp?tab=tags) repository.

### Build versioning

For the most stable FPP VPP version, use the release images tagged with the `v22.02.1_release` naming schema.
Image tagging uses the following convention: `v<vpp-release>.<internal-build>`.

`v22.02.1` means that the VPP base version is `22.02`, and `.1` is the internal build number.

You can use the FPP VPP images to create containerized applications for packet processing or build custom VPP plugins
based on the patched VPP version.

### Run built image

> **Warning**
>
> It may be required to enable HugePages on local machine to run VPP.
> To do so, run on `sysctl vm.nr_hugepages=2000`, this allocates 2000 hugepages of size 2M

To simply run the FPP VPP image using docker:

```console
$ docker run -it --rm --privileged --entrypoint /usr/bin/vpp quay.io/travelping/fpp-vpp:v22.02.1_release unix { nodaemon interactive } api-segment { prefix vpp1 } cpu { workers 0 } heapsize 2G
```

This will run the FPP VPP container on a local machine, giving access to VPP CLI (`vppctl`). You can play with available commands,
see [VPP CLI docs](https://s3-docs.fd.io/vpp/22.02/cli-reference/gettingstarted/index.html) for reference.

For more information, see the [VPP tutorial](https://s3-docs.fd.io/vpp/22.02/gettingstarted/progressivevpp/index.html).

## Development

FPP VPP enables to build VPP from sources and apply custom patches on top of VPP code base.

### Download sources

Run this script to download FD.io VPP source code to the `vpp` directory and apply downstream patches stored in the `vpp-patches` folder:

```
hack/update-vpp.sh
```

### Contribute

To add new functionality or fix an encountered issue in VPP code base, you can develop the required extension/fix in VPP C code,
create a patch and commit it to FPP-VPP repo.

To add another patch to FPP VPP follow the steps:

1. Run `hack/update-app.sh` to download sources and downstream patches stored in a `vpp-patches` folder
1. Develop the code in `vpp/` directory provided by the above point, commit the output to git
1. Create a patch using the git command: `git format-patch -N -1 HEAD`
1. Add resulting patch to `vpp-patches/` folder
1. The resulting patch can be committed to the FPP VPP repo
1. To test the patch, you can build an FPP VPP image (see [next section](#build-the-base-image)) and run a modified VPP in a container

### Build the base image

> **Warning**
>
> You need to prepare VPP source code before building FPP VPP image.
> Make sure that `vpp` folder is present by running `hack/update-vpp.sh` first.

[`Dockerfile`](./Dockerfile) provided in this repo creates four types of build images:

- `release` - optimized build with proper performance, but without debug tools (like `gdb`)
- `debug` - does not provide optimal performance, but enables easier analyzes with `gdb` and also provides
  more debug log information
- `dev_release` - development image including tools to build VPP plugin, used for building `release` image with this plugin
- `dev_debug` - development image including tools to build VPP plugin, used for building `debug` image with this plugin

The type of image build is defined with `BUILD_TYPE` argument passed to `docker build`.
Possible options are `debug` or `release`. This parameter is required during container build.

To build a release FPP VPP image with a patched VPP version installed inside:

```console
$ DOCKER_BUILDKIT=1 docker build --build-arg BUILD_TYPE=release -f Dockerfile -t fpp-vpp:latest_release .
```

`BUILD_TYPE` can be set to `debug` in the above command to get debug image. `latest_release` tag was applied above
to distinguish release or debug builds.

### Build dev images
To support building VPP plugins using FPP VPP base image, [`Dockerfile`](./Dockerfile) provided in this repo includes
a build target called `dev-stage`. This target includes source headers needed to build the VPP plugin.

To build release FPP VPP image with development tools included:

```console
$ DOCKER_BUILDKIT=1 docker build --build-arg BUILD_TYPE=release -f Dockerfile -t fpp-vpp:latest_dev_release . --target dev-stage
```

`latest_dev_release` image tag was applied to distinguish between the release image that runs modified VPP and
the development image used to build VPP plugins. `dev_release` image is required to build the VPP plugin with
the resulting `release` type of image.

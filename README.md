# FPP VPP image source repository

FPP (Fast Path Provider) VPP image source repository contains code with [FD.io VPP](https://s3-docs.fd.io/vpp/22.02/)
patches and tools to create a container image that runs a modified version of VPP.

User Plane Gateway ([UPG VPP](https://github.com/travelping/upg-vpp)) CNF uses FPP VPP and its patched VPP version
to implement the required Mobile Core User Plane Function (UPF) features:

- User Plane Function (UPF) in 5G networks
- Packet Data Network Gateway User plane (PGW-U)
- Traffic Detection Function User plane (TDF-U)

## Usage

FPP VPP provides a [`Dockerfile`](./Dockerfile) that creates an Ubuntu image with the installed patched VPP version.
FPP VPP is currently based on VPP version `stable/2202`.

Build images are stored in the [Travelping's quay](https://quay.io/repository/travelping/fpp-vpp?tab=tags) repository.

### Build versioning

For the most stable FPP VPP version, use the release images tagged with the `v22.02.1_release` naming schema.
Image tagging uses the following convention: `v<vpp-release>.<internal-build>`. For example, `v22.02.1` means that the VPP base version is `22.02`, and `.1` is the internal build number.

### Run the built image

> **Warning**
>
> It may be required to enable HugePages on local machine to run VPP.
> To do so, run on `sysctl vm.nr_hugepages=2000`, this allocates 2000 hugepages of size 2M

Use this command to run the FPP VPP container image on a local machine using Docker:

```console
$ docker run -it --rm --privileged --entrypoint /usr/bin/vpp quay.io/travelping/fpp-vpp:v22.02.1_release unix { nodaemon interactive } api-segment { prefix vpp1 } cpu { workers 0 } heapsize 2G
```

This command gives you access to VPP CLI (`vppctl`). To see the list of available commands, read the [VPP CLI](https://s3-docs.fd.io/vpp/22.02/cli-reference/gettingstarted/index.html) documentation. For more information on how to use VPP, see the [VPP tutorial](https://s3-docs.fd.io/vpp/22.02/gettingstarted/progressivevpp/index.html).

## Development

Run this script to download FD.io VPP source code to the `vpp` directory and apply downstream patches stored in the `vpp-patches` folder:

```
hack/update-vpp.sh
```

## Contribution

You can add a new functionality or fix an encountered issue in the VPP code base. To do so, provide the required code changes, create a patch, and commit it to the FPP VPP repository.

To add a patch to FPP VPP, follow these steps:

1. Run the `hack/update-app.sh` script to download sources and downstream patches stored in the `vpp-patches` folder.
1. Provide changes to the code in the `vpp` directory and commit the output to git.
1. Create a patch using this command: 
    ```
    git format-patch -N -1 HEAD
    ```
4. Add the patch to the `vpp-patches` folder.
5. Commit the patch to the FPP VPP repository.
6. To test the patch, build an FPP VPP image and run a modified VPP in a container.

### Build the base image

> **Warning**
>
> You must prepare VPP source code before building an FPP VPP image.
> Make sure that `vpp` folder is present by running `hack/update-vpp.sh` first.

[`Dockerfile`](./Dockerfile) provided in this repository creates four types of build images:

- `release` - optimized build with proper performance but without debug tools like `gdb`
- `debug` - does not provide optimal performance but allows for easier analyzes with `gdb` and also provides
  more debug log information
- `dev_release` - development image that includes tools to build a VPP plugin, used for building a `release` image with this plugin
- `dev_debug` - development image that includes tools to build a VPP plugin, used for building a `debug` image with this plugin

The type of image build is defined with `BUILD_TYPE` argument passed to `docker build`.
The possible options are `debug` or `release`. This parameter is required during the container build.

To build a release FPP VPP image with a patched VPP version installed inside, run:

```console
$ DOCKER_BUILDKIT=1 docker build --build-arg BUILD_TYPE=release -f Dockerfile -t fpp-vpp:latest_release .
```

You can set `BUILD_TYPE` to `debug` in the above command to get debug image. `latest_release` tag was applied above
to distinguish release or debug builds.

### Build dev images

To support building VPP plugins using FPP VPP base image, the [`Dockerfile`](./Dockerfile) includes
a build target called `dev-stage`. This target includes source headers needed to build the VPP plugin.

To build release FPP VPP image with development tools included, run:

```console
$ DOCKER_BUILDKIT=1 docker build --build-arg BUILD_TYPE=release -f Dockerfile -t fpp-vpp:latest_dev_release . --target dev-stage
```

`latest_dev_release` image tag was applied to distinguish between the release image that runs modified VPP and
the development image used to build VPP plugins. `dev_release` image is required to build the VPP plugin with
the resulting `release` type of image.

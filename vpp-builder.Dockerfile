# syntax = docker/dockerfile:experimental
FROM ubuntu:22.04@sha256:ce4a593b4e323dcc3dd728e397e0a866a1bf516a1b7c31d6aa06991baec4f2e0

WORKDIR /

RUN echo "wireshark-common wireshark-common/install-setuid boolean true" | debconf-set-selections

# netbase is needed for Scapy
RUN --mount=target=/var/lib/apt,type=cache,sharing=locked \
    --mount=target=/var/cache/apt,type=cache,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    echo "wireshark-common wireshark-common/install-setuid boolean true" | debconf-set-selections && \
    echo "debconf debconf/frontend select Noninteractive" | debconf-set-selections && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential sudo git \
        netbase curl ca-certificates ccache \
        iproute2 gdb tcpdump iputils-ping libpcap-dev \
        dumb-init gdbserver \
        # clang also installed in vpp Makefile, make sure to match versions
        clang \
        # llvm provides llc for xdp-tools build
        llvm \
        # clang uses gcc for stdc++ library via auto-detection.
        # gcc-12 omits c++ stuff, so we add it manually. libstdc++-12-dev should be enough, but entire g++ is not that heavy to add.
        g++-12 \
    && \
    # Install Go 1.25.7 directly from golang.org
    curl -fsSL -o /tmp/go.tar.gz https://go.dev/dl/go1.25.7.linux-amd64.tar.gz && \
    echo "12e6d6a191091ae27dc31f6efc630e3a3b8ba409baf3573d955b196fdf086005  /tmp/go.tar.gz" | sha256sum -c && \
    tar -C /usr/local -xzf /tmp/go.tar.gz && \
    rm /tmp/go.tar.gz && \
    ln -s /usr/local/go/bin/go /usr/bin/go && \
    ln -s /usr/local/go/bin/gofmt /usr/bin/gofmt && \
    # set clang as default C and C++ compiler
    update-alternatives --set c++ /usr/bin/clang++ && \
    update-alternatives --set cc /usr/bin/clang

# Configure ccache, but do not provide it in path. Each RUN should provide it separately
ENV CCACHE_DIR=/ccache \
    CCACHE_MAXSIZE=600M \
    CCACHE_COMPRESS=true \
    CCACHE_COMPRESSLEVEL=6 \
    GOPATH=/go

# golang uses ccache as well
RUN --mount=target=/ccache,type=cache \
    PATH="/usr/lib/ccache:$PATH" && \
    go install github.com/onsi/ginkgo/v2/ginkgo@v2.27.2 && \
    mv /go/bin/ginkgo /usr/local/bin/ginkgo && \
    go install golang.org/x/tools/gopls@v0.11.0 && \
    mv /go/bin/gopls /usr/local/bin

COPY vpp/Makefile /vpp-src/Makefile
COPY vpp/build/external /vpp-src/build/external

RUN --mount=target=/var/lib/apt,type=cache,sharing=locked \
    --mount=target=/var/cache/apt,type=cache,sharing=locked \
    --mount=target=/ccache,type=cache \
    cd /vpp-src && \
    git config --global user.email "dummy@example.com" && \
    git config --global user.name "dummy user" && \
    git init && \
    git add Makefile && \
    git commit -m "dummy commit" && \
    # tag requred to have this format
    git tag -a v24.02-rc0 -m "dummy tag" && \
    make UNATTENDED=yes install-dep install-ext-dep && \
    ccache -s && \
    rm -rf /vpp-src 

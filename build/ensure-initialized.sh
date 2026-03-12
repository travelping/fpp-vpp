#!/bin/bash

set -e

SKIP_DEPS="${SKIP_DEPS:-0}"

if [[ "${SKIP_DEPS}" -eq 1 ]]; then
    exit 0
fi

if [[ ! -d vpp ]] || ! find vpp -mindepth 1 -print -quit | grep -q .; then
    "$(dirname "${BASH_SOURCE}")/update-vpp.sh"
fi


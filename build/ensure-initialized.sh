#!/bin/bash

set -e

CI_BUILD="${CI_BUILD:-}"

if [[ "${CI_BUILD}" -eq 1 ]]; then
    exit 0
fi

if [[ ! -d vpp ]] || ! find vpp -mindepth 1 -print -quit | grep -q .; then
    "$(dirname "${BASH_SOURCE}")/update-vpp.sh"
fi


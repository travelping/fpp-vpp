#!/bin/bash

CWD_GIT_PATH="$(git rev-parse --show-prefix)"
echo $(git rev-parse HEAD:${CWD_GIT_PATH}vpp-builder.Dockerfile)$(git rev-parse HEAD:${CWD_GIT_PATH}vpp.spec) | sha1sum | awk '{print $1}'

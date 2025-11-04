#!/bin/bash

echo "Trying to pull cached image: ${1}" > /dev/stderr
if ! PULL_ERR="$(docker pull "${1}" 2>&1 >/dev/null)"; then
    if echo "${PULL_ERR}" | grep -q "unknown"; then
        echo "Cached image: ${1} was not present" > /dev/stderr
        exit 2
    else
        echo "Error during attempt to pull cached image:" > /dev/stderr
        echo "${PULL_ERR}" > /dev/stderr
        exit 1
    fi
fi

echo "Successfully pulled cached image: ${1}" > /dev/stderr


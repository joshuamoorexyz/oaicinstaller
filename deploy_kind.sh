#!/usr/bin/env bash

SCRIPT_DIR=`dirname $0`

if ! command -v kind; then
    if command -v brew; then
        brew install kind
    else
        go get sigs.k8s.io/kind
    fi
fi

kind create cluster --image=kindest/node:v1.16.15 --config=$SCRIPT_DIR/config.yaml
#!/usr/bin/env bash
set -e

SCRIPT_DIR=`dirname $0`

if ! command -v $(go env GOPATH)/bin/kind; then
    GO111MODULE=on go get sigs.k8s.io/kind@v0.14.0
fi

$(go env GOPATH)/bin/kind create cluster --image=kindest/node:v1.16.15 --config=$SCRIPT_DIR/config.yaml

./get_config.sh

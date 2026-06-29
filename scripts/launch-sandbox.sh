#!/bin/bash

docker run --rm -it \
  -v "$HOME/.pi/agent:/root/.pi/agent" \
  -v "$PWD:/workspace" \
  pi-sandbox
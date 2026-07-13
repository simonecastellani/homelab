#!/bin/bash

docker run --rm -it \
  -u "$(id -u):$(id -g)" \
  -v "$HOME/.ssh:/home/node/.ssh" \
  -v "$HOME/.pi/:/home/node/.pi/" \
  -v "$PWD:/home/node/workspace" \
  pi-sandbox
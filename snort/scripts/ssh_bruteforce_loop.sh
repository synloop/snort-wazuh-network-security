#!/usr/bin/env bash
set -e
for i in {1..5}; do
  ssh -o ConnectTimeout=1 user@192.168.1.1 || true
done

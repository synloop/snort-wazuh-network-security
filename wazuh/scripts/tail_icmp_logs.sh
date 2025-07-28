#!/usr/bin/env bash
set -euo pipefail

sudo journalctl -k -f | grep --line-buffered "ICMP_PACKET:"

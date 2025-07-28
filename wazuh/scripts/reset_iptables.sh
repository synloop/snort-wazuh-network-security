#!/usr/bin/env bash
set -euo pipefail

sudo iptables -D INPUT  -j PING_IN_LOG 2>/dev/null || true
sudo iptables -D OUTPUT -j PING_IN_LOG 2>/dev/null || true
sudo iptables -F PING_IN_LOG 2>/dev/null || true
sudo iptables -X PING_IN_LOG 2>/dev/null || true

echo "[OK] PING_IN_LOG chain removed."

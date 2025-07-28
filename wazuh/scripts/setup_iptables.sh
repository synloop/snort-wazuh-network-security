#!/usr/bin/env bash
set -euo pipefail

CLIENT_IP="${1:-192.168.56.101}"

sudo iptables -N PING_IN_LOG 2>/dev/null || true
sudo iptables -F PING_IN_LOG

sudo iptables -D INPUT  -j PING_IN_LOG 2>/dev/null || true
sudo iptables -D OUTPUT -j PING_IN_LOG 2>/dev/null || true
sudo iptables -I INPUT  -j PING_IN_LOG
sudo iptables -I OUTPUT -j PING_IN_LOG

sudo iptables -A PING_IN_LOG -p icmp --icmp-type echo-request -s "$CLIENT_IP" \
  -j LOG --log-prefix "ICMP_PACKET: " --log-level 4
sudo iptables -A PING_IN_LOG -p icmp --icmp-type echo-request -s "$CLIENT_IP" -j ACCEPT

echo "[OK] iptables configured. Current counters:"
sudo iptables -L PING_IN_LOG -v -n

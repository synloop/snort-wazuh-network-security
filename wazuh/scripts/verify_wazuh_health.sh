#!/usr/bin/env bash
set -euo pipefail

echo "[*] Manager services:"
sudo systemctl status wazuh-manager --no-pager || true

echo "[*] Rules loaded (grep local):"
sudo /var/ossec/bin/wazuh-logtest -V 2>/dev/null | head -n 1 || true
sudo grep -E "19999(3|4)" /var/ossec/logs/ossec.log || true

echo "[*] Tail manager log:"
sudo tail -n 50 /var/ossec/logs/ossec.log

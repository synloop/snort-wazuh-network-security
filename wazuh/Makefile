# Wazuh Lab Makefile
# Run on the Wazuh SERVER VM (192.168.56.102).
# It deploys local rules/decoders, auditd rule, configures iptables logging for ICMP,
# and provides quick health checks.

SHELL := /bin/bash

# ---- Variables ---------------------------------------------------------------

# Client IP that sends the pings
CLIENT_IP ?= 192.168.56.101

# Source files (relative to this Makefile, i.e., repo-root/wazuh/)
RULE_SRC       := config/local_rules.xml
DECODER_SRC    := config/local_decoder.xml
AUDIT_SRC      := config/audit/ping.rules

# Destination paths on the server
RULE_DST       := /var/ossec/etc/rules/local_rules.xml
DECODER_DST    := /var/ossec/etc/decoders/local_decoder.xml
AUDIT_DST      := /etc/audit/rules.d/ping.rules

SUDO           := sudo

# ---- Phony targets -----------------------------------------------------------
.PHONY: help deploy deploy-rules deploy-decoder deploy-audit reload-audit \
        restart-manager status-manager health iptables reset-iptables counters \
        tail-icmp ensure-exec check-files clean all

# Default target
all: help

help:
	@echo ""
	@echo "Wazuh Lab — Makefile (run on the SERVER 192.168.56.102)"
	@echo ""
	@echo "Usage:"
	@echo "  make deploy                  # Install local rule, decoder, audit rule; restart Wazuh + reload auditd"
	@echo "  make iptables CLIENT_IP=IP   # Configure iptables logging chain for ICMP echo-request from the client"
	@echo "  make counters                # Show iptables counters for PING_IN_LOG"
	@echo "  make tail-icmp               # Follow kernel log lines produced by iptables (ICMP_PACKET: ...)"
	@echo "  make health                  # Quick Wazuh manager health check"
	@echo "  make reset-iptables          # Remove the custom iptables chain"
	@echo "  make status-manager          # Show wazuh-manager service status"
	@echo "  make clean                   # Alias for reset-iptables"
	@echo ""
	@echo "Variables:"
	@echo "  CLIENT_IP (default: 192.168.56.101)"
	@echo ""

# ---- Deploy Wazuh content ----------------------------------------------------

deploy: check-files deploy-rules deploy-decoder deploy-audit restart-manager reload-audit
	@echo "[OK] Wazuh local rule/decoder + audit rule deployed."

deploy-rules: $(RULE_SRC)
	@echo "[*] Installing Wazuh local rule -> $(RULE_DST)"
	$(SUDO) install -m 0644 -o root -g root "$(RULE_SRC)" "$(RULE_DST)"

deploy-decoder: $(DECODER_SRC)
	@echo "[*] Installing Wazuh local decoder -> $(DECODER_DST)"
	$(SUDO) install -m 0644 -o root -g root "$(DECODER_SRC)" "$(DECODER_DST)"

deploy-audit: $(AUDIT_SRC)
	@echo "[*] Installing auditd rule -> $(AUDIT_DST)"
	$(SUDO) install -m 0644 -o root -g root "$(AUDIT_SRC)" "$(AUDIT_DST)"

restart-manager:
	@echo "[*] Restarting wazuh-manager ..."
	$(SUDO) systemctl restart wazuh-manager

status-manager:
	@echo "[*] wazuh-manager status:"
	-$(SUDO) systemctl status wazuh-manager --no-pager

reload-audit:
	@echo "[*] Reloading audit rules (augenrules --load) ..."
	$(SUDO) augenrules --load || true
	@echo "[*] (Optional) Restarting auditd ..."
	-$(SUDO) systemctl restart auditd || true

# ---- Iptables (ICMP logging) -------------------------------------------------

ensure-exec:
	@chmod +x scripts/*.sh 2>/dev/null || true

iptables: ensure-exec
	@echo "[*] Configuring iptables logging for ICMP echo-request from $(CLIENT_IP)"
	bash scripts/setup_iptables.sh "$(CLIENT_IP)"

reset-iptables: ensure-exec
	@echo "[*] Removing custom iptables chain (PING_IN_LOG) ..."
	bash scripts/reset_iptables.sh

counters:
	@echo "[*] iptables counters for PING_IN_LOG:"
	-$(SUDO) iptables -L PING_IN_LOG -v -n

tail-icmp: ensure-exec
	@echo "[*] Following kernel logs with ICMP_PACKET prefix (Ctrl+C to stop) ..."
	bash scripts/tail_icmp_logs.sh

# ---- Health / Checks ---------------------------------------------------------

health: ensure-exec
	@echo "[*] Quick Wazuh health:"
	bash scripts/verify_wazuh_health.sh

check-files:
	@test -f "$(RULE_SRC)" || (echo "Missing $(RULE_SRC)"; exit 1)
	@test -f "$(DECODER_SRC)" || (echo "Missing $(DECODER_SRC)"; exit 1)
	@test -f "$(AUDIT_SRC)" || (echo "Missing $(AUDIT_SRC)"; exit 1)

# ---- Cleanup -----------------------------------------------------------------

clean: reset-iptables
	@echo "[OK] Cleanup done."

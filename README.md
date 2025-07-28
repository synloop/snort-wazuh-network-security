# Network Security Labs – Snort (pfSense) & Wazuh (Ubuntu)

[![Status](https://img.shields.io/badge/status-complete-brightgreen)](#)
[![License](https://img.shields.io/badge/license-See%20LICENSE-lightgrey)](LICENSE)
[![Docs: Snort](https://img.shields.io/badge/docs-Snort%20Report-blueviolet)](docs/Report_SNORT.pdf)
[![Docs: Wazuh](https://img.shields.io/badge/docs-Wazuh%20Report-blueviolet)](docs/Report_Wazuh.pdf)

[![Platform](https://img.shields.io/badge/platform-VirtualBox-1155CC)](#)
[![OS](https://img.shields.io/badge/OS-Ubuntu%2022.04-E95420?logo=ubuntu&logoColor=white)](#)

[![Firewall](https://img.shields.io/badge/firewall-pfSense-005C99)](#)
[![IDS](https://img.shields.io/badge/IDS-Snort-F15A24)](snort/rules/custom.rules)
[![SIEM](https://img.shields.io/badge/SIEM-Wazuh-0A7BBC)](wazuh/)

[![Network](https://img.shields.io/badge/network-192.168.56.0%2F24%20(Host--Only)-informational)](#)
[![Server](https://img.shields.io/badge/server-192.168.56.102-informational)](#)
[![Client](https://img.shields.io/badge/client-192.168.56.101-informational)](#)

[![Scripts](https://img.shields.io/badge/scripts-bash-121011?logo=gnu-bash&logoColor=white)](#)

This repository contains two independent labs completed for the **HEPIA Summer Lab – Practical Network Security**:

* **Snort on pfSense** — first as **IDS** (alert‑only), then as **IPS** (Block Offenders + Kill States).
* **Wazuh on Ubuntu** — SIEM setup with a custom **decoder + rule** to detect ICMP echo‑requests logged by the Linux kernel, plus an **auditd** rule for single‑ping verification.

Both labs are self‑contained and can be reproduced on a local VirtualBox setup.

---

## Repository layout

```
.
├─ docs/
│  ├─ Report_SNORT.pdf         # Full write-up of the Snort lab (pfSense)
│  └─ Report_Wazuh.pdf         # Full write-up of the Wazuh lab (Ubuntu)
├─ snort/
│  ├─ rules/
│  │  └─ custom.rules          # All custom rule SIDs used during the lab
│  ├─ scripts/                 # Quick test scripts (ping, DNS, nmap, SSH, exfil)
│  └─ images/                  # Screenshots referenced in the report
├─ wazuh/
│  ├─ Makefile                 # Automates deploy/verify for the Wazuh lab
│  ├─ config/
│  │  ├─ local_rules.xml       # Wazuh rule (ICMP log -> alert)
│  │  ├─ local_decoder.xml     # Wazuh decoder (parses kernel ICMP log)
│  │  └─ audit/
│  │     └─ ping.rules         # auditd rule (sendto syscall tagged ping_detect)
│  ├─ scripts/                 # iptables setup/reset, tail logs, health checks
│  └─ images/                  # Screenshots referenced in the report
├─ LICENSE
└─ README.md                   # You are here
```

---

## Lab 1 — Snort on pfSense (IDS → IPS)

### Topology (example)

* **Firewall**: pfSense on **LAN 192.168.1.0/24**, **pfSense LAN IP: `192.168.1.1`**
* **Client**: Ubuntu Desktop on the same LAN (e.g., `192.168.1.x`)

> Adjust IPs to your environment. My test scripts assume `192.168.1.1` is the pfSense LAN IP.

### Custom rules (SIDs)

```
1000001 — ICMP Ping detected (all ICMP)
1000002 — Inbound ICMP Ping (external → internal)
1000003 — DNS request with "youtube" (policy alert)
1000004 — Possible Nmap Scan (SYN threshold)
1000005 — SSH Brute Force attempt (>3 in 60s)
10000012 — Possible Data Exfiltration (large TCP payload)
```

Rules are in `snort/rules/custom.rules`.

### Quick how‑to

**IDS (alert‑only)**

1. On pfSense: **System → Package Manager → Available Packages → Snort** (install).
2. **Services → Snort → Interfaces → Add LAN** (enable interface).
3. **LAN → Rules → custom.rules**: paste the content of `snort/rules/custom.rules`.
4. **Start** Snort on LAN (blue ▶).

**IPS (active blocking)**

1. **Services → Snort → LAN → Block Settings**.
2. Enable **Block Offenders** and **Kill States**.
3. Re‑run tests; offenders appear in **Services → Snort → Blocked Hosts**.

> Inline mode was **not** used (common virtual NIC constraints). IPS here relies on Block Offenders + Kill States.

### Test scripts (run from the Ubuntu client)

From `snort/scripts/`:

```bash
./ping_gateway.sh          # ICMP – expect SID 1000001 (then refined to 1000002)
./dns_youtube.sh           # DNS contains "youtube" – expect SID 1000003
./nmap_scan.sh             # Burst SYNs – expect SID 1000004
./ssh_bruteforce_loop.sh   # >3 attempts/60s – expect SID 1000005
./hydra_ssh.sh             # Real brute‑forcer – expect SID 1000005
./exfil_passwd.sh          # Large outbound payload – expect SID 10000012
```

**Expected outcomes**

* ICMP: alerts for all pings (1000001), then only external (1000002) after refinement.
* DNS: alert when resolving `youtube.com` (1000003).
* Nmap: “Possible Nmap Scan” alerts (1000004).
* SSH: alert after >3 attempts/60s (1000005).
* Exfiltration: alert on large outbound payload (10000012); with IPS, source gets blocked.

**Notes**

* Keep separate rule‑sets per interface (WAN vs LAN) to reduce false positives and focus per zone.
* HTTPS payload is encrypted; detection relies on **DNS** or **TLS SNI**, not content inspection.

---

## Lab 2 — Wazuh on Ubuntu (Server + Agent)

### Topology (example)

* **Server VM**: Wazuh Server + Indexer + Dashboard — Host‑Only **`192.168.56.102`**
* **Client VM**: Wazuh Agent — Host‑Only **`192.168.56.101`**

> Adjust IPs !

### What this lab shows

* **auditd + ausearch** to tag/verify a **single ping** (`sendto()` syscall).
* **Netfilter (iptables) logging** of ICMP echo‑requests from the client VM.
* **Wazuh decoder + rule** converting those kernel log lines into structured **alerts** in the Dashboard.

High‑level flow:

```
client ping -> server kernel logs (iptables LOG "ICMP_PACKET: ...")
            -> journald/syslog
            -> Wazuh logcollector
            -> local_decoder.xml parses (SRC, DST, etc.)
            -> local_rules.xml matches "ICMP_PACKET" and raises alert
            -> Wazuh Dashboard shows the alert
```

### Prerequisites (server VM)

* Wazuh Server components **installed and running**
* `auditd` enabled
* `iptables` available (Ubuntu’s `iptables-nft` backend works)
* journald/syslog enabled (default on Ubuntu)

### Makefile‑driven workflow (server VM)

All paths and commands are encapsulated in the **`wazuh/Makefile`**.
From the server VM:

```bash
cd /path/to/repo/wazuh

# 1) Deploy Wazuh decoder, rule, and auditd rule (and restart services)
make deploy

# 2) Create iptables logging chain for ICMP echo-requests from the client IP
make iptables CLIENT_IP=192.168.56.101

# 3) Generate traffic (on the client VM)
#    ping -c 1 192.168.56.102

# 4) Observe kernel logs in real time on server
make tail-icmp

# 5) Check counters on the custom chain
make counters

# 6) Quick Wazuh health check
make health

# Cleanup iptables logging (optional)
make reset-iptables
```

**Installed files (by `make deploy`):**

* `/var/ossec/etc/rules/local_rules.xml`
* `/var/ossec/etc/decoders/local_decoder.xml`
* `/etc/audit/rules.d/ping.rules` (then `augenrules --load`)

> After changing rules/decoders, restart `wazuh-manager` (the Makefile already does this in `deploy`).

**Common troubleshooting (server VM)**

* No ICMP alerts:

  * Check the **exact** iptables prefix: `ICMP_PACKET:`
    `journalctl -k -n 100 | grep ICMP_PACKET`
  * Validate counters: `make counters`
  * Check manager status: `make status-manager`
  * Look at Wazuh logs: `/var/ossec/logs/ossec.log`
* Audit rule missing: `sudo auditctl -l | grep ping_detect`
* Dashboard unreachable:

  * `sudo systemctl status wazuh-dashboard --no-pager`
  * `sudo ss -lntp | egrep ':443\b'`
  * `sudo ufw allow 443/tcp` (if needed)

---

## Reproducing the environment (summary)

* **Virtualization**: Oracle VirtualBox
* **OS**: Ubuntu 22.04 (Server & Client), pfSense for Snort lab
* **Network**:

  * Snort lab: pfSense **LAN `192.168.1.0/24`** (`192.168.1.1` gateway), client on same LAN
  * Wazuh lab: Host‑Only **`192.168.56.0/24`** (server `192.168.56.102`, client `192.168.56.101`)
* **Tools on client (for tests)**: `dnsutils` (`dig`), `nslookup`, `curl`, `nmap`, `hydra`, wordlists (e.g., `rockyou.txt`)

---

## Reports & Screenshots

* **Snort**: `docs/Report_SNORT.pdf` (screenshots in `snort/images/`)
* **Wazuh**: `docs/Report_Wazuh.pdf` (screenshots in `wazuh/images/`)

Open the PDFs for a step‑by‑step narrative, annotated screenshots, and configuration snippets.

---

## License

See the top‑level `LICENSE` file for licensing terms.

---

## Acknowledgments

Prepared for **HEPIA – Practical Network Security (Summer Lab)**.
Thanks to the open‑source communities behind **pfSense**, **Snort**, and **Wazuh**.

---

### Security Notice

These labs generate alerts and (optionally) block hosts. Run them **only in isolated lab networks**. Never aim tests at systems you do not own or manage.

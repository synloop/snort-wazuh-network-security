# Wazuh Lab – README

This folder contains everything needed to reproduce the **HEPIA Summer Lab – SIEM with Wazuh**:

- Wazuh **local rule** and **decoder** to detect ICMP echo-requests logged by the Linux kernel.
- An **auditd rule** to tag relevant syscalls (part of the exercise).
- Helper **scripts** and a **Makefile** to deploy, verify, and demo the lab fast.
- Screenshots used in the report.

The lab uses **two VMs** (VirtualBox):

| Node   | Role                                  | OS (example) | Host‑Only IP       |
|--------|---------------------------------------|--------------|--------------------|
| server | Wazuh Server + Dashboard + Indexer    | Ubuntu 22.04 | `192.168.56.102`   |
| client | Wazuh Agent                           | Ubuntu 22.04 | `192.168.56.101`   |

> Adjust IPs if your lab uses different addresses.

---

## Repository layout (this folder)

```
wazuh/
├─ Makefile
├─ README.md
├─ config/
│  ├─ local_rules.xml         # Wazuh rule: raises alert on kernel ICMP logs
│  ├─ local_decoder.xml       # Wazuh decoder: parses kernel ICMP log line
│  └─ audit/
│     └─ ping.rules           # auditd rule (sendto syscall tagged ping_detect)
├─ scripts/
│  ├─ setup_iptables.sh       # create logging chain for ICMP echo-requests
│  ├─ reset_iptables.sh       # remove custom chain
│  ├─ tail_icmp_logs.sh       # follow kernel logs (ICMP_PACKET prefix)
│  └─ verify_wazuh_health.sh  # quick Wazuh manager health checks
└─ images/
   ├─ dashboard_agent_active.PNG
   ├─ user_created_alerts.PNG
   ├─ audit_ping_ausearch.PNG
   ├─ kernel_log_icmp.PNG
   ├─ iptables_counters.PNG
   └─ wazuh_alert_icmp.PNG
```

---

## What this lab demonstrates

1. **Auditd + ausearch** to tag/verify single ping operations (`sendto()`).
2. **Netfilter (iptables) logging** of ICMP echo-requests from the client VM.
3. **Wazuh decoder + rule** that turns those kernel log lines into **structured alerts** in the Wazuh Dashboard.

High‑level flow for exercise #3:

```
client ping -> server kernel logs (iptables LOG with "ICMP_PACKET: ...") 
            -> journald/syslog
            -> Wazuh logcollector
            -> local_decoder.xml parses fields (e.g., SRC, DST)
            -> local_rules.xml matches "ICMP_PACKET" and raises an alert
            -> Wazuh Dashboard displays the alert
```

---

## Prerequisites (server VM)

- Wazuh Server (manager, indexer, dashboard) **installed and running**.
- `auditd` installed and running.
- `iptables` available (on Ubuntu, the `iptables-nft` backend also works).
- Systemd/journald enabled (default on Ubuntu).
- Your **client** VM can reach the **server** VM (host‑only network).

---

## Quick start

> All commands below are run on the **server VM** (`192.168.56.102`) unless stated otherwise.

1) **Enter this folder on the server VM**
```bash
cd /path/to/your/repo/wazuh
```

2) **Deploy Wazuh content + audit rule**
```bash
make deploy
```
This copies:
- `config/local_rules.xml` → `/var/ossec/etc/rules/local_rules.xml`
- `config/local_decoder.xml` → `/var/ossec/etc/decoders/local_decoder.xml`
- `config/audit/ping.rules` → `/etc/audit/rules.d/ping.rules`

and then **restarts** `wazuh-manager` and **reloads** audit rules.

3) **Configure iptables logging for ICMP** (from the client IP)
```bash
make iptables CLIENT_IP=192.168.56.101
```
This creates a dedicated chain (e.g., `PING_IN_LOG`) that:
- **LOGs** ICMP **echo-request** with prefix `ICMP_PACKET: `
- then **ACCEPTs** it (so ping still works)

> If your client IP differs, pass `CLIENT_IP=<your_client_ip>`.

4) **Generate traffic** (on the **client VM**)
```bash
ping -c 1 192.168.56.102
```

5) **Verify kernel logs** (server VM)
```bash
make tail-icmp
# or simply:
# journalctl -k -f | grep "ICMP_PACKET:"
```
You should see lines containing the prefix `ICMP_PACKET:` with SRC/DST.

6) **Verify counters** (server VM)
```bash
make counters
```
You should see packet/byte counters increasing on the `PING_IN_LOG` chain.

7) **Check Wazuh health** (server VM)
```bash
make health
```

8) **Open the Wazuh Dashboard** and confirm the ICMP alert  
Navigate to `https://192.168.56.102/` → Search alerts for your time window.  
You should see an alert matching the local rule (see **images/wazuh_alert_icmp.PNG**).

---

## How the Makefile works

The Makefile automates deployment and testing. Main targets:

| Target | What it does |
|-------|---------------|
| `make deploy` | Copies **local_rules.xml**, **local_decoder.xml**, and **audit/ping.rules** to their system paths, restarts **wazuh-manager**, reloads **auditd** rules. |
| `make iptables CLIENT_IP=…` | Calls `scripts/setup_iptables.sh` to create a custom iptables chain that **LOGs** ICMP echo‑requests from the given client IP with prefix **`ICMP_PACKET: `** and then ACCEPTs them. |
| `make counters` | Shows packet/byte counters for the custom chain (helps prove the filter is hit). |
| `make tail-icmp` | Tails kernel logs and filters for the `ICMP_PACKET:` prefix. |
| `make health` | Runs quick Wazuh manager checks via `scripts/verify_wazuh_health.sh`. |
| `make reset-iptables` | Removes the custom chain/rules created by the lab (cleanup). |
| `make status-manager` | Displays `wazuh-manager` systemd status. |
| `make clean` | Alias of `reset-iptables`. |

**Variables**

- `CLIENT_IP` (default in the Makefile: `192.168.56.101`)  
  You can override it per command:  
  `make iptables CLIENT_IP=192.168.56.50`

**Where files are installed**

- `/var/ossec/etc/rules/local_rules.xml`
- `/var/ossec/etc/decoders/local_decoder.xml`
- `/etc/audit/rules.d/ping.rules`

> After changing rules/decoders, you must restart `wazuh-manager` (done by `make deploy`).

---

## About the Wazuh files

- **`config/local_rules.xml`**  
  Defines a **local rule** (e.g., ID `199993`, level `5`, group `icmp,syslogicmp`) that triggers on **kernel** lines containing the marker **`ICMP_PACKET`**:
  ```xml
  <group name="icmp,syslogicmp,">
    <rule id="199993" level="5">
      <decoded_as>kernel</decoded_as>
      <match>ICMP_PACKET</match>
      <description>Ping detected from ICMP log</description>
    </rule>
  </group>
  ```

- **`config/local_decoder.xml`**  
  A local **decoder** that helps Wazuh parse kernel log lines produced by iptables (those with the `ICMP_PACKET:` prefix).  
  It extracts IPs (SRC/DST) and ensures the event is **decoded as `kernel`** so the rule above can match.  
  > Open the file to see the exact regex/prematch used in your lab.

- **`config/audit/ping.rules`**  
  Adds an **auditd** rule (key `ping_detect`) to tag relevant syscalls (e.g., `sendto()`).  
  Reload with `augenrules --load` (already handled by `make deploy`).

---

## Screenshots (for the report)

- `images/dashboard_agent_active.PNG` — Agent is connected and healthy.
- `images/user_created_alerts.PNG` — Alerts for the new user creation exercise.
- `images/audit_ping_ausearch.PNG` — `ausearch -k ping_detect` output (single-ping audit).
- `images/kernel_log_icmp.PNG` — Kernel log lines (`ICMP_PACKET:`) while pinging.
- `images/iptables_counters.PNG` — iptables counters rising on the custom chain.
- `images/wazuh_alert_icmp.PNG` — Wazuh alert triggered by the ICMP log match.

---

## Troubleshooting

- **No ICMP alerts in Wazuh**
  - Ensure the **prefix** in iptables is exactly `ICMP_PACKET: ` (a trailing space is OK—match your decoder).
  - Check kernel logs: `journalctl -k -n 100 | grep ICMP_PACKET`.
  - Verify counters: `make counters`.
  - Confirm manager is running: `make status-manager`.
  - Check Wazuh logs for rule/decoder loading issues:  
    `/var/ossec/logs/ossec.log`

- **Audit rule not visible**
  - `sudo auditctl -l | grep ping_detect`
  - If missing: `sudo augenrules --load && sudo systemctl restart auditd`

- **Dashboard unreachable**
  - `sudo systemctl status wazuh-dashboard --no-pager`
  - Verify tcp/443 is listening: `sudo ss -lntp | egrep ':443\b'`
  - If needed, allow firewall: `sudo ufw allow 443/tcp`

- **iptables vs nftables**
  - On recent Ubuntu, `iptables` commands are translated by nft. This lab works as-is.
  - If you have legacy conflicts, select the backend: `sudo update-alternatives --config iptables`

- **Log flooding**
  - The iptables `LOG` target can be noisy. Use **`make reset-iptables`** after the lab.

---

## Cleanup

Remove the custom logging chain and references:
```bash
make reset-iptables
```

(Your Wazuh local rule/decoder and auditd rule remain installed; remove them manually if needed.)

---

## License

See the repository’s top-level `LICENSE` file.

---

## Credits

Prepared for **HEPIA – Practical Network Security (Summer Lab)**.  
Covers Wazuh installation, auditd verification, and custom ICMP detection end‑to‑end.

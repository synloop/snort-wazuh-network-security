# Snort IDS/IPS on pfSense – HEPIA Summer Lab

This folder contains the practical work I completed with Snort on pfSense, used both as an IDS (alert-only) and as an IPS (Block Offenders + Kill States). The rules, tests and outcomes match my report “Intrusion Detection System – SNORT” (June 26, 2025).

## Rules covered
- 1000001 – ICMP Ping detected (all ICMP)
- 1000002 – Inbound ICMP Ping (external → internal only)
- 1000003 – DNS request with "youtube" (policy alert)
- 1000004 – Possible Nmap Scan (SYN threshold)
- 1000005 – SSH Brute Force attempt (>3 in 60s)
- 10000012 – Possible Data Exfiltration (large TCP payload)

See `rules/custom.rules` for the exact signatures.

## How I ran it

### IDS (alert-only)
- pfSense → Services → Snort → LAN → Enable interface
- Add rules in **LAN Rules → custom.rules**
- Start the LAN Snort instance (blue ▶)

### IPS (active blocking)
- pfSense → Services → Snort → LAN → Block Settings
- Enable **Block Offenders** and **Kill States**
- Test again with the same scripts; repeat attempts are blocked

Inline mode was not used in this lab due to virtual NIC constraints; the IPS path shown here relies on Block Offenders + Kill States.

## Quick tests

From the Ubuntu client:

./scripts/ping_gateway.sh
./scripts/dns_youtube.sh
./scripts/nmap_scan.sh
./scripts/ssh_bruteforce_loop.sh
./scripts/hydra_ssh.sh
./scripts/exfil_passwd.sh

Expected outcomes:
- ICMP: alerts for all pings, then only for external after refinement
- DNS: alert when resolving youtube.com
- Nmap: burst of “Possible Nmap Scan” alerts
- SSH: alert after more than 3 attempts in 60 seconds
- Exfiltration: alert on large outbound payload; with IPS enabled, the offender is added to Blocked Hosts and states are killed

## Notes
- Interface-scoped rules reduce false positives and keep detection relevant per zone (WAN vs LAN).
- HTTPS content is encrypted; detection of browsing relies on DNS or TLS SNI, not payload inspection.

#!/bin/bash
#
# Perform port scanning

#######################################
# Port scanning and basic detection
# Arguments:
#   naabu out
# Outputs:
#   Writes to stdout
#######################################
# NSE-approach
# nmap --script "discovery,ftp*,ssh*,http-vuln*,mysql-vuln*,imap-*,pop3-*" -iL $TARGETDIR/nmap_input.txt
nmap_nse(){
  # https://gist.github.com/storenth/b419dc17d2168257b37aa075b7dd3399
  # https://youtu.be/La3iWKRX-tE?t=1200
  # https://medium.com/@noobhax/my-recon-process-dns-enumeration-d0e288f81a8a
  echo "[$(date +%H:%M:%S)] [nmap] scanning..."

  while read line; do
    IP=$(echo $line | cut -f1 -d ':')
    PORT=$(echo $line | cut -f2 -d ':')

    echo "[nmap] scanning $IP using $PORT port"
    # -n: no DNS resolution
    # -Pn: Treat all hosts as online - skip host discovery
    # -sV: Probe open ports to determine service/version info (--version-intensity 9: means maximum probes)
    # -sS: raw packages
    # -sC: equivalent to --script=default (-O and -sC equal to run with -A)
    # -T4: aggressive time scanning
    # --spoof-mac Cisco: Spoofs the MAC address to match a Cisco product (0=random)
    # -f: used to fragment the packets (i.e. split them into smaller pieces) making it less likely that the packets will be detected by a firewall or IDS.

    # grep smtp /usr/local/Cellar/nmap/7.91/share/nmap/scripts/script.db
    # grep "intrusive" /usr/share/nmap/scripts/script.db
    nmap --spoof-mac 0 -n -sV --version-intensity 9 --script=default,http-headers -sS -Pn -T4 -f -p"${PORT}" "${IP}"
    echo
    echo
  done < $1
  echo "[$(date +%H:%M:%S)] [nmap] done."
}

nmap_nse $1

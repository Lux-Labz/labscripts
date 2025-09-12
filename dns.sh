#!/usr/bin/env bash

set -euo pipefail

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Try: sudo $0"
   exit 1
fi

# DNS configuration
PIHOLE="10.50.255.17"
BACKUP1="1.1.1.1"
BACKUP2="8.8.8.8"
SEARCH_DOMAIN="lan"
RESOLV_CONF="/etc/resolv.conf"

echo "[*] Stopping and disabling systemd-resolved..."
systemctl stop systemd-resolved
systemctl disable systemd-resolved

echo "[*] Removing symlinked /etc/resolv.conf if it exists..."
if [ -L "$RESOLV_CONF" ]; then
    rm -f "$RESOLV_CONF"
fi

echo "[*] Creating new resolv.conf..."
cat > "$RESOLV_CONF" <<EOF
search ${SEARCH_DOMAIN}
nameserver ${PIHOLE}
nameserver ${BACKUP1}
nameserver ${BACKUP2}
EOF

echo "[*] Done! Current resolv.conf contents:"
cat "$RESOLV_CONF"


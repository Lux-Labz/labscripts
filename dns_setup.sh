#!/usr/bin/env bash
set -euo pipefail

# ------------------------
# CONFIGURATION
# ------------------------
PIHOLE="10.50.255.17"
BACKUP1="1.1.1.1"
BACKUP2="8.8.8.8"
SEARCH_DOMAIN="lan"
RESOLV_CONF="/etc/resolv.conf"

# ------------------------
# PRECHECKS
# ------------------------
if [[ $EUID -ne 0 ]]; then
    echo "❌ This script must be run as root. Try: sudo $0"
    exit 1
fi

# ------------------------
# SYSTEMD RESOLVED
# ------------------------
echo "[*] Stopping and disabling systemd-resolved..."
if systemctl is-active --quiet systemd-resolved; then
    systemctl stop systemd-resolved
fi
systemctl disable systemd-resolved || true

# ------------------------
# RESOLV.CONF
# ------------------------
echo "[*] Handling /etc/resolv.conf..."
if [ -L "$RESOLV_CONF" ]; then
    echo "[*] Removing symlinked /etc/resolv.conf..."
    rm -f "$RESOLV_CONF"
fi

# Backup previous resolv.conf if not already backed up
BACKUP_FILE="${RESOLV_CONF}.backup"
if [ ! -f "$BACKUP_FILE" ]; then
    echo "[*] Backing up current resolv.conf to $BACKUP_FILE"
    cp "$RESOLV_CONF" "$BACKUP_FILE" || true
fi

# Desired resolv.conf content
read -r -d '' NEW_RESOLV <<EOF || true
search ${SEARCH_DOMAIN}
nameserver ${PIHOLE}
nameserver ${BACKUP1}
nameserver ${BACKUP2}
EOF

# Only overwrite if different
if ! diff -q <(echo "$NEW_RESOLV") "$RESOLV_CONF" >/dev/null 2>&1; then
    echo "[*] Writing new resolv.conf..."
    echo "$NEW_RESOLV" > "$RESOLV_CONF"
else
    echo "[*] resolv.conf already up-to-date. Skipping write."
fi

echo "[*] Done! Current resolv.conf contents:"
cat "$RESOLV_CONF"


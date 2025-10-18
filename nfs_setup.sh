#!/bin/bash
set -e

# ------------------------
# CONFIGURATION
# ------------------------
NAS_HOST="nas"
NAS_SHARE="/volume1/lab"
MOUNT_POINT="/lab"

MOUNT_UNIT="/etc/systemd/system/lab.mount"
AUTOMOUNT_UNIT="/etc/systemd/system/lab.automount"

# ------------------------
# PRECHECKS
# ------------------------
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run this script as root (sudo)."
    exit 1
fi

# Install NFS utilities if missing
if ! command -v mount.nfs >/dev/null 2>&1; then
    echo "📦 Installing NFS utilities..."
    apt-get update -y
    apt-get install -y nfs-common
else
    echo "✅ NFS utilities already installed."
fi

# ------------------------
# CREATE MOUNT POINT
# ------------------------
if [ ! -d "$MOUNT_POINT" ]; then
    mkdir -p "$MOUNT_POINT"
    echo "✅ Mount point $MOUNT_POINT created."
else
    echo "✅ Mount point $MOUNT_POINT already exists."
fi

# ------------------------
# CREATE SYSTEMD UNITS
# ------------------------
if [ ! -f "$MOUNT_UNIT" ]; then
cat > "$MOUNT_UNIT" <<EOF
[Unit]
Description=Mount NFS Share for Lab
Requires=network-online.target
After=network-online.target

[Mount]
What=${NAS_HOST}:${NAS_SHARE}
Where=${MOUNT_POINT}
Type=nfs
Options=_netdev,hard,intr,timeo=14,retrans=3,nofail

[Install]
WantedBy=multi-user.target
EOF
    echo "✅ Mount unit created: $MOUNT_UNIT"
else
    echo "✅ Mount unit already exists: $MOUNT_UNIT"
fi

if [ ! -f "$AUTOMOUNT_UNIT" ]; then
cat > "$AUTOMOUNT_UNIT" <<EOF
[Unit]
Description=Automount NFS Share for Lab

[Automount]
Where=${MOUNT_POINT}
TimeoutIdleSec=600

[Install]
WantedBy=multi-user.target
EOF
    echo "✅ Automount unit created: $AUTOMOUNT_UNIT"
else
    echo "✅ Automount unit already exists: $AUTOMOUNT_UNIT"
fi

chmod 644 "$MOUNT_UNIT" "$AUTOMOUNT_UNIT"

# ------------------------
# ENABLE & START AUTOMOUNT
# ------------------------
systemctl daemon-reload
systemctl enable lab.automount --now

echo "✅ NFS setup completed successfully."


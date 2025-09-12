#!/bin/bash

# Variables
NAS_HOST="nas"
NAS_SHARE="/volume1/lab"   # Exported NFS path on the NAS
MOUNT_POINT="/lab"         # Local directory to mount to
FSTAB_ENTRY="${NAS_HOST}:${NAS_SHARE} ${MOUNT_POINT} nfs defaults,_netdev 0 0"

# Check for sudo
if ! command -v sudo >/dev/null 2>&1; then
    echo "Error: sudo is not installed. Please install it or run this script as root."
    exit 1
fi

# Ensure NFS client utilities are installed (Debian/Ubuntu)
if ! command -v mount.nfs >/dev/null 2>&1; then
    echo "NFS utilities not found. Installing..."
    sudo apt update
    sudo apt install -y nfs-common
    if ! command -v mount.nfs >/dev/null 2>&1; then
        echo "❌ Failed to install NFS utilities."
        exit 1
    fi
    echo "✅ NFS utilities installed successfully."
fi

# Create the mount point if it doesn't exist
if [ ! -d "$MOUNT_POINT" ]; then
    echo "Creating mount point: $MOUNT_POINT"
    sudo mkdir -p "$MOUNT_POINT"
fi

# Check if already mounted
if mountpoint -q "$MOUNT_POINT"; then
    echo "$MOUNT_POINT is already mounted."
else
    # Mount the NFS share
    echo "Mounting NFS share from $NAS_HOST:$NAS_SHARE to $MOUNT_POINT"
    if sudo mount -t nfs "${NAS_HOST}:${NAS_SHARE}" "$MOUNT_POINT"; then
        echo "✅ NFS share successfully mounted at $MOUNT_POINT"
    else
        echo "❌ Failed to mount NFS share"
        exit 1
    fi
fi

# Add to /etc/fstab if not already present
if ! grep -qs "^${NAS_HOST}:${NAS_SHARE} ${MOUNT_POINT} " /etc/fstab; then
    echo "Adding entry to /etc/fstab for persistent mount"
    echo "$FSTAB_ENTRY" | sudo tee -a /etc/fstab >/dev/null
    echo "✅ Entry added to /etc/fstab"
else
    echo "Entry already exists in /etc/fstab"
fi


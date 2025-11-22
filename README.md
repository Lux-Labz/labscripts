# Lab NFS Deployment README

## Overview

This guide explains how to deploy `nfs_setup.sh` to multiple lab computers safely using `deploy.sh`.

### Features:

* Serial deployment (one host at a time)
* Automatic skipping of unreachable hosts
* Retry logic for failed hosts
* Logging and CSV summary on admin machine
* Root execution on lab machines via `sudo`
* Safe to rerun multiple times

---

## Prerequisites

* Admin machine with SSH access to lab computers
* Lab computers with administrative privileges
* Bash shell on all machines

---

## Step 1: Prepare Admin Machine

1. Ensure `ssh` and `scp` are installed:

```bash
sudo apt update
sudo apt install -y openssh-client
```

2. Verify Bash:

```bash
bash --version
```

---

## Step 2: Set Up Passwordless SSH

1. Generate SSH key pair (skip if you already have one):

```bash
ssh-keygen -t ed25519
```

2. Copy key to each lab host:

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub lab@desktop03
ssh-copy-id -i ~/.ssh/id_ed25519.pub lab@desktop04
```

3. Test SSH connection:

```bash
ssh lab@desktop03 "echo 'success'"
```

---

## Step 3: Prepare Deployment Scripts

1. Copy `deploy.sh` and `nfs_setup.sh` to admin machine:

```
~/lab_deploy/
├── deploy.sh
├── nfs_setup.sh
└── lab_hosts.txt
```

2. Make scripts executable:

```bash
chmod +x deploy.sh nfs_setup.sh
```

---

## Step 4: Prepare Host List

Create `lab_hosts.txt` with one hostname/IP per line:

```
labpc01
labpc02
labpc03
```

* Lines starting with `#` are ignored
* Ensure hostnames are resolvable from admin machine

---

## Step 5: Run Deployment

```bash
./deploy.sh nfs_setup.sh lab_hosts.txt
```

* Deploys scripts serially
* Runs `nfs_setup.sh` as root via `sudo` on lab hosts
* Logs and CSV summary are written on admin machine only
* Safe to rerun multiple times

---

## Step 6: Verify Deployment

1. Check logs:

```bash
less deployment_log_YYYYMMDD_HHMMSS.log
```

2. Check CSV summary:

```bash
cat deployment_summary_YYYYMMDD_HHMMSS.csv
```

3. Optional: verify NFS mount on a host:

```bash
ssh labpc01 "mount | grep /lab"
```

---

## Step 7: Notes

* Serial deployment simplifies debugging
* All output captured on admin machine; lab machines do not need log write permissions
* Root execution on lab machines is required for mounting NFS and creating systemd units
* Scripts are idempotent and safe to rerun

---

## Summary

This setup allows you to deploy NFS mounts across your lab efficiently, safely, and with full logging on the admin machine.


#!/bin/bash
set -euo pipefail

# ------------------------
# CONFIGURATION
# ------------------------
SUDO_PASS="lab123"            # <-- lab sudo password (plaintext)
RETRY_ATTEMPTS=2
REMOTE_DIR="~/lab_deploy"     # user-writable dir on remote hosts
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m"

# ------------------------
# ARGUMENTS
# ------------------------
if [ $# -ne 2 ]; then
    echo -e "Usage: $0 <script_to_deploy> <host_list_file>"
    exit 1
fi

SCRIPT="$1"
HOST_LIST="$2"
SCRIPT_NAME=$(basename "$SCRIPT")
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="./deployment_log_${TIMESTAMP}.log"
CSV_FILE="./deployment_summary_${TIMESTAMP}.csv"

# ------------------------
# PRECHECKS
# ------------------------
if [ ! -f "$SCRIPT" ]; then
    echo -e "${RED}❌ Deployment script not found: $SCRIPT${NC}"
    exit 1
fi

if [ ! -f "$HOST_LIST" ]; then
    echo -e "${RED}❌ Host list not found: $HOST_LIST${NC}"
    exit 1
fi

echo -e "${GREEN}=== $(date): Starting deployment of $SCRIPT ===${NC}" | tee -a "$LOG_FILE"

# Initialize CSV
echo "Host,Status,Message" > "$CSV_FILE"

# ------------------------
# DEPLOY FUNCTION
# ------------------------
deploy_one() {
    local HOST="$1"
    local TIMESTAMP
    local SUCCESS=0
    local MESSAGE=""

    set +e  # allow failures inside this function

    # Quick reachable test
    if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$HOST" "echo 1" &>/dev/null; then
        TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
        MESSAGE="Host unreachable or SSH failed"
        echo -e "[$TIMESTAMP] ${YELLOW}⚠️ $HOST unreachable. Skipping.${NC}" | tee -a "$LOG_FILE"
        echo "$HOST,Skipped,$MESSAGE" >> "$CSV_FILE"
        set -e
        return
    fi

    # Create remote directory
    ssh "$HOST" "mkdir -p $REMOTE_DIR"

    for ((i=1;i<=RETRY_ATTEMPTS;i++)); do
        TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
        echo "[$TIMESTAMP] 🚀 Deploying to: $HOST" | tee -a "$LOG_FILE"

        # Copy script
        scp "$SCRIPT" "$HOST:$REMOTE_DIR/$SCRIPT_NAME"
        if [ $? -ne 0 ]; then
            MESSAGE="Failed to copy script (attempt $i)"
            echo -e "[$TIMESTAMP] ${YELLOW}⚠️ $MESSAGE${NC}" | tee -a "$LOG_FILE"
            continue
        fi

        # Make executable
        ssh "$HOST" "chmod +x $REMOTE_DIR/$SCRIPT_NAME"
        echo "[$TIMESTAMP] ✅ Script made executable on $HOST" | tee -a "$LOG_FILE"

        # Run remotely with sudo -S
        ssh "$HOST" "echo '$SUDO_PASS' | sudo -S $REMOTE_DIR/$SCRIPT_NAME" >/dev/null 2>>"$LOG_FILE"
        SSH_EXIT="$?"

        if [ "$SSH_EXIT" -eq 0 ]; then
            MESSAGE="Deployment completed successfully"
            echo -e "[$TIMESTAMP] ${GREEN}✅ Deployment successful on $HOST${NC}" | tee -a "$LOG_FILE"
            echo "$HOST,Success,$MESSAGE" >> "$CSV_FILE"
            SUCCESS=1
            break
        else
            MESSAGE="Deployment attempt $i failed (exit $SSH_EXIT)"
            echo -e "[$TIMESTAMP] ${YELLOW}⚠️ $MESSAGE on $HOST${NC}" | tee -a "$LOG_FILE"
        fi
    done

    if [ $SUCCESS -eq 0 ]; then
        MESSAGE="Deployment failed after $RETRY_ATTEMPTS attempts"
        TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
        echo -e "[$TIMESTAMP] ${RED}❌ $MESSAGE on $HOST${NC}" | tee -a "$LOG_FILE"
        echo "$HOST,Failed,$MESSAGE" >> "$CSV_FILE"
    fi

    set -e
}

# ------------------------
# SERIAL DEPLOYMENT USING ARRAY (robust)
# ------------------------
# Read hosts into array, remove blank lines, spaces, comments, and \r
mapfile -t HOSTS < <(sed 's/\r$//' "$HOST_LIST" | grep -Ev '^\s*#|^\s*$')

for HOST in "${HOSTS[@]}"; do
    deploy_one "$HOST"
done

# ------------------------
# SUMMARY
# ------------------------
echo -e "\n${GREEN}=== Deployment Summary ===${NC}" | tee -a "$LOG_FILE"
grep -F ",Success," "$CSV_FILE" | cut -d, -f1 | xargs -r echo -e "${GREEN}✅ Successful hosts:${NC}" | tee -a "$LOG_FILE"
grep -F ",Skipped," "$CSV_FILE" | cut -d, -f1 | xargs -r echo -e "${YELLOW}⚠️ Skipped/unreachable hosts:${NC}" | tee -a "$LOG_FILE"
grep -F ",Failed," "$CSV_FILE" | cut -d, -f1 | xargs -r echo -e "${RED}❌ Failed hosts:${NC}" | tee -a "$LOG_FILE"

echo -e "${GREEN}=== Deployment completed. Logs: $LOG_FILE | CSV report: $CSV_FILE ===${NC}"


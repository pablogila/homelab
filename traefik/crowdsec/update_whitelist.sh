#!/bin/bash
# This script updates your personal and home IPs in the CrowdSec whitelist.
# Make sure to configure your Dynamic DNS domains and the whitelist file path in update_whitelist.cfg
# You can run this with a cron to keep the whitelist updated.

# Load external configuration
CONFIG_FILE="$(dirname "$0")/update_whitelist.cfg"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "Error: Configuration file not found at $CONFIG_FILE"
    exit 1
fi

RELOAD_NEEDED=0
TIME=$(date +"%Y-%m-%d_%H:%M:%S_%Z")

update_ip() {
    local TAG=$1
    shift  # Shift the arguments so that "$@" only contains the domains
    local NEW_IP=""
    # Loop through the provided DNS resolvers until a valid IP is found
    for DOMAIN in "$@"; do
        NEW_IP=$(dig +short +time=5 +tries=3 "$DOMAIN" | grep -E '^[0-9.]+$' | tail -n1)
        if [ -n "$NEW_IP" ]; then
            break
        fi
    done
    # Proceed only if we got a valid, non-empty IP address
    if [ -n "$NEW_IP" ]; then
        # Unban the IP if it was accidentally blocked before
        if docker exec crowdsec cscli decisions list -i "$NEW_IP" 2>/dev/null | grep -q "$NEW_IP"; then
            docker exec crowdsec cscli decisions delete --ip "$NEW_IP" >/dev/null 2>&1
        fi
        # Check the current IP from the whitelist file, between the ""
        local CURRENT_IP=$(grep "# $TAG" "$WHITELIST_FILE" | awk -F'"' '{print $2}')
        # Update only if the IPs are different
        if [ "$NEW_IP" != "$CURRENT_IP" ]; then
            sed -i "s|.*# $TAG.*|    - \"$NEW_IP\"  # $TAG  $TIME|" "$WHITELIST_FILE"
            RELOAD_NEEDED=1
        fi
    fi
}

# Iterate over the DOMAINS array defined in update_whitelist.cfg
for entry in "${DOMAINS[@]}"; do
    read -r -a args <<< "$entry"
    update_ip "${args[@]}"
done

# Reload CrowdSec config files only if an IP actually changed
if [ "$RELOAD_NEEDED" -eq 1 ]; then
    docker exec crowdsec kill -HUP 1
fi

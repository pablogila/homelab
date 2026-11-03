#!/bin/bash
# This script is intended to run at startup and daily at night,
# so that it copies and activates a neighboring WireGuard .conf file
# to connect the NAS to another server.

current_folder=$(dirname "$0")
log_file="$current_folder/log.txt"
touch "$log_file"

shopt -s nullglob
conf_files=("$current_folder"/*.conf)
shopt -u nullglob
if [ ${#conf_files[@]} -eq 0 ]; then
    echo "Error: Missing .conf file!"
    exit 1
elif [ ${#conf_files[@]} -gt 1 ]; then
    echo "Error: More than one .conf file found, there should only be one!"
    exit 1
fi

WG_CONF_FILEPATH="${conf_files[0]}"
cp "$WG_CONF_FILEPATH" /etc/wireguard/nas2wg.conf

previous_log=$(tail -n 2000 "$log_file")
{
[ -n "$previous_log" ] && echo "$previous_log"
echo "Restarting WireGuard connection on $(date):"
/usr/bin/wg-quick down nas2wg 2>&1
/usr/bin/wg-quick up nas2wg 2>&1
echo "----------------------------------------"
} > "$log_file"

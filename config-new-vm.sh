#!/bin/bash

# Version: 2.0

# Variables
PROXMOX_API_URL="https://172.16.1.5:8006/api2/json"
API_TOKEN_ID="deployments-newvms@pam!deployments-newvms-token"
API_TOKEN_SECRET="c8ef1757-d1ba-4d26-8d90-97d9b765abc3"
VMID="500"
NODE_NAME="gpu1"  # Confirm that this is the correct node name
CURRENT_HOSTNAME=$(hostname)
IP_BEFORE=$(hostname -I | awk '{print $1}')

# Colors for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging Function
log_message() {
    echo -e "${CYAN}[$(date +%Y-%m-%dT%H:%M:%S)] ${YELLOW}$1${NC}"
}

success_message() {
    echo -e "${GREEN}[$(date +%Y-%m-%dT%H:%M:%S)] $1${NC}"
}

error_message() {
    echo -e "${RED}[$(date +%Y-%m-%dT%H:%M:%S)] $1${NC}"
}

# Step 1: Prompt user for the new hostname
read -p "Enter the new hostname (avoid periods): " NEW_HOSTNAME

# Check for period in hostname
if [[ "$NEW_HOSTNAME" == *"."* ]]; then
    error_message "Error: Hostname should not contain periods."
    exit 1
fi

# Step 2: Update the hostname temporarily (for the current session)
log_message "Changing hostname from ${RED}$CURRENT_HOSTNAME${YELLOW} to ${GREEN}$NEW_HOSTNAME${NC}..."
sudo hostnamectl set-hostname "$NEW_HOSTNAME"

# Step 3: Update /etc/hostname file
echo "$NEW_HOSTNAME" | sudo tee /etc/hostname > /dev/null

# Step 4: Update /etc/hosts file
sudo sed -i "s/$CURRENT_HOSTNAME/$NEW_HOSTNAME/g" /etc/hosts

# Step 5: Release and renew IP address
log_message "Releasing IP address..."
if ! command -v dhclient &> /dev/null; then
    error_message "Error: dhclient not found. Please install it using 'sudo apt install isc-dhcp-client'."
    exit 1
fi
sudo dhclient -r
log_message "Renewing IP address..."
sudo dhclient -v

# Step 6: Display old and new IP addresses
IP_AFTER=$(hostname -I | awk '{print $1}')
success_message "Old IP Address: $IP_BEFORE"
success_message "New IP Address: $IP_AFTER"

# Step 7: Update the Proxmox VM name using the API
log_message "Updating Proxmox VM name in the Proxmox UI..."
RESPONSE=$(curl -k -s -X PUT "$PROXMOX_API_URL/nodes/$NODE_NAME/qemu/$VMID/config" \
    -H "Authorization: PVEAPIToken=$API_TOKEN_ID=$API_TOKEN_SECRET" \
    -d "name=$NEW_HOSTNAME")

# Log the full response from Proxmox for debugging
log_message "Proxmox API response: $RESPONSE"

# Check for errors in the response and provide feedback
if [[ $RESPONSE == *"errors"* ]]; then
    error_message "Failed to update Proxmox VM name. Detailed response: $RESPONSE"
else
    success_message "Proxmox VM name successfully updated to $NEW_HOSTNAME."
fi

# Step 8: Set Welcome Message (Message of the Day)
log_message "Setting custom welcome message for $NEW_HOSTNAME..."
WELCOME_MESSAGE="Welcome to $NEW_HOSTNAME\n\n\
IP Address: $IP_AFTER\n\
Hostname: $NEW_HOSTNAME\n\
Proxmox VM ID: $VMID\n\
Logged in on: $(date)\n\
\nEnjoy your session!"

echo -e "$WELCOME_MESSAGE" | sudo tee /etc/motd > /dev/null
success_message "Custom MOTD set with updated IP address: $IP_AFTER."

# Final message
success_message "Hostname successfully changed from '$CURRENT_HOSTNAME' to '$NEW_HOSTNAME'."

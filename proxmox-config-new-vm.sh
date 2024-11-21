#!/bin/bash

# Version: 3.0

# Load Environment Variables
if [ -f .env.proxmox ]; then
    source .env.proxmox
else
    echo "Error: .env.proxmox file not found. Please create it with PROXMOX_API_TOKEN_ID and PROXMOX_API_TOKEN_SECRET."
    exit 1
fi

# Variables
PROXMOX_API_URL="https://172.16.1.5:8006/api2/json"
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

# Logging Functions
log_message() {
    echo -e "${CYAN}[$(date +%Y-%m-%dT%H:%M:%S)] ${YELLOW}$1${NC}"
}

success_message() {
    echo -e "${GREEN}[$(date +%Y-%m-%dT%H:%M:%S)] $1${NC}"
}

error_message() {
    echo -e "${RED}[$(date +%Y-%m-%dT%H:%M:%S)] $1${NC}"
}

# Validate Proxmox API Token
log_message "Validating Proxmox API token..."
VALIDATE_TOKEN=$(curl -k -s -o /dev/null -w "%{http_code}" -H "Authorization: PVEAPIToken=$PROXMOX_API_TOKEN_ID=$PROXMOX_API_TOKEN_SECRET" "$PROXMOX_API_URL/version")
if [[ "$VALIDATE_TOKEN" -ne 200 ]]; then
    error_message "Proxmox API token validation failed. Please check your .env.proxmox file."
    exit 1
fi
success_message "Proxmox API token validated successfully."

# Check for hostname argument or prompt user
if [[ -z "$1" ]]; then
    read -p "Enter the new hostname (alphanumeric, hyphens, periods allowed): " NEW_HOSTNAME
else
    NEW_HOSTNAME="$1"
fi

# Validate hostname (allow alphanumeric, periods, and hyphens)
if ! [[ "$NEW_HOSTNAME" =~ ^[a-zA-Z0-9.-]+$ ]]; then
    error_message "Error: Hostname must use only alphanumeric characters, hyphens, and periods."
    exit 1
fi

# Confirmation prompt
log_message "You are about to change the hostname from ${RED}$CURRENT_HOSTNAME${YELLOW} to ${GREEN}$NEW_HOSTNAME${NC}."
read -p "Are you sure you want to proceed? [y/N]: " CONFIRM
if [[ "$CONFIRM" != "y" ]]; then
    error_message "Operation canceled by user."
    exit 0
fi

# Step 1: Update the hostname temporarily (for the current session)
log_message "Changing hostname to $NEW_HOSTNAME..."
sudo hostnamectl set-hostname "$NEW_HOSTNAME" || { error_message "Failed to update hostname."; exit 1; }

# Step 2: Update /etc/hostname file
echo "$NEW_HOSTNAME" | sudo tee /etc/hostname > /dev/null

# Step 3: Update /etc/hosts file
sudo sed -i "s/$CURRENT_HOSTNAME/$NEW_HOSTNAME/g" /etc/hosts

# Step 4: Check and Install isc-dhcp-client if missing
log_message "Checking for DHCP client (isc-dhcp-client)..."
if ! command -v dhclient &> /dev/null; then
    log_message "isc-dhcp-client not found. Installing..."
    sudo apt update && sudo apt install -y isc-dhcp-client || { error_message "Failed to install isc-dhcp-client."; exit 1; }
    success_message "isc-dhcp-client installed successfully."
else
    success_message "isc-dhcp-client is already installed."
fi

# Step 5: Release and renew IP address
log_message "Releasing IP address..."
sudo dhclient -r || { error_message "Failed to release IP address."; exit 1; }
log_message "Renewing IP address..."
sudo dhclient -v || { error_message "Failed to renew IP address."; exit 1; }

# Step 6: Display old and new IP addresses
IP_AFTER=$(hostname -I | awk '{print $1}')
success_message "Old IP Address: $IP_BEFORE"
success_message "New IP Address: $IP_AFTER"

# Step 7: Update the Proxmox VM name using the API
log_message "Updating Proxmox VM name in the Proxmox UI..."
RESPONSE=$(curl -k -s -X PUT "$PROXMOX_API_URL/nodes/$NODE_NAME/qemu/$VMID/config" \
    -H "Authorization: PVEAPIToken=$PROXMOX_API_TOKEN_ID=$PROXMOX_API_TOKEN_SECRET" \
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

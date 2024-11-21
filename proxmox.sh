#!/bin/bash

# Variables
REQUIRED_VERSION="24.04"
REQUIRED_CODENAME="lunar"
DOCKER_GPG_URL="https://download.docker.com/linux/ubuntu/gpg"
DOCKER_REPO="deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# Functions
print_status() {
    if [ $? -eq 0 ]; then
        echo -e "\e[32m$1 - SUCCESS\e[0m"
    else
        echo -e "\e[31m$1 - FAILED\e[0m"
        exit 1
    fi
}

print_info() {
    echo -e "\e[34m$1\e[0m"
}

check_ubuntu_version() {
    print_info "Checking Ubuntu version..."
    VERSION=$(lsb_release -r -s)
    CODENAME=$(lsb_release -c -s)

    if [[ "$VERSION" == "$REQUIRED_VERSION" && "$CODENAME" == "$REQUIRED_CODENAME" ]]; then
        print_status "Ubuntu $REQUIRED_VERSION LTS detected"
    else
        echo -e "\e[31mThis script requires Ubuntu $REQUIRED_VERSION LTS.\e[0m"
        exit 1
    fi
}

install_prerequisites() {
    print_info "Installing system prerequisites..."
    apt update && apt -y upgrade
    apt -y install net-tools qemu-guest-agent
    systemctl enable qemu-guest-agent
    systemctl start qemu-guest-agent
    print_status "System prerequisites installed and QEMU Guest Agent configured"
}

install_docker() {
    print_info "Installing Docker and Docker Compose..."

    # Remove conflicting packages
    echo "Removing any conflicting Docker packages..."
    for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do 
        apt-get remove -y $pkg 
    done
    print_status "Conflicting packages removed"

    # Install prerequisites for Docker
    echo "Installing prerequisites for Docker..."
    apt-get install -y ca-certificates curl
    print_status "Docker prerequisites installed"

    # Add Docker GPG key
    echo "Adding Docker GPG key..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL "$DOCKER_GPG_URL" -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    print_status "Docker GPG key added"

    # Set up Docker repository
    echo "Setting up Docker repository..."
    echo "$DOCKER_REPO" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    print_status "Docker repository setup"

    # Install Docker and Docker Compose
    echo "Installing Docker Engine and Docker Compose..."
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    print_status "Docker Engine and Docker Compose installed"

    # Enable Docker service
    echo "Enabling Docker service..."
    systemctl enable docker
    systemctl start docker
    print_status "Docker service enabled and started"

    # Verify installation
    echo "Verifying Docker and Docker Compose installations..."
    docker --version && docker compose version
    print_status "Docker and Docker Compose verified"
}

install_tailscale() {
    AUTH_KEY=$1
    if [[ -z "$AUTH_KEY" ]]; then
        echo -e "\e[31mError: Tailscale auth key must be provided as an argument.\e[0m"
        echo "Usage: $0 <tailscale-auth-key>"
        exit 1
    fi

    print_info "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | bash
    print_status "Tailscale installed"

    echo "Authenticating Tailscale..."
    tailscale up --authkey="$AUTH_KEY"
    print_status "Tailscale authenticated and configured"
}

# Main script execution
if [[ $EUID -ne 0 ]]; then
    echo -e "\e[31mThis script must be run as root.\e[0m"
    exit 1
fi

check_ubuntu_version
install_prerequisites
install_docker
install_tailscale "$1"

echo -e "\e[32mAll tasks completed successfully!\e[0m"

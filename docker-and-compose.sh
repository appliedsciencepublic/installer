#!/bin/bash

# Variables
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

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo -e "\e[31mThis script must be run as root.\e[0m"
    exit 1
fi

# Install Docker and Docker Compose
install_docker() {
    print_info "Installing Docker and Docker Compose..."

    # Remove conflicting packages
    echo "Removing any conflicting Docker packages..."
    for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do 
        apt-get remove -y $pkg >/dev/null 2>&1
    done
    print_status "Conflicting packages removed"

    # Install prerequisites for Docker
    echo "Installing prerequisites for Docker..."
    apt-get install -y ca-certificates curl >/dev/null
    print_status "Docker prerequisites installed"

    # Add Docker GPG key
    echo "Adding Docker GPG key..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL "$DOCKER_GPG_URL" -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    print_status "Docker GPG key added"

    # Set up Docker repository
    echo "Setting up Docker repository..."
    echo "$DOCKER_REPO" | tee /etc/apt/sources.list.d/docker.list >/dev/null
    apt-get update >/dev/null
    print_status "Docker repository setup"

    # Install Docker and Docker Compose
    echo "Installing Docker Engine and Docker Compose..."
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null
    print_status "Docker Engine and Docker Compose installed"

    # Enable Docker service
    echo "Enabling Docker service..."
    systemctl enable docker >/dev/null
    systemctl start docker
    print_status "Docker service enabled and started"

    # Verify installation
    echo "Verifying Docker and Docker Compose installations..."
    docker --version && docker compose version >/dev/null
    print_status "Docker and Docker Compose verified"
}

# Execute the installation
install_docker

echo -e "\e[32mDocker and Docker Compose installation completed successfully!\e[0m"

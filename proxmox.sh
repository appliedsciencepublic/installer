#!/bin/bash

# Variables
DOCKER_GPG_URL="https://download.docker.com/linux/ubuntu/gpg"
DOCKER_REPO="deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
OH_MY_ZSH_INSTALLER="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"
USERNAME="yalefox"

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

add_user_to_groups() {
    print_info "Adding user $USERNAME to groups..."

    if id "$USERNAME" &>/dev/null; then
        usermod -aG docker "$USERNAME"
        print_status "User $USERNAME added to 'docker' group"

        if ! id -nG "$USERNAME" | grep -qw "root"; then
            usermod -aG root "$USERNAME"
            print_status "User $USERNAME added to 'root' group"
        else
            print_status "User $USERNAME is already in 'root' group"
        fi
    else
        echo -e "\e[31mUser $USERNAME does not exist. Please create the user first.\e[0m"
        exit 1
    fi
}

install_prerequisites() {
    print_info "Installing system prerequisites..."
    apt update && apt -y upgrade
    apt -y install net-tools qemu-guest-agent zsh curl git fonts-powerline
    systemctl enable qemu-guest-agent
    systemctl start qemu-guest-agent
    print_status "System prerequisites installed and QEMU Guest Agent configured"
}

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
    echo "$DOCKER_REPO" | tee /etc/apt/sources.list.d/docker.list >/dev/null
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
    if ! tailscale up --authkey="$AUTH_KEY"; then
        echo -e "\e[31mError: Tailscale authentication failed. Please verify your auth key.\e[0m"
        exit 1
    fi
    print_status "Tailscale authenticated and configured"
}

install_oh_my_zsh() {
    print_info "Installing Oh My Zsh and configuring Powerline..."
    
    # Install Oh My Zsh non-interactively
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL $OH_MY_ZSH_INSTALLER)"
        print_status "Oh My Zsh installed"
    else
        print_status "Oh My Zsh is already installed"
    fi

    # Set Zsh as default shell for root
    chsh -s $(which zsh) root

    # Install Powerline fonts (already installed via prerequisites)
    print_status "Powerline fonts are ready"

    # Add Powerline configuration to .zshrc
    grep -qxF 'export TERM="xterm-256color"' ~/.zshrc || echo 'export TERM="xterm-256color"' >> ~/.zshrc
    grep -qxF 'POWERLEVEL9K_MODE="nerdfont-complete"' ~/.zshrc || echo 'POWERLEVEL9K_MODE="nerdfont-complete"' >> ~/.zshrc
    print_status ".zshrc updated for Powerline"
}

# Main script execution
if [[ $EUID -ne 0 ]]; then
    echo -e "\e[31mThis script must be run as root.\e[0m"
    exit 1
fi

install_prerequisites
install_docker
add_user_to_groups
install_tailscale "$1"
install_oh_my_zsh

echo -e "\e[32mAll tasks completed successfully!\e[0m"

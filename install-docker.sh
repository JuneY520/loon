#!/bin/bash
# ==========================================
# Lazy Docker Installer for Debian/Ubuntu
# Installs Docker + Docker Compose + adds current user to docker group
# Compatible with Debian Bullseye/Buster and Ubuntu 20/22
# ==========================================

set -e

echo "🚀 Updating system packages..."
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg lsb-release software-properties-common

echo "🔑 Adding Docker GPG key..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Detect OS
if [ -f /etc/debian_version ]; then
    DISTRO=$(lsb_release -cs)
    OS_TYPE="debian"
elif [ -f /etc/lsb-release ]; then
    DISTRO=$(lsb_release -cs)
    OS_TYPE="ubuntu"
else
    echo "❌ Unsupported OS"
    exit 1
fi

ARCH=$(dpkg --print-architecture)

echo "📦 Adding Docker repository for $DISTRO..."
echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $DISTRO stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "📥 Updating apt cache..."
sudo apt-get update -y

echo "🐳 Installing Docker Engine and Compose plugin..."
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "🔧 Adding current user to docker group..."
sudo usermod -aG docker $USER

echo "⚡ Enabling Docker service..."
sudo systemctl enable docker
sudo systemctl start docker

echo "✅ Docker and Docker Compose installed successfully!"
echo "⚠️ Please log out and log back in (or run 'newgrp docker') to use Docker without sudo."

# Quick test
echo "🐳 Testing Docker..."
docker version
docker run --rm hello-world
docker compose version
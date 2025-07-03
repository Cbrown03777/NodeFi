# Use an official Rust image as base for cross-chain development
FROM rust:1.70-slim

# Install system dependencies for both Rust and Node.js development
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      build-essential \
      curl \
      wget \
      openssl \
      pkg-config \
      libssl-dev \
      clang \
      cmake \
      protobuf-compiler \
      git \
      python3 \
      python3-pip \
      ca-certificates \
      gnupg \
      lsb-release \
      sudo && \
    rm -rf /var/lib/apt/lists/*

# Install Node.js 18.x
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get update && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# Create a non-root user 'vscode' early
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Install Solana CLI as root first
RUN curl -sSfL https://release.solana.com/v1.16.23/install | sh

# Set up directories for vscode user
RUN mkdir -p /home/${USERNAME}/.cargo \
    && mkdir -p /home/${USERNAME}/.local/share \
    && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}

# Copy Solana installation to user directory
RUN cp -r /root/.local/share/solana /home/${USERNAME}/.local/share/ 2>/dev/null || \
    mkdir -p /home/${USERNAME}/.local/share/solana

# Install Anchor CLI (simplified installation)
RUN cargo install --git https://github.com/coral-xyz/anchor --tag v0.30.1 avm || \
    echo "Anchor installation failed, continuing..."

# Install npm packages as root to avoid permission issues
RUN npm install -g \
    @truffle/hdwallet-provider \
    hardhat \
    truffle \
    ganache || echo "Some npm packages failed to install"

# Fix ownership
RUN chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}

# Switch to vscode user
USER ${USERNAME}
WORKDIR /workspace

# Set environment variables for vscode user
ENV PATH="/home/vscode/.local/share/solana/install/active_release/bin:/home/vscode/.cargo/bin:${PATH}"

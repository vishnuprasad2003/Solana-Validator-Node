FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl wget bc jq bzip2 ca-certificates \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Download and install Solana/Agave directly
ENV SOLANA_VERSION=v1.18.26
RUN mkdir -p /opt/solana && \
    wget -q "https://github.com/solana-labs/solana/releases/download/${SOLANA_VERSION}/solana-release-x86_64-unknown-linux-gnu.tar.bz2" -O /tmp/solana.tar.bz2 && \
    tar -xjf /tmp/solana.tar.bz2 -C /opt/solana --strip-components=1 && \
    rm /tmp/solana.tar.bz2

# Set PATH
ENV PATH="/opt/solana/bin:$PATH"

# Verify installation
RUN solana --version && (agave-validator --version || solana-validator --version)

WORKDIR /app
COPY scripts/ /app/scripts/
COPY programs/ /app/programs/
RUN chmod +x /app/scripts/*.sh

ENTRYPOINT ["/app/scripts/docker-entrypoint.sh"]

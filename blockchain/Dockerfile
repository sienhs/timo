# =========================
# 1. Build stage - installs devDependencies (hardhat/ts-node/typescript are
#    devDependencies but are what actually runs `hardhat node`/`hardhat run`)
#    and compiles once so the container doesn't recompile on every start.
# =========================
FROM node:20-bookworm-slim AS builder

WORKDIR /app

# keccak/secp256k1 (hardhat's crypto deps) ship native addons that need to
# be built from source on this base image.
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 make g++ \
    && rm -rf /var/lib/apt/lists/*

COPY package.json package-lock.json ./
RUN npm ci

COPY hardhat.config.ts tsconfig.json ./
COPY contracts contracts
RUN node_modules/.bin/hardhat compile

# =========================
# 2. Runtime stage - no build toolchain, just node_modules + compiled output
# =========================
FROM node:20-bookworm-slim

WORKDIR /app

COPY --from=builder /app/node_modules node_modules
COPY --from=builder /app/artifacts artifacts
COPY --from=builder /app/cache cache
COPY --from=builder /app/typechain-types typechain-types
COPY hardhat.config.ts tsconfig.json package.json ./
COPY contracts contracts
COPY scripts scripts
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 8545

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

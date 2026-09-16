#!/bin/sh
# Starts the Hardhat node in the background, waits for its RPC to answer,
# then redeploys the 4 contracts against it before handing the foreground
# back to the node process.
#
# Why redeploy on every start: Hardhat's in-memory chain has no state once
# the process restarts (container restart, EC2 reboot, ...) - a Docker
# volume can't help here because the state was never on disk to begin with.
# So "the node is up" and "the contracts exist on it" have to be the same
# event, not two separately-remembered facts.
#
# Why deploy.ts and not seedDummyShows.ts: the backend's own
# LocalDataSeeder (domain/blockchain/ShowRegistryClient) now owns
# registering shows on-chain - it targets fixed addresses hardcoded in
# application.yml, not whatever a TS seed script happened to deploy this
# time. This container's only job is to make those addresses exist again -
# which works because deploy.ts always uses the same ADMIN_PRIVATE_KEY and
# the same fixed deploy order (ShowRegistry, TicketNFT, TicketVault,
# Marketplace), so the CREATE address for each one is identical every time.
# If ADMIN_PRIVATE_KEY ever changes, or a 5th contract gets deployed ahead
# of these in this script, the addresses will drift and application.yml
# needs updating to match.
set -e

cd /app

echo "[timo-hardhat] starting hardhat node on 0.0.0.0:8545..."
node_modules/.bin/hardhat node --hostname 0.0.0.0 &
NODE_PID=$!

# Forward docker stop's SIGTERM to the actual node process instead of dying
# and leaving it orphaned.
trap 'echo "[timo-hardhat] stopping..."; kill -TERM "$NODE_PID" 2>/dev/null; wait "$NODE_PID"' TERM INT

echo "[timo-hardhat] waiting for RPC..."
tries=0
until node -e "
  fetch('http://127.0.0.1:8545', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'eth_chainId', params: [] })
  }).then((r) => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1));
" >/dev/null 2>&1; do
  tries=$((tries + 1))
  if [ "$tries" -ge 30 ]; then
    echo "[timo-hardhat] RPC never came up after 30s - exiting"
    exit 1
  fi
  sleep 1
done

echo "[timo-hardhat] RPC is up. deploying contracts..."
# --network localhost, not the default in-memory "hardhat" network - that
# network would deploy into a throwaway chain nobody is actually serving.
node_modules/.bin/hardhat run scripts/deploy/deploy.ts --network localhost

echo "[timo-hardhat] deploy complete - node is live on :8545 (backend's LocalDataSeeder handles show data)"
wait "$NODE_PID"

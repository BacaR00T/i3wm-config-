#!/usr/bin/env bash
set -euo pipefail

echo "Clearing Tailscale route settings..."
tailscale set \
  --exit-node= \
  --exit-node-allow-lan-access=false \
  --accept-routes=false

echo
echo "Disconnecting Tailscale..."
sudo tailscale down

echo
echo "Done."
tailscale status || true

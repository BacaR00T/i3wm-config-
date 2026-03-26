#!/usr/bin/env bash
set -euo pipefail

EXIT_NODE="TYPE_THE_IP_ADDRESS"

if ! systemctl is-active --quiet tailscaled; then
    echo "Starting tailscaled..."
    sudo systemctl enable --now tailscaled
fi

echo "Connecting to Tailscale using exit node ${EXIT_NODE}..."
sudo tailscale up
tailscale set \
  --exit-node="${EXIT_NODE}" \
  --exit-node-allow-lan-access=true \
  --accept-routes=true

echo
echo "Done."
tailscale status

#!/usr/bin/bash
# Script to build SEAPATH ISOs for Nodes 1, 2, and 3
set -e

# --- CONFIGURATION ---
KS_SOURCE="seapath_kickstart.ks"
ISO_BASE="CentOS-Stream-9-latest-x86_64-dvd1.iso"
INTERNAL_SSH_PATH=$(ls /mnt/ssh/*.pub 2>/dev/null | head -n1)

# --- 1. ENVIRONMENT CHECK ---
echo "--- Checking environment ---"
if [ ! -f "$INTERNAL_SSH_PATH" ]; then
  echo "ERROR: SSH Public Key not found at /mnt/ssh/"
  exit 1
fi

if [ ! -f "$ISO_BASE" ]; then
  echo "ERROR: Base ISO ($ISO_BASE) not found."
  exit 1
fi

SSH_CONTENT=$(cat "$INTERNAL_SSH_PATH")

# --- 2. GENERATION LOOP ---
for i in 1 2 3; do
  echo "--- Preparing ISO for Node $i ---"

  KS_TMP="tmp_node$i.ks"
  ISO_FINAL="seapath-node$i.iso"

  # Calculate IP (Node 1 = .2, Node 2 = .3, Node 3 = .4)
  NODE_IP="192.168.124.$((i + 1))"

  cp "$KS_SOURCE" "$KS_TMP"

  # Inject SSH Keys and Node Specific Identity
  sed -i "s|__SSH_KEY_VIRTU__|$SSH_CONTENT|g" "$KS_TMP"
  sed -i "s|__SSH_KEY_ANSIBLE__|$SSH_CONTENT|g" "$KS_TMP"
  sed -i "s|__SSH_KEY_ROOT__|$SSH_CONTENT|g" "$KS_TMP"
  sed -i "s|__HOSTNAME__|node$i|g" "$KS_TMP"
  sed -i "s|__NODE_IP__|$NODE_IP|g" "$KS_TMP"

  echo "--- Running mkksiso for Node $i ---"
  mkksiso --ks "$KS_TMP" "$ISO_BASE" "$ISO_FINAL"

  rm "$KS_TMP"
  echo "--- SUCCESS: $ISO_FINAL created ---"
done

echo "--- ALL ISOs GENERATED SUCCESSFULLY ---"

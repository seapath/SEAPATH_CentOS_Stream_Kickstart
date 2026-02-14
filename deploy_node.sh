#!/usr/bin/bash
# SEAPATH VM Deployment Script for individual ISOs
# Usage: ./deploy_node.sh [--cluster]

set -e

CURRENT_DIR="/var/lib/libvirt/images"
TEMPLATE="virtualized_node_example.xml"

# Check if user wants a cluster or standalone
if [[ "$1" == "--cluster" ]]; then
  NUM_NODES=3
  echo "--- Preparing deployment for a 3-node CLUSTER ---"
else
  NUM_NODES=1
  echo "--- Preparing deployment for a STANDALONE node ---"
fi

for i in $(seq 1 $NUM_NODES); do
  NODE_NAME="seapath-node-$i"
  XML_FINAL="$NODE_NAME.xml"
  B_A="hostbridge$((i - 1))"
  B_B="hostbridge$((i % 3))"

  echo "------------------------------------------------"
  echo "Configuring $NODE_NAME..."

  # 1. Copy template
  cp "$TEMPLATE" "$XML_FINAL"

  # 2. Cleanup: Remove UUID from the final XML to avoid conflicts
  sed -i '/<uuid>/d' "$XML_FINAL"

  # 3. Replace placeholders
  sed -i "s|seapath-node-TEMPLATE|$NODE_NAME|g" "$XML_FINAL"
  sed -i "s|__ISO_PATH__|$CURRENT_DIR|g" "$XML_FINAL"
  sed -i "s|__DISK_PATH__|$CURRENT_DIR|g" "$XML_FINAL"

  sed -i "s|__BRIDGE_A__|$B_A|g" "$XML_FINAL"
  sed -i "s|__BRIDGE_B__|$B_B|g" "$XML_FINAL"

  # 4. Match the disk and ISO names (Crucial fix here)
  sed -i "s|seapath.iso|seapath-node$i.iso|g" "$XML_FINAL"
  sed -i "s|seapath-node-os.qcow2|seapath-node$i-os.qcow2|g" "$XML_FINAL"
  sed -i "s|seapath-node-ceph.qcow2|seapath-node$i-ceph.qcow2|g" "$XML_FINAL"

  # 5. Define the VM in Libvirt (System Scope)
  sudo virsh -c qemu:///system define "$XML_FINAL"
done

echo "------------------------------------------------"
echo "--- Deployment configuration finished ---"
echo "Next steps:"
echo "1. Verify your disks and ISOs are in $CURRENT_DIR"
echo "2. Start your nodes: sudo virsh -c qemu:///system start seapath-node-X"
echo "------------------------------------------------"

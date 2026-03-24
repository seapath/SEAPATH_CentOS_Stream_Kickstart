#!/usr/bin/bash
# SEAPATH VM Deployment Script for individual ISOs
# Usage: ./deploy_node.sh [--cluster]

set -e

CURRENT_DIR="/var/lib/libvirt/images"
TEMPLATE="templates/virtualized_node_example.xml"

# 1. Validate if the template file exists before starting
if [[ ! -f "$TEMPLATE" ]]; then
  echo "ERROR: Template file '$TEMPLATE' not found in the current directory!"
  exit 1
fi

# 2. Check if user wants a cluster or standalone deployment
if [[ "$1" == "--cluster" ]]; then
  NUM_NODES=3
  echo "--- Preparing deployment for a 3-node CLUSTER ---"
else
  NUM_NODES=1
  echo "--- Preparing deployment for a STANDALONE node ---"
fi

# 3. Main deployment loop
for i in $(seq 1 $NUM_NODES); do
  NODE_NAME="seapath-node-$i"
  XML_FINAL="${NODE_NAME}.xml"
  BRIDGE_PREV="hostbridge$((i - 1))"
  BRIDGE_NEXT="hostbridge$((i % 3))"

  echo "--------------------------------------------------"
  echo "Configuring $NODE_NAME..."

  # Check if the VM is already defined in libvirt
  # If it exists, print a warning and skip to the next iteration
  if sudo virsh -c qemu:///system dominfo "$NODE_NAME" >/dev/null 2>&1; then
    echo "WARNING: Domain '$NODE_NAME' already exists in libvirt."
    echo "Skipping creation for this node to prevent conflicts."
    continue
  fi

  # Copy the generated ISO to the libvirt directory
  if [[ -f "isos/seapath-node$i.iso" ]]; then
    echo "Copying ISO to libvirt storage..."
    sudo cp "isos/seapath-node$i.iso" "$CURRENT_DIR/"
  else
    echo "WARNING: ISO 'isos/seapath-node$i.iso' not found. VM may fail to boot."
  fi

  # Copy template
  cp "$TEMPLATE" "$XML_FINAL"

  # Cleanup: Remove UUID from the final XML to avoid conflicts
  sed -i '/<uuid>/d' "$XML_FINAL"

  # Replace placeholders
  sed -i "s|seapath-node-TEMPLATE|$NODE_NAME|g" "$XML_FINAL"
  sed -i "s|__ISO_PATH__|$CURRENT_DIR|g" "$XML_FINAL"
  sed -i "s|__DISK_PATH__|$CURRENT_DIR|g" "$XML_FINAL"

  sed -i "s|__BRIDGE_A__|$BRIDGE_PREV|g" "$XML_FINAL"
  sed -i "s|__BRIDGE_B__|$BRIDGE_NEXT|g" "$XML_FINAL"

  # Match the disk and ISO names
  sed -i "s|seapath.iso|seapath-node$i.iso|g" "$XML_FINAL"
  sed -i "s|seapath-node-os.qcow2|seapath-node$i-os.qcow2|g" "$XML_FINAL"
  sed -i "s|seapath-node-ceph.qcow2|seapath-node$i-ceph.qcow2|g" "$XML_FINAL"

  # Define the VM in Libvirt
  echo "Defining VM in libvirt..."
  sudo virsh -c qemu:///system define "$XML_FINAL"

  # Clean up the temporary XML file to keep the directory clean
  rm -f "$XML_FINAL"

  echo "Success: $NODE_NAME defined."
done

echo "--------------------------------------------------"
echo "--- Deployment configuration finished ---"
echo "Next steps:"
echo "Start your nodes: sudo virsh -c qemu:///system start seapath-node-X"
echo "--------------------------------------------------"

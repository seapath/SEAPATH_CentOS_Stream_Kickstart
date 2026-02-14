#!/usr/bin/bash
# [VM Specific] - Setup Network and Storage for SEAPATH Lab
set -e

DEST_DIR="/var/lib/libvirt/images"

echo "--- 1. Setting up Management Network ---"
if [ -f "seapath-network.xml" ]; then
  sudo virsh -c qemu:///system net-define seapath-network.xml || true
  sudo virsh -c qemu:///system net-start seapath-default || true
  sudo virsh -c qemu:///system net-autostart seapath-default || true
else
  echo "ERROR: seapath-network.xml not found in current directory."
  exit 1
fi

echo "--- 2. Setting up Cluster Bridges ---"
for i in 0 1 2; do
  echo "Creating bridge br$i..."
  sudo ip link add br$i type bridge || true
  sudo ip link set br$i up
  sudo ip link set dev br$i mtu 9000

  # Create temporary XML for the bridge
  cat <<EOF >"tmp-bridge-$i.xml"
<network>
    <name>hostbridge$i</name>
    <forward mode="bridge"/>
    <bridge name="br$i"/>
</network>
EOF
  sudo virsh -c qemu:///system net-define "tmp-bridge-$i.xml" || true
  sudo virsh -c qemu:///system net-start "hostbridge$i" || true
  rm "tmp-bridge-$i.xml"
done

echo "--- 3. Preparing Storage and ISOs ---"
# Move the 3 ISOs to the libvirt folder
for i in 1 2 3; do
  if [ -f "seapath-node$i.iso" ]; then
    sudo mv "seapath-node$i.iso" "$DEST_DIR/"
  fi

  echo "Creating virtual disks for Node $i..."
  sudo qemu-img create -f qcow2 "$DEST_DIR/seapath-node$i-os.qcow2" 100G
  sudo qemu-img create -f qcow2 "$DEST_DIR/seapath-node$i-ceph.qcow2" 50G
done

# Change ownership for the QEMU driver
sudo bash -c "chown qemu:qemu $DEST_DIR/seapath-node*"

echo "--- DONE: Host infrastructure is ready! ---"

#!/usr/bin/bash
# [VM Specific] - Cleanup SEAPATH Lab Environment
echo "--- Starting full cleanup ---"

# 1. Destroy and Undefine VMs
for i in 1 2 3; do
  echo "Removing seapath-node-$i..."
  sudo virsh -c qemu:///system destroy seapath-node-$i 2>/dev/null || true
  sudo virsh -c qemu:///system undefine seapath-node-$i --nvram 2>/dev/null || true
done

# 2. Remove Networks
for net in seapath-default hostbridge0 hostbridge1 hostbridge2; do
  echo "Removing network $net..."
  sudo virsh -c qemu:///system net-destroy $net 2>/dev/null || true
  sudo virsh -c qemu:///system net-undefine $net 2>/dev/null || true
done

# 3. Delete Bridges
for b in br0 br1 br2; do
  echo "Deleting bridge $b..."
  sudo ip link delete $b 2>/dev/null || true
done

# 4. Delete Storage Files
echo "Deleting storage files from libvirt images..."
sudo bash -c "rm -f /var/lib/libvirt/images/seapath*"

# 5. Delete locally generated ISOs
if [ -d "isos" ]; then
  echo "Deleting locally generated ISOs from 'isos' directory..."
  sudo rm -rf isos/
fi

echo "Cleanup complete!"

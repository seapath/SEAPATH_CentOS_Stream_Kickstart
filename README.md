# SEAPATH CentOS Stream 9 - Automated Deployment Guide


This guide provides a workflow to build custom **SEAPATH ISOs** and deploy them on **Physical Servers (Bare Metal)** or **Virtual Machines (Libvirt)**.

> **Note:** All scripts (`.sh`) and configuration files (`.xml`, `.ks`) mentioned in this guide are located in the root of this repository.


### Prerequisites

-   Download the **CentOS Stream 9 ISO** and place it in the root of this repository.
    
    -   Download from: [https://centos.org/download/#centos-stream-9](https://centos.org/download/#centos-stream-9)
        
-   **Optional:** The default password for `root` and `virtu` is `toto`. To change it, edit `seapath_kickstart.ks` and replace the hashed passwords.


## 1. Generating Custom ISOs

In this phase, you will create **three unique ISOs** (one for each node). During this process, your host's SSH public key is automatically injected into the images for secure, passwordless access.

### Build the Environment

```Bash
sudo podman build -t centos4seapath .
```

### Generate the ISO

This script creates `seapath-node1.iso`, `seapath-node2.iso`, and `seapath-node3.iso`.



```Bash
sudo podman run --privileged --rm \
   --security-opt label=disable \
   -v /dev:/dev \
   -v $(pwd):/build:Z \
   -v /home/$(whoami)/.ssh:/mnt/ssh:ro,Z \
   -w /build \
   -it centos4seapath bash ./create_vm_isos.sh
```

----------


## 2. Infrastructure Setup **[VM Specific]**

If you are deploying on **Physical Hardware**, ensure your management switch is configured for the `192.168.124.0/24` range and skip this section.

For **Virtual Machine** environments, we provide an automation script that defines the network, creates the bridges and prepares the virtual disks:

```Bash
# This script uses the seapath-network.xml file found in this folder
./prepare_vm_host.sh
```

----------


## 3. Boot the hosts with the ISO files.

### Step 1: Booting the Hosts

-   **Physical Hardware:** Flash each ISO to a USB drive and boot the corresponding server.
    
-   **[VM Specific]:** Register and start the virtual nodes using our deployment script:


    ```Bash
    ./deploy_node.sh --cluster
    sudo virsh -c qemu:///system start seapath-node-1
    sudo virsh -c qemu:///system start seapath-node-2
    sudo virsh -c qemu:///system start seapath-node-3
    ```


> The `--cluster` option generates all 3 ISOs. Running `./deploy_node.sh` without parameters only generates 1 ISO.

##### Automated Installation

- Select **"Install CentOS Stream 9"** in the boot menu.
- The installation is 100% automated via Kickstart. The system will reboot once finished.

    ----------
## 4. SSH Access & Connection

Access is secured via **SSH**. Passwords are disabled for remote login.

### How to Connect

1.  **Add your key to your local session:**    
    
    ```Bash
    ssh-add ~/.ssh/your_private_key    
    ```
    
2.  **Login to a node:**    **[VM Specific]**
    
    ```Bash
    ssh root@192.168.124.2  # Node 1
    ```    

#### Troubleshooting: "Identification Has Changed"   **[VM Specific]**
If you reinstall a node, your host will detect a fingerprint mismatch. Clear the old record with: `ssh-keygen -R 192.168.124.2`


----------

## 5. SEAPATH Configuration (Ansible)

Once nodes are online, run the SEAPATH hardening playbooks.

### A. Clone the Seapath Ansible repository into the root of our repository:
```Bash
 git clone https://github.com/seapath/ansible.git
```

### B. Run the Container with Host Networking  **[VM Specific]**

```Bash
sudo podman run --privileged --rm \
  --net=host \
  --security-opt label=disable \
  --mount type=bind,source=$(pwd)/ansible,target=/root/ansible/ \
  --mount type=bind,source=/home/$(whoami)/.ssh/,target=/root/.ssh/ \
  -it centos4seapath bash

```

### C. Inside Container - Prepare and Execute  **[VM Specific]**


```Bash
cd /root/ansible/

python3.9 -m pip install netaddr 

git config --global --add safe.directory /root/ansible

./prepare.sh

eval $(ssh-agent -s)

ssh-add /root/.ssh/your_private_key_42

export ANSIBLE_HOST_KEY_CHECKING=False
```

### 6. Inventory Configuration

Before running the playbook, you must customize the inventory file to map the Ansible variables to your virtual infrastructure.

Edit the file `inventories/examples/seapath-standalone.yaml` to match the following configuration (example for **Node 1**):


```Diff
--- a/inventories/examples/seapath-standalone.yaml
+++ b/inventories/examples/seapath-standalone.yaml
      node1:
 
        # Admin network settings
-       ansible_host: 192.168.200.125 # administration IP. TODO
-       network_interface: eno1 # Administration interface name. TODO
-       gateway_addr: 192.168.200.1 # Administration Gateway. TODO
-       dns_servers: 192.168.200.1 # DNS servers. Remove if not used. TODO
+       ansible_host: 192.168.124.2 # administration IP.
+       network_interface: enp1s0 # Administration interface name.
+       gateway_addr: 192.168.124.1 # Administration Gateway.
+       dns_servers: 192.168.124.1 # DNS servers.
        subnet: 24 # Subnet mask in CIDR notation.
 
        # Time synchronisation
-       ptp_interface: eno12419 # PTP interface receiving PTP frames. TODO
+       ptp_interface: enp1s0 # PTP interface receiving PTP frames.
        ntp_servers:
          - "185.254.101.25" # public NTP server example
 
        ansible_connection: ssh
        ansible_python_interpreter: /usr/bin/python3
        ansible_remote_tmp: /tmp/.ansible/tmp
-       ansible_user: ansible
+       ansible_user: virtu
+       ansible_ssh_private_key_file: /root/.ssh/your_private_key_42

```

> **Note:** In this virtual lab setup, `enp1s0` is the default management interface. If you are deploying on different hardware, verify the interface name using `ip addr`.

Now that everything is prepared, run the playbook.
```Bash
ansible-playbook -i inventories/examples/seapath-standalone.yaml playbooks/seapath_setup_main.yaml
```
--------
## 7. Deployment: 3-Node Cluster Mode 

This mode enables High Availability and Distributed Storage with Ceph. It uses the Ring Topology simulated by the Linux bridges created in Step 2.

### A. Inventory Configuration

Before running the cluster setup, you must configure the inventory to match our virtual lab's network mapping.

Edit the file `inventories/examples/seapath-cluster.yaml` with the following key values:

 
| Section | Variable | Value for Virtual Lab
|--|--|-- |
| **All Hosts** | `ansible_host` | `.2` (node1), `.3` (node2), `.4` (node3)|
|**Network** | `gateway_addr`|`192.168.124.1`
| **Interfaces** | `network_interface` |`enp1s0`
| **Ring Links** | `team0_0 / team0_1`| `enp2s0` and `enp3s0` (Data Ring)
| **Storage** |  `ceph_osd_disk` | `/dev/disk/by-path/your_disk`
| **SSH** | `ansible_user` |`virtu` |


#### Identifying the Ceph Disk

The Ceph OSD requires a dedicated disk. In this lab, we created a secondary 50GB disk. You need to find its unique path to ensure Ansible targets the correct device.

1.  Log into **Node 1** via SSH.
    
2.  Run the following command:
    
    ```Bash
    ls -l /dev/disk/by-path/ | grep -v "part"    
    ```
    
3.  Look for the disk that points to `sdb` (our secondary disk). **Example for this VM setup:** `ceph_osd_disk: "/dev/disk/by-path/pci-0000:00:1f.2-ata-3"`

**Note:** This ID will vary depending on your virtual controller or physical hardware. Always verify it before running the playbook.


### B. Execution

Inside the automation container, run the main playbook pointing to the cluster inventory:

```Bash
ansible-playbook -i inventories/examples/seapath-cluster.yaml playbooks/seapath_setup_main.yaml
```

--------
### Reset Lab Environment [VM Specific]
```Bash
./cleanup_vm_host.sh
```

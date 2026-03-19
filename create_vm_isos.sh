#!/usr/bin/bash
set -e

KS_SOURCE="seapath_kickstart.ks"
ISO_BASE="${BASE_ISO:-CentOS-Stream-9-latest-x86_64-dvd1.iso}"
OS_TYPE="${OS_TYPE:-centos}"
INTERNAL_SSH_PATH=$(ls /mnt/ssh/*.pub 2>/dev/null | head -n1)
SSH_CONTENT=$(cat "$INTERNAL_SSH_PATH" 2>/dev/null || echo "")

# Ensures temporary files are deleted even if the script fails or is interrupted
cleanup() {
  rm -f r.txt p.txt post.txt tmp_node*.ks
}
trap cleanup EXIT

if [ ! -f "$KS_SOURCE" ]; then
  echo "ERROR: Kickstart source '$KS_SOURCE' not found!"
  exit 1
fi

if [ -z "$SSH_CONTENT" ]; then
  echo "WARNING: No SSH public key found in /mnt/ssh/. Key injection will be empty."
fi

if [ "$OS_TYPE" = "rhel" ]; then
  if [ -z "$ORG_ID" ] || [ -z "$ACTIVATION_KEY" ]; then
    echo "ERROR: RHEL build requires ORG_ID and ACTIVATION_KEY environment variables."
    exit 1
  fi
fi

for i in 1 2 3; do
  echo "--- Preparing ISO for Node $i ---"
  KS_TMP="tmp_node$i.ks"
  cp "$KS_SOURCE" "$KS_TMP"

  sed -i "s|__SSH_KEY_VIRTU__|$SSH_CONTENT|g" "$KS_TMP"
  sed -i "s|__SSH_KEY_ANSIBLE__|$SSH_CONTENT|g" "$KS_TMP"
  sed -i "s|__SSH_KEY_ROOT__|$SSH_CONTENT|g" "$KS_TMP"
  sed -i "s|__HOSTNAME__|node$i|g" "$KS_TMP"
  sed -i "s|__NODE_IP__|192.168.124.$((i + 1))|g" "$KS_TMP"

  if [ "$OS_TYPE" = "rhel" ]; then

    cat <<EOF >r.txt
rhsm --org=${ORG_ID} --activation-key=${ACTIVATION_KEY} --connect
repo --name="EPEL" --metalink="https://mirrors.fedoraproject.org/metalink?repo=epel-9&arch=x86_64"
repo --name="Ceph" --baseurl="https://download.ceph.com/rpm-quincy/el9/x86_64/" --noverifyssl
repo --name="Ceph-noarch" --baseurl="https://download.ceph.com/rpm-quincy/el9/noarch/" --noverifyssl
repo --name="Docker" --baseurl="https://download.docker.com/linux/rhel/9/x86_64/stable/" --noverifyssl
EOF

    cat <<'EOF' >p.txt
@^minimal-environment
@virtualization-hypervisor
@development
vim
git
rsync
curl
audit
net-tools
openssh-server
python3-dnf
sudo
pciutils
tuned
libvirt
systemd-networkd
systemd-resolved
linuxptp
syslog-ng
bridge-utils
ceph
ceph-common
ceph-osd
ceph-mgr
ceph-mon
docker-ce
docker-ce-cli
containerd.io
busybox
ntfs-3g
python3-flask-wtf
python3-gunicorn
python3-devel
asciidoc
autoconf
automake
libtool
EOF

    cat <<'EOF' >post.txt
subscription-manager refresh
subscription-manager repos --enable="rhel-9-for-x86_64-baseos-rpms" --enable="rhel-9-for-x86_64-appstream-rpms" --enable="rhel-9-for-x86_64-highavailability-rpms" --enable="rhel-9-for-x86_64-rt-rpms" --enable="fast-datapath-for-rhel-9-x86_64-rpms" --enable="codeready-builder-for-rhel-9-x86_64-rpms"

dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
dnf install -y kernel-rt kernel-rt-devel pacemaker pcs pcs-snmp corosync tuned-profiles-nfv tuned-profiles-realtime openvswitch3.6 python3-openvswitch3.6

systemctl enable openvswitch

cat <<'REPO' > /etc/yum.repos.d/crb-dummy.repo
[crb]
name=CRB Repo to ceph-ansible
baseurl=https://dl.fedoraproject.org/pub/epel/9/Everything/x86_64/
enabled=1
gpgcheck=0
REPO

tuned-adm profile realtime

RT_KERNEL_PATH=$(find /boot -name "vmlinuz*rt*" | sort -V | tail -n 1)
if [ -n "$RT_KERNEL_PATH" ]; then
    grubby --set-default="$RT_KERNEL_PATH"
    grubby --set-default-index=0
else
    echo "ERROR: Kernel RT not found in /boot" >> /root/anaconda-post.log
fi
EOF

  else
    cat <<'EOF' >r.txt
repo --name=BaseOS --metalink=https://mirrors.centos.org/metalink?repo=centos-baseos-9-stream&arch=x86_64&protocol=https,http --install
repo --name=AppStream --metalink=https://mirrors.centos.org/metalink?repo=centos-appstream-9-stream&arch=x86_64&protocol=https,http --install

# CentOS Addons
repo --name=HighAvailability --metalink=https://mirrors.centos.org/metalink?repo=centos-highavailability-9-stream&arch=x86_64&protocol=https,http --install
repo --name=Realtime --metalink=https://mirrors.centos.org/metalink?repo=centos-rt-9-stream&arch=x86_64&protocol=https,http --install
repo --name=CentOS-NFV --metalink=https://mirrors.centos.org/metalink?repo=centos-nfv-9-stream&arch=x86_64&protocol=https,http --install

# Docker
repo --name=Docker --baseurl=https://download.docker.com/linux/centos/9/x86_64/stable/ --install

# Fedora EPEL
repo --name=fedora_epel --baseurl=https://dl.fedoraproject.org/pub/epel/9/Everything/x86_64/ --install --cost=2

# OpenVSwitch
repo --name=rdo-release --metalink=https://mirrors.centos.org/metalink?repo=centos-cloud-sig-openstack-yoga-9-stream&arch=x86_64 --install --cost=3
repo --name=centos-nfv-sig-openvswitch --metalink=https://mirrors.centos.org/metalink?repo=centos-nfv-sig-openvswitch-2-9-stream&arch=x86_64 --install --cost=4

# Ceph
repo --name=Ceph_x86 --baseurl=https://mirror.stream.centos.org/SIGs/9-stream/storage/x86_64/ceph-pacific/ --install --cost=5
EOF

    cat <<'EOF' >p.txt
linux-firmware
microcode_ctl
at
audispd-plugins
audit
bridge-utils
ca-certificates
chrony
curl
docker-ce
docker-ce-cli
containerd.io
pcp-system-tools
gnupg
hddtemp
irqbalance
jq
lbzip2
linuxptp
net-tools
openssh-server
edk2-ovmf
python3-dnf
python3-cffi
python3-setuptools
net-snmp
net-snmp-utils
sudo
sysfsutils
syslog-ng
sysstat
vim
wget
rsync
pciutils
conntrack-tools
busybox
python-gunicorn
ipmitool
nginx
ntfs-3g
python3-flask-wtf
corosync
pacemaker
openvswitch
kernel-rt
grubby
qemu-kvm
ceph
ceph-base
ceph-common
ceph-mgr
ceph-mon
ceph-osd
libcephfs2
libvirt
libvirt-daemon
libvirt-daemon-driver-storage-rbd
python3-ceph-argparse
python3-cephfs
tuna
tuned
tuned-profiles-nfv
tuned-profiles-realtime
virt-install
pcs
pcs-snmp
systemd-networkd
systemd-resolved
systemd-timesyncd
openscap-scanner
openscap
scap-security-guide
@development
@virtualization-hypervisor
EOF

    cat <<'EOF' >post.txt
systemctl enable openvswitch
EOF
  fi

  sed -i '/__REPOS__/r r.txt' "$KS_TMP"
  sed -i '/__REPOS__/d' "$KS_TMP"

  sed -i '/__PACKAGES__/r p.txt' "$KS_TMP"
  sed -i '/__PACKAGES__/d' "$KS_TMP"

  sed -i '/__OS_POST__/r post.txt' "$KS_TMP"
  sed -i '/__OS_POST__/d' "$KS_TMP"

  mkksiso --ks "$KS_TMP" "$ISO_BASE" "seapath-node$i.iso"
done

# Installation process
text
reboot
cdrom

# localization
lang en_US
keyboard --xlayouts='us'
timezone America/New_York --utc

# System bootloader configuration
bootloader --append="quiet crashkernel=1G-4G:192M,4G-64G:256M,64G-:512M  console=ttyS0,115200 console=tty0 efi=runtime ipv6.disable=1"

%include /tmp/disk-config
%include /tmp/network-config

rhsm --org={{ORG_ID}} --activation-key={{ACTIVATION_KEY}} --connect

repo --name="EPEL" --baseurl="https://dl.fedoraproject.org/pub/epel/9/Everything/x86_64/" --noverifyssl

repo --name="Ceph" --baseurl="https://download.ceph.com/rpm-quincy/el9/x86_64/" --noverifyssl

repo --name="Ceph-noarch" --baseurl="https://download.ceph.com/rpm-quincy/el9/noarch/" --noverifyssl

repo --name="Docker" --baseurl="https://download.docker.com/linux/rhel/9/x86_64/stable/" --noverifyssl

# Do not configure the X Window System
skipx


# Users
# UPDATE: The password is "toto" for all users
user --uid=1006 --gid=1006 --groups=wheel --name=virtu --iscrypted --password="$6$BZGBti/HRUWlyHhY$8zI5CFPcuBJw7pKupU4d9QLTqphBDyDpkW8zMySquiKO/qcRZoEcqvCJraJXJ5y0sdNdJ2vHb6.z/UvvLJSrM/"

user --uid=1005 --gid=1005 --groups=wheel,haclient --name=ansible --iscrypted --password="$6$BZGBti/HRUWlyHhY$8zI5CFPcuBJw7pKupU4d9QLTqphBDyDpkW8zMySquiKO/qcRZoEcqvCJraJXJ5y0sdNdJ2vHb6.z/UvvLJSrM/"

user --uid=902 --gid=902  --name=seapath-snmp

rootpw  --iscrypted $6$2Aj/yELlJst1TZMM$3JVT2YYjrbMpNGoHs.2O.SvcbtGSZqQvz5Ot5CdDmU/IsRFASnSqmlvS8bg8eGoOHmQ5i7dak0VWQWtziqYjh0


# ssh keys
# UPDATE: input your ssh-keys for
sshkey --username=virtu "__SSH_KEY_VIRTU__"
sshkey --username=ansible "__SSH_KEY_ANSIBLE__"
sshkey --username=root "__SSH_KEY_ROOT__"

# adding needed repositories

%packages
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

# Network packages and Ceph/Docker
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

# EPEL
busybox
ntfs-3g
python3-flask-wtf
python3-gunicorn

# COMPILATION DEPENDENCIES CRMSH
python3-devel
asciidoc
autoconf
automake
libtool
%end

%pre
# 1. DISK DISCOVERY
# Finds the first available disk that is not the installer
TARGET_DISK=$(lsblk -dno NAME,TYPE | grep disk | head -n1 | awk '{print $1}')

cat <<EOF > /tmp/disk-config
ignoredisk --only-use=/dev/$TARGET_DISK
zerombr
clearpart --all --initlabel
reqpart --add-boot
part pv.0 --fstype=lvmpv --ondisk=/dev/$TARGET_DISK --size=25600
part /boot/efi --fstype=efi --ondisk=/dev/$TARGET_DISK --size=512 --asprimary

volgroup vg1 --pesize=4096 pv.0

logvol / --vgname=vg1 --name=vg1-root --fstype=ext4 --size=12288
logvol /var --vgname=vg1 --name=vg1-var --fstype=ext4 --size=4096
logvol /var/log --vgname=vg1 --name=vg1-varlog --fstype=ext4 --size=3120
logvol /var/log/audit --vgname=vg1 --name=vg1-varlogaudit --fstype=ext4 --size=2000
logvol /home --vgname=vg1 --name=vg1-home --fstype=ext4 --size=1024
logvol /srv --vgname=vg1 --name=vg1-srv --fstype=ext4 --size=512
logvol /var/tmp --vgname=vg1 --name=vg1-vartmp --fstype=ext4 --size=512
logvol swap --vgname=vg1 --name=vg1-swap --fstype=swap --size=500
EOF

INTERFACE=$(ls /sys/class/net | grep -v lo | head -n1)

# The placeholders __NODE_IP__ and __HOSTNAME__ will be replaced by the shell script.
echo "network --device=$INTERFACE --bootproto=static --ip=__NODE_IP__ --netmask=255.255.255.0 --gateway=192.168.124.1 --nameserver=8.8.8.8,1.1.1.1,192.168.124.1 --hostname=__HOSTNAME__ --activate --onboot=on" > /tmp/network-config
%end

# additional file changes
%post
exec > /root/anaconda-post.log 2>&1

subscription-manager refresh

subscription-manager repos --enable="rhel-9-for-x86_64-baseos-rpms" \
                           --enable="rhel-9-for-x86_64-appstream-rpms" \
                           --enable="rhel-9-for-x86_64-highavailability-rpms" \
                           --enable="rhel-9-for-x86_64-rt-rpms" \
                           --enable="fast-datapath-for-rhel-9-x86_64-rpms" \
                           --enable="codeready-builder-for-rhel-9-x86_64-rpms"


dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm

dnf install -y \
    kernel-rt \
    kernel-rt-devel \
    pacemaker \
    pcs \
    pcs-snmp \
    corosync \
    tuned-profiles-nfv \
    tuned-profiles-realtime \
    openvswitch3.6 \
    python3-openvswitch3.6

systemctl enable openvswitch

cat <<EOF > /etc/yum.repos.d/crb-dummy.repo
[crb]
name=Dummy CRB Repo to satisfy ceph-ansible
baseurl=https://dl.fedoraproject.org/pub/epel/9/Everything/x86_64/
enabled=1
gpgcheck=0
EOF

tuned-adm profile realtime

RT_KERNEL_PATH=$(find /boot -name "vmlinuz*rt*" | sort -V | tail -n 1)

if [ -n "$RT_KERNEL_PATH" ]; then
    grubby --set-default="$RT_KERNEL_PATH"
    grubby --set-default-index=0
else
    echo "ERROR: Kernel RT not found in /boot" >> /root/anaconda-post.log
fi

cat <<EOF > /etc/motd
 ____  _____    _    ____   _  _____ _   _
/ ___|| ____|  / \  |  _ \ / \|_   _| | | |
\___ \|  _|   / _ \ | |_) / _ \ | | | |_| |
 ___) | |___ / ___ \|  __/ ___ \| | |  _  |
|____/|_____/_/   \_\_| /_/   \_\_| |_| |_|
EOF

cat <<EOF > /tmp/Docker_gpg
-----BEGIN PGP PUBLIC KEY BLOCK-----

mQINBFit5IEBEADDt86QpYKz5flnCsOyZ/fk3WwBKxfDjwHf/GIflo+4GWAXS7wJ
1PSzPsvSDATV10J44i5WQzh99q+lZvFCVRFiNhRmlmcXG+rk1QmDh3fsCCj9Q/yP
w8jn3Hx0zDtz8PIB/18ReftYJzUo34COLiHn8WiY20uGCF2pjdPgfxE+K454c4G7
gKFqVUFYgPug2CS0quaBB5b0rpFUdzTeI5RCStd27nHCpuSDCvRYAfdv+4Y1yiVh
KKdoe3Smj+RnXeVMgDxtH9FJibZ3DK7WnMN2yeob6VqXox+FvKYJCCLkbQgQmE50
uVK0uN71A1mQDcTRKQ2q3fFGlMTqJbbzr3LwnCBE6hV0a36t+DABtZTmz5O69xdJ
WGdBeePCnWVqtDb/BdEYz7hPKskcZBarygCCe2Xi7sZieoFZuq6ltPoCsdfEdfbO
+VBVKJnExqNZCcFUTEnbH4CldWROOzMS8BGUlkGpa59Sl1t0QcmWlw1EbkeMQNrN
spdR8lobcdNS9bpAJQqSHRZh3cAM9mA3Yq/bssUS/P2quRXLjJ9mIv3dky9C3udM
+q2unvnbNpPtIUly76FJ3s8g8sHeOnmYcKqNGqHq2Q3kMdA2eIbI0MqfOIo2+Xk0
rNt3ctq3g+cQiorcN3rdHPsTRSAcp+NCz1QF9TwXYtH1XV24A6QMO0+CZwARAQAB
tCtEb2NrZXIgUmVsZWFzZSAoQ0UgcnBtKSA8ZG9ja2VyQGRvY2tlci5jb20+iQI3
BBMBCgAhBQJYrep4AhsvBQsJCAcDBRUKCQgLBRYCAwEAAh4BAheAAAoJEMUv62ti
Hp816C0P/iP+1uhSa6Qq3TIc5sIFE5JHxOO6y0R97cUdAmCbEqBiJHUPNQDQaaRG
VYBm0K013Q1gcJeUJvS32gthmIvhkstw7KTodwOM8Kl11CCqZ07NPFef1b2SaJ7l
TYpyUsT9+e343ph+O4C1oUQw6flaAJe+8ATCmI/4KxfhIjD2a/Q1voR5tUIxfexC
/LZTx05gyf2mAgEWlRm/cGTStNfqDN1uoKMlV+WFuB1j2oTUuO1/dr8mL+FgZAM3
ntWFo9gQCllNV9ahYOON2gkoZoNuPUnHsf4Bj6BQJnIXbAhMk9H2sZzwUi9bgObZ
XO8+OrP4D4B9kCAKqqaQqA+O46LzO2vhN74lm/Fy6PumHuviqDBdN+HgtRPMUuao
xnuVJSvBu9sPdgT/pR1N9u/KnfAnnLtR6g+fx4mWz+ts/riB/KRHzXd+44jGKZra
IhTMfniguMJNsyEOO0AN8Tqcl0eRBxcOArcri7xu8HFvvl+e+ILymu4buusbYEVL
GBkYP5YMmScfKn+jnDVN4mWoN1Bq2yMhMGx6PA3hOvzPNsUoYy2BwDxNZyflzuAi
g59mgJm2NXtzNbSRJbMamKpQ69mzLWGdFNsRd4aH7PT7uPAURaf7B5BVp3UyjERW
5alSGnBqsZmvlRnVH5BDUhYsWZMPRQS9rRr4iGW0l+TH+O2VJ8aQ
=0Zqq
-----END PGP PUBLIC KEY BLOCK-----
EOF

echo "EDITOR=vim" >> /etc/environment
echo "SYSTEMD_EDITOR=vim" >> /etc/environment
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
rpm -import /tmp/Docker_gpg

echo "Defaults:ansible !requiretty" >> /etc/sudoers
echo "ansible    ALL=NOPASSWD:EXEC:SETENV: /bin/sh" >> /etc/sudoers
echo "ansible    ALL=NOPASSWD: /usr/bin/rsync" >> /etc/sudoers
echo "ansible    ALL=NOPASSWD: /usr/local/bin/crm" >> /etc/sudoers
echo "ansible    ALL=NOPASSWD: /usr/bin/ceph" >> /etc/sudoers

echo "virtu   ALL=NOPASSWD: ALL" >> /etc/sudoers

cat <<EOF > /etc/profile.d/custom-path.sh
PATH=\$PATH:/usr/local/bin/
EOF

git clone  --depth 1 --branch 4.6.0 https://github.com/ClusterLabs/crmsh.git /tmp/crmsh
cd /tmp/crmsh
./autogen.sh
./configure
make
make install
ln -s /usr/local/bin/crm /usr/bin/crm
mkdir -p  /var/log/crmsh/


%end

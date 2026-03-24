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

# --- NETWORK CONFIGURATION ---
network --device=__INTERFACE__ --bootproto=static --ip=__NODE_IP__ --netmask=255.255.255.0 --gateway=192.168.124.1 --nameserver=8.8.8.8 --hostname=__HOSTNAME__ --activate --onboot=on

# --- DISK CONFIGURATION ---
ignoredisk --only-use=__TARGET_DISK__
zerombr
clearpart --all --initlabel

part /boot/efi --fstype=efi --ondisk=__TARGET_DISK__ --size=512 --asprimary
part /boot --fstype=xfs --ondisk=__TARGET_DISK__ --size=1024 --asprimary

part pv.0 --fstype=lvmpv --ondisk=__TARGET_DISK__ --size=1000 --grow
volgroup vg1 --pesize=4096 pv.0
logvol / --vgname=vg1 --name=vg1-root --fstype=ext4 --size=8000 --grow
logvol /var --vgname=vg1 --name=vg1-var --fstype=ext4 --size=4096
logvol /var/log --vgname=vg1 --name=vg1-varlog --fstype=ext4 --size=2000
logvol /var/log/audit --vgname=vg1 --name=vg1-varlogaudit --fstype=ext4 --size=1024
logvol /home --vgname=vg1 --name=vg1-home --fstype=ext4 --size=1024
logvol /srv --vgname=vg1 --name=vg1-srv --fstype=ext4 --size=512
logvol swap --vgname=vg1 --name=vg1-swap --fstype=swap --size=500

# Do not configure the X Window System
skipx

# system services 
services --disabled=corosync,pacemaker

# Users
user --uid=1006 --gid=1006 --groups=wheel --name=virtu --iscrypted --password="$6$BZGBti/HRUWlyHhY$8zI5CFPcuBJw7pKupU4d9QLTqphBDyDpkW8zMySquiKO/qcRZoEcqvCJraJXJ5y0sdNdJ2vHb6.z/UvvLJSrM/"
user --uid=1005 --gid=1005 --groups=wheel,haclient --name=ansible --iscrypted --password="$6$BZGBti/HRUWlyHhY$8zI5CFPcuBJw7pKupU4d9QLTqphBDyDpkW8zMySquiKO/qcRZoEcqvCJraJXJ5y0sdNdJ2vHb6.z/UvvLJSrM/"
user --uid=902 --gid=902  --name=Centos-snmp
rootpw  --iscrypted $6$2Aj/yELlJst1TZMM$3JVT2YYjrbMpNGoHs.2O.SvcbtGSZqQvz5Ot5CdDmU/IsRFASnSqmlvS8bg8eGoOHmQ5i7dak0VWQWtziqYjh0

# ssh keys
sshkey --username=virtu "__SSH_KEY_VIRTU__"
sshkey --username=ansible "__SSH_KEY_ANSIBLE__"
sshkey --username=root "__SSH_KEY_ROOT__"

# adding needed repositories
__REPOS__

%packages
__PACKAGES__
%end

%post
exec > /root/anaconda-post.log 2>&1

__OS_POST__

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
echo "ansible   ALL=NOPASSWD:EXEC:SETENV: /bin/sh" >> /etc/sudoers
echo "ansible   ALL=NOPASSWD: /usr/bin/rsync" >> /etc/sudoers
echo "ansible   ALL=NOPASSWD: /usr/local/bin/crm" >> /etc/sudoers
echo "ansible   ALL=NOPASSWD: /usr/bin/ceph" >> /etc/sudoers
echo "virtu   ALL=NOPASSWD: ALL" >> /etc/sudoers

cat <<EOF > /etc/profile.d/custom-path.sh
PATH=\$PATH:/usr/local/bin/
EOF

git clone --depth 1 --branch 4.6.0 https://github.com/ClusterLabs/crmsh.git /tmp/crmsh
cd /tmp/crmsh
./autogen.sh
./configure
make
make install
ln -s /usr/local/bin/crm /usr/bin/crm
mkdir -p /var/log/crmsh/
grubby --set-default-index=0

%end

# Use official CentOS Stream 9 as base
FROM quay.io/centos/centos:stream9

# 1. Install system dependencies
RUN dnf -y update && \
    dnf install -y \
    gcc \
    python3.11 \
    python3.11-pip \
    python3-pip \
    git \
    rsync \
    vim \
    iputils \
    lorax \
    xorriso \
    && dnf clean all


# 2. Install modern Ansible using Python 3.11
RUN python3.11 -m pip install --upgrade pip && \
    python3.11 -m pip install \
    "ansible-core>=2.16,<2.17" \
    netaddr \
    six

# 3. Environment setup
RUN mkdir -p /build /mnt/ssh
WORKDIR /build

CMD ["/bin/bash"]

FROM registry.access.redhat.com/ubi9/ubi:latest

ARG ORG_ID
ARG ACTIVATION_KEY

RUN subscription-manager register --org=${ORG_ID} --activationkey=${ACTIVATION_KEY} && \
    subscription-manager repos --enable=rhel-9-for-x86_64-appstream-rpms && \
    dnf install -y gcc python3.11 python3.11-pip git rsync vim lorax xorriso python3-netaddr && \
    subscription-manager unregister && \
    dnf clean all

RUN python3.11 -m pip install --upgrade pip && \
    python3.11 -m pip install "ansible-core>=2.16,<2.17" netaddr six

WORKDIR /build
CMD ["/bin/bash"]

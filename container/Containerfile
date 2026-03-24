ARG BASE_IMAGE="quay.io/centos/centos:stream9"
FROM ${BASE_IMAGE}

ARG OS_TYPE="centos"

RUN --mount=type=secret,id=org_id --mount=type=secret,id=act_key \
    if [ "$OS_TYPE" = "rhel" ]; then \
        ORG_ID=$(cat /run/secrets/org_id) && \
        ACTIVATION_KEY=$(cat /run/secrets/act_key) && \
        subscription-manager register --org=${ORG_ID} --activationkey=${ACTIVATION_KEY} && \
        subscription-manager repos --enable=rhel-9-for-x86_64-appstream-rpms; \
    else \
        dnf -y update; \
    fi && \
    dnf install -y gcc python3.11 python3.11-pip git rsync vim iputils lorax xorriso python3-netaddr && \
    if [ "$OS_TYPE" = "rhel" ]; then \
        subscription-manager unregister; \
    fi && \
    dnf clean all

RUN python3.11 -m pip install --upgrade pip && \
    python3.11 -m pip install "ansible-core>=2.16,<2.17" netaddr six

WORKDIR /build
CMD ["/bin/bash"]

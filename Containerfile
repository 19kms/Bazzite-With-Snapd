# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /
COPY scripts /scripts

FROM quay.io/fedora/fedora:43

# Install rpm-ostree for immutability and overlays
RUN dnf install -y rpm-ostree

# Configure rpm-ostree to allow layered packages and overlays
RUN echo 'allow-dnf=true' >> /etc/rpm-ostree.conf || true

# Optionally, install dnf5 for normal RPM management
RUN dnf install -y dnf5

# Install Steam
RUN flatpak install -y flathub com.valvesoftware.Steam

COPY build_files/ /tmp/build_files/
COPY scripts/ /tmp/scripts/

### MODIFICATIONS
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /usr/bin/bash /ctx/build.sh

### LINTING
RUN bootc container lint
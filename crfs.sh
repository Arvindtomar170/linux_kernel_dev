#!/bin/sh
# Create a basic initramfs root filesystem

# Clean up any old rootfs
echo "creating initramfs"

rm -rf initramfs

# Create directories explicitly (no brace expansion)
mkdir -p \
  initramfs/bin \
  initramfs/etc/init.d \
  initramfs/usr/bin \
  initramfs/usr/sbin \
  initramfs/proc \
  initramfs/sys \
  initramfs/dev \
  initramfs/tmp

# Create /etc/inittab
cat > initramfs/etc/inittab <<EOF
::sysinit:/etc/init.d/rcS
::once:-sh -c 'cat /etc/motd; setuidgid 0 /bin/sh; poweroff'
EOF

# Create /etc/motd
echo "\n\nA message from Arvind Tomar\n\n" > initramfs/etc/motd

# Create rcS script
cat > initramfs/etc/init.d/rcS <<EOF
#!/bin/sh
/bin/busybox --install -s
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs devtmpfs /dev
mount -t tmpfs tmpfs /tmp
EOF

# Make rcS executable
chmod +x initramfs/etc/init.d/rcS

echo "bulding buzybox using docker\n"
cat > Dockerfile <<'EOF'
FROM debian:10.8-slim

ARG BUSYBOX_VERSION=1.37.0
RUN apt-get update && \
    apt-get install -y \
      bc bison build-essential cpio flex wget \
      libelf-dev libncurses-dev libssl-dev && \
    rm -rf /var/lib/apt/lists/*

# Build BusyBox statically and install it to /build
RUN mkdir /build && \
    cd /tmp && \
    wget https://busybox.net/downloads/busybox-${BUSYBOX_VERSION}.tar.bz2 && \
    tar -xf busybox-${BUSYBOX_VERSION}.tar.bz2 && \
    cd busybox-${BUSYBOX_VERSION} && \
    make defconfig && \
    LDFLAGS="--static" make CONFIG_PREFIX=/build -j$(nproc) install
EOF

# Build the Docker image ( avoid making multiple images)
sudo docker build --build-arg BUSYBOX_VERSION=1.37.0 -t busybox-builder .

# Create shared folder
mkdir -p shared

# Run the container and copy the files from it
sudo docker run --rm -v "$(pwd)/shared:/out" busybox-builder /bin/sh -c "cp -r /build/* /out"

cp -r ./shared/* ./initramfs/
cp initramfs/linuxrc initramfs/init

cd initramfs
    find . -print0 | cpio --null -ov --format=newc > initramfs.cpio
    gzip ./initramfs.cpio
cd ..

echo "✅ initramfs created successfull"


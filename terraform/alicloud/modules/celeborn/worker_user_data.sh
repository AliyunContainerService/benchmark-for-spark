#!/bin/bash

set -eux

yum install -y parted e2fsprogs

output=$(fdisk -l | awk '/^Disk \//' | grep -o -E '/dev/nvme[0-9]n1')
disks=()
while IFS= read -r line; do
    disks+=("$line")
done <<<"$output"

n=${#disks[@]}

# Create one primary partition for every disk.
for ((i = 0; i < n; i++)); do
    disk="${disks[i]}"
    parted "${disk}" mklabel gpt
    parted "${disk}" mkpart primary 1 100%
    parted "${disk}" align-check optimal 1
done
partprobe

# Create XFS file system for the first partition of every disk.
for ((i = 0; i < n; i++)); do
    disk="${disks[i]}"
    if [[ ${disk} =~ "/dev/nvme" ]]; then
        mkfs -t xfs "${disk}p1"
    elif [[ ${disk} =~ "/dev/vd" ]]; then
        mkfs -t xfs "${disk}1"
    elif [[ ${disk} =~ "/dev/xvd" ]]; then
        mkfs -t xfs "${disk}1"
    fi
done

# Mount file systems to /mnt/disk1, /mnt/disk2, etc.
cp /etc/fstab /etc/fstab.bak

for ((i = 0; i < n; i++)); do
    dir="/mnt/disk$((i + 1))"
    mkdir -p ${dir}
    if [[ ${disk} =~ "/dev/nvme" ]]; then
        echo "$(blkid "${disks[i]}p1" | awk '{print $2}' | sed 's/\"//g') ${dir} xfs defaults 0 0" >>/etc/fstab
    elif [[ ${disk} =~ "/dev/vd" ]]; then
        echo "$(blkid "${disks[i]}1" | awk '{print $2}' | sed 's/\"//g') ${dir} xfs defaults 0 0" >>/etc/fstab
    elif [[ ${disk} =~ "/dev/xvd" ]]; then
        echo "$(blkid "${disks[i]}1" | awk '{print $2}' | sed 's/\"//g') ${dir} xfs defaults 0 0" >>/etc/fstab
    fi
done

mount -a

chmod a+w /mnt/disk*

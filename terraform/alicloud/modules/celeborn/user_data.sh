#!/bin/bash

# 打印命令
set -ex

# 添加 parted
yum install -y parted e2fsprogs

# 为数据盘新建分区
disks=(/dev/nvme0n1)
for disk in ${disks[@]}; do
    parted ${disk} mklabel gpt
    parted ${disk} mkpart primary 1 100%
    parted ${disk} align-check optimal 1
done
partprobe

# 为分区创建文件系统
for disk in ${disks[@]}; do
    mkfs -t xfs ${disk}p1
done

# 挂载分区
cp /etc/fstab /etc/fstab.bak
n=${#disks[@]}
for ((i = 0; i < n; i++)); do
    dir="/mnt/disk$(($i + 1))"
    mkdir -p ${dir}
    echo "$(blkid ${disks[i]}p1 | awk '{print $2}' | sed 's/\"//g') ${dir} xfs defaults 0 0" >>/etc/fstab
done
mount -a

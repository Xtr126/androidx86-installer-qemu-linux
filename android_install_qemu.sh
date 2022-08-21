#!/bin/bash

local isoname="$1"
local android_dir="$2"
local size="{$3:-8G}"

local iso_mount=/tmp/iso_mount-${uuidgen}
local android_mount=/tmp/android-x86-${uuidgen}
mkdir $iso_mount

echo "mount ISO ${iso_mount}.."
mount -o loop "$isoname" $iso_mount && echo -n ". success"

echo "copy kernel initrd.img.."
mkdir -p "$android_dir"
cp $iso_mount/kernel $iso_mount/initrd.img "$android_dir" && echo -n ". success"

echo "creating android.img ${size}.."
qemu-img create -f raw "$android_dir"/android.img -s $size && echo -n ". success"

echo "mkfs.ext4 android.img.."
mkfs.ext4 "$android_dir"/android.img &>/dev/null && echo -n ". success"

echo "mount android.img.."
mkdir $android_mount
mount -o loop android.img $android_mount && echo -n ". success"

echo "create /data /system.."
mkdir -p $android_mount/data $android_mount/system && echo -n ". success"

cp $iso_mount/ramdisk.img $iso_mount/gearlock $android_mount &>/dev/null

echo "mount system.sfs / system.img.."
mount -o loop $iso_mount/system.sfs $iso_mount
echo -n .
mount -o loop $iso_mount/system.img $iso_mount && echo -n ". success"

echo "copy /system.. please wait"
cp -a -Z $iso_mount $android_mount/system && echo -n ".. success"

echo "cleanup"
umount $iso_mount; umount $iso_mount; umount $iso_mount;
umount $android_mount; losetup -D; rm -r $android_mount $iso_mount && echo -n ".. success"


android_dir=\""$android_dir"\"
echo "qemu-system-x86_64 -enable-kvm -cpu host -smp 2 -m 2G  \
                        -drive file="$android_dir"/android.img,format=raw,cache=none,if=virtio \
                        -display sdl,gl=on,show-cursor=on \\
                        -device virtio-vga-gl,xres=1280,yres=720 \\
                        -net nic,model=virtio-net-pci -net user,hostfwd=tcp::5555-:5555 \\
                        -machine vmport=off -machine q35 \\
                        -device virtio-tablet-pci -device virtio-keyboard-pci \\
                         -kernel "$android_dir"/kernel -append \""root=/dev/ram0 quiet video=1280x720 SRC=/ GRALLOC=gbm"\" \\
                         -initrd "$android_dir"/initrd.img"

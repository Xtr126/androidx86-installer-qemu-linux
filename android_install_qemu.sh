#!/bin/bash

isoname="$1"
android_dir="$2"
size=${3:-8G}

iso_mount=/tmp/iso_mount-$(uuidgen)
android_mount=/tmp/android_x86-$(uuidgen)
mkdir $iso_mount

echo "mount ISO ${iso_mount}.."
mount -o loop "$isoname" $iso_mount && echo -n ". "

echo -n "copy kernel initrd.img.."
mkdir -p "$android_dir"
cp $iso_mount/kernel $iso_mount/initrd.img "$android_dir" && echo -n "."

echo "creating android.img ${size}.."
qemu-img create -f raw "$android_dir"/android.img -s $size && echo -n ". "

echo -n "mkfs.ext4 android.img.."
mkfs.ext4 "$android_dir"/android.img &>/dev/null && echo -n "."

echo "mount android.img.."
mkdir $android_mount
mount -o loop android.img $android_mount && echo -n ". "

echo -n "create /data /system.."
mkdir -p $android_mount/data $android_mount/system && echo -n "."

cp $iso_mount/ramdisk.img $iso_mount/gearlock $android_mount &>/dev/null && echo "gearlock found.."

echo "mount system.sfs.."
mount -o loop $iso_mount/system.sfs $iso_mount && echo -n ". "
echo -n "mount system.img.."
mount -o loop $iso_mount/system.img $iso_mount && echo -n .

echo "copy /system.. please wait"
cp -a -Z $iso_mount $android_mount/system && echo -n ".. done"

echo "cleanup.."
umount $iso_mount; umount $iso_mount; umount $iso_mount;
umount $android_mount; losetup -D; rm -r $android_mount $iso_mount && echo -n "."


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

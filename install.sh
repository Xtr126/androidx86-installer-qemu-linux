#!/bin/bash

isoname="$1"
android_dir="$2"
size=${3:-8G}

iso_mount=/tmp/iso_mount-$(uuidgen)
android_mount=/tmp/android_x86-$(uuidgen)
mkdir $iso_mount

echo "mount iso.."
mount -o loop "$isoname" $iso_mount

echo -n "copy kernel initrd.img.."
mkdir -p "$android_dir"
cp $iso_mount/kernel $iso_mount/initrd.img "$android_dir" && echo "."

echo -n "creating android.img ${size}.. "
qemu-img create -f raw "$android_dir"/android.img $size
mkfs.ext4 "$android_dir"/android.img

echo -n "mount android.img.."
mkdir $android_mount
mount -o loop "$android_dir"/android.img $android_mount && echo "."

echo -n "create /data.."
mkdir -p $android_mount/data && echo "."

cp $iso_mount/ramdisk.img $android_mount &>/dev/null
cp $iso_mount/gearlock $android_mount &>/dev/null && echo "gearlock found..\n creating nosc file to tell gearlock not to touch our system.img" && touch $android_mount/nosc

echo -n "mount system.sfs.. "
mount -o loop $iso_mount/system.sfs $iso_mount

echo -n "copy system.img.. please wait"
cp $iso_mount/system.img $android_mount/system.img && echo ".. done"

echo -n "cleanup.. "
echo -n "unmounting filesystems: "
umount $iso_mount; umount $iso_mount; echo "done"
echo -n "syncing to disk.. " && sync && echo "done"
umount $android_mount; losetup -D; rm -r $android_mount $iso_mount


android_dir=\""$android_dir"\"
echo "
qemu-system-x86_64 -enable-kvm -cpu host -smp 2 -m 2G \\
                -drive file="$android_dir"/android.img,format=raw,cache=none,if=virtio \\
                -display sdl,gl=on,show-cursor=on \\
                -device virtio-vga-gl,xres=1280,yres=720 \\
                -net nic,model=virtio-net-pci -net user,hostfwd=tcp::5555-:5555 \\
                -machine vmport=off -machine q35 \\
                -device virtio-tablet-pci -device virtio-keyboard-pci \\
                -kernel "$android_dir"/kernel -append \""root=/dev/ram0 quiet video=1280x720 SRC=/ GRALLOC=gbm"\" \\
                -initrd "$android_dir"/initrd.img
                         "

echo "run sudo chown -hR "'$(whoami)' "$android_dir" "if permission denied"

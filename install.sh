#!/bin/bash

if [ "$(id -u)" != "0" ]
then
	echo "error: script has not been run with root privileges, it may not work."
	echo "try to run with sudo"
	echo "Press any key to ignore and continue"
    x=3
	while true; do
      echo -en " exiting in $x seconds\r"
	  read -n 1 -t 1 breakvar && break
      let x=x-1
      test $x = 0 && echo -n "exiting in $x seconds" && exit 1
    done
fi

help_usage()
{
	echo ""
	echo "install.sh [-s X] -i android_iso_path -d android_install_dir"
	echo "-i (iso), --isofile (iso)	Android-x86 ISO file"
	echo "-d, --destination (path)	Directory to install android files into"
	echo "-s (size), --size (size) size in GB (default=8)"
	echo "-h, --help"
  exit 1
}

if [ $# -eq 0 ]; then
help_usage
fi

while [ $# -gt 0 ]; do
    case "$1" in
        -i | --isofile)
        shift
        isoname="$1"
        ;;
        -d | --destination)
        shift
        android_dir="$1"
        ;;
        -s | --size)
        shift
        size=$1
        ;;
        -h | --help)
        help_usage
        ;;
        *)
        echo "error: invalid argument"
        help_usage
    esac
    shift
done

[ ! -f "$isoname" ] && echo "error: ${1:-iso_file} not found, try --help" && exit 1
[ -z "$android_dir" ] && echo "error: android install dir not specified, try --help" && exit 1

if [ -z $size ]; then
  echo "size not specified, defaulting to 8GB"; size=8
else
  [ -z "${size##*[!0-9]*}" ] && echo "error: size is not numeric" && exit 1
fi

iso_mount=/tmp/iso_mount-$(uuidgen)
android_mount=/tmp/android_x86-$(uuidgen)
mkdir $iso_mount $android_mount

mount_and_verify_iso(){
  files_list=( kernel initrd.img system.sfs )
  mount -o loop "$1" $2
  for file in ${files_list[@]}; do
    if [ ! -f $2/$file ]; then 
    echo "error: $file not found: incompatible iso" && exit 1
    fi
  done
}

echo "mount iso.."
mount_and_verify_iso "$isoname" $iso_mount

echo -n "copy kernel initrd.img.."
mkdir -p "$android_dir"
cp $iso_mount/kernel $iso_mount/initrd.img "$android_dir" && echo "."

echo -n "creating android.img.. "
qemu-img create -f raw "$android_dir"/android.img ${size}G || truncate -s ${size}G "$android_dir"/android.img
mkfs.ext4 "$android_dir"/android.img

echo -n "mount android.img.."
mount -o loop "$android_dir"/android.img $android_mount && echo "."

echo -n "create /data.."
mkdir -p $android_mount/data && echo "."

cp $iso_mount/ramdisk.img $android_mount &>/dev/null
cp $iso_mount/gearlock $android_mount &>/dev/null && \
echo "gearlock found: attempt to disable gearlock supercharge function" && \
touch $android_mount/nosc

echo -n "mount system.sfs.. "
mount -o loop $iso_mount/system.sfs $iso_mount

echo "copy system.img.. please wait"
dd if=$iso_mount/system.img of=$android_mount/system.img status=progress

echo "cleanup.. "
echo -n "syncing to disk: " && sync && echo "done"
echo -n "unmounting filesystems: "
umount $android_mount && rm -rf $android_mount || echo "error: umount $android_mount failed, manually remove it"
umount $iso_mount && umount $iso_mount && rm -rf $iso_mount && echo "done" || echo "error: umount $iso_mount failed, manually remove it"
losetup -D


android_dir=\""$(cd "$android_dir" && pwd)"\"
echo "
qemu-system-x86_64 -enable-kvm -cpu host -smp 2 -m 2G \\
                -drive file="$android_dir"/android.img,format=raw,cache=none,if=virtio \\
                -display sdl,gl=on,show-cursor=on \\
                -device virtio-vga-gl,xres=1280,yres=720 \\
                -net nic,model=virtio-net-pci -net user,hostfwd=tcp::5555-:5555 \\
                -machine vmport=off -machine q35 \\
                -device virtio-tablet-pci -device virtio-keyboard-pci \\
                -serial mon:stdio \\
                -kernel "$android_dir"/kernel -append \""root=/dev/ram0 quiet SRC=/ GRALLOC=gbm video=1280x720 console=ttyS0"\" \\
                -initrd "$android_dir"/initrd.img
                         "

echo "run sudo chown -hR "'$(whoami)' "$android_dir" "if permission denied"

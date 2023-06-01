#!/bin/bash

if [ "$(id -u)" != "0" ]; then
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
cat <<- EOF
  Usage: ${0##*/} [-s X] -i android_iso_path -d android_install_dir

  Options:
    -i, --isofile (iso)       Android-x86 ISO file
    -d, --destination (path)  Directory to install android files into
    -s, --size (size)         Size in GB (default=8)
        --rw-system           Extract system.img from system.sfs 
        --extract-system      Extract system.img and copy contents
    -h, --help                Display this message and exit
EOF
exit 1
}

set_color(){
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m' 
  BLUE='\033[0;34m' 

  local color=$1
  case "$color" in
    red)
        echo -en "${RED}";;
    blue)
        echo -en "${BLUE}";;
    green)
        echo -en "${GREEN}";;
    yellow)
        echo -en "${YELLOW}";;
    *)
        echo -en '\033[0m';;
  esac
}

extract_system_to_dir(){
  system_mount_dir=/tmp/system_$(uuidgen)
  mkdir $system_mount_dir

  echo -n "mount ${system_image}.. "
  mount -o loop $iso_mount/$system_image $system_mount_dir

  check_if_system_img_exists || return

  echo -n "system.img.. "
  mount -o loop $system_mount_dir/system.img $system_mount_dir && echo "done"

  echo "extracting system.img.. please wait"
  echo "this might take a while"
  cp -a -Z $system_mount_dir $android_mount/system
  umount $system_mount_dir
}

install_system_rw(){
  system_mount_dir=/tmp/system_$(uuidgen)
  mkdir $system_mount_dir

  echo -n "mount ${system_image}.. "
  mount -o loop $iso_mount/$system_image $system_mount_dir

  check_if_system_img_exists || return

  echo "copy system.img.. please wait"
  dd if=$system_mount_dir/system.img of=$android_mount/system.img status=progress
}

copy_system_image(){
  dd if=$iso_mount/$system_image of=$android_mount/$system_image status=progress
}

check_if_system_img_exists(){
  if [ ! -f $system_mount_dir/system.img ]; then
    umount $system_mount_dir
    copy_system_image
    return 1
  fi
}

cleanup() {
  error(){
    set_color red
    echo "error: umount $1 failed, manually remove it"
    set_color green
  }

  set_color green
  echo "cleanup.. "
  echo -n "syncing to disk: " && sync && echo "done"
  echo -n "unmounting filesystems: "
  
  if [ -d "$android_mount" ]; then
    umount $android_mount && rm -rf $android_mount || error $android_mount 
  fi

  if [ -d "$system_mount_dir" ]; then
    umount $system_mount_dir && rm -rf $system_mount_dir || error $system_mount_dir 
  fi

  if [ -d "$iso_mount" ]; then
    umount $iso_mount && rm -rf $iso_mount && echo "done" || error $iso_mount
  fi

  losetup -D
  set_color null
}

echo_err(){
  set_color red
  echo "error: $1"
  set_color null
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
    --extract-system)
        extract_system=yes
        ;;
    --rw-system)
        rw_system=yes
        ;;
    -h | --help)
        help_usage ;;
    *)
        set_color red; echo "error: invalid argument"; set_color null
        help_usage
        ;;
    esac
    shift
done

[ ! -f "$isoname" ] && echo_err "file ${isoname:-iso_file} not found, try --help" 
[ -z "$android_dir" ] && echo_err "android install dir not specified, try --help" 

if [ -z $size ]; then
  set_color yellow; echo "size not specified, defaulting to 8GB"; size=8; set_color null
else
  set_color red
  [ -z "${size##*[!0-9]*}" ] && echo_err "size is not numeric" 
  set_color null
fi

iso_mount=/tmp/iso_mount-$(uuidgen)
android_mount=/tmp/android_x86-$(uuidgen)
mkdir $iso_mount $android_mount

mount_and_verify_iso(){
  local iso="$1"
  local dest="$2"
  mount -o loop "$iso" "$dest"

  cd $dest
  
  if [ ! -f $dest/initrd.img ]; then 
    echo_err "initrd.img not found: incompatible iso" 
  fi

  files=(system*); system_image="${files[0]}"
  if [ ! -f $system_image ]; then
    echo_err "system.sfs or system.efs not found" 
  fi
  
  kernels_=(kernel*); kernel_image="${kernels_[0]}"
  if [ ! -f $kernel_image ]; then
    echo_err "kernel not found: incompatible iso" 
  fi
  cd -
}

echo "mount iso.."
mount_and_verify_iso "$isoname" $iso_mount

trap "cleanup" EXIT

echo -n "copy kernel initrd.img.."
mkdir -p "$android_dir"
cp $iso_mount/$kernel_image $iso_mount/initrd.img "$android_dir" && echo "."

echo -n "creating android.img.. "
qemu-img create -f raw "$android_dir"/android.img ${size}G || truncate -s ${size}G "$android_dir"/android.img
mkfs.ext4 "$android_dir"/android.img

echo -n "mount android.img.."
mount -o loop "$android_dir"/android.img $android_mount && echo "."

echo -n "create /data.."  
mkdir -p $android_mount/data && echo "."

set_color blue
cp $iso_mount/ramdisk.img $android_mount &>/dev/null
cp $iso_mount/gearlock $android_mount &>/dev/null && \
echo "gearlock found: force disabling supercharge" && \
touch $android_mount/nosc
set_color none

if [ "${extract_system}" == yes ]; then
  extract_system_to_dir
elif [ "${rw_system}" == yes ]; then
  install_system_rw
else
  copy_system_image
fi

script_name="$android_dir/start_android.sh"
echo '#!/bin/bash' > "$script_name"
chmod a+x "$script_name"

android_dir=\""$(cd "$android_dir" && pwd)"\"
set_color blue
echo "
qemu-system-x86_64 -enable-kvm -cpu host -smp 2 -m 2G \\
                -drive file="$android_dir"/android.img,format=raw,cache=none,if=virtio \\
                -display sdl,gl=on,show-cursor=on \\
                -device virtio-vga-gl,xres=1280,yres=720 \\
                -net nic,model=virtio-net-pci -net user,hostfwd=tcp::5555-:5555 \\
                -machine vmport=off -machine q35 \\
                -device virtio-tablet-pci -device virtio-keyboard-pci \\
                -serial mon:stdio \\
                -kernel "$android_dir"/$kernel_image -append \""root=/dev/ram0 quiet SRC=/ video=1280x720 console=ttyS0"\" \\
                -initrd "$android_dir"/initrd.img
                         " | tee -a "$script_name"

set_color yellow
echo "run sudo chown -hR "'$(whoami)' "$android_dir" "if permission denied"
echo "script written to ${script_name}"
set_color null

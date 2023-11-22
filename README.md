Quick setup Android-x86 QEMU guest.

This script automates the process of deploying android x86 guests for QEMU.  
Bypassing GRUB2, Android x86 installation wizard.  
Easily change resolution of guest by using video= in kernel command line (-append "cmdline")  
Tested to work on Fedora / Arch Linux with QEMU 6.2 / 7.0-7.1

To install Android in specified directory with a disk image of 8GB, run  
`sudo bash install.sh -s 8 -i /path/to/android-x86.iso -d ~/Documents/android-x86`

Command line options:
```
install.sh [-s X] -i android_iso_path -d android_install_dir

Options:
    -i, --isofile (iso)       Android-x86 ISO file
    -d, --destination (path)  Directory to install android files into
    -s, --size (size)         Size in GB (default=8)
        --rw-system           Extract system.img from system.sfs 
        --extract-system      Extract system.img and copy contents
    -h, --help                Display this message and exit
```
An alternate version of this documentation is available here: https://xtr126.github.io/XtMapper-docs/blissos/quick_vm/  
Refer to QEMU advanced configuration section in BlissOS wiki and/or other resources for Audio support and other further optimizations/tweaks/settings applicable to Android running on QEMU, that are beyond the scope of this script.  
https://docs.blissos.org/installation/install-in-a-virtual-machine/advanced-qemu-config

`--extract-system` might have problems with certain Android builds, do not use that option with
- AOSP 12L build 2022-03-17 from blissos.org  
System will be stuck at Detecting Android x86...  
initrd.img will be looking for system.img or default.prop, but this build has no default.prop.  
Newer Bliss 14/15 builds should work fine.

- Project Sakura x86 by HMTheBoy154  
Has initrd-magisk integrated to system, it doesnt like /system bind mounted from a directory rather than system.img. Will most likely result in a bootloop. 


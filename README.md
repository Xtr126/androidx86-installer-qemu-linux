Quick setup Android-x86 QEMU guest.

This script automates the process of deploying android x86 guests for qemu.  
Bypassing GRUB2, Android x86 installation wizard.  
Easily change resolution of guest by using video= in kernel cmdline (-append "cmdline")  
Works on Fedora / Arch Linux with QEMU 6.2 /7.0 +  

To install Android in specified directory with a disk image of 8GB, run  
`sudo bash install.sh -s 8 -i /path/to/android-x86.iso -d ~/Documents/android-x86`

Command line options:
```
install.sh [-s X] -i android_iso_path -d android_install_dir
-i (iso), --isofile (iso)       Android-x86 ISO file
-d, --destination (path)        Directory to install android files into
-s (size), --size (size) size in GB (default=8)
--extract-system-to-dir  Extract system.img and copy contents
-h, --help
```
`--extract-system-to-dir` might have problems with certain Android builds, do not use that option with
- AOSP 12L build 2022-03-17 from blissos.org  
System will be stuck at Detecting Android x86...  
initrd.img will be looking for system.img or default.prop, but Android 12L has no default.prop.

- Project Sakura x86 by HMTheBoy154  
Has initrd-magisk integrated to system, it doesnt like /system bind mounted from a directory rather than system.img. Will most likely result in a bootloop. 

Quick setup Android-x86 QEMU guest.

This script automates the process of deploying android x86 guests for qemu.  
Bypassing GRUB2, Android x86 installation wizard.  
Easily change resolution of guest by using video= in kernel cmdline (-append "cmdline")  

Clone this repository and run

`cd repo_name`  
`sudo bash install.sh -s 8 -i android-x86.iso -d ~/Documents/android-x86`

Installs Android x86 in specified directory with a disk image of 8GB.
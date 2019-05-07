#!/bin/bash

OLDQEMU_URL=https://dugoh.github.io/oldqemu/qemu.tar.bz2
CD386BSD_URL=https://dugoh.github.io/386bsdcd
FREEDOS_URL=http://www.freedos.org/download/download/FD12FLOPPY.zip

# Get and install old qemu
( cd /root; wget -O - "${OLDQEMU_URL}" |bunzip2 -c |tar -xf - )
( cd /root/qemu; make install )
/usr/local/bin/qemu --help || exit 1

# Get 386BSD 1.0 CD and mount it
for i in a b c; do
  wget -O - "${CD386BSD_URL}"/x${i}
done |bunzip2 -c >386BSD-1.0
mount -t iso9660 386BSD-1.0 /mnt/
ls /mnt/386bsd || exit 1

# Download Freedos boot floppy
wget "${FREEDOS_URL}"
unzip -o FD12FLOPPY.zip
ls FLOPPY.img || exit 1

# Make some room on the floppy
mcopy -i ./FLOPPY.img ::FDCONFIG.SYS ::/FDSetup/BIN/HIMEMX.EXE ./
sed -i -e's/.FDSetup.BIN.//g' FDCONFIG.SYS
mcopy -i ./FLOPPY.img -o FDCONFIG.SYS HIMEMX.EXE ::
mdeltree -i ./FLOPPY.img FDSETUP AUTOEXEC.BAT SETUP.BAT

# Copy in the boot utility and the kernels
mcopy -i ./FLOPPY.img /mnt/386bsd /mnt/386bsd.ddb /mnt/boot.exe ::

# Create empty disk
dd if=/dev/zero of=disk.img bs=4096 count=129024

# Try
(
sleep 10
echo 11-01-1994
sleep 3
echo
sleep 10
echo boot 386bsd wd1d
sleep 30
) |/usr/local/bin/qemu  \
     -no-acpi           \
     -M isapc           \
     -fda FLOPPY.img    \
     -hda disk.img      \
     -hdachs 1024,16,63 \
     -hdb 386BSD-1.0    \
     -curses            \
     -m 4               \
     -boot a

#!/bin/bash

OLDQEMU_URL=https://dugoh.github.io/oldqemu/qemu.tar.bz2
CD386BSD_URL=https://dugoh.github.io/386bsdcd
FREEDOS_URL=http://www.freedos.org/download/download/FD12FLOPPY.zip

# Like `cat' but slow
slowcat() {
  [[ -z "${4}" ]] && echo usage: $0 file chunksize keywait enterwait && return 1
  local c=0
  local b=$(wc -c <${1})
  while [ ${c} -lt ${b} ]; do
    dd if=${1} bs=1 count=${2} skip=${c} 2>/dev/null
    dd if=${1} bs=1 count=${2} skip=${c} 2>/dev/null |grep -q "^$" && sleep ${4}
    (( c = c + ${2} ))
    sleep ${3}
  done
}

# Translation of some characters to QEMU sendkey command arguments (incomplete)
qtrans() {
  sed -e's/-/minus/'           \
      -e's/ /spc/'             \
      -e's/=/equal/'           \
      -e's/,/comma/'           \
      -e's/\./dot/'            \
      -e's/\//slash/'          \
      -e's/\*/asterisk/'       \
      -e's/:/shift-semicolon/' \
      -e's/;/semicolon/'       \
      -e's/</shift-comma/'     \
      -e's/>/shift-dot/'       \
      -e's/[A-Z]/shift-&/'     \
    |tr '[:upper:]' '[:lower:]'
}

# The video camera
movietime() {
  export TERM=ms-vt100-color
  stty rows 25
  stty columns 80
  script -qfc "asciinema rec -i 10 --stdin -c 'script -qfc ./build.sh' 1.cast"
  asciinema upload 1.cast
  exit
}

# The answering machine
autoattendant() {
  declare -a qa=(\
  "erase"                                                            "install" \
  "(Please press return to continue)"                                       "" \
  "Would you like to configure it for use with 386BSD? (y/n)"              "y" \
  "Would you like a DOS partition table to be made by 386BSD? (y/n)"       "n" \
  "Do you want to configure the ENTIRE drive for 386BSD? (y/n)"            "y" \
  "Do you *still* want to configure the entire drive for 386BSD? (y/n)"    "y" \
  "paging storage? (y/n)"                                                  "n" \
  "Enter one of the above designations"                                  "UTC" \
  "N.B. system installation on secondary drives must boot from DOS"   "reboot" \
  )

  for ((i = 0; i < "${#qa[@]}"; i=i+2)); do
    until fgrep -q "${qa[$i]}" 1.cast 2>/dev/null ; do
      sleep 1
    done
    (
      sleep 5
      for key in $(grep -o . <<< "${qa[$i+1]}"  |qtrans) ret ; do
        echo "sendkey ${key}"
        sleep .3
      done
    )|telnet localhost 3440 >/dev/null 2>&1
    sleep 5
  done
}

bootc() {
  script -qfc 'qemu            \
       -no-reboot              \
       -no-acpi                \
       -M isapc                \
       -m 16                   \
       -fda FLOPPY.img         \
       -hda dirtydisk.img      \
       -hdb 386BSD-1.0         \
       -boot c                 \
       -startdate "1994-11-02" \
       -curses                 \
       -monitor tcp:127.0.0.1:3440,server,nowait'
}

boota() {
  script -qfc 'qemu            \
       -no-reboot              \
       -no-acpi                \
       -M isapc                \
       -m 16                   \
       -fda FLOPPY.img         \
       -hda dirtydisk.img      \
       -hdb 386BSD-1.0         \
       -boot a                 \
       -startdate "1994-11-02" \
       -curses                 \
       -monitor tcp:127.0.0.1:3440,server,nowait'
}

# Start the recording if we haven't yet
ls 1.cast >/dev/null 2>&1 || movietime

# Get and install old qemu
( cd /root; wget -q -O - "${OLDQEMU_URL}" |bunzip2 -c |tar -xf - )
( cd /root/qemu; make install )
/usr/local/bin/qemu --help >/dev/null 2>&1 || exit 1

# Get 386BSD 1.0 CD and mount it
for i in a b c; do
  wget -q -O - "${CD386BSD_URL}"/x${i}
done |bunzip2 -c >386BSD-1.0
mount -t iso9660 386BSD-1.0 /mnt/
ls /mnt/386bsd >/dev/null 2>&1 || exit 1

# Download Freedos boot floppy
wget -q "${FREEDOS_URL}"
unzip -o FD12FLOPPY.zip
ls FLOPPY.img >/dev/null 2>&1 || exit 1

# Make some room on the floppy
mcopy -i ./FLOPPY.img ::FDCONFIG.SYS ::/FDSetup/BIN/HIMEMX.EXE ./
sed -i -e's/.FDSetup.BIN.//g' FDCONFIG.SYS
printf "boot 386bsd wd1d\r\n" > AUTOEXEC.BAT
mcopy -i ./FLOPPY.img -o FDCONFIG.SYS AUTOEXEC.BAT HIMEMX.EXE ::
mdeltree -i ./FLOPPY.img FDSETUP SETUP.BAT

# Copy in the boot utility and the kernels
mcopy -i ./FLOPPY.img /mnt/386bsd /mnt/386bsd.ddb /mnt/boot.exe ::

# Create empty disk
dd if=/dev/zero of=disk.img bs=4096 count=129024 2>/dev/null
ls -l disk.img >/dev/null 2>&1 || exit 1

# Turn on the answering machine
autoattendant &

script -qfc 'qemu            \
     -no-reboot              \
     -no-acpi                \
     -M isapc                \
     -m 16                   \
     -fda FLOPPY.img         \
     -hda disk.img           \
     -hdb 386BSD-1.0         \
     -boot a                 \
     -startdate "1994-11-01" \
     -curses                 \
     -monitor tcp:127.0.0.1:3440,server,nowait'

cp disk.img dirtydisk.img

#( sleep 20; (sleep 40 ; echo quit ; sleep 10) |telnet localhost 3440 ) &

#( tail -f 1.cast |fgrep 'press key to boot/dump' | while read line; do
#    (sleep 10 ; echo quit ; sleep 10) |telnet localhost 3440
#  done
#) &

(
  while true ; do
    (sleep 55 ; echo quit ; sleep 5) |telnet localhost 3440
  done
) &


for i in $(seq 10); do echo "+++ bootc $i +++" ; bootc; done 

sed -i -e's/wd1d/wd0a/' AUTOEXEC.BAT
mcopy -i ./FLOPPY.img -o AUTOEXEC.BAT ::

for i in $(seq 10); do echo "+++ boota $i +++" ; boota; done 

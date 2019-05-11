#!/bin/bash
echo $TERM; stty -a; tput cols; tput lines
OLDQEMU_URL=https://dugoh.github.io/oldqemu/qemu.tar.bz2
CD386BSD_URL=https://dugoh.github.io/386bsdcd
FREEDOS_URL=http://www.freedos.org/download/download/FD12FLOPPY.zip

# Poor man's expect
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

# The video camera
movietime() {
    #export TERM=ms-vt100-color
    export TERM=xterm
    stty rows 27
    stty columns 82
    echo $TERM; stty -a; tput cols; tput lines
    script -f -c "asciinema rec --stdin -y -c 'script -f -c ./build.sh' ./1.cast"
    #sed -i -e '1 s/height": 24/height": 26/' ./1.cast
    head -1 ./1.cast
    asciinema upload ./1.cast
    exit
}

# Start the recording if we haven't yet
ls ./1.cast >/dev/null 2>&1 || movietime
echo $TERM; stty -a; tput cols; tput lines
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

# Try
cat >keys1 <<__EOF
$(printf "\x1b1")./install$(printf "\x1b1")
y
$(printf "\x1b1")n
y
y
n
__EOF
while true; do printf '\x16'; sleep 0.1; printf '\x16'; sleep 1; done &
(
  sleep 30
  slowcat keys1 1 1 15
  sleep 100
  printf "\x1b2"
  sleep 3
  printf "quit\n"
  sleep 3
) |script -f -c 'qemu        \
     -no-reboot              \
     -no-acpi                \
     -M isapc                \
     -m 4                    \
     -fda FLOPPY.img         \
     -hda disk.img           \
     -hdb 386BSD-1.0         \
     -boot a                 \
     -startdate "1994-11-01" \
     -curses'
#-hdachs 1024,16,63      \
#-net nic,model=ne2k_isa \
kill %1

#!/bin/sh

PROJ_DIR=`pwd`
ISO_FILENAME="MattHat.iso"
HOSTNAME="MattHat"

# CLEAN WORK

rm -rf work
mkdir work

# LINUX

LINUX_ARCHIVE_FILE="linux-4.12.2.tar.xz"
cd source
if [ ! -f "$LINUX_ARCHIVE_FILE" ]; then
  wget "https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.12.2.tar.xz"
fi
rm -rf ../work/kernel
mkdir ../work/kernel
tar -xvf $LINUX_ARCHIVE_FILE -C ../work/kernel
cd ..
cd work/kernel
cd $(ls -d *)
make mrproper
make defconfig
sed -i "s/.*CONFIG_DEFAULT_HOSTNAME.*/CONFIG_DEFAULT_HOSTNAME=\"$HOSTNAME\"/" .config
make bzImage -j $(grep ^processor /proc/cpuinfo | wc -l)
make headers_install

# GLIBC

GLIBC_ARCHIVE_FILE="glibc-2.23.tar.xz"
cd $PROJ_DIR
cd source
if [ ! -f "$GLIBC_ARCHIVE_FILE" ]; then
  wget "http://ftp.gnu.org/gnu/libc/glibc-2.23.tar.xz"
fi
rm -rf ../work/glibc
mkdir ../work/glibc
tar -xvf $GLIBC_ARCHIVE_FILE -C ../work/glibc
cp -r ./selinux ../work/glibc/glibc-2.23/include/
cd ..
cd work/kernel
cd $(ls -d *)
WORK_KERNEL_DIR=$(pwd)
cd ../../..
cd work/glibc
cd $(ls -d *)
rm -rf ./glibc_objects
mkdir glibc_objects
rm -rf ./glibc_installed
mkdir glibc_installed
cd glibc_installed
GLIBC_INSTALLED=$(pwd)
cd ../glibc_objects
../configure --prefix= --with-headers=$WORK_KERNEL_DIR/usr/include --disable-werror
make -j $(grep ^processor /proc/cpuinfo | wc -l)
make install DESTDIR=$GLIBC_INSTALLED -j $(grep ^processor /proc/cpuinfo | wc -l)
cd $GLIBC_INSTALLED
mkdir -p usr
cd usr
unlink include 2>/dev/null
ln -s ../include include
unlink lib 2>/dev/null
ln -s ../lib lib
cd ../include
unlink linux 2>/dev/null
ln -s $WORK_KERNEL_DIR/usr/include/linux linux
unlink asm 2>/dev/null
ln -s $WORK_KERNEL_DIR/usr/include/asm asm
unlink asm-generic 2>/dev/null
ln -s $WORK_KERNEL_DIR/usr/include/asm-generic asm-generic
unlink mtd 2>/dev/null
ln -s $WORK_KERNEL_DIR/usr/include/mtd mtd

# BUSYBOX

BUSYBOX_ARCHIVE_FILE="busybox-1.27.1.tar.bz2"
cd $PROJ_DIR
cd source
if [ ! -f "$BUSYBOX_ARCHIVE_FILE" ]; then
  wget "http://busybox.net/downloads/busybox-1.27.1.tar.bz2"
fi
rm -rf ../work/busybox
mkdir ../work/busybox
tar -xvf $BUSYBOX_ARCHIVE_FILE -C ../work/busybox
cd ..
cd work/busybox
cd $(ls -d *)
make distclean
make defconfig
GLIBC_INSTALLED_ESCAPED=$(echo \"$GLIBC_INSTALLED\" | sed 's/\//\\\//g')
sed -i "s/.*CONFIG_SYSROOT.*/CONFIG_SYSROOT=$GLIBC_INSTALLED_ESCAPED/" .config
sed -i "s/.*CONFIG_INETD.*/CONFIG_INETD=n/" .config
make busybox -j $(grep ^processor /proc/cpuinfo | wc -l)
make install

# ROOTFS

cd $PROJ_DIR
cd work
rm -rf rootfs
cd busybox
cd $(ls -d *)
cp -R _install ../../rootfs           # Copy busy box stuff to initramfs folder
cd ../../rootfs
rm -f linuxrc                         # Remove 'linuxrc' which is used when we boot in 'RAM disk' mode. 
mkdir dev                             # Create root FS folders.
mkdir etc
mkdir lib
mkdir proc
mkdir root
mkdir src
mkdir sys
mkdir tmp
chmod 1777 tmp
# Copy all source files to '/src'. Note that the scripts won't work there.
cp ../../*.sh src
cp ../../.config src
cp ../../*.txt src
chmod +rx src/*.sh
chmod +r src/.config
chmod +r src/*.txt
# This is the dynamic loader. The file name is different for 32-bit and 64-bit machines.
cp $GLIBC_INSTALLED/lib/ld-linux* ./lib
# BusyBox has direct dependencies on these libraries.
cp $GLIBC_INSTALLED/lib/libm.so.6 ./lib
cp $GLIBC_INSTALLED/lib/libc.so.6 ./lib
# These libraries are necessary for the DNS resolving.
cp $GLIBC_INSTALLED/lib/libresolv.so.2 ./lib
cp $GLIBC_INSTALLED/lib/libnss_dns.so.2 ./lib
# Make sure the dynamic loader is visible on 64-bit machines.
ln -s lib lib64
cd ../..
# Copy the rootfs overlay
cp -r ./rootfs_overlay/* work/rootfs/
cd work
rm -f rootfs.cpio.gz
cd rootfs
find . | cpio -R root:root -H newc -o | gzip > ../rootfs.cpio.gz
cd ../..

# GENERATE ISO

cd work/kernel
cd $(ls -d *)
WORK_KERNEL_DIR=$(pwd)
cd ../../..
# Remove the old ISO file if it exists.
rm -f $ISO_FILENAME
# Remove the old ISO generation area if it exists.
rm -rf work/isoimage
# This is the root folder of the ISO image.
mkdir work/isoimage
cd work/isoimage
# Search and copy the files 'isolinux.bin' and 'ldlinux.c32'
cp ../../source/ISOLINUX/isolinux.bin .
cp ../../source/ISOLINUX/ldlinux.c32 .
# Now we copy the kernel.
cp $WORK_KERNEL_DIR/arch/x86/boot/bzImage ./kernel.bz
# Now we copy the root file system.
cp ../rootfs.cpio.gz ./rootfs.gz
# Copy all source files to '/src'. Note that the scripts won't work there.
mkdir src
cp ../../*.sh src
cp ../../.config src
cp ../../*.txt src
chmod +rx src/*.sh
chmod +r src/.config
chmod +r src/*.txt
# Create ISOLINUX configuration file.
echo 'default kernel.bz  initrd=rootfs.gz' > ./isolinux.cfg
# Now we generate the ISO image file.
genisoimage -J -r -o ../$ISO_FILENAME -b isolinux.bin -c boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table ./
# This allows the ISO image to be bootable if it is burned on USB flash drive.
isohybrid ../$ISO_FILENAME 2>/dev/null || true
# Copy the ISO image to the root project folder.
cp ../$ISO_FILENAME ../../
cd ../..
isohybrid $ISO_FILENAME
ln -s $ISO_FILENAME linux.iso
echo
echo "All done"

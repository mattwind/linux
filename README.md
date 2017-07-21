
# Linux

Build your own custom live linux installation and run it on a USB stick. 

Run the `build.sh` script to generate the ISO file, takes about 30 minutes to compile everything on a quad core system.

## Compiled from source

* Linux 4.12.2
* Glibc 2.23
* Busybox 1.27.1

# Overlay

Files inside `rootfs_overlay` will be copied to the rootfs during the build process. You can use this folder to add cross-compiled binaries and scripts.

## Notes

If you are building on a Debian system `apt-get install build-essential`

Compiling from source `make DESTDIR=/patch/to/rootfs_overlay install`

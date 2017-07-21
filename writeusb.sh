#!/bin/sh

echo
echo "Wait! This will overwrite /dev/sdb device."
echo "Be really warned!"
echo
read -p "Continue (y/n)?" choice
case "$choice" in 
  y|Y )
  echo "write"
  sudo dd if=linux.iso of=/dev/sdb
  sync
  sudo fdisk /dev/sdb
  sync
  exit 1
  ;;
  n|N )
  echo "Okay bye"
  exit 1
  ;;
  * ) echo "invalid";;
esac


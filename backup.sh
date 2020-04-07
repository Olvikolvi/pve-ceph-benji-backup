#!/bin/bash

. $(pwd)/ceph.sh

get_disk () {
  # Limit to first 20 lines to hopefully avoid including snapshot images
  # Convert template clone names to rbd names   ie: rbd_hdd:base-116-disk-0/vm-117-disk-0 -> rbd_hdd/vm-117-disk-0
  # Convert vm disk names to rbd names          ie: rbd_hdd:vm-103-disk-0                 -> rbd_hdd/vm-103-disk-0
  for vmconf in /etc/pve/nodes/*/qemu-server/$1.conf; do
    head -n 20 $vmconf | grep size | grep -v 'backup=0' | perl -pe 's/^\S+ (.*?):(.*?),.*/\1\/\2/g;s/(.*)\/.*(\/.*)/\1\2/g;' | uniq;
  done
}

network_ceph_backup () {
  name=`grep name /etc/pve/nodes/*/qemu-server/$1.conf | head -n 1 | perl -pe 's/.*name:\s+(.*)/\1/g'`;
  num=0;
  for disk in `get_disk $1`; do
    #[ $disk == "rbd_ssd/vm-130-disk-2" ] && continue;  # vivotek-vast2 - video recordings (skip)
    IFS='/' read pool image <<< $disk;
    if [ "$pooll" == "ceph-odroid" ]; then
      export CONF="/etc/ceph/ceph.odroid.conf"
      export IO="rbdodroid"
    else
      continue
    fi
    benji::backup::ceph "$name""-disk$num" "$pool" "$image" "AutomatedBackup";
    let "num++";
  done
}

# Backup appliances:
for f in /etc/pve/nodes/*/qemu-server/*.conf; do
#  if [ `grep -Pc 'name:.*(-mikrotik|zatjnb|sip|unix|checkpoint)' $f` -gt 0 ]; then
    f=${f#/etc/*/qemu-server/};
    f=${f%.conf};
    network_ceph_backup $f;
#  fi;
done

benji ls 2> /dev/null | grep incomplete | awk '{print $4}' | xargs -r benji rm -f;

benji batch-deep-scrub -P 15;

benji enforce latest3,hours48,days7,weeks4,months3;
benji cleanup;

exit


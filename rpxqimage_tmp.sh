#!/bin/sh
#

cd $(dirname $0)
trap "set +e; rm -f ${1:-rpxqimage_tmp.tar.xz}; rm -f $(basename $0);" EXIT

work_dir="/tmp/rpxqimage_tmp_workdir"
rootfs_rw_dir="$work_dir/merged"
rootfs_ro_dir="$work_dir/lower"
rootfs_env="$work_dir/upper"
proc_empty="$work_dir/empty"

set -e

mkdir "$work_dir"
mount -t tmpfs tmpfs "$work_dir"

mkdir -p "$rootfs_ro_dir" "$rootfs_env" "$rootfs_rw_dir" "$work_dir/work" "$proc_empty"
tar -xJf "${1:-rpxqimage_tmp.tar.xz}" -C "$rootfs_env"

LD_LIBRARY_PATH=$rootfs_env/usr/lib
export LD_LIBRARY_PATH

squasf_dev="$(cat /proc/mtd | grep ubi_rootfs)"
squasf_dev="/dev/${squasf_dev%:*}"
eval "$rootfs_env/usr/bin/squashfuse $squasf_dev $rootfs_ro_dir"
mount -t overlay overlay -o lowerdir="$rootfs_ro_dir",upperdir="$rootfs_env",workdir="$work_dir/work" "$rootfs_rw_dir"
[ -d "/proc/$(pidof squashfuse)" ] && mount --bind "$proc_empty" "/proc/$(pidof squashfuse)"

[ -z "$(cat $rootfs_ro_dir/bin/flash.sh | grep rpxqimage)" ] && cp -fp "$rootfs_ro_dir/bin/flash.sh" "$rootfs_rw_dir/bin/flash_do_upgrade.sh"
[ -z "$(cat $rootfs_ro_dir/bin/mkxqimage | grep rpxqimage)" ] && cp -fp "$rootfs_ro_dir/bin/mkxqimage" "$rootfs_rw_dir/bin/mkxqimage.elf"
while IFS= read -r dir_path
do
	mount --bind "$rootfs_rw_dir/$dir_path" "$dir_path"
done << END
/bin
/sbin
/usr/bin
/usr/sbin
/usr/lib
END

exit 0

######END######
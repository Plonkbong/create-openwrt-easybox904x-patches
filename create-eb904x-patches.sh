#!/bin/sh

# if git not configured do it first:
# git config --global user.email "you@example.com"; git config --global user.name "Your Name"

CWD=$(pwd)
DATE=$(date +%Y.%m.%d)
BUILD_D=/mnt/mapper/sda3/build
RESULT_ROOT="$CWD/result-eb904x-patches"
RESULT_D="$RESULT_ROOT"

PATCHES_D="$BUILD_D/create_patches"
OWRT_COMMIT=master
#OWRT_COMMIT=v18.06.1



# rm -rf "$PATCHES_D"

test -d "$PATCHES_D" || mkdir -p "$PATCHES_D"
cd "$PATCHES_D"
test -d openwrt_orig ||		{ git clone https://git.openwrt.org/openwrt/openwrt.git openwrt_orig; }
test -d Easybox-904-XDSL || 	{ git clone https://github.com/Quallenauge/Easybox-904-XDSL.git; cd ./Easybox-904-XDSL; git checkout master-lede; \
git remote add openwrt https://git.openwrt.org/openwrt/openwrt.git; git fetch openwrt; git checkout -b master; git pull openwrt master; \
cd ..; \
}
read

cd ./openwrt_orig; git checkout $OWRT_COMMIT; cd ..;

rm -r ./patches_info; mkdir -p ./patches_info
diff -x .git -x .github -aurN openwrt_orig/target/linux/generic/files/drivers/net/phy		Easybox-904-XDSL/target/linux/generic/files/drivers/net/phy > ./patches_info/generic_files_drivers_net_phy.diff
diff -x .git -x .github -aurN openwrt_orig/target/linux/lantiq/patches-4.14 			Easybox-904-XDSL/target/linux/lantiq/patches-4.14 > ./patches_info/lantiq_patches-4.14.diff
diff -x .git -x .github -aurN openwrt_orig/target/linux/lantiq/files-4.14/arch/mips/boot/dts 	Easybox-904-XDSL/target/linux/lantiq/files-4.14/arch/mips/boot/dts > ./patches_info/lantiq_files-4.14_arch_mips_boot_dts.diff
diff -x .git -x .github -aurN openwrt_orig/target/linux/lantiq/base-files 			Easybox-904-XDSL/target/linux/lantiq/base-files > ./patches_info/lantiq_base-files.diff
diff -x .git -x .github -aurN openwrt_orig/target/linux/lantiq/image 				Easybox-904-XDSL/target/linux/lantiq/image > ./patches_info/lantiq_image.diff
diff -x .git -x .github -aurN openwrt_orig/target/linux/lantiq/xrx200 				Easybox-904-XDSL/target/linux/lantiq/xrx200 > ./patches_info/lantiq_xrx200.diff


rm -rf ./openwrt_modified; git clone ./openwrt_orig openwrt_modified; cd ./openwrt_modified; git checkout $OWRT_COMMIT; git checkout -b eb904x-patch-for-$OWRT_COMMIT-$DATE; cd ..;

#### main ####
rm -r ./patches_tmp; mkdir -p ./patches_tmp

p=lantiq/files-4.14/arch/mips/boot/dts/VGV952CJW33-E-IR.dts
cat ./Easybox-904-XDSL/target/linux/$p \
| sed s/"nand-on-flash-bbt;"/"nand-on-flash-bbt;\n\t\tcustomized-samsung-K9F4G08U0x;"/g \
> ./openwrt_modified/target/linux/$p


p=lantiq/image/Makefile;
diff -x .git -x .github -aurN openwrt_orig/target/linux/$p Easybox-904-XDSL/target/linux/$p	> ./patches_tmp/lantiq_image_Makefile.patch
cd ./openwrt_modified
patch -p1 < ../patches_tmp/lantiq_image_Makefile.patch
cd ..

p=lantiq/patches-4.14/4027-NET-MIPS-lantiq-support-fixed-link.patch; 	cp -a ./Easybox-904-XDSL/target/linux/$p ./openwrt_modified/target/linux/$p
p=lantiq/patches-4.14/4028-NET-MIPS-lantiq-add-FID-setting.patch; 	cp -a ./Easybox-904-XDSL/target/linux/$p ./openwrt_modified/target/linux/$p
p=lantiq/patches-4.14/4050-MIPS-lantiq-EBU-set_buscon_params.patch; 	cp -a ./Easybox-904-XDSL/target/linux/$p ./openwrt_modified/target/linux/$p
#p=lantiq/patches-4.14/4052-NAND-add-easybox904-bbt.patch; 		cp -a ./Easybox-904-XDSL/target/linux/$p ./openwrt_modified/target/linux/$p
cp -a "$CWD/files/4052-NAND-add-easybox904-bbt-byDTS.patch" ./openwrt_modified/target/linux/lantiq/patches-4.14/4052-NAND-add-easybox904-bbt-byDTS.patch
p=lantiq/patches-4.14/4053-NET-reactivate-ndo_do_ioctl-fallback.patch; 	cp -a ./Easybox-904-XDSL/target/linux/$p ./openwrt_modified/target/linux/$p
p=lantiq/patches-4.14/4055-NET-rtl8367b-wait-for-mdio-bus.patch;	cp -a ./Easybox-904-XDSL/target/linux/$p ./openwrt_modified/target/linux/$p
p=lantiq/patches-4.14/4056-MTD-nand_samsung_disable_subpage_writes_on_21nm_NAND.patch; cp -a ./Easybox-904-XDSL/target/linux/$p ./openwrt_modified/target/linux/$p



##### base-files ####



p=lantiq/base-files/etc/uci-defaults/80_wifi_setup;			cp -a ./Easybox-904-XDSL/target/linux/$p ./openwrt_modified/target/linux/$p
p=lantiq/base-files/lib/preinit/06_init_network_lantiq;			cp -a ./Easybox-904-XDSL/target/linux/$p ./openwrt_modified/target/linux/$p
p=lantiq/base-files/lib/preinit/85_reset_watchdog_timer_lantiq;		cp -a ./Easybox-904-XDSL/target/linux/$p ./openwrt_modified/target/linux/$p

diff -x .git -x .github -aurN openwrt_orig/target/linux/lantiq/base-files/etc/board.d/02_network	Easybox-904-XDSL/target/linux/lantiq/base-files/etc/board.d/02_network	> ./patches_tmp/etc_board.d_02_network.patch
diff -x .git -x .github -aurN openwrt_orig/target/linux/lantiq/base-files/lib/upgrade/platform.sh	Easybox-904-XDSL/target/linux/lantiq/base-files/lib/upgrade/platform.sh	> ./patches_tmp/lib_upgrade_platform.sh.patch
diff -x .git -x .github -aurN openwrt_orig/target/linux/lantiq/base-files/etc/diag.sh			Easybox-904-XDSL/target/linux/lantiq/base-files/etc/diag.sh		> ./patches_tmp/etc_diag.sh.patch
cd ./openwrt_modified
patch -p1 < ../patches_tmp/etc_board.d_02_network.patch
patch -p1 < ../patches_tmp/lib_upgrade_platform.sh.patch
patch -p1 < ../patches_tmp/etc_diag.sh.patch
cd ..



#### packages

psfx=package/network/config/ltq-vdsl-app/files/dsl_control
pfile=$(echo $psfx | tr '/' '_').patch
diff -x .git -x .github -aurN openwrt_orig/$psfx	Easybox-904-XDSL/$psfx > ./patches_tmp/$pfile
cd ./openwrt_modified
patch -p1 < ../patches_tmp/$pfile
cd ..

#####

cd ./openwrt_modified
infotxt=""; infotxt="$(cat "$CWD/files/patchinfo-main.txt")"
test -z "$infotxt" && infotxt="add support for Arcadyan/Astoria VGV952CJW33-E-IR aka Vodafon Easybox-904xDSL
It base on Quallenauge git from here https://github.com/Quallenauge/Easybox-904-XDSL"
git add -A .; git commit -s -m "$infotxt"; git status
test -d "$RESULT_D" || { mkdir -p "$RESULT_D"; chmod 0755" $RESULT_D"; }
git format-patch -1 --stdout > "$RESULT_D/add-eb904x-support-for-$OWRT_COMMIT-$DATE.patch"
cd ..

#####


psfx=package/boot/uboot-envtools/files/lantiq
pfile=$(echo $psfx | tr '/' '_').patch
diff -x .git -x .github -aurN openwrt_orig/$psfx	Easybox-904-XDSL/$psfx > ./patches_tmp/$pfile
cd ./openwrt_modified
patch -p1 < ../patches_tmp/$pfile
cd ..

cp -a ./Easybox-904-XDSL/package/boot/uboot-lantiq-easybox904xdsl ./openwrt_modified/package/boot

cd ./openwrt_modified
infotxt=""; infotxt="$(cat "$CWD/files/patchinfo-uboot.txt")"
test -z "$infotxt" && infotxt="add UBoot support for Arcadyan/Astoria VGV952CJW33-E-IR aka Vodafon Easybox-904xDSL
It base on Quallenauge git from here https://github.com/Quallenauge/Easybox-904-XDSL"
git add -A .; git commit -s -m "$infotxt"; git status
test -d "$RESULT_D" || { mkdir -p "$RESULT_D"; chmod 0755" $RESULT_D"; }
git format-patch -1 --stdout > "$RESULT_D/add-uboot-for-eb904x-support-for-$OWRT_COMMIT-$DATE.patch"
cd ..


exit 0


















#!/bin/sh

# git config --global user.email "you@example.com"; git config --global user.name "Your Name"

EOL="
"
CWD=$(pwd)
DATE=$(date +%Y.%m.%d)
BUILD_D=/mnt/mapper/sda3/build
RESULT_ROOT="$CWD/result-eb904x-patches"
PATCHES_D="$BUILD_D/create_patches"
#PATCHES_D="$CWD"

OWRT_COMMIT=master
#OWRT_COMMIT=0dbdb476f3d4b21e6a3b95b596b56bf8f9bae948 # bump kernel to 4.14.71 20.09.2018

EB_V=6746686-2019.01.30
EB_V_LIST_ALL="
fa8e9a8-2018.10.26
18cddf8-2018.11.21
fbb617f-2018.11.23
53a469d-2018.11.29
5a13ea6-2018.12.05
556b8ac-2018.12.15
6746686-2019.01.30
"

for e in $EB_V_LIST_ALL; do
	if test -z "${EB_V_LIST}"; then 
		EB_V_LIST="$e"
	else
		EB_V_LIST="${EB_V_LIST}${EOL}$e"
	fi
	test "$e" == "$EB_V" && break;
done






# rm -rf "$PATCHES_D"

test -d "$PATCHES_D" || mkdir -p "$PATCHES_D"
cd "$PATCHES_D"

if ! test -d ./openwrt-orig; then
	git clone https://github.com/openwrt/openwrt.git openwrt-orig
fi
if ! test -d ./Easybox-904-XDSL-orig; then
	git clone https://github.com/Quallenauge/Easybox-904-XDSL.git Easybox-904-XDSL-orig
fi



cd "$CWD"

rm -r ./openwrt-with-eb904x
git clone "$PATCHES_D/openwrt-orig" openwrt-with-eb904x
cd ./openwrt-with-eb904x
git remote add QAuge-eb904x "$PATCHES_D/Easybox-904-XDSL-orig"
git fetch QAuge-eb904x
git checkout -b eb904x $OWRT_COMMIT



OWRT_COMMIT=$(git log -n1 | grep commit | cut -d' ' -f2)
OWRT_DATE=$(date -u -d "$(git log -n1 | grep Date | cut -d':' -f2-5 | cut -d+ -f1)" +%Y.%m.%d)
OWRT_V=${OWRT_COMMIT:0:7}-$OWRT_DATE
RESULT_D="$RESULT_ROOT/patches-owrt-${OWRT_V}_eb-${EB_V}"
UNBUND_RESULT_D="$RESULT_D/unbundle"

rm -r "$RESULT_D" 2> /dev/null
test -d "$RESULT_D" || { mkdir -p "$RESULT_D"; chmod 0755" $RESULT_D"; }
rm -r "$UNBUND_RESULT_D" 2> /dev/null
test -d "$UNBUND_RESULT_D" || { mkdir -p "$UNBUND_RESULT_D"; chmod 0755" $UNBUND_RESULT_D"; }









# Image
img_num=0
if echo "$EB_V_LIST" | grep -o "fa8e9a8-2018.10.26"; then
	git cherry-pick 9f83f9fd04db011cd689c1254a2caf9d232e89a7 || exit 1 # image: VGV952CJW33-E-IR: Add dts for VGV952CJW33-E-IR. / target/linux/lantiq/files-4.14/arch/mips/boot/dts/VGV952CJW33-E-IR.dts
	git cherry-pick fa8e9a88891841f6b4a35296315db68526cde2f1 || exit 1 # image: VGV952CJW33-E-IR: Wait until mdio bus appears. / target/linux/lantiq/files-4.14/arch/mips/boot/dts/VGV952CJW33-E-IR.dts
	git cherry-pick 0b6120dcb0ed73b4d51ba3e497b9775428c35adf || exit 1 # image: VGV952CJW33-E-IR: Add image generation configuration. / Makefile target/linux/lantiq/image/Makefile  target/linux/lantiq/image/eb904.mk
	git cherry-pick d96de31a3439084a8f66f4bb9f16871c5704cb7c || { \
	sed s/"^<<<<<<<.*"/"# <<<<<<<"/g -i package/base-files/files/lib/upgrade/nand.sh; \
	sed s/"^=======.*"/"# ======="/g -i package/base-files/files/lib/upgrade/nand.sh; \
	sed s/"^>>>>>>>.*"/"# >>>>>>>"/g -i package/base-files/files/lib/upgrade/nand.sh; \
	git add package/base-files/files/lib/upgrade/nand.sh; \
	git cherry-pick --continue || exit 1; \
	} # image: VGV952CJW33-E-IR: Sysupgrade: Deactivate subpages on nand. / target/linux/lantiq/base-files/lib/upgrade/platform.sh does not work because package/base-files/files/lib/upgrade/nand.sh
	img_num=$(($img_num + 4))
fi
if echo "$EB_V_LIST" | grep -o "18cddf8-2018.11.21"; then
	git cherry-pick 83aab1c44349a06397c461b7611ac16808cece3d || exit 1 # image: Use standard kernel params, no vpe, no UBI
	git cherry-pick aa07a71e7136c8a7ec18e88ea4b487baeccb0bb2 || exit 1 # image: Avoid using device specific eb904.mk for building the images
	git cherry-pick 5455621a91a2e90ce79587f9b34070dfca996535 || exit 1 # image: Remove obsolete eb904.mk 
	git cherry-pick 18cddf8148b14f3f11b02bedab379498f8449724 || exit 1 # image: Use partition 'ubi' (mtd12) for rootfs and rootfs_data; use 512 UBI s…
	img_num=$(($img_num + 4))
fi
if echo "$EB_V_LIST" | grep -o "fbb617f-2018.11.23"; then
	git cherry-pick fbb617f3387390c6bcc2d43dcd72bd13737afe42 || exit 1 # Add .dts entries to make second USB port work
	img_num=$(($img_num + 1))
fi
if echo "$EB_V_LIST" | grep -o "53a469d-2018.11.29"; then
	git cherry-pick ece99ec209aaf1113b9723bc2240df93bbfe4dde
	git rm vr9_default.config
	git cherry-pick --continue || exit 1 #  Add gpio-spi driver for 74hc595 pin extender.
	git cherry-pick 9d8cedc49f262c64837dc6c69d0016d55118ae87 || exit 1 # Add DSL relays handling
	git cherry-pick d7edc7f0ced5354c5f364c45667374c91b8f1f8d || exit 1 # Add pin definition into stop function
	git cherry-pick 53a469dc8386c92e85da917cf05cdb1321ee4de6 || exit 1 # Fix LED activity level specification in .dts file
	img_num=$(($img_num + 4))
fi
if echo "$EB_V_LIST" | grep -o "556b8ac-2018.12.15"; then
	git cherry-pick 556b8ac0079dad023ba89493cbf1dd36d715a829 || exit 1 # Add missing space in file /etc/init.d/dsl_control
	img_num=$(($img_num + 1))
fi
if echo "$EB_V_LIST" | grep -o "6746686-2019.01.30"; then
	git cherry-pick 9346b8f5a11d1a29b81e9f8d54f159c669e9725a || exit 1 # VGV952CJW33-E-IR: DTS: Whitespace format change (cosmetic only)
	git cherry-pick 674668605210442b5347d3e7ae8771cd5eedb368 || exit 1 # VGV952CJW33-E-IR: DTS: Fix dts definition for display.
	img_num=$(($img_num + 2))
fi
git format-patch -$img_num --stdout > "$UNBUND_RESULT_D/add-device-VGV952CJW33-E-IR-adding-image.patch"





# Kernelpatches
kpatch_num=0
if echo "$EB_V_LIST" | grep -o "fa8e9a8-2018.10.26"; then
	git cherry-pick a2bd152f41d9e0330b604899578904a5cd6dc074 || exit 1 # kpatch: VGV952CJW33-E-IR: Add support for fixed-link definition.
	git cherry-pick e6b7e5b4920b8667fd347e2980a69a16e69cc3f3 || exit 1 # kpatch: VGV952CJW33-E-IR: lantiq/xrx200-net: add FID (filtering identifier) s…
	git cherry-pick 41e4cb1d70a4d7c2b9c634511d434dc0586dae8e || exit 1 # kpatch: VGV952CJW33: Add buscon2 and addrsel2 parameters, taken from vendor f… 
	git cherry-pick a6161b26d0c39ed3f0e4216fa0ba57cb0157f73c || exit 1 # kpatch: VGV952CJW33-E-IR: Add bad block table implementation. 
	git cherry-pick 1e18a856f5d7573cda57f378217166a8a819e98d || exit 1 # kpatch: VGV952CJW33-E-IR: Revert "wireless: wext: remove ndo_do_ioctl
	kpatch_num=$(($kpatch_num + 5))
fi
if echo "$EB_V_LIST" | grep -o "5a13ea6-2018.12.05"; then
	git cherry-pick 308e0c2d1a5a416e9dde31cd887f32305b4b0f44 || exit 1 # VGV952CJW33-E-IR: mtd: nand: samsung: Disable subpage writes on 21nm …
	kpatch_num=$(($kpatch_num + 1))
fi
if echo "$EB_V_LIST" | grep -o "6746686-2019.01.30"; then
	git cherry-pick 026194c601548f929c8073cc30b6c15bd3ff5a39 || exit 1 # VGV952CJW33-E-IR: Move driver specific ebu setup to driver
	kpatch_num=$(($kpatch_num + 1))
fi
git format-patch -$kpatch_num --stdout > "$UNBUND_RESULT_D/add-device-VGV952CJW33-E-IR-adding-Kernelpatches.patch"




# basefiles
basefile_num=0
if echo "$EB_V_LIST" | grep -o "fa8e9a8-2018.10.26"; then
	git cherry-pick d05e61becc856a89b343901ade83492b35f05252 || exit 1 # base-files: VGV952CJW33-E-IR: Add preinit network initialization code.
	git cherry-pick 1a2285ee614e39ff65142dd094692e3f203b9947 || exit 1 # base-files: VGV952CJW33-E-IR: Reimplement recovery watchdog for vendor uboot. 
	git cherry-pick 2df2ebb609fecbc1c2b944f2a057988a0c21d702 || exit 1 # base-files: VGV952CJW33-E-IR: Improve default wifi switch network config. 
	git cherry-pick dd3bae0463fd32d6d0c98cf8a7d2de1d71e2429f || exit 1 # base-files: VGV952CJW33-E-IR: Bring up network default configuration.
	basefile_num=$(($basefile_num + 4))
fi
git format-patch -$basefile_num --stdout > "$UNBUND_RESULT_D/add-device-VGV952CJW33-E-IR-adding-basefiles.patch"

rm -v ./target/linux/lantiq/patches-4.14/4052-NAND-add-easybox904-bbt.patch || exit 1
cp -vf "$CWD/files/4052-NAND-add-easybox904-bbt-byDTS.patch" ./target/linux/lantiq/patches-4.14/4052-NAND-add-easybox904-bbt-byDTS.patch || exit 1
git add -A .
git commit -s -m "change patch 4052-* easybox904 BBT now by DTS

add code that detect by DTS if the special easybox-904 BBT are required.
Now it called 4052-NAND-add-easybox904-bbt-byDTS.patch"

p=lantiq/files-4.14/arch/mips/boot/dts/VGV952CJW33-E-IR.dts
sed s/"nand-on-flash-bbt;"/"nand-on-flash-bbt;\n\t\tcustomized-samsung-K9F4G08U0x;"/g -i ./target/linux/$p
git add -A .
git commit -s -m "change DTS, add string for NAND-bbt

add the line \"customized-samsung-K9F4G08U0x;\" to VGV952CJW33-E-IR.dts
Needed by patch 4052-NAND-add-easybox904-bbt-byDTS.patch"


git format-patch -$(($basefile_num + $kpatch_num + $img_num + 1)) --stdout > "$RESULT_D/add-Arcadyan-VGV952CJW33-E-IR_owrt-${OWRT_V}_eb-${EB_V}.patch"





# UBOOT
uboot_num=0
if echo "$EB_V_LIST" | grep -o "fa8e9a8-2018.10.26"; then
	git cherry-pick ce1083f654f7bf80c7688b271e832bfd61094237 || exit 1 # uboot: VGV952CJW33-E-IR: Add MTD parition details for uboot-env-tools. / package/boot/uboot-envtools/files/lantiq
	git cherry-pick 816d14b22e19617104322ecfced1c55e3760103f || exit 1 # uboot: VGV952CJW33-E-IR: Include vendor uboot-implementation. /  package/boot/uboot-lantiq-easybox904xdsl/Makefile
	uboot_num=$(($uboot_num + 2))
fi
if echo "$EB_V_LIST" | grep -o "18cddf8-2018.11.21"; then
	git cherry-pick c9603c983529fb9db1e80bc0ccdeae98bd8e31e9 || exit 1 # uboot: Set recommended values for eb904 as default values for U-Boot
	git cherry-pick 6e827c5811df9131fda96a6f6e6d61ad1bfc4ff5 || exit 1 # uboot: Add enhancements to u-boot-for-Easybox904
	git cherry-pick ab84d2857d944f97e8c7237f2f0410d647436eac || exit 1 # uboot: Refactured the package Makefile so it is closer to OpenWrt standards 
	git cherry-pick 8a6076cb6d952c9aa7ace48a9b4ca266238c7c48 || exit 1 # uboot: uboot-lantiq-eb904: Fix i.e. increase load address of recovery image
	git cherry-pick 32f1db68dffcc9e4bba856f8d2985c6bd3c67c6d || exit 1 # uboot: Replaced patch 610 by a version which can boot different formats of
	uboot_num=$(($uboot_num + 5))
fi
git format-patch -$uboot_num --stdout > "$UNBUND_RESULT_D/add-device-VGV952CJW33-E-IR-adding-uboot.patch"

git format-patch -$uboot_num --stdout > "$RESULT_D/add-uboot-for-Arcadyan-VGV952CJW33-E-IR_owrt-${OWRT_V}_eb-${EB_V}.patch"




git checkout -b eb904x-incl-not-used



# Not used
notused_num=0
if echo "$EB_V_LIST" | grep -o "fa8e9a8-2018.10.26"; then
	git cherry-pick 65c86177991f11692b5c8a4e65b068c79bf9a8bf || exit 1 # VGV952CJW33-E-IR: Add recovery configuration.
	git cherry-pick 744e6d57dd2d2de1071e2ba7e1d5ebe7a10c73a1 || exit 1 # VGV952CJW33-E-IR: Display: Turn off display at boot.
	git cherry-pick dc319e3a9f7d24e3381c128716fe94fc893e96bd || exit 1 # rpcd: Use proper staging include dir.
	git cherry-pick d86d812d3d83df7dd099210fecbaaac312e6cbc6 || exit 1 # VGV952CJW33-E-IR: Add device specific feed. 
	git cherry-pick a7c4343b7f517b5a9d3aa0da7a014fe794ce7177 || exit 1 # VGV952CJW33-E-IR: Provide a branch update script.
	git cherry-pick 8623c12d794bd099a4c07fcb37b12365ad4cc801 || exit 1 # VGV952CJW33-E-IR: Updated readme.
	git cherry-pick 235ad64574c43e9e8d5bd2ee747edf9133dfb210 || exit 1 # VGV952CJW33-E-IR: Add default config.
	git cherry-pick da15f8497d99f02a2e0f2834920129a60cd94383 || exit 1 # Update README.md
	notused_num=$(($notused_num + 8))
fi
if echo "$EB_V_LIST" | grep -o "5a13ea6-2018.12.05"; then
	git cherry-pick 5a13ea66792eba5a524deb986e9eede86a1fde39 || exit 1 # VGV952CJW33-E-IR: config: Refresh recovery configuration.
	notused_num=$(($notused_num + 1))
fi
# files to remove:  ./recovery.cfg  ./vr9_default.config ./feeds.conf.default  ./README.md ./updateGitRepo.sh
# revert patch for ./package/system/rpcd/Makefile
git format-patch -$notused_num --stdout > "$UNBUND_RESULT_D/add-device-VGV952CJW33-E-IR-adding-not-used-files.patch"

git format-patch -$(($basefile_num + $kpatch_num + $img_num + $notused_num)) 	--stdout > "$UNBUND_RESULT_D/add-Arcadyan-VGV952CJW33-E-IR-incl-not-need.patch"





revert_num=0
#git revert dc319e3a9f7d24e3381c128716fe94fc893e96bd
#rm ./recovery.cfg  ./vr9_default.config ./feeds.conf.default  ./README.md ./updateGitRepo.sh
#git add -A .
#git commit -s -m "remove non openwrt reposatory files"
revert_num=$(($revert_num + 0))

git format-patch -$(($basefile_num + $kpatch_num + $img_num + $notused_num + $uboot_num + $revert_num)) --stdout > "$UNBUND_RESULT_D/add-device-VGV952CJW33-E-IR-all.patch"






exit 0

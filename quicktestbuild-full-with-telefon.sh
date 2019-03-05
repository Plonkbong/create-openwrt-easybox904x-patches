#!/bin/sh

git config --global user.email "you@example.com"; git config --global user.name "Your Name"

CWD=$(pwd)
BUILD_ROOT=/opt/build
CFGSEED="$CWD/files/eb904x-with-usb-with-telefon-no-smp-config.seed"
#PDATE=2019.02.28
PDATE=$(find "$CWD/result-eb904x-patches" | grep "add-eb904x-support-for-master*" | sort | tail -n1 | rev | cut -d- -f1 | cut -d. -f2-4 | rev)
BASE_PATCH_PATH="$CWD/result-eb904x-patches/add-eb904x-support-for-master-$PDATE.patch"
UBOOT_PATCH_PATH="$CWD/result-eb904x-patches/add-uboot-for-eb904x-support-for-master-$PDATE.patch"
DL_DIR=/opt/openwrt-source-dl
OWRT_DN=eb904_ft

########

cd "$BUILD_ROOT" || exit 1
sudo rm -r ./$OWRT_DN || rm -r ./$OWRT_DN 
test -d ./$OWRT_DN && exit 1

git clone https://git.openwrt.org/openwrt/openwrt.git $OWRT_DN
cd $OWRT_DN
git checkout master

rm -r ./dl; ln -sv "$DL_DIR" dl

git am < "$BASE_PATCH_PATH" || patch -p1 < "$BASE_PATCH_PATH" || exit 1
git am < "$UBOOT_PATCH_PATH" || patch -p1 < "$UBOOT_PATCH_PATH" || exit 1
cp -vf "$CWD/files/video.mk" ./package/kernel/linux/modules/video.mk || exit 1

#rm -v ./target/linux/lantiq/patches-4.14/4052-NAND-add-easybox904-bbt-byDTS.patch || exit 1
#cp -vf "$CWD/files/4052-NAND-add-easybox904-bbt-byDTS-with-a-lot-of-comments.patch" ./target/linux/lantiq/patches-4.14 || exit 1

########

bootargs="console=ttyLTQ0,115200"
smp=""
vpe=" mem=116M phym=128M vpe1_load_addr=0x87e00000 vpe1_mem=2M maxvpes=1 maxtcs=1 nosmp"
mtd=" rootdelay=3"
usb=" root=/dev/sda1 rootdelay=7 rootfstype=f2fs"
bootargs="${bootargs}${vpe}${mtd}"
sed -r s:"^[[:blank:]]*bootargs.*":"\t\tbootargs = \"${bootargs}\";":g -i ./target/linux/lantiq/files-4.14/arch/mips/boot/dts/VGV952CJW33-E-IR.dts

########

cat << EOF > ./feeds.conf

src-git eb904 https://github.com/Quallenauge/lede-feeds-easybox904.git
src-link fix $CWD/files/eb904x-fbtft-feed

EOF
./scripts/feeds update -a
./scripts/feeds install -p eb904 ralink_bin
./scripts/feeds install -p eb904 ralink_inic
./scripts/feeds install -p eb904 touchpad
./scripts/feeds install -p fix fbtft

########

cat "$CFGSEED" > ./.config  || exit 1
make defconfig # expand to full config
make menuconfig
mkdir ./bin
./scripts/diffconfig.sh > ./bin/eb904x-lastconfig.seed

make -j4 V=1 IGNORE_ERRORS=1 || make -j1 V=s IGNORE_ERRORS=1

exit 0

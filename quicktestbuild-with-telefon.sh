#!/bin/sh

git config --global user.email "you@example.com"; git config --global user.name "Your Name"

CWD=$(pwd)
BUILD_ROOT=/opt/build
#CFGSEED="$CWD/../mkscripts/files/eb904x-config.seed"
#CFGSEED="$CWD/eb904x-config.seed"
CFGSEED="$CWD/files/eb904x-with-usb-with-telefon-no-smp-config.seed"
PDATE=2019.02.26
BASE_PATCH_PATH="$CWD/result-eb904x-patches/add-eb904x-support-for-master-$PDATE.patch"
UBOOT_PATCH_PATH="$CWD/result-eb904x-patches/add-uboot-for-eb904x-support-for-master-$PDATE.patch"
DL_DIR=/opt/openwrt-source-dl
OWRT_DN=owrtqb-eb904

cd "$BUILD_ROOT" || exit 1
sudo rm -r ./$OWRT_DN || rm -r ./$OWRT_DN 
test -d ./$OWRT_DN && exit 1

git clone https://git.openwrt.org/openwrt/openwrt.git $OWRT_DN
cd $OWRT_DN
git checkout master

rm -r ./dl; ln -sv "$DL_DIR" dl

git am < "$BASE_PATCH_PATH" || patch -p1 < "$BASE_PATCH_PATH" || exit 1
git am < "$UBOOT_PATCH_PATH" || patch -p1 < "$UBOOT_PATCH_PATH" || exit 1
bootargs="console=ttyLTQ0,115200"
smp=""
vpe=" mem=116M phym=128M vpe1_load_addr=0x87e00000 vpe1_mem=2M maxvpes=1 maxtcs=1 nosmp"
mtd=""
usb=" root=/dev/sda1 rootdelay=7 rootfstype=f2fs"
bootargs="${bootargs}${vpe}${mtd}"
sed -r s:"^[[:blank:]]*bootargs.*":"\t\tbootargs = \"${bootargs}\";":g -i ./target/linux/lantiq/files-4.14/arch/mips/boot/dts/VGV952CJW33-E-IR.dts

cat << EOF > ./feeds.conf

src-git eb904 https://github.com/Quallenauge/lede-feeds-easybox904.git

EOF
./scripts/feeds update -a
./scripts/feeds install -p eb904 ralink_bin
./scripts/feeds install -p eb904 ralink_inic
./scripts/feeds install -p eb904 touchpad

cat << EOF >> ./target/linux/lantiq/xrx200/config-4.14
CONFIG_VGA_CONSOLE=y 
CONFIG_VGACON_SOFT_SCROLLBACK=n 
CONFIG_DUMMY_CONSOLE_COLUMNS=80
CONFIG_DUMMY_CONSOLE_ROWS=25
CONFIG_FRAMEBUFFER_CONSOLE=y
CONFIG_FRAMEBUFFER_CONSOLE_DETECT_PRIMARY=y
CONFIG_FRAMEBUFFER_CONSOLE_ROTATION=y
EOF

cat "$CFGSEED" > ./.config  || exit 1
make defconfig # expand to full config
make menuconfig

make -j4 V=1 IGNORE_ERRORS=1

exit 0

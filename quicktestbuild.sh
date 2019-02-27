#!/bin/sh

git config --global user.email "you@example.com"; git config --global user.name "Your Name"

CWD=$(pwd)
BUILD_ROOT=/opt/build
#CFGSEED="$CWD/../mkscripts/files/eb904x-config.seed"
#CFGSEED="$CWD/eb904x-config.seed"
CFGSEED="$CWD/files/eb904x-smp-no-telefon-config.seed"
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

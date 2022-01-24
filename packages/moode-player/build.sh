#!/bin/bash
#########################################################################
#
# Scripts for building moode packages
#
# (C) bitkeeper 2021 http://moodeaudio.org
# License: GPLv3
#
#########################################################################

. ../../scripts/rebuilder.lib.sh

PKG="moode-player_8.0.0-1moode1pre8"

# PKG_SOURCE_GIT="https://github.com/moode-player/moode.git"
# PKG_SOURCE_GIT_TAG="r760prod"

# For now git isn't used to get the source. During development it is much handier
# to use an already checkout ( and gulp build version of moode )
# The enviroment var MOODE_DIR should be set to the location where the moode project source is.

# sync required npm modules for gulp build
NPM_CI=0
# build web app with gulp
BUILD_APP=0

GULP_BIN=$MOODE_DIR/node_modules/.bin/gulp

# ----------------------------------------------------------------------------
# 1. Prepare pacakge build dir and build deps

# the web app is build with gulp
rbl_check_build_dep npm
# For packign fpm is used, which is created with Ruby
rbl_check_fpm

_rbl_decode_pkg_version
_rbl_check_curr_is_package_dir

#_rbl_cleanup_previous_build
_rbl_change_to_build_root

# location where we build a fakeroot system with the moode file to be package into the package
PKG_ROOT_DIR="$BUILD_ROOT_DIR/root"


# init build root
rm -rf $BUILD_ROOT_DIR/root
mkdir -p $BUILD_ROOT_DIR/root

if [ -z "$MOODE_DIR" ]
then
    echo "${YELLOW}Error: MOODE_DIR is should point to a moode source dir${NORMAL}"
    exit 1
fi


if [ -z "$PKG_ROOT_DIR" ]
then
    echo "${YELLOW}Error: PKG_ROOT_DIR is not set?${NORMAL}"
    exit 1
fi

rm $PKG*.deb
# ----------------------------------------------------------------------------
# 2. Buildweb app an deploy to test directory (prepared for copy)

cd $MOODE_DIR

#TODO: detect if node_modules is missing and if so do both steps
if [[ $NPM_CI -gt 0 ]]
then
    npm ci
fi

if [[ $BUILD_APP -gt 0 ]]
then
    $GULP_BIN clean --all
    $GULP_BIN build
fi
$GULP_BIN deploy --test

cd $BUILD_ROOT_DIR

# ----------------------------------------------------------------------------
# 3. Collect installable files
#
# Collect files for the package in the $PKG_ROOT_DIR
# Some file cannot the directly owned by the package, because it is owned by
# an other package. In this case fles need to be copied after install and are temporaty located in $NOT_OWNED_TEMP.
#
# If it is really required to install an already owned file, the
# preinstall script of the pacakge should use `dpkg-divert`
#
# ----------------------------------------------------------------------------


# location for files that should overwrite existing files (not owned by moode-player)
NOT_OWNED_TEMP=$PKG_ROOT_DIR/usr/share/moode-player
mkdir -p $NOT_OWNED_TEMP

# /boot
rsync -av --prune-empty-dirs --exclude *.sed* --exclude *.overwrite* --exclude *.ignore* $MOODE_DIR/boot/ $PKG_ROOT_DIR/boot/
rsync -av --prune-empty-dirs --include "*/" --include "*.overwrite*" --exclude="*" $MOODE_DIR/boot/ $NOT_OWNED_TEMP/boot/

# /etc
rsync -av --prune-empty-dirs --exclude *.sed* --exclude *.overwrite* $MOODE_DIR/etc/ $PKG_ROOT_DIR/etc/
rsync -av --prune-empty-dirs --include "*/" --include "*.overwrite*" --exclude="*" $MOODE_DIR/etc/ $NOT_OWNED_TEMP/etc/
#TODO: remove this one and make sure it is generated on startup
#cp $MOODE_DIR/mpd/mpd.conf.default $NOT_OWNED_TEMP/etc/mpd.conf

# /home
mkdir -p $PKG_ROOT_DIR/home
rsync -av --exclude xinitrc.default --exclude dircolors $MOODE_DIR/home/ $PKG_ROOT_DIR/home/pi
cp $MOODE_DIR/home/xinitrc.default $PKG_ROOT_DIR/home/pi/.xinitrc
cp $MOODE_DIR/home/dircolors $PKG_ROOT_DIR/home/pi/.dircolors

# /lib
rsync -av --prune-empty-dirs --exclude *.sed* --exclude *.overwrite* $MOODE_DIR/lib/ $PKG_ROOT_DIR/lib/
rsync -av --prune-empty-dirs --include "*/" --include "*.overwrite*" --exclude="*" $MOODE_DIR/lib/ $NOT_OWNED_TEMP/lib/

# /mnt (mount points)
mkdir -p $PKG_ROOT_DIR/mnt/{NAS,SDCARD,UPNP}
cp -r "$MOODE_DIR/other/sdcard/Stereo Test/" $PKG_ROOT_DIR/mnt/SDCARD

# /usr
rsync -av --prune-empty-dirs --exclude='mpd.conf' --exclude='mpdasrc.default' --exclude='install-wifi' --exclude='html/index.html' $MOODE_DIR/usr/ $PKG_ROOT_DIR/usr
rsync -av --prune-empty-dirs --include "*/" --include "*.overwrite*" --exclude="*" --exclude='mpd.conf' --exclude='mpdasrc.default' --exclude='install-wifi' --exclude='html/index.html' $MOODE_DIR/usr/ $NOT_OWNED_TEMP/usr/

# /var
rsync -av --exclude='moode-sqlite3.db' $MOODE_DIR/var/ $PKG_ROOT_DIR/var

# /var/lib/mpd
# TODO: maybe move the file $PKG_ROOT_DIR/mpd into the correct filesystem location
mkdir -p $PKG_ROOT_DIR/var/lib/mpd
cp $MOODE_DIR/mpd/sticker.sql $PKG_ROOT_DIR/var/lib/mpd
mkdir -p $PKG_ROOT_DIR/var/lib/mpd/music/RADIO
mkdir -p $PKG_ROOT_DIR/var/lib/mpd/playlists
cp -r $MOODE_DIR/mpd/RADIO/* $PKG_ROOT_DIR/var/lib/mpd/music/RADIO
cp $MOODE_DIR/mpd/playlists/* $PKG_ROOT_DIR/var/lib/mpd/playlists

# /var/local/php
mkdir -p $PKG_ROOT_DIR/var/local/php

# /var/wwww
mkdir -p $PKG_ROOT_DIR/var/www
cp -r $MOODE_DIR/build/distr/var/www/* $PKG_ROOT_DIR/var/www/


# In $NOT_OWNED_TEMP remove the ".overwrite" part from the files
function rename_files() {
    org_name=$1
    new_name=`echo "$org_name" | sed -r 's/(.*)[.]overwrite(.*)/\1\2/'`
    mv $org_name $new_name
}
export -f rename_files;
find $NOT_OWNED_TEMP -name "*.overwrite*" -exec bash -c 'rename_files "{}"' \;

#chmod -R 0644  $PKG_ROOT_DIR/etc/*
#chmod -R 0644  $NOT_OWNED_TEMP/*
# exit
# chmod -R -644  $PKG_ROOT_DIR/etc/*
# chmod -R -644  $NOT_OWNED_TEMP/*

# echo "** Reset permissions"
# #TODO: maybe set the rights before packed
chmod -R 0755  $PKG_ROOT_DIR/var/www
chmod 0755  $PKG_ROOT_DIR/var/www/command/*
chmod -R 0755  $PKG_ROOT_DIR/var/local/www
chmod -R 0777  $PKG_ROOT_DIR/var/local/www/commandw/*
chmod -R 0766  $PKG_ROOT_DIR/var/local/www/db
chmod -R 0755  $PKG_ROOT_DIR/usr/local/bin

# # chmod -R ug-s /var/local/www
chmod -R 0755  $PKG_ROOT_DIR/usr/local/bin


# ------------------------------------------------------------
# 5. Create the package

#TODO: Critical look at the deps, remove unneeded.
#TODO: Add license and readme, improve description

# Don't include packages as dependency, if those package depends on the used kernel (like drivers).
# Install those separate.
fpm -s dir -t deb -n $PKGNAME -v $PKGVERSION \
--license GPLv3 \
--category sound \
-S moode \
--iteration $DEBVER$DEBLOC \
--deb-priority optional \
--url https://www.moode.org \
-m moodeaudio.org \
--description 'moOde audio player' \
--after-install $BASE_DIR/postinstall.sh \
--depends rpi-update \
--depends php-fpm \
--depends nginx \
--depends sqlite3 \
--depends php-sqlite3 \
--depends php7.4-gd \
--depends bs2b-ladspa \
--depends libbs2b0 \
--depends libasound2-plugin-equal \
--depends telnet \
--depends sysstat \
--depends squashfs-tools \
--depends shellinabox \
--depends samba \
--depends smbclient \
--depends ntfs-3g \
--depends exfat-fuse \
--depends inotify-tools \
--depends ffmpeg \
--depends avahi-utils \
--depends python3-setuptools \
--depends libmediainfo0v5 \
--depends libmms0 \
--depends libzen0v5 \
--depends winbind \
--depends libnss-winbind \
--depends djmount \
--depends haveged \
--depends python3-pip \
--depends xfsprogs \
--depends triggerhappy \
--depends zip \
--depends id3v2 \
--depends dos2unix \
--depends php-yaml \
--depends sox \
--depends flac \
--depends nmap \
--depends libtool-bin \
--depends libatasmart4 \
--depends libdbus-glib-1-2 \
--depends libgudev-1.0-0 \
--depends libsgutils2-2 \
--depends libdevmapper-event1.02.1 \
--depends libconfuse-dev \
--depends libdbus-glib-1-dev \
--depends udevil \
--depends dnsmasq \
--depends hostapd \
--depends bluez-firmware \
--depends pi-bluetooth \
--depends alsa-cdsp \
--depends alsacap \
--depends bluez \
--depends bluez-alsa-utils \
--depends libasound2-plugin-bluez \
--depends python3-rpi.gpio \
--depends camilladsp \
--depends camillagui \
--depends caps \
--depends librespot \
--depends mediainfo \
--depends mpc \
--depends mpd \
--depends python3-libupnpp \
--depends shairport-sync \
--depends squeezelite \
--depends minidlna \
--depends trx \
--depends udisks-glue \
--depends upmpdcli \
--depends boss2-oled-p3 \
--depends xinit \
--depends xorg \
--depends lsb-release \
--depends chromium-browser \
root/boot/.=/boot \
root/var/.=/var \
root/home/.=/home \
root/mnt/.=/mnt \
root/usr/.=/usr \
root/etc/.=/etc


if [[ $? -gt 0 ]]
then
    echo "${RED}Error: failure during fpm.${NORMAL}"
    exit 1
fi

#------------------------------------------------------------
rbl_move_to_dist

echo "done"



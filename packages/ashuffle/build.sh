#!/bin/bash
#########################################################################
#
# Build Recipe for ashuffle
#
# (C) bitkeeper 2021 http://moodeaudio.org
# License: GPLv3
#
#########################################################################

. ../../scripts/rebuilder.lib.sh

#TODO: If needed add systemd files

PKG="ashuffle_3.12.5-1~moode1"

PKG_SOURCE_GIT="https://github.com/joshkunz/ashuffle.git"
PKG_SOURCE_GIT_TAG="v3.12.5"


rbl_prepare_clone_from_git $PKG_SOURCE_GIT $PKG_SOURCE_GIT_TAG

#------------------------------------------------------------
# Custom part of the packing

git archive  --format=tar.gz --output ../${PKGNAME}_${PKGVERSION}.tar.gz v$PKGVERSION

dh_make -l -p ${PKGNAME} -f ../${PKGNAME}_${PKGVERSION}.tar.gz -c custom --copyrightfile ../LICENSE -y
rm ../${PKGNAME}_${PKGVERSION}.tar.gz

#TODO: replace it with a better solution: include submodules in the archive
patch -p1 < ../debian.rules.initsubmodule.patch
patch -p1 < ../debian.control.patch

rm debian/manpage.*.ex
rm debian/README.*

# DEBFULLNAME=$DEBFULLNAME DEBEMAIL=$DEBEMAIL dch --newversion $FULL_VERSION "Modifications and enhancements to support integration into moOde audio player. Mods by Tim Curtis tim@moodeaudio.org"
rbl_set_initial_version_changelog $PKGNAME $FULL_VERSION

#------------------------------------------------------------
rbl_build
echo "done"


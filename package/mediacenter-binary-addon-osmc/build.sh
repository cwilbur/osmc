# (c) 2014-2015 Sam Nazarko
# email@samnazarko.co.uk

#!/bin/bash

. ../common.sh

git_to_archive()
{
    file_contents=$(cat $1)
    if grep -q github.com $1
    then
	PKG_NAME=$(echo $file_contents | cut -f 1 -d " ")
        GIT_REPO=$(echo $file_contents | cut -f 2 -d " ")
        GIT_REV=$(echo $file_contents | cut -f 3 -d " ")
        GIT_URL=$(echo ${GIT_REPO}/archive/${GIT_REV}.zip)
        echo "${PKG_NAME} ${GIT_URL}" > $1
     fi
}

if [ -z "$ADDONS" ]
then
    echo -e "Please specify which addons you would like to build"
	exit 1
fi
pull_source "https://github.com/xbmc/xbmc/archive/master.tar.gz" "$(pwd)/src"
if [ $? != 0 ]; then echo -e "Error downloading" && exit 1; fi
# Build in native environment
build_in_env "${1}" $(pwd) "mediacenter-binary-addon-osmc"
build_return=$?
if [ $build_return == 99 ]
then
	echo -e "Building binary addons for mediacenter"
	out=$(pwd)/files
	if [ -d files/usr ]; then rm -rf files/usr; fi
	update_sources
	handle_dep "cmake"
	handle_dep "${1}-libplatform-dev-osmc"
	handle_dep "git"
	handle_dep "make"
	pushd src/xbmc-*
	install_patch "../../patches" "all"
	for file in project/cmake/addons/addons/*/*.txt
	do
	    git_to_archive "$file"
	done
	git_to_archive "project/cmake/addons/depends/common/kodi-platform/kodi-platform.txt"
	popd
	for addon in $ADDONS
	do
		sed '/Package/d' -i files/DEBIAN/control
		echo "Package: ${1}-mediacenter-binary-addon-${ADDON}-osmc" >> files/DEBIAN/control
		echo "Version: 1.0.0" >> files/DEBIAN/control
		push src/xbmc-*
		$BUILD -C tools/depends/target/binary-addons/ INSTALL_OSMC_DIR="${out}/usr" PREFIX="." ADDONS="$ADDON"
		if [ $? != 0 ]; then echo "Error occured during build" && exit 1; fi
		strip_files "${out}"
		popd
		fix_arch_ctl "files/DEBIAN/control"
		dpkg_build files ${1}-mediacenter-binary-addon-${ADDON}-osmc.deb
		rm -rf ${out}/usr # Clean for next addon
	done
	build_return=$?
fi
teardown_env "${1}"
exit $build_return

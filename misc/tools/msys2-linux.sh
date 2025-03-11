#!/bin/sh

# (re)initialises an msys2 environment for obtaining current binaries cleanly on linux
# requires packages (in schroot if used): pacman-package-manager 7.0.0 and makepkg 7.0.0

# https://www.msys2.org/docs/windows_support/
TBURL=https://repo.msys2.org/distrib/msys2-x86_64-latest.tar.zst
MSYSROOT=msys64
cd "$HOME"

case "$1" in
	--schroot=*)
		SCHROOT="schroot -c ${1#--schroot=} --"
		shift
		;;
esac

# there's a bunch of first-time setup in etc/profile which calls more in etc/post-install/
# most isn't relevant or safe for our purposes but we do need pacman keys
# see: etc/post-install/07-pacman-key.post
pacman_init() {
	export PACMAN_KEYRING_DIR=etc/pacman.d/gnupg        # equivalent to pacman-key --gpgdir
	export KEYRING_IMPORT_DIR=usr/share/pacman/keyrings # equivalent to pacman-key --populate-from
	export CONFIG=etc/pacman.conf                       # equivalent to pacman-key --config
	export GNUPGHOME=etc/pacman.d/gnupg                 # tell gpg to use this instead of ~/.gnupg
	set -ex
	cd $MSYSROOT
	pacman-key --init
	pacman-key --populate msys2 || true
	# msys2 gpg has this server as compiled default, debian's default server doesn't have the keys
	# and we need this persistent
	echo "keyserver hkps://keyserver.ubuntu.com" >> etc/pacman.d/gnupg/gpg.conf
	pacman-key --refresh-keys || true
	gpgconf --kill all
}

case "$1" in
	pacman_init)
		pacman_init
		;;
	*)
		[ $(id -u) -eq 0 ] && (printf "\n\033[1;31mDo not run as root!\033[m\n"; exit 1)
		[ -n "$ABORT" ] && (printf "\n\033[1;31mToo much fail, giving up.\033[m\n"; exit 1)
		set -ex
		if [ ! -d $MSYSROOT ]; then
			rm -f "${TBURL##*/}"
			curl -O "$TBURL"
			tar --zstd -xf "${TBURL##*/}"
			rm -f "${TBURL##*/}"
			$SCHROOT fakeroot "$0" pacman_init
			export ABORT=true
		fi
		# update msys2 base and all packages, or delete and redownload if that fails
		# NOTE: sometimes this can print an error (for a specific package install) without failing,
		# eg "could not change the root directory (Operation not permitted)" (fakechroot doesn't fix, just changes error)
		# but it doesn't matter for our purposes because the files we need still get updated.
		$SCHROOT fakeroot pacman --sysroot $MSYSROOT --noconfirm -Syu || (rm -rf $MSYSROOT && exec "$0" "$@")
		# install specified packages if they're not already installed
		if ! $SCHROOT pacman --sysroot $MSYSROOT -Q "$@" ; then
			$SCHROOT fakeroot pacman --sysroot $MSYSROOT --noconfirm -S "$@"
		fi
		# some cleanup
		$SCHROOT fakeroot pacman --sysroot $MSYSROOT --noconfirm -Sc
		;;
esac

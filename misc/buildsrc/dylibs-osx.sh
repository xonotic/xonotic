#!/bin/bash
#
# Xonotic macOS dylib cross-compile script
# by <author>
#
# Equivalent of dlls.sh for macOS. Runs on Debian stable, cross-compiles
# macOS dylibs using osxcross. Uses Debian stable source packages.
#
# Requires (Debian):
#   apt-get install libtool automake cmake nasm git
#   osxcross installed at $OSXCROSS_PATH (default: ~/osxcross)
#   deb-src entries for stable in /etc/apt/sources.list
#
# Usage: dylibs-osx.sh <step> [build_path] [arch]
#
# arch:
#   osx64    x86_64-apple-darwin (requires osxcross with x86_64 target)
#   osxarm64 aarch64-apple-darwin (requires osxcross with arm64 target)

d0=$(pwd)
OSXCROSS_PATH="${OSXCROSS_PATH:-$HOME/osxcross}"

require () {
	if ! dpkg -s "$1" >/dev/null 2>&1; then
		echo "$1 package is required. Please install it."
		exit 1
	fi
}

prepare () {
	case $target_arch in
		osx64)
			ARCH="x86_64"
			CC_CMD="o64-clang"
			CXX_CMD="o64-clang++"
			export MACOSX_DEPLOYMENT_TARGET="10.9"
			;;
		osxarm64)
			ARCH="aarch64"
			CC_CMD="oa64-clang"
			CXX_CMD="oa64-clang++"
			export MACOSX_DEPLOYMENT_TARGET="11.0"
			;;
		*)
			echo "Invalid arch (osx64 or osxarm64)." && exit 1 ;;
	esac

	BIN="$OSXCROSS_PATH/out/bin"
	if [ ! -d "$BIN" ]; then
		echo "osxcross not found at $OSXCROSS_PATH"
		echo "Set OSXCROSS_PATH= to the osxcross installation directory."
		exit 1
	fi

	CC="$BIN/$CC_CMD"
	CXX="$BIN/$CXX_CMD"

	if [ ! -x "$CC" ]; then
		echo "Cross-compiler not found: $CC"
		[ "$target_arch" = "osxarm64" ] && \
			echo "Note: arm64 osxcross target may not be set up — check with the build server admin."
		exit 1
	fi

	# Derive the full target triple from the compiler
	CHOST=$("$CC" --print-target-triple 2>/dev/null)
	if [ -z "$CHOST" ]; then
		echo "Cannot determine target triple from $CC"
		exit 1
	fi

	ITN="$BIN/$CHOST-install_name_tool"
	OTOOL="$BIN/$CHOST-otool"
	STRIP_CMD="$BIN/$CHOST-strip"

	# Set directories
	src_dir="$buildpath/src"
	work_dir="$buildpath/work/$target_arch"
	pkg_dir="$buildpath/pkg/$target_arch"
	out_dir="$buildpath/out/$target_arch"

	export LDFLAGS="-L$pkg_dir/lib"
	export CPPFLAGS="-I$pkg_dir/include"

	# Check Debian dependencies
	require libtool
	require automake
	require cmake
	require nasm

	set -ex

	mkdir -p "$src_dir"
	mkdir -p "$work_dir"
	mkdir -p "$pkg_dir"
}

get_this_src () {
	dir=$(find . -maxdepth 1 -type d -print | grep -m1 "^\./$1") || return 1
	this_src="$src_dir/$dir"
	this_ver="${dir##*-}"
}

fetch_source () {
	cd "$src_dir"

	if get_this_src "$1"; then
		echo "Source for $1 already exists."
		return 1
	else
		echo "Getting source for $1..."
		apt-get source -t=stable "$1"
		get_this_src "$1"
		return 0
	fi
}

cmake_cross () {
	# CMake invocation for osxcross cross-compilation.
	# Usage: cmake_cross <source_dir> [extra cmake args...]
	local src="$1"
	shift
	cmake \
		-DCMAKE_SYSTEM_NAME=Darwin \
		-DCMAKE_C_COMPILER="$CC" \
		-DCMAKE_CXX_COMPILER="$CXX" \
		-DCMAKE_INSTALL_NAME_DIR='@executable_path' \
		-DCMAKE_PREFIX_PATH="$pkg_dir" \
		-DCMAKE_INSTALL_PREFIX="$pkg_dir" \
		-G"Unix Makefiles" \
		"$@" \
		"$src"
}

mkcd () {
	mkdir -p "$1"
	cd "$1"
}

build_gmp () {
	fetch_source gmp || true

	mkcd "$work_dir/gmp"
	autoreconf -i "$this_src"
	# --disable-assembly: GMP assembly uses non-PIC code which breaks dylib linking
	"$this_src/configure" \
		--prefix="$pkg_dir" \
		--host="$CHOST" \
		--with-pic \
		--disable-assembly \
		--enable-static \
		--disable-shared \
		CC="$CC"
	make
	make install
}

build_libd0 () {
	if [ -d "$src_dir/d0_blind_id" ]; then
		echo "Sources already exist."
	else
		echo "Getting git sources for libd0..."
		cd "$src_dir"
		git clone https://gitlab.com/xonotic/d0_blind_id.git
		cd d0_blind_id
		./autogen.sh
	fi

	mkcd "$work_dir/libd0"
	# CPPFLAGS/LDFLAGS (set in prepare) point configure to our GMP static lib in pkg_dir
	"$src_dir/d0_blind_id/configure" \
		--prefix="$pkg_dir" \
		--host="$CHOST" \
		--with-pic \
		CC="$CC"
	make
	make install
}

build_libogg () {
	fetch_source libogg || true

	mkcd "$work_dir/libogg"
	cmake_cross "$this_src" \
		-DBUILD_SHARED_LIBS=ON
	make
	make install
}

build_libvorbis () {
	if fetch_source libvorbis; then
		# -force_cpusubtype_ALL was for old Apple GCC; modern clang rejects it
		sed -i 's/-force_cpusubtype_ALL//g' "$this_src/configure"
	fi

	mkcd "$work_dir/libvorbis"
	cmake_cross "$this_src" \
		-DBUILD_SHARED_LIBS=ON
	make
	make install
}

build_libtheora () {
	if fetch_source libtheora; then
		# -force_cpusubtype_ALL was for old Apple GCC; modern clang rejects it
		sed -i 's/-force_cpusubtype_ALL//g' "$this_src/configure"
	fi

	mkcd "$work_dir/libtheora"
	# Use the pre-generated configure from the Debian source package.
	# Do NOT run autoreconf: libtheora 1.1.x uses macros (AM_PATH_SDL, AS_AC_EXPAND)
	# that fail with modern autoconf.
	"$this_src/configure" \
		--host="$CHOST" \
		--prefix="$pkg_dir" \
		--enable-shared \
		--disable-static \
		--disable-encode \
		--disable-examples \
		--disable-sdltest \
		--disable-vorbistest \
		--disable-oggtest \
		CC="$CC"
	make
	make install
}

build_freetype () {
	fetch_source freetype || true

	mkcd "$work_dir/freetype"
	cmake_cross "$this_src" \
		-DBUILD_SHARED_LIBS=ON \
		-DCMAKE_BUILD_TYPE=Release
	make
	make install
}

build_libpng16 () {
	fetch_source "libpng1.6" || true

	mkcd "$work_dir/libpng1.6"
	cmake_cross "$this_src" \
		-DPNG_STATIC=OFF \
		-DPNG_TESTS=OFF
	make
	make install
}

build_libjpeg () {
	fetch_source libjpeg-turbo || true

	mkcd "$work_dir/libjpeg"
	# WITH_SIMD=0: SIMD assembly can't be compiled for multiple architectures in
	# one pass. Disable for now; full SIMD is possible by building each arch
	# separately and merging with the universal step.
	cmake_cross "$this_src" \
		-DCMAKE_SYSTEM_PROCESSOR="$ARCH" \
		-DENABLE_SHARED=ON \
		-DENABLE_STATIC=OFF \
		-DWITH_TURBOJPEG=OFF \
		-DWITH_SIMD=0
	make
	make install
}

build_zlib () {
	fetch_source zlib || true

	mkcd "$work_dir/zlib"
	cmake_cross "$this_src" \
		-DBUILD_SHARED_LIBS=ON
	make
	make install
}

build_libcurl () {
	fetch_source curl || true

	mkcd "$work_dir/curl"
	# CURL_USE_SECTRANSP: SecureTransport was deprecated by Apple and support
	# removed in curl 8.15. Debian stable ships 8.14 so this is fine for now.
	# When Debian stable moves to curl 8.15+, switch to USE_APPLE_SECTRUST=ON
	# and add a TLS library (e.g. openssl or mbedtls) built and statically
	# linked into libcurl or shipped as an additional dylib.
	cmake_cross "$this_src" \
		-DCMAKE_INSTALL_PREFIX="$pkg_dir" \
		-DCURL_USE_SECTRANSP=ON \
		-DCURL_USE_LIBPSL=OFF \
		-DBUILD_SHARED_LIBS=ON \
		-DBUILD_CURL_EXE=OFF \
		-DHTTP_ONLY=ON
	make
	make install
}

build_libsdl2 () {
	fetch_source libsdl2 || true

	mkdir -p "$pkg_dir/sdl"

	mkcd "$work_dir/libsdl2"
	cmake_cross "$this_src" \
		-DCMAKE_SYSTEM_PROCESSOR="$ARCH" \
		-DCMAKE_INSTALL_PREFIX="$pkg_dir/sdl"
	make
	make install
}

build_libode () {
	fetch_source libode || true

	mkcd "$work_dir/libode"
	cmake_cross "$this_src" \
		-DBUILD_SHARED_LIBS=ON \
		-DODE_WITH_DEMOS=OFF \
		-DODE_WITH_TESTS=OFF
	make
	make install
}

build_all () {
	build_zlib
	build_gmp
	build_libd0
	build_libogg
	build_libvorbis
	build_libtheora
	build_freetype
	build_libpng16
	build_libjpeg
	build_libode
	build_libcurl
	build_libsdl2
}

fix_install_names () {
	local f="$1"
	local name
	name=$(basename "$f")

	# Fix this dylib's own install name
	"$ITN" -id "@executable_path/$name" "$f"

	# Fix any references to pkg_dir paths -> @executable_path/
	# (autoconf/libtool builds record the build-time path; cmake builds
	# should already use @executable_path via CMAKE_INSTALL_NAME_DIR)
	while IFS= read -r ref; do
		if [[ "$ref" == "$pkg_dir/lib/"* ]]; then
			local refname
			refname=$(basename "$ref")
			"$ITN" -change "$ref" "@executable_path/$refname" "$f"
		fi
	done < <("$OTOOL" -L "$f" 2>/dev/null | awk 'NR>1 {print $1}')
}

install () {
	mkdir -p "$out_dir"

	local dylibs=(
		libd0_blind_id.0.dylib
		libd0_rijndael.0.dylib
		libogg.0.dylib
		libvorbis.0.dylib
		libvorbisenc.2.dylib
		libvorbisfile.3.dylib
		libtheora.0.dylib
		libfreetype.6.dylib
		libpng16.16.dylib
		libjpeg.62.dylib
	)

	for name in "${dylibs[@]}"; do
		local src
		src=$(find "$pkg_dir/lib" -name "$name" -type f 2>/dev/null | head -1)
		if [ -z "$src" ]; then
			echo "WARNING: $name not found in $pkg_dir/lib — check build output"
			continue
		fi
		cp -v "$src" "$out_dir/$name"
		fix_install_names "$out_dir/$name"
	done

	# ODE soversion is 8 for ODE 0.16.x; keep libode.3.dylib as well for compat
	# with any existing dlopen calls that use the old name
	local ode_src
	ode_src=$(find "$pkg_dir/lib" -name "libode.*.dylib" -type f 2>/dev/null | head -1)
	if [ -n "$ode_src" ]; then
		local ode_name
		ode_name=$(basename "$ode_src")
		cp -v "$ode_src" "$out_dir/$ode_name"
		fix_install_names "$out_dir/$ode_name"
		if [ "$ode_name" != "libode.3.dylib" ]; then
			cp -v "$out_dir/$ode_name" "$out_dir/libode.3.dylib"
			"$ITN" -id "@executable_path/libode.3.dylib" "$out_dir/libode.3.dylib"
		fi
	else
		echo "WARNING: libode dylib not found — check ODE build output"
	fi

	# Do not strip: osxcross already strips before signing, and stripping
	# after removes the ad-hoc signature that arm64 binaries require to run.
}

universal () {
	# Merge osx64 and osxarm64 outputs into universal (fat) dylibs using lipo.
	# Run 'all' for both osx64 and osxarm64 first.
	local lipo="$OSXCROSS_PATH/out/bin/lipo"
	if [ ! -x "$lipo" ]; then
		echo "lipo not found at $lipo — set OSXCROSS_PATH correctly"
		exit 1
	fi

	local out64="$buildpath/out/osx64"
	local outarm64="$buildpath/out/osxarm64"
	local outuniv="$buildpath/out/universal"
	mkdir -p "$outuniv"

	set -ex

	for f in "$out64"/*.dylib; do
		local name
		name=$(basename "$f")
		if [ -f "$outarm64/$name" ]; then
			"$lipo" -create "$f" "$outarm64/$name" -output "$outuniv/$name"
		else
			echo "WARNING: $name missing from osxarm64 output — copying x86_64 slice only"
			cp "$f" "$outuniv/$name"
		fi
	done
}

clean () {
	rm -rf "$buildpath/src"
	rm -rf "$buildpath/work"
	rm -rf "$buildpath/pkg"
	rm -rf "$buildpath/out"
}

list () {
	echo "Compilable libraries:"
	echo
	echo zlib
	echo gmp
	echo libd0
	echo libogg
	echo libvorbis
	echo libtheora
	echo freetype
	echo libpng16
	echo libjpeg
	echo libode
	echo libcurl
	echo libsdl2
}

usage () {
	echo "Xonotic macOS dylib cross-compile script"
	echo
	echo "usage: $0 <step> [build_path] [arch]"
	echo
	echo "available steps (require arch):"
	echo "  <library>  build a single library"
	echo "  build_all  build all libraries"
	echo "  install    copy dylibs with fixed install names to out/<arch>/"
	echo "  all        prepare, build_all, and install"
	echo
	echo "steps without arch:"
	echo "  universal  lipo osx64+osxarm64 outputs into universal dylibs"
	echo "  list       list compilable libraries"
	echo "  clean      delete all work directories"
	echo
	echo "arch:"
	echo "  osx64      x86_64-apple-darwin"
	echo "  osxarm64   aarch64-apple-darwin (requires arm64 osxcross target)"
	echo
	echo "environment:"
	echo "  OSXCROSS_PATH  path to osxcross installation (default: ~/osxcross)"
}

step=$1
buildpath=$2
target_arch=$3

case $step in
	zlib)       prepare && build_zlib ;;
	gmp)        prepare && build_gmp ;;
	libd0)      prepare && build_libd0 ;;
	libogg)     prepare && build_libogg ;;
	libvorbis)  prepare && build_libvorbis ;;
	libtheora)  prepare && build_libtheora ;;
	freetype)   prepare && build_freetype ;;
	libpng16)   prepare && build_libpng16 ;;
	libjpeg)    prepare && build_libjpeg ;;
	libode)     prepare && build_libode ;;
	libcurl)    prepare && build_libcurl ;;
	libsdl2)    prepare && build_libsdl2 ;;
	build_all)  prepare && build_all ;;
	install)    prepare && install ;;
	all)        prepare && build_all && install ;;
	universal)  universal ;;
	clean)      clean ;;
	list)       list ;;
	*)          usage ;;
esac

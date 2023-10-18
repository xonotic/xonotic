#!/bin/bash
#
# Xonotic DLL automatic cross-compile script
# by z411

d0=$(pwd)

require () {
	if ! dpkg -s "$1" >/dev/null 2>&1 ; then
		echo "$1 package is required. Please install it."
		exit -1
	fi
}

prepare () {
	case $target_arch in
		win32)	  ARCH="i686" ;;
		win64)	  ARCH="x86_64" ;;
		*)        echo "Invalid arch (win32 or win64)." && exit -1 ;;
	esac

	# Set directories
	src_dir="$buildpath/src"
	work_dir="$buildpath/work/$target_arch"
	pkg_dir="$buildpath/pkg/$target_arch"
	out_dir="$buildpath/out/$target_arch"

	# Set arch vars
	CHOST="$ARCH-w64-mingw32"
	toolchain_file="$d0/toolchain-$CHOST.cmake"

	# Fix for Debian package missing the Windows resource file
	zlib1rc_file="$d0/zlib1.rc"

	export LDFLAGS="-L$pkg_dir/lib"
	export CPPFLAGS="-I$pkg_dir/include"

	# Check dependencies
	require libtool
	require mingw-w64
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

verlte () {
	printf '%s\n%s' "$1" "$2" | sort -C -V
}

verlt () {
	! verlte "$2" "$1"
}

mkcd () {
	mkdir -p "$1"
	cd "$1"
}

build_zlib () {
	if fetch_source zlib ; then
		echo "Fixing zlib prefix..."
		sed -i '/zlib PROPERTIES SUFFIX/i set_target_properties(zlib PROPERTIES PREFIX "")' "$this_src/CMakeLists.txt"

		# Debian source package is missing the win32 resource file for some reason,
		# so we add it ourselves.
		echo "Fixing zlib1.rc..."
		mkdir -p "$this_src/win32"
		cp "$zlib1rc_file" "$this_src/win32"
	fi

	mkcd "$work_dir/zlib"
	cmake -DCMAKE_TOOLCHAIN_FILE="$toolchain_file"\
	      -DBUILD_SHARED_LIBS=ON \
	      -DCMAKE_INSTALL_PREFIX="$pkg_dir" \
	      -G"Unix Makefiles" "$this_src"
	make
	make install
}

build_gmp () {
	fetch_source gmp || true

	mkcd "$work_dir/gmp"
	autoreconf -i "$this_src"
	"$this_src/configure" --prefix="$pkg_dir" \
			      --host="$CHOST" \
			      --with-pic \
			      --enable-fat \
			      --disable-static \
			      --enable-shared
	make
	make install
}

build_libd0 () {
	if [[ -d "$src_dir/d0_blind_id" ]] ; then
		echo "Sources already exist."
	else
		echo "Getting git sources for libd0..."
		cd "$src_dir"
		git clone https://gitlab.com/xonotic/d0_blind_id.git
		cd d0_blind_id
		./autogen.sh
		sed -i '/libd0_blind_id_la_LDFLAGS/ s/$/ -no-undefined/' Makefile.am
		sed -i '/libd0_rijndael_la_LDFLAGS/ s/$/ -no-undefined/' Makefile.am
	fi

	mkcd "$work_dir/libd0"
	"$src_dir/d0_blind_id/configure" --with-pic \
		                         --prefix="$pkg_dir" \
					 --host="$CHOST"
	make
	make install
}

build_libogg() {
	if fetch_source libogg ; then
		echo "Fixing win32 def files..."
		sed -i 's/^LIBRARY ogg$/LIBRARY libogg/' "$this_src/win32/ogg.def"
	fi

	mkcd "$work_dir/libogg"
	cmake -DCMAKE_TOOLCHAIN_FILE="$toolchain_file" \
	      -DBUILD_SHARED_LIBS=ON \
	      -DCMAKE_INSTALL_PREFIX="$pkg_dir" \
	      -G"Unix Makefiles" "$this_src"
	make
	make install
}

build_libvorbis () {
	if fetch_source libvorbis ; then
		echo "Fixing win32 def files..."
		sed -i 's/^LIBRARY$/LIBRARY libvorbis/' "$this_src/win32/vorbis.def"
		sed -i 's/^LIBRARY$/LIBRARY libvorbisenc/' "$this_src/win32/vorbisenc.def"
		sed -i 's/^LIBRARY$/LIBRARY libvorbisfile/' "$this_src/win32/vorbisfile.def"
	fi

	mkcd "$work_dir/libvorbis"
	cmake -DCMAKE_TOOLCHAIN_FILE="$toolchain_file" \
	      -DBUILD_SHARED_LIBS=ON \
	      -DOGG_INCLUDE_DIR="$pkg_dir/include" \
	      -DOGG_LIBRARY="$pkg_dir/lib/libogg.dll.a" \
	      -DCMAKE_INSTALL_PREFIX="$pkg_dir" \
	      -G"Unix Makefiles" "$this_src"
	make
	make install
}

build_libtheora () {
	if fetch_source libtheora ; then
		echo "Fixing mingw32 defs..."
		sed -i '1iLIBRARY libtheoradec' "$this_src/win32/xmingw32/libtheoradec-all.def"
		sed -i '1iLIBRARY libtheoraenc' "$this_src/win32/xmingw32/libtheoraenc-all.def"
		sed -i '/TH_VP31_QUANT_INFO/d' "$this_src/win32/xmingw32/libtheoraenc-all.def"
		sed -i '/TH_VP31_HUFF_CODES/d' "$this_src/win32/xmingw32/libtheoraenc-all.def"
	fi

	mkcd "$work_dir/libtheora"
	"$this_src/autogen.sh"
	"$this_src/configure" --host="$CHOST" \
		              --prefix="$pkg_dir" \
			      --with-ogg="$pkg_dir" \
			      --with-vorbis="$pkg_dir" \
			      --enable-shared \
			      --disable-examples \
			      --disable-sdltest \
			      --disable-vorbistest \
			      --disable-oggtest
	make
	make install
}

build_freetype () {
	fetch_source freetype || true

	mkcd "$work_dir/freetype"
	cmake -DCMAKE_TOOLCHAIN_FILE="$toolchain_file" \
	      -DBUILD_SHARED_LIBS=ON \
	      -DCMAKE_BUILD_TYPE=Release \
	      -DCMAKE_INSTALL_PREFIX="$pkg_dir" \
	      -G"Unix Makefiles" "$this_src"
	make
	make install
}

build_libpng16 () {
	fetch_source "libpng1.6" || true

	mkcd "$work_dir/libpng1.6"
	cmake -DCMAKE_TOOLCHAIN_FILE="$toolchain_file" \
	      -DPNG_STATIC=OFF \
	      -DPNG_TESTS=OFF \
	      -DZLIB_INCLUDE_DIR="$pkg_dir/include" \
	      -DZLIB_LIBRARY="$pkg_dir/lib/libzlib.dll.a" \
	      -DCMAKE_INSTALL_PREFIX="$pkg_dir" \
	      -G"Unix Makefiles" "$this_src"
	make
	make install
}

build_libjpeg () {
	fetch_source libjpeg-turbo || true

	mkcd "$work_dir/libjpeg"
	cmake -DCMAKE_TOOLCHAIN_FILE="$toolchain_file" \
	      -DCMAKE_SYSTEM_PROCESSOR="$ARCH" \
	      -DCMAKE_INSTALL_PREFIX="$pkg_dir" \
	      -DENABLE_SHARED=ON \
	      -DENABLE_STATIC=OFF \
	      -DWITH_TURBOJPEG=OFF \
	      -G"Unix Makefiles" "$this_src"
	make
	make install
}

build_curl () {
	fetch_source curl || true

	# curl versions older than 7.81.0 used CMAKE instead of CURL for
	# private USE identifiers
	verlt $this_ver 7.81.0 && PARAM="CMAKE" || PARAM="CURL"

	mkcd "$work_dir/curl"
	cmake -DCMAKE_TOOLCHAIN_FILE="$toolchain_file" \
	      -DCMAKE_INSTALL_PREFIX="$pkg_dir" \
	      -DZLIB_INCLUDE_DIR="$pkg_dir/include" \
	      -DZLIB_LIBRARY="$pkg_dir/lib/libzlib.dll.a" \
	      -D${PARAM}_USE_SCHANNEL=ON \
	      -DBUILD_SHARED_LIBS=ON \
	      -DBUILD_CURL_EXE=OFF \
	      -DHTTP_ONLY=ON \
	      -G"Unix Makefiles" "$this_src"
	make
	make install
}

build_libsdl2 ()
{
	fetch_source libsdl2 || true

	# this subdir will be made available to DP's linker
	mkdir -p "$pkg_dir/sdl"

	mkcd "$work_dir/libsdl2"
	cmake -DCMAKE_TOOLCHAIN_FILE="$toolchain_file" \
	      -DCMAKE_SYSTEM_PROCESSOR="$ARCH" \
	      -DCMAKE_INSTALL_PREFIX="$pkg_dir/sdl" \
	      -G"Unix Makefiles" "$this_src"
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
	build_curl
	build_libsdl2
}

install () {
	mkdir -p "$out_dir"

	cp -v "$pkg_dir/bin/libgmp-10.dll" "$out_dir"
	cp -v "$pkg_dir/bin/libd0_blind_id-0.dll" "$out_dir"
	cp -v "$pkg_dir/bin/libd0_rijndael-0.dll" "$out_dir"
	cp -v "$pkg_dir/bin/libogg.dll" "$out_dir"
	cp -v "$pkg_dir/bin/libvorbis.dll" "$out_dir"
	cp -v "$pkg_dir/bin/libvorbisenc.dll" "$out_dir"
	cp -v "$pkg_dir/bin/libvorbisfile.dll" "$out_dir"
	cp -v "$pkg_dir/bin/libtheora-0.dll" "$out_dir"
	cp -v "$pkg_dir/bin/libfreetype.dll" "$out_dir/libfreetype-6.dll"
	cp -v "$pkg_dir/bin/zlib1.dll" "$out_dir"
	cp -v "$pkg_dir/bin/libpng16.dll" "$out_dir"
	cp -v "$pkg_dir/bin/libjpeg-62.dll" "$out_dir/libjpeg.dll"
	cp -v "$pkg_dir/bin/libcurl.dll" "$out_dir/libcurl-4.dll"
#	cp -v "$pkg_dir/sdl/bin/SDL2.dll" "$out_dir"

	# Required for win32 builds
	if [ "$ARCH" = "i686" ]; then
		cp -v /usr/lib/gcc/i686-w64-mingw32/[0-9][0-9]-win32/libgcc_s_dw2-1.dll "$out_dir"
	fi

	cd "$out_dir"
	${CHOST}-strip -s *.dll
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
	echo gmp
	echo libd0
	echo libogg
	echo libvorbis
	echo libtheora
	echo freetype
	echo zlib
	echo libpng16
	echo libjpeg
	echo curl
	echo libsdl2
}

usage () {
	echo "Experimental Windows DLL cross-compiling for Xonotic"
	echo "by z411"
	echo
	echo "usage: $0 <step> [build path] [arch]"
	echo
	echo "available steps (require arch):"
	echo "  <library name>: build specified library"
	echo "  build_all: build all libraries"
	echo "  install: copy built DLLs into output directory"
	echo "  all: do all the previous steps in order"
	echo
	echo "steps without arch:"
	echo "  list: list all compilable libraries"
	echo "  clean: delete all work"
	echo
	echo "arch can be:"
	echo "  win32"
	echo "  win64"
}

step=$1
buildpath=$2
target_arch=$3

case $step in
	gmp)           prepare && build_gmp ;;
	libd0)         prepare && build_libd0 ;;
	libogg)        prepare && build_libogg ;;
	libvorbis)     prepare && build_libvorbis ;;
	libtheora)     prepare && build_libtheora ;;
	freetype)      prepare && build_freetype ;;
	zlib)          prepare && build_zlib ;;
	libpng16)      prepare && build_libpng16 ;;
	libjpeg)       prepare && build_libjpeg ;;
	curl)          prepare && build_curl ;;
	libsdl2)       prepare && build_libsdl2 ;;
	build_all)     prepare && build_all ;;
	install)       prepare && install ;;
	all)           prepare && build_all && install ;;
	clean)         clean ;;
	list)          list ;;
	*)             usage ;;
esac

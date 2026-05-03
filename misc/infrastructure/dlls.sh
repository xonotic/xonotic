#!/bin/bash
#
# Xonotic DLL automatic cross-compile script
# by z411

d0=$(readlink -m "$(dirname "$0")/../..") # xonotic.git/

require ()
{
	if ! dpkg -s "$1" >/dev/null 2>&1 ; then
		echo "$1 package is required. Please install it."
		exit -1
	fi
}

prepare ()
{
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

	export LDFLAGS="-L$pkg_dir/lib"
	export CPPFLAGS="-I$pkg_dir/include"
	export PKG_CONFIG_LIBDIR="$pkg_dir/lib/pkgconfig:$pkg_dir/share/pkgconfig"

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

get_this_src ()
{
	dir=$(find . -maxdepth 1 -type d -print | grep -m1 "^\./$1") || return 1
	this_src="$src_dir/$dir"
	this_ver="${dir##*-}"
}

fetch_source ()
{
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

cmake_cross ()
{
	# CMake invocation for osxcross cross-compilation.
	# Usage: cmake_cross <source_dir> [extra cmake args...]
	local src="$1"
	shift

	# autotools derives the $CHOST -based values from --host, cmake needs them all set,
	# also work around cmake_minimum_required error (4.2 is first version where CMAKE_SYSROOT works with mingw).
	CMAKE_POLICY_VERSION_MINIMUM=4.2 \
	PKG_CONFIG="${CHOST}-pkg-config" \
	cmake \
		-DCMAKE_SYSTEM_NAME=Windows \
		-DCMAKE_SYSTEM_PROCESSOR="$ARCH" \
		-DCMAKE_C_COMPILER="${CHOST}-gcc" \
		-DCMAKE_CXX_COMPILER="${CHOST}-g++" \
		-DCMAKE_RC_COMPILER="${CHOST}-windres" \
		-DCMAKE_PREFIX_PATH="$pkg_dir" \
		-DCMAKE_INSTALL_PREFIX="$pkg_dir" \
		-DCMAKE_SYSROOT="/usr/${CHOST}" \
		-G"Unix Makefiles" \
		"$@" \
		"$src"
}

verlte ()
{
	printf '%s\n%s' "$1" "$2" | sort -C -V
}

verlt ()
{
	! verlte "$2" "$1"
}

mkcd ()
{
	mkdir -p "$1"
	cd "$1"
}

build_zlib ()
{
	if fetch_source zlib ; then
		echo "Fixing zlib prefix..."
		sed -i '/zlib PROPERTIES SUFFIX/i set_target_properties(zlib PROPERTIES PREFIX "")' "$this_src/CMakeLists.txt"

		# Debian source package is missing the win32 resource file for some reason,
		# so we add it ourselves.
		echo "Fixing zlib1.rc..."
		mkdir -p "$this_src/win32"
		cp "$d0/misc/buildsrc/zlib1.rc" "$this_src/win32"
	fi

	mkcd "$work_dir/zlib"
	cmake_cross "$this_src" \
	      -DBUILD_SHARED_LIBS=ON \
	      -DZLIB_BUILD_EXAMPLES=OFF
	make
	make install
}

build_gmp ()
{
	fetch_source gmp || true

	mkcd "$work_dir/gmp"
	autoreconf -i "$this_src"
	"$this_src/configure" \
		--host="$CHOST" \
		--prefix="$pkg_dir" \
		--enable-fat \
		--enable-shared \
		--disable-static
	make
	make install
}

build_libd0 ()
{
	this_src=$d0/d0_blind_id
	git -C "$this_src" clean -fdx
	git -C "$this_src" restore .

	mkcd "$work_dir/libd0"
	autoreconf -i "$this_src"
	"$this_src/configure" \
		--host="$CHOST" \
		--prefix="$pkg_dir" \
		--enable-shared \
		--disable-static
	make
	make install
}

build_libogg()
{
	if fetch_source libogg ; then
		echo "Fixing win32 def files..."
		sed -i 's/^LIBRARY ogg$/LIBRARY libogg/' "$this_src/win32/ogg.def"
	fi

	mkcd "$work_dir/libogg"
	cmake_cross "$this_src" \
	      -DBUILD_SHARED_LIBS=ON \
	      -DINSTALL_DOCS=OFF
	make
	make install
}

build_libvorbis ()
{
	if fetch_source libvorbis ; then
		echo "Fixing win32 def files..."
		sed -i 's/^LIBRARY$/LIBRARY libvorbis/' "$this_src/win32/vorbis.def"
		sed -i 's/^LIBRARY$/LIBRARY libvorbisenc/' "$this_src/win32/vorbisenc.def"
		sed -i 's/^LIBRARY$/LIBRARY libvorbisfile/' "$this_src/win32/vorbisfile.def"
	fi

	mkcd "$work_dir/libvorbis"
	cmake_cross "$this_src" \
	      -DBUILD_SHARED_LIBS=ON
	make
	make install
}

build_libtheora ()
{
	if fetch_source libtheora ; then
		echo "Fixing mingw32 defs..."
		sed -i '1iLIBRARY libtheoradec' "$this_src/win32/xmingw32/libtheoradec-all.def"
		sed -i '1iLIBRARY libtheoraenc' "$this_src/win32/xmingw32/libtheoraenc-all.def"
		sed -i '/TH_VP31_QUANT_INFO/d' "$this_src/win32/xmingw32/libtheoraenc-all.def"
		sed -i '/TH_VP31_HUFF_CODES/d' "$this_src/win32/xmingw32/libtheoraenc-all.def"
	fi

	mkcd "$work_dir/libtheora"
	"$this_src/autogen.sh"
	"$this_src/configure" \
		--host="$CHOST" \
		--prefix="$pkg_dir" \
		--with-ogg="$pkg_dir" \
		--with-vorbis="$pkg_dir" \
		--enable-shared \
		--disable-static \
		--disable-examples \
		--disable-vorbistest \
		--disable-oggtest
	make
	make install
}

build_freetype ()
{
	fetch_source freetype || true

	mkcd "$work_dir/freetype"
	cmake_cross "$this_src" \
	      -DBUILD_SHARED_LIBS=ON \
	      -DCMAKE_BUILD_TYPE=Release \
	      -DFT_DISABLE_BZIP2=TRUE \
	      -DFT_DISABLE_HARFBUZZ=TRUE \
	      -DFT_DISABLE_BROTLI=TRUE
	make
	make install
}

build_libpng16 ()
{
	fetch_source "libpng1.6" || true

	mkcd "$work_dir/libpng1.6"
	cmake_cross "$this_src" \
	      -DPNG_SHARED=ON \
	      -DPNG_STATIC=OFF \
	      -DPNG_TESTS=OFF \
	      -DPNG_TOOLS=OFF
	make
	make install
}

build_libjpeg ()
{
	fetch_source libjpeg-turbo || true

	mkcd "$work_dir/libjpeg"
	cmake_cross "$this_src" \
	      -DENABLE_SHARED=ON \
	      -DENABLE_STATIC=OFF \
	      -DWITH_TURBOJPEG=OFF
	make
	make install
}

build_curl ()
{
	fetch_source curl || true

	# curl versions older than 7.81.0 used CMAKE instead of CURL for
	# private USE identifiers
	verlt $this_ver 7.81.0 && PARAM="CMAKE" || PARAM="CURL"

	# libpsl dependency disabled: xon doesn't use cookies
	# see: https://daniel.haxx.se/blog/2024/01/10/psl-in-curl/

	mkcd "$work_dir/curl"
	cmake_cross "$this_src" \
	      -D${PARAM}_USE_SCHANNEL=ON \
	      -D${PARAM}_USE_LIBPSL=OFF \
	      -DBUILD_SHARED_LIBS=ON \
	      -DBUILD_STATIC_LIBS=OFF \
	      -DBUILD_CURL_EXE=OFF \
	      -DHTTP_ONLY=ON
	make
	make install
}

build_libsdl2 ()
{
	fetch_source libsdl2 || true

	mkcd "$work_dir/libsdl2"
	cmake_cross "$this_src" \
	      -DSDL_SHARED=OFF \
	      -DSDL_STATIC=ON \
	      -DSDL_RENDER_D3D=OFF \
	      -DSDL_TEST=OFF
	make
	make install
}

build_libxmp()
{
	fetch_source libxmp || true

	mkcd "$work_dir/libxmp"
	cmake_cross "$this_src" \
		-DBUILD_SHARED=ON \
		-DBUILD_STATIC=OFF
	make
	make install
}

build_all ()
{
	build_zlib
	build_gmp
	build_libd0
	build_libogg
	build_libvorbis
	build_libtheora
	build_libpng16
	build_freetype
	build_libjpeg
	build_curl
	build_libsdl2
	build_libxmp
}

install ()
{
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
#	cp -v "$pkg_dir/bin/SDL2.dll" "$out_dir"
	cp -v "$pkg_dir/bin/libxmp.dll" "$out_dir"

	# Required for win32 builds
	if [ "$ARCH" = "i686" ]; then
		cp -v /usr/lib/gcc/i686-w64-mingw32/[0-9][0-9]-win32/libgcc_s_dw2-1.dll "$out_dir"
	fi

	cd "$out_dir"
	${CHOST}-strip -s *.dll
}

clean ()
{
	rm -rf "$buildpath/src"
	rm -rf "$buildpath/work"
	rm -rf "$buildpath/pkg"
	rm -rf "$buildpath/out"
}

list ()
{
	echo "Compilable libraries:"
	echo
	echo zlib
	echo gmp
	echo libd0
	echo libogg
	echo libvorbis
	echo libtheora
	echo libpng16
	echo freetype
	echo libjpeg
	echo curl
	echo libsdl2
	echo libxmp
}

usage ()
{
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
	gmp)           prepare ; build_gmp ;;
	libd0)         prepare ; build_libd0 ;;
	libogg)        prepare ; build_libogg ;;
	libvorbis)     prepare ; build_libvorbis ;;
	libtheora)     prepare ; build_libtheora ;;
	freetype)      prepare ; build_freetype ;;
	zlib)          prepare ; build_zlib ;;
	libpng16)      prepare ; build_libpng16 ;;
	libjpeg)       prepare ; build_libjpeg ;;
	curl)          prepare ; build_curl ;;
	libsdl2)       prepare ; build_libsdl2 ;;
	libxmp)        prepare ; build_libxmp ;;
	build_all)     prepare ; build_all ;;
	install)       prepare ; install ;;
	all)           prepare ; build_all ; install ;;
	clean)         clean ;;
	list)          list ;;
	*)             usage ;;
esac

#!/bin/bash
#
# Xonotic macOS dylib cross-compile script using Debian stable sources.
# Please try to keep in sync with dlls.sh
#
# Requires (Debian):
#   apt-get install libtool automake cmake nasm git
#   osxcross installed with osxcross-conf locatable
#   deb-src entries for stable in /etc/apt/sources.list
#
# Usage: dylibs-osx.sh <step> [build_path] [target_machine]
#
# targets:
#   macos-x86_64 x86_64-apple-darwin (requires osxcross with x86_64 target)
#   macos-arm64  arm64-apple-darwin (requires osxcross with arm64 target)

d0=$(readlink -m "$(dirname "$0")/../..") # xonotic.git/
eval $(osxcross-conf) || { echo "Couldn't load osxcross config."; exit 1; }
export PATH="$OSXCROSS_CCTOOLS_PATH:$PATH"

require ()
{
	if ! dpkg -s "$1" >/dev/null 2>&1; then
		echo "$1 package is required. Please install it."
		exit 1
	fi
}

prepare ()
{
	case $target_arch in
		macos-x86_64)
			ARCH=x86_64
			export MACOSX_DEPLOYMENT_TARGET="10.9"
			;;
		macos-arm64)
			ARCH=arm64
			export MACOSX_DEPLOYMENT_TARGET="11.0"
			;;
		*)
			echo "Invalid target machine (macos-x86_64 or macos-arm64)." && exit 1 ;;
	esac

	# Set directories
	src_dir="$buildpath/src"
	work_dir="$buildpath/work/$target_arch"
	pkg_dir="$buildpath/pkg/$target_arch"
	out_dir="$buildpath/out/$target_arch"

	# Derive the full target triple from the compiler	
	CHOST=$(xcrun clang -arch $ARCH --print-target-triple) \
		|| { echo "Cannot determine target triple."; exit 1; }

	CC="$CHOST-clang"
	CXX="$CHOST-clang++"
	if ! which "$CC" >/dev/null; then
		echo "Cross-compiler not found: $CC"
		exit 1
	fi

	export LDFLAGS="-L$pkg_dir/lib -L$OSXCROSS_BUILD_DIR/compiler-rt/compiler-rt/build/lib/darwin"
	export CPPFLAGS="-I$pkg_dir/include -I$OSXCROSS_BUILD_DIR/compiler-rt/compiler-rt/include"
	export OSXCROSS_PKG_CONFIG_LIBDIR="$pkg_dir/lib/pkgconfig:$pkg_dir/share/pkgconfig"
	export CODESIGN_ALLOCATE="$CHOST-codesign_allocate"
	ITN="$CHOST-install_name_tool"
	OTOOL="$CHOST-otool"

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
	# also work around cmake_minimum_required error.
	CMAKE_POLICY_VERSION_MINIMUM=3.31 \
	PKG_CONFIG="${CHOST}-pkg-config" \
	cmake \
		-DCMAKE_SYSTEM_NAME=Darwin \
		-DCMAKE_SYSTEM_PROCESSOR="$ARCH" \
		-DCMAKE_C_COMPILER="$CC" \
		-DCMAKE_CXX_COMPILER="$CXX" \
		-DCMAKE_INSTALL_NAME_DIR='@executable_path' \
		-DCMAKE_PREFIX_PATH="$pkg_dir" \
		-DCMAKE_INSTALL_PREFIX="$pkg_dir" \
		-DCMAKE_OSX_SYSROOT="$OSXCROSS_SDK" \
		-G"Unix Makefiles" \
		"$@" \
		"$src"
}

mkcd ()
{
	mkdir -p "$1"
	cd "$1"
}

build_zlib ()
{
	if fetch_source zlib ; then
		# Debian source package is missing the win32 resource file for some reason,
		# so we add it ourselves.
		# bones_was_here: it "needs" this even when compiling for macos on linux ...
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
		--disable-static \
		CC="$CC"
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
		--disable-static \
		CC="$CC"
	make
	make install
}

build_libogg ()
{
	fetch_source libogg || true

	mkcd "$work_dir/libogg"
	cmake_cross "$this_src" \
		-DBUILD_SHARED_LIBS=ON \
		-DINSTALL_DOCS=OFF
	make
	make install
}

build_libvorbis ()
{
	fetch_source libvorbis || true

	mkcd "$work_dir/libvorbis"
	cmake_cross "$this_src" \
		-DBUILD_SHARED_LIBS=ON
	make
	make install
}

build_libtheora ()
{
	if fetch_source libtheora ; then
		# Work around for "machine `arm64-apple' not recognized" (aarch64 same problem)
		sed -i 's/ armv\*-\* / armv\*-\* \| arm64-* /' "$this_src/config.sub"
	fi

	mkcd "$work_dir/libtheora"
	"$this_src/autogen.sh"
	# --disable-asm: theora assembly currently isn't compatible with osxcross
	"$this_src/configure" \
		--host="$CHOST" \
		--prefix="$pkg_dir" \
		--with-ogg="$pkg_dir" \
		--with-vorbis="$pkg_dir" \
		--disable-asm \
		--enable-shared \
		--disable-static \
		--disable-examples \
		--disable-vorbistest \
		--disable-oggtest \
		CC="$CC"
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

build_libcurl ()
{
	if fetch_source curl ; then
		rm "$this_src/debian/rules"
	fi

	mkcd "$work_dir/curl"
	# CURL_USE_SECTRANSP: SecureTransport was deprecated by Apple and support
	# removed in curl 8.15. Debian stable ships 8.14 so this is fine for now.
	# When Debian stable moves to curl 8.15+, switch to USE_APPLE_SECTRUST=ON
	# and add a TLS library (e.g. openssl or mbedtls) built and statically
	# linked into libcurl or shipped as an additional dylib.
	cmake_cross "$this_src" \
		-DCURL_USE_SECTRANSP=ON \
		-DCURL_USE_LIBPSL=OFF \
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
	LDFLAGS="$LDFLAGS -lclang_rt.osx" \
	cmake_cross "$this_src" \
		-DSDL_SHARED=ON \
		-DSDL_STATIC=OFF \
		-DSDL2_DISABLE_SDL2MAIN=ON \
		-DSDL_RENDER_METAL=OFF \
		-DSDL_METAL=OFF \
		-DSDL_TEST=OFF
	make
	make install
}

build_libode ()
{
	fetch_source ode || true

	mkcd "$work_dir/libode"
	cmake_cross "$this_src" \
		-DBUILD_SHARED_LIBS=ON \
		-DODE_WITH_DEMOS=OFF \
		-DODE_WITH_TESTS=OFF
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
#	build_zlib
	build_gmp
	build_libd0
	build_libogg
	build_libvorbis
	build_libtheora
	build_libpng16
	build_freetype
	build_libjpeg
#	build_libode
#	build_libcurl
	build_libsdl2
	build_libxmp
}

fix_install_names ()
{
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

install ()
{
	mkdir -p "$out_dir"

	cp -dv "$pkg_dir/lib/"*.dylib "$out_dir/"

	for dylib in "$out_dir/"*.dylib ; do
		if [ ! -h "$dylib" ]; then
			fix_install_names "$dylib"
		fi
	done
}

universal ()
{
	# Merge dylibs into universal (fat) dylibs using lipo.
	# Run 'all' for both macos-x86_64 and macos-arm64 first.
	if ! which lipo >/dev/null; then
		echo "lipo not found — check osxcross installation"
		exit 1
	fi

	local outx64="$buildpath/out/macos-x86_64"
	local outarm64="$buildpath/out/macos-arm64"
	local outuniv="$buildpath/out/universal"
	mkdir -p "$outuniv"

	set -ex

	for f in "$outx64"/*.dylib; do
		if [ -h "$f" ]; then
			cp -dv "$f" "$outuniv/"
			continue
		fi
		local name
		name=$(basename "$f")
		if [ -f "$outarm64/$name" ]; then
			lipo -create "$f" "$outarm64/$name" -output "$outuniv/$name"
		else
			echo "ERROR: $name missing from arm64 output"
			exit 1
		fi
	done
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
	echo libode
	echo libcurl
	echo libsdl2
	echo libxmp
}

usage ()
{
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
	echo "  universal  lipo x86_64+arm64 dylibs into universal dylibs"
	echo "  list       list compilable libraries"
	echo "  clean      delete all work directories"
	echo
	echo "arch:"
	echo "  x86_64     x86_64-apple-darwin"
	echo "  arm64      arm64-apple-darwin (requires arm64 osxcross target)"
}

step=$1
buildpath=$2
target_arch=$3

case $step in
	zlib)       prepare ; build_zlib ;;
	gmp)        prepare ; build_gmp ;;
	libd0)      prepare ; build_libd0 ;;
	libogg)     prepare ; build_libogg ;;
	libvorbis)  prepare ; build_libvorbis ;;
	libtheora)  prepare ; build_libtheora ;;
	libpng16)   prepare ; build_libpng16 ;;
	freetype)   prepare ; build_freetype ;;
	libjpeg)    prepare ; build_libjpeg ;;
	libode)     prepare ; build_libode ;;
	libcurl)    prepare ; build_libcurl ;;
	libsdl2)    prepare ; build_libsdl2 ;;
	libxmp)     prepare ; build_libxmp ;;
	build_all)  prepare ; build_all ;;
	install)    prepare ; install ;;
	all)        prepare ; build_all ; install ;;
	universal)  universal ;;
	clean)      clean ;;
	list)       list ;;
	*)          usage ;;
esac

#!/bin/bash
# build-dylibs-osx.sh — Build universal (arm64 + x86_64) dylibs and engine for Xonotic macOS
#
# This script reproduces the contents of misc/buildfiles/osx/Xonotic.app/Contents/MacOS/
# All dylibs and the main executable are built as universal binaries targeting macOS 10.15+.
#
# Prerequisites (install with Homebrew):
#   brew install cmake autoconf automake libtool pkg-config nasm gmp sdl2
#
# Usage:
#   cd /path/to/xonotic        # root of the xonotic meta-repo
#   ./all update               # clone/update darkplaces, d0_blind_id, etc.
#   misc/tools/build-dylibs-osx.sh
#
# Related issue: https://gitlab.com/xonotic/xonotic/-/issues/335

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
XONOTIC_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUTDIR="$XONOTIC_ROOT/misc/buildfiles/osx/Xonotic.app/Contents/MacOS"
BUILD_DIR="${TMPDIR:-/tmp}/xonotic-dylib-build"

export MACOSX_DEPLOYMENT_TARGET=10.15
CFLAGS_BASE="-mmacosx-version-min=10.15"
NCPU=$(sysctl -n hw.logicalcpu)

# Library versions
LIBOGG_VERSION=1.3.5
LIBVORBIS_VERSION=1.3.7
FREETYPE_VERSION=2.13.3
LIBJPEG_TURBO_VERSION=3.0.4
LIBPNG_VERSION=1.6.44
ODE_VERSION=0.16.5
LIBTHEORA_VERSION=1.1.1
SDL2_VERSION=2.32.4
GMP_VERSION=6.3.0

echo "==> Build directory: $BUILD_DIR"
echo "==> Output directory: $OUTDIR"
mkdir -p "$BUILD_DIR"

# Add Homebrew GNU libtool to PATH (avoids -force_cpusubtype_ALL issues)
export PATH="/opt/homebrew/opt/libtool/libexec/gnubin:$PATH"

# ============================================================
# Helper: build a simple autoconf lib for one arch
# build_autoconf_lib <srcdir> <arch> <host-triple> <extra-configure-args...>
# ============================================================
build_autoconf_lib() {
    local srcdir="$1"; local arch="$2"; local host="$3"; shift 3
    local builddir="$srcdir/build-$arch"
    mkdir -p "$builddir"
    (
        cd "$builddir"
        ../configure --host="$host" \
            CC="clang -arch $arch $CFLAGS_BASE" \
            --disable-static --enable-shared \
            --prefix="$(pwd)/inst" \
            "$@" 2>&1 | tail -3
        make -j"$NCPU" install 2>&1 | tail -3
    )
}

# ============================================================
# Step 0: Build GMP (static, for d0_blind_id)
# ============================================================
echo ""
echo "==> [0/8] Building GMP $GMP_VERSION (static bignum library for d0_blind_id)"
GMP_SRC="$BUILD_DIR/gmp-$GMP_VERSION"
if [ ! -f "$GMP_SRC/configure" ]; then
    curl -L -o "$BUILD_DIR/gmp-$GMP_VERSION.tar.xz" \
        "https://gmplib.org/download/gmp/gmp-$GMP_VERSION.tar.xz"
    tar xf "$BUILD_DIR/gmp-$GMP_VERSION.tar.xz" -C "$BUILD_DIR"
fi
for arch in arm64 x86_64; do
    bdir="$GMP_SRC/build-$arch"
    if [ ! -f "$bdir/inst/lib/libgmp.a" ]; then
        mkdir -p "$bdir"
        (cd "$bdir" && ../configure \
            CC="clang -arch $arch -mmacosx-version-min=10.15 -fPIC" \
            CFLAGS="-fPIC -O2" \
            --disable-shared --enable-static \
            --disable-assembly \
            --prefix="$(pwd)/inst" 2>&1 | tail -3
        make -j"$NCPU" install 2>&1 | tail -3)
    fi
done

# ============================================================
# Step 1: libogg
# ============================================================
echo ""
echo "==> [1/8] Building libogg $LIBOGG_VERSION"
OGG_SRC="$BUILD_DIR/libogg-$LIBOGG_VERSION"
if [ ! -f "$OGG_SRC/configure" ]; then
    curl -L -o "$BUILD_DIR/libogg-$LIBOGG_VERSION.tar.gz" \
        "https://downloads.xiph.org/releases/ogg/libogg-$LIBOGG_VERSION.tar.gz"
    tar xf "$BUILD_DIR/libogg-$LIBOGG_VERSION.tar.gz" -C "$BUILD_DIR"
fi
for arch in arm64 x86_64; do
    host=$([ "$arch" = "arm64" ] && echo "aarch64-apple-darwin" || echo "x86_64-apple-darwin")
    [ -f "$OGG_SRC/build-$arch/inst/lib/libogg.0.dylib" ] && continue
    build_autoconf_lib "$OGG_SRC" "$arch" "$host"
done
lipo -create "$OGG_SRC/build-arm64/inst/lib/libogg.0.dylib" \
             "$OGG_SRC/build-x86_64/inst/lib/libogg.0.dylib" \
     -output "$OUTDIR/libogg.0.dylib"
install_name_tool -id "@executable_path/libogg.0.dylib" "$OUTDIR/libogg.0.dylib"

# ============================================================
# Step 2: libvorbis (depends on libogg)
# ============================================================
echo ""
echo "==> [2/8] Building libvorbis $LIBVORBIS_VERSION"
VORBIS_SRC="$BUILD_DIR/libvorbis-$LIBVORBIS_VERSION"
if [ ! -f "$VORBIS_SRC/configure" ]; then
    curl -L -o "$BUILD_DIR/libvorbis-$LIBVORBIS_VERSION.tar.gz" \
        "https://downloads.xiph.org/releases/vorbis/libvorbis-$LIBVORBIS_VERSION.tar.gz"
    tar xf "$BUILD_DIR/libvorbis-$LIBVORBIS_VERSION.tar.gz" -C "$BUILD_DIR"
    # Remove -force_cpusubtype_ALL which is unsupported on modern Xcode
    sed -i '' 's/-force_cpusubtype_ALL//g' "$VORBIS_SRC/configure"
fi
for arch in arm64 x86_64; do
    host=$([ "$arch" = "arm64" ] && echo "aarch64-apple-darwin" || echo "x86_64-apple-darwin")
    OGG_INST="$OGG_SRC/build-$arch/inst"
    [ -f "$VORBIS_SRC/build-$arch/inst/lib/libvorbis.0.dylib" ] && continue
    build_autoconf_lib "$VORBIS_SRC" "$arch" "$host" \
        CPPFLAGS="-I$OGG_INST/include" \
        LDFLAGS="-L$OGG_INST/lib"
done
for lib in libvorbis.0 libvorbisenc.2 libvorbisfile.3; do
    lipo -create "$VORBIS_SRC/build-arm64/inst/lib/${lib}.dylib" \
                 "$VORBIS_SRC/build-x86_64/inst/lib/${lib}.dylib" \
         -output "$OUTDIR/${lib}.dylib"
    install_name_tool -id "@executable_path/${lib}.dylib" "$OUTDIR/${lib}.dylib"
done
# Fix inter-library references
for lib in libvorbis.0.dylib libvorbisenc.2.dylib libvorbisfile.3.dylib; do
    for old in $(otool -L "$OUTDIR/$lib" | grep "libogg\|libvorbis" | grep -v "@executable_path" | awk '{print $1}'); do
        base=$(basename "$old")
        install_name_tool -change "$old" "@executable_path/$base" "$OUTDIR/$lib"
    done
done

# ============================================================
# Step 3: libfreetype
# ============================================================
echo ""
echo "==> [3/8] Building libfreetype $FREETYPE_VERSION"
FT_SRC="$BUILD_DIR/freetype-$FREETYPE_VERSION"
if [ ! -f "$FT_SRC/configure" ]; then
    curl -L -o "$BUILD_DIR/freetype-$FREETYPE_VERSION.tar.gz" \
        "https://download.savannah.gnu.org/releases/freetype/freetype-$FREETYPE_VERSION.tar.gz"
    tar xf "$BUILD_DIR/freetype-$FREETYPE_VERSION.tar.gz" -C "$BUILD_DIR"
fi
for arch in arm64 x86_64; do
    host=$([ "$arch" = "arm64" ] && echo "aarch64-apple-darwin" || echo "x86_64-apple-darwin")
    [ -f "$FT_SRC/build-$arch/inst/lib/libfreetype.6.dylib" ] && continue
    build_autoconf_lib "$FT_SRC" "$arch" "$host" \
        --without-zlib --without-bzip2 --without-png
done
lipo -create "$FT_SRC/build-arm64/inst/lib/libfreetype.6.dylib" \
             "$FT_SRC/build-x86_64/inst/lib/libfreetype.6.dylib" \
     -output "$OUTDIR/libfreetype.6.dylib"
install_name_tool -id "@executable_path/libfreetype.6.dylib" "$OUTDIR/libfreetype.6.dylib"

# ============================================================
# Step 4: libjpeg-turbo (cmake-based)
# ============================================================
echo ""
echo "==> [4/8] Building libjpeg-turbo $LIBJPEG_TURBO_VERSION"
JPEG_SRC="$BUILD_DIR/libjpeg-turbo-$LIBJPEG_TURBO_VERSION"
if [ ! -f "$JPEG_SRC/CMakeLists.txt" ]; then
    curl -L -o "$BUILD_DIR/libjpeg-turbo-$LIBJPEG_TURBO_VERSION.tar.gz" \
        "https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/$LIBJPEG_TURBO_VERSION/libjpeg-turbo-$LIBJPEG_TURBO_VERSION.tar.gz"
    tar xf "$BUILD_DIR/libjpeg-turbo-$LIBJPEG_TURBO_VERSION.tar.gz" -C "$BUILD_DIR"
fi
for arch in arm64 x86_64; do
    [ -f "$JPEG_SRC/build-$arch/inst/lib/libjpeg.62.dylib" ] && continue
    cmake -S "$JPEG_SRC" -B "$JPEG_SRC/build-$arch" \
        -DCMAKE_OSX_ARCHITECTURES="$arch" \
        -DCMAKE_OSX_DEPLOYMENT_TARGET=10.15 \
        -DCMAKE_BUILD_TYPE=Release \
        -DENABLE_SHARED=ON -DENABLE_STATIC=OFF \
        -DCMAKE_INSTALL_PREFIX="$JPEG_SRC/build-$arch/inst" 2>&1 | tail -3
    cmake --build "$JPEG_SRC/build-$arch" -j"$NCPU" 2>&1 | tail -2
    cmake --install "$JPEG_SRC/build-$arch" 2>&1 | tail -2
done
lipo -create "$JPEG_SRC/build-arm64/inst/lib/libjpeg.62.dylib" \
             "$JPEG_SRC/build-x86_64/inst/lib/libjpeg.62.dylib" \
     -output "$OUTDIR/libjpeg.62.dylib"
install_name_tool -id "@executable_path/libjpeg.62.dylib" "$OUTDIR/libjpeg.62.dylib"

# ============================================================
# Step 5: libpng
# ============================================================
echo ""
echo "==> [5/8] Building libpng $LIBPNG_VERSION"
PNG_SRC="$BUILD_DIR/libpng-$LIBPNG_VERSION"
if [ ! -f "$PNG_SRC/configure" ]; then
    curl -L -o "$BUILD_DIR/libpng-$LIBPNG_VERSION.tar.gz" \
        "https://download.sourceforge.net/project/libpng/libpng16/$LIBPNG_VERSION/libpng-$LIBPNG_VERSION.tar.gz"
    tar xf "$BUILD_DIR/libpng-$LIBPNG_VERSION.tar.gz" -C "$BUILD_DIR"
fi
for arch in arm64 x86_64; do
    host=$([ "$arch" = "arm64" ] && echo "aarch64-apple-darwin" || echo "x86_64-apple-darwin")
    [ -f "$PNG_SRC/build-$arch/inst/lib/libpng16.16.dylib" ] && continue
    build_autoconf_lib "$PNG_SRC" "$arch" "$host"
done
lipo -create "$PNG_SRC/build-arm64/inst/lib/libpng16.16.dylib" \
             "$PNG_SRC/build-x86_64/inst/lib/libpng16.16.dylib" \
     -output "$OUTDIR/libpng16.16.dylib"
install_name_tool -id "@executable_path/libpng16.16.dylib" "$OUTDIR/libpng16.16.dylib"

# ============================================================
# Step 6: libode
# ============================================================
echo ""
echo "==> [6/8] Building libode $ODE_VERSION"
ODE_SRC="$BUILD_DIR/ode-$ODE_VERSION"
if [ ! -f "$ODE_SRC/configure" ]; then
    curl -L -o "$BUILD_DIR/ode-$ODE_VERSION.tar.gz" \
        "https://bitbucket.org/odedevs/ode/downloads/ode-$ODE_VERSION.tar.gz"
    tar xf "$BUILD_DIR/ode-$ODE_VERSION.tar.gz" -C "$BUILD_DIR"
fi
for arch in arm64 x86_64; do
    host=$([ "$arch" = "arm64" ] && echo "aarch64-apple-darwin" || echo "x86_64-apple-darwin")
    [ -f "$ODE_SRC/build-$arch/inst/lib/libode.8.dylib" ] && continue
    bdir="$ODE_SRC/build-$arch"
    mkdir -p "$bdir"
    (cd "$bdir" && ../configure --host="$host" \
        CC="clang -arch $arch $CFLAGS_BASE" \
        CXX="clang++ -arch $arch $CFLAGS_BASE" \
        --disable-static --enable-shared \
        --disable-demos --disable-tests \
        --prefix="$(pwd)/inst" 2>&1 | tail -3
    make -j"$NCPU" install 2>&1 | tail -3)
done
lipo -create "$ODE_SRC/build-arm64/inst/lib/libode.8.dylib" \
             "$ODE_SRC/build-x86_64/inst/lib/libode.8.dylib" \
     -output "$OUTDIR/libode.8.dylib"
install_name_tool -id "@executable_path/libode.8.dylib" "$OUTDIR/libode.8.dylib"
# Provide libode.3.dylib alias for backwards compatibility
cp "$OUTDIR/libode.8.dylib" "$OUTDIR/libode.3.dylib"
install_name_tool -id "@executable_path/libode.3.dylib" "$OUTDIR/libode.3.dylib"

# ============================================================
# Step 7: libtheora (manual build — configure.ac too old for autoreconf)
# ============================================================
echo ""
echo "==> [7/8] Building libtheora $LIBTHEORA_VERSION"
THEORA_SRC="$BUILD_DIR/libtheora-$LIBTHEORA_VERSION"
if [ ! -d "$THEORA_SRC" ]; then
    curl -L -o "$BUILD_DIR/libtheora-$LIBTHEORA_VERSION.tar.gz" \
        "https://downloads.xiph.org/releases/theora/libtheora-$LIBTHEORA_VERSION.tar.gz"
    tar xf "$BUILD_DIR/libtheora-$LIBTHEORA_VERSION.tar.gz" -C "$BUILD_DIR"
    # Remove -force_cpusubtype_ALL
    sed -i '' 's/-force_cpusubtype_ALL//g' "$THEORA_SRC/configure" 2>/dev/null || true
    # Update config.sub/config.guess to recognize aarch64
    cp /opt/homebrew/share/automake-*/config.sub "$THEORA_SRC/config.sub"
    cp /opt/homebrew/share/automake-*/config.guess "$THEORA_SRC/config.guess"
    cp /opt/homebrew/share/automake-*/compile "$THEORA_SRC/compile"
    cp /opt/homebrew/share/automake-*/missing "$THEORA_SRC/missing"
fi
# Build decoder-only manually (configure.ac uses macros incompatible with autoconf 2.7x)
THEORA_SRCS="apiwrapper bitpack decapiwrapper decinfo decode dequant fragment huffdec idct info internal quant state"
for arch in arm64 x86_64; do
    bdir="$BUILD_DIR/theora-obj-$arch"
    [ -f "$bdir/libtheora.0.dylib" ] && continue
    OGG_INST="$OGG_SRC/build-$arch/inst"
    mkdir -p "$bdir"
    for src in $THEORA_SRCS; do
        clang -arch "$arch" -mmacosx-version-min=10.15 -O2 -fPIC \
            -I"$THEORA_SRC/include" -I"$OGG_INST/include" \
            -c "$THEORA_SRC/lib/${src}.c" -o "$bdir/${src}.o" 2>/dev/null
    done
    clang -arch "$arch" -mmacosx-version-min=10.15 -dynamiclib \
        -install_name "@executable_path/libtheora.0.dylib" \
        -compatibility_version 3.0 -current_version 3.4 \
        -L"$OGG_INST/lib" -logg \
        "$bdir"/*.o -o "$bdir/libtheora.0.dylib"
done
lipo -create "$BUILD_DIR/theora-obj-arm64/libtheora.0.dylib" \
             "$BUILD_DIR/theora-obj-x86_64/libtheora.0.dylib" \
     -output "$OUTDIR/libtheora.0.dylib"
install_name_tool -id "@executable_path/libtheora.0.dylib" "$OUTDIR/libtheora.0.dylib"
for old in $(otool -L "$OUTDIR/libtheora.0.dylib" | grep "libogg" | grep -v "@executable_path" | awk '{print $1}'); do
    install_name_tool -change "$old" "@executable_path/libogg.0.dylib" "$OUTDIR/libtheora.0.dylib"
done

# ============================================================
# Step 8: d0_blind_id + d0_rijndael (Xonotic crypto)
# ============================================================
echo ""
echo "==> [8/8] Building d0_blind_id"
D0_SRC="$XONOTIC_ROOT/d0_blind_id"
if [ ! -f "$D0_SRC/configure" ]; then
    (cd "$D0_SRC" && autoreconf -i)
fi
for arch in arm64 x86_64; do
    host=$([ "$arch" = "arm64" ] && echo "aarch64-apple-darwin" || echo "x86_64-apple-darwin")
    GMP_INST="$BUILD_DIR/gmp-$GMP_VERSION/build-$arch/inst"
    [ -f "$D0_SRC/build-$arch/inst/lib/libd0_blind_id.0.dylib" ] && continue
    build_autoconf_lib "$D0_SRC" "$arch" "$host" \
        CPPFLAGS="-I$GMP_INST/include" \
        LDFLAGS="-L$GMP_INST/lib"
done
lipo -create "$D0_SRC/build-arm64/inst/lib/libd0_blind_id.0.dylib" \
             "$D0_SRC/build-x86_64/inst/lib/libd0_blind_id.0.dylib" \
     -output "$OUTDIR/libd0_blind_id.0.dylib"
lipo -create "$D0_SRC/build-arm64/inst/lib/libd0_rijndael.0.dylib" \
             "$D0_SRC/build-x86_64/inst/lib/libd0_rijndael.0.dylib" \
     -output "$OUTDIR/libd0_rijndael.0.dylib"
install_name_tool -id "@executable_path/libd0_blind_id.0.dylib" "$OUTDIR/libd0_blind_id.0.dylib"
install_name_tool -id "@executable_path/libd0_rijndael.0.dylib" "$OUTDIR/libd0_rijndael.0.dylib"

# ============================================================
# Step 9: DarkPlaces engine (arm64 + x86_64 universal)
# ============================================================
echo ""
echo "==> [9/9] Building DarkPlaces engine"
DP_SRC="$XONOTIC_ROOT/darkplaces"

# Build SDL2 x86_64 static (Homebrew SDL2 is arm64-only)
SDL2_X86_DIR="$BUILD_DIR/SDL2-$SDL2_VERSION/build-x86_64"
if [ ! -f "$SDL2_X86_DIR/inst/bin/sdl2-config" ]; then
    if [ ! -d "$BUILD_DIR/SDL2-$SDL2_VERSION" ]; then
        curl -L -o "$BUILD_DIR/SDL2-$SDL2_VERSION.tar.gz" \
            "https://github.com/libsdl-org/SDL/releases/download/release-$SDL2_VERSION/SDL2-$SDL2_VERSION.tar.gz"
        tar xf "$BUILD_DIR/SDL2-$SDL2_VERSION.tar.gz" -C "$BUILD_DIR"
    fi
    mkdir -p "$SDL2_X86_DIR"
    (cd "$SDL2_X86_DIR" && ../configure --host=x86_64-apple-darwin \
        CC="clang -arch x86_64 -mmacosx-version-min=10.15" \
        --disable-shared --enable-static \
        --prefix="$(pwd)/inst" 2>&1 | tail -5
    make -j"$NCPU" install 2>&1 | tail -3)
fi

# arm64 slice
(cd "$DP_SRC" && make clean 2>&1 | tail -2
make sdl-release \
    DP_MAKE_TARGET=macosx \
    CC="clang -arch arm64 -mmacosx-version-min=10.15" \
    DP_LINK_CRYPTO=dlopen \
    DP_LINK_CRYPTO_RIJNDAEL=dlopen \
    CFLAGS_EXTRA="-I$XONOTIC_ROOT" \
    2>&1 | grep -E "error:|^ld:.*error|strip darkplaces" | tail -5
cp darkplaces-sdl darkplaces-sdl-arm64)

# x86_64 slice
(cd "$DP_SRC" && make clean 2>&1 | tail -2
make sdl-release \
    DP_MAKE_TARGET=macosx \
    CC="clang -arch x86_64 -mmacosx-version-min=10.15" \
    DP_LINK_CRYPTO=dlopen \
    DP_LINK_CRYPTO_RIJNDAEL=dlopen \
    CFLAGS_EXTRA="-I$XONOTIC_ROOT" \
    SDL_CONFIG="$SDL2_X86_DIR/inst/bin/sdl2-config" \
    2>&1 | grep -E "error:|^ld:.*error|strip darkplaces" | tail -5
cp darkplaces-sdl darkplaces-sdl-x86_64)

# Universal binary
lipo -create "$DP_SRC/darkplaces-sdl-arm64" \
             "$DP_SRC/darkplaces-sdl-x86_64" \
     -output "$OUTDIR/xonotic-osx-sdl-bin"

# ============================================================
# Step 10: Code sign and verify
# ============================================================
echo ""
echo "==> Signing app bundle"
codesign --force --deep --sign - "$XONOTIC_ROOT/misc/buildfiles/osx/Xonotic.app"

echo ""
echo "==> Architecture verification"
for f in "$OUTDIR"/*; do
    NAME=$(basename "$f")
    [ -L "$f" ] && echo "  [symlink] $NAME" && continue
    INFO=$(lipo -info "$f" 2>/dev/null) || { echo "  [script]  $NAME"; continue; }
    if echo "$INFO" | grep -q "arm64" && echo "$INFO" | grep -q "x86_64"; then
        echo "  [OK universal] $NAME"
    elif echo "$INFO" | grep -qE "i386|ppc"; then
        echo "  [legacy, unchanged] $NAME"
    else
        echo "  [WARNING - not universal] $NAME: $(lipo -archs $f 2>/dev/null)"
    fi
done

echo ""
echo "==> Build complete. Test with:"
echo "    open $XONOTIC_ROOT/misc/buildfiles/osx/Xonotic.app"

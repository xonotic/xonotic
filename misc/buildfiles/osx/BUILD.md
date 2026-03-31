# macOS Bundle — Build Notes

This document explains the contents of `Xonotic.app/Contents/MacOS/`, how the bundle works, and how to reproduce the dylib and engine builds from source.

## How the bundle works

`xonotic-osx-sdl` is a shell script (not a binary). It:
1. Resolves symlinks so the app can be symlinked into `/Applications`
2. Sets `DYLD_LIBRARY_PATH="$SCRIPT_DIR"` pointing at the `MacOS/` folder
3. Calls `xonotic-osx-sdl-bin -basedir "$XONOTIC_DIR"`

`DYLD_LIBRARY_PATH` is what makes all the `.dylib` files findable at runtime. The engine binary itself has no embedded rpaths to these libraries — they are loaded via `dlopen()` or `DYLD_LIBRARY_PATH` as appropriate.

> **macOS security note:** On macOS 12.4+, `DYLD_LIBRARY_PATH` is stripped from processes launched from quarantined apps. If the game fails to load after downloading, remove quarantine: `xattr -dr com.apple.quarantine /path/to/Xonotic.app`

## Bundle contents

| File | Description |
|------|-------------|
| `xonotic-osx-sdl` | Launcher shell script |
| `xonotic-osx-sdl-bin` | Universal engine binary (arm64 + x86_64) |
| `libogg.0.dylib` | Ogg container (1.3.5) |
| `libvorbis.0.dylib` | Vorbis audio decode (1.3.7) |
| `libvorbisenc.2.dylib` | Vorbis encode (1.3.7) |
| `libvorbisfile.3.dylib` | Vorbis high-level API (1.3.7) |
| `libtheora.0.dylib` | Theora video decode (1.1.1) |
| `libfreetype.6.dylib` | FreeType font rendering (2.13.3) |
| `libjpeg.62.dylib` | JPEG decode via libjpeg-turbo (3.0.4) |
| `libpng16.16.dylib` | PNG decode (1.6.44) |
| `libode.8.dylib` | ODE physics (0.16.5, soversion 8) |
| `libode.3.dylib` | ODE compat alias (copy of libode.8) |
| `libd0_blind_id.0.dylib` | Crypto for server authentication |
| `libd0_rijndael.0.dylib` | Rijndael cipher |
| `libpng12.0.dylib` | Legacy (unused, kept for historical compat) |
| `libpng15.15.dylib` | Legacy (unused, kept for historical compat) |

All dylibs are universal fat binaries containing `arm64` and `x86_64` slices. All use `@executable_path/` install names.

SDL2 is **statically linked** into `xonotic-osx-sdl-bin` and does not appear as a separate dylib.

## Reproducing the build

`misc/tools/build-dylibs-osx.sh` is a self-contained script that downloads all source tarballs and builds both architecture slices from scratch. Run it from the repo root on an Apple Silicon Mac with Xcode command-line tools and Homebrew installed:

```sh
# Prerequisites
brew install automake libtool pkg-config gmp cmake

# Run from repo root (darkplaces/ must already be cloned via ./all update)
bash misc/tools/build-dylibs-osx.sh
```

The script builds everything into `/tmp/xonotic-build/` and copies finished files into `misc/buildfiles/osx/Xonotic.app/Contents/MacOS/`. It also builds the engine binary for both arches and combines them with `lipo`.

After the script completes, verify with:
```sh
for f in misc/buildfiles/osx/Xonotic.app/Contents/MacOS/*.dylib; do
    echo "=== $f ==="; lipo -info "$f"; otool -L "$f"; echo
done
lipo -info misc/buildfiles/osx/Xonotic.app/Contents/MacOS/xonotic-osx-sdl-bin
```

No dylib should have paths referencing `/tmp/`, `/opt/homebrew/`, or any absolute build directory — all deps must be `@executable_path/...`, `/usr/lib/`, `/System/`, or Apple frameworks.

## Building DarkPlaces manually

```sh
# arm64 (native on Apple Silicon)
make -C darkplaces sdl-release DP_MAKE_TARGET=macosx \
    DP_LINK_CRYPTO=dlopen

# x86_64 (cross-compile from Apple Silicon)
make -C darkplaces sdl-release DP_MAKE_TARGET=macosx \
    DP_LINK_CRYPTO=dlopen \
    CC="clang -arch x86_64" \
    SDL_CONFIG=/tmp/xonotic-build/SDL2-2.32.4/build-x86_64/inst/bin/sdl2-config

# Combine into universal binary
lipo -create \
    darkplaces/darkplaces-sdl \       # arm64 (built first)
    darkplaces/darkplaces-sdl-x86_64 \
    -output misc/buildfiles/osx/Xonotic.app/Contents/MacOS/xonotic-osx-sdl-bin
```

`DP_LINK_CRYPTO=dlopen` (the macOS default) loads `libd0_blind_id` at runtime via `DYLD_LIBRARY_PATH`. This avoids needing d0_blind_id headers and library present at DarkPlaces link time.

If `d0_blind_id/` headers are present in the repo, pass `CFLAGS_EXTRA="-I/path/to/xonotic"` so the compiler can find `d0_blind_id/d0_blind_id.h`.

## Known issues / decisions

- **libpng12 and libpng15** are dead weight — DarkPlaces searches for libpng16 first and these are never loaded on a modern system. They are retained to keep the diff minimal; removing them is a separate cleanup.
- **libode.3 vs libode.8** — ODE 0.16.5 changed its soversion from 3 to 8. Both are present: libode.8 is the real build, libode.3 is a copy for any older reference.
- **SDL2 is not a separate dylib** — it is statically linked into the engine binary on macOS. This was already the case before the arm64 work.
- **Code signing** — the script applies ad-hoc signing (`codesign --sign -`). The release team should re-sign with a proper Apple Developer certificate. Do not commit the `_CodeSignature/` directory (it is gitignored).

## Related

- GitLab issue: [#335](https://gitlab.com/xonotic/xonotic/-/issues/335) — Apple Silicon support
- Build script: `misc/tools/build-dylibs-osx.sh`
- Launcher script: `Xonotic.app/Contents/MacOS/xonotic-osx-sdl`

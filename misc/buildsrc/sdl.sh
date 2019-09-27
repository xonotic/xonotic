#!?bin/sh

set -ex

builddeps=$PWD/../builddeps
buildfiles=$PWD/../buildfiles

enter() {
	rm -rf tmp
	mkdir tmp
	cd tmp
}

leave() {
	cd ..
}

enter
curl -O http://libsdl.org/release/SDL2-2.0.10.dmg
7z x *.dmg
7z x *.hfs
rm -rf "$buildfiles/osx/Xonotic.app/Contents/Frameworks/SDL2.framework/Versions/A"
mv SDL2/SDL2.framework/Versions/A  "$buildfiles/osx/Xonotic.app/Contents/Frameworks/SDL2.framework/Versions/A"
git add "$buildfiles/osx/Xonotic.app/Contents/Frameworks/SDL2.framework/Versions/A"
leave

enter
curl -O http://libsdl.org/release/SDL2-2.0.10.tar.gz
tar xvf *.tar.gz
cd SDL2*/
LD_LIBRARY_PATH="$HOME/opt/cross_toolchain_32/x86_64-slackware-linux/i686-w64-mingw32/lib:$HOME/opt/cross_toolchain_32/libexec/gcc/i686-w64-mingw32/4.8.3" \
./configure --host=i686-w64-mingw32 --prefix="$PWD/../32" --disable-shared --enable-static CC="$HOME/opt/cross_toolchain_32/bin/i686-w64-mingw32-gcc -g1 -mstackrealign -Wl,--dynamicbase -Wl,--nxcompat"
LD_LIBRARY_PATH="$HOME/opt/cross_toolchain_32/x86_64-slackware-linux/i686-w64-mingw32/lib:$HOME/opt/cross_toolchain_32/libexec/gcc/i686-w64-mingw32/4.8.3" \
make
make install
sed -i 's,^prefix=.*,prefix=${0%/bin/sdl2-config},' ../32/bin/sdl2-config
rm -rf "$builddeps/win32/sdl"
mv ../32 "$builddeps/win32/sdl"
git add "$buillddeps/win32/sdl"
make clean
LD_LIBRARY_PATH="$HOME/opt/cross_toolchain_64/x86_64-slackware-linux/x86_64-w64-mingw32/lib:$HOME/opt/cross_toolchain_64/libexec/gcc/x86_64-w64-mingw32/4.8.3" \
./configure --host=i686-w64-mingw32 --prefix="$PWD/../64" --disable-shared --enable-static CC="$HOME/opt/cross_toolchain_64/bin/x86_64-w64-mingw32-gcc -g1 -Wl,--dynamicbase -Wl,--nxcompat"
LD_LIBRARY_PATH="$HOME/opt/cross_toolchain_64/x86_64-slackware-linux/x86_64-w64-mingw32/lib:$HOME/opt/cross_toolchain_64/libexec/gcc/x86_64-w64-mingw32/4.8.3" \
make
make install
sed -i 's,^prefix=.*,prefix=${0%/bin/sdl2-config},' ../64/bin/sdl2-config
rm -rf "$builddeps/win64/sdl"
mv ../64 "$builddeps/win64/sdl"
git add "$buillddeps/win64/sdl"
make clean
leave

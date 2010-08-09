#!/bin/sh

# all these shall be defined in a .brand file passed as first argument
flags="-quake"
name=DarkPlaces-Quake
dirname1=id1
dirname2=
screenshotname=dp
userdirname=darkplaces
icon_icns=Darkplaces.app/Contents/Resources/Darkplaces.icns
icon_ico=darkplaces.ico
icon_xpm=darkplaces.xpm

. "$1"; shift

d=`pwd`
t=`mktemp -d -t darkplaces-rebrand.XXXXXX`

flags="$flags -customgamename \"$name\" -customgamedirname1 \"$dirname1\" -customgamedirname2 \"$dirname2\" -customgamescreenshotname \"$screenshotname\" -customgameuserdirname \"$userdirname\""
echo "$flags" > "$t/darkplaces.opt"

cd "$t"
zip -9r darkplaces.zip darkplaces.opt
rm -f darkplaces.opt
cd "$d"

for EXECUTABLE in "$@"; do
	uses_xpm=false
	uses_ico=false
	uses_icns=false

	# detect what the executable is
	case "`file -b "$EXECUTABLE"`" in
		*ELF*)
			case "$EXECUTABLE" in
				*-dedicated)
					;;
				*)
					uses_xpm=true
					;;
			esac
			;;
		*Mach*)
			uses_icns=true
			case "$EXECUTABLE" in
				*-sdl)
					uses_xpm=true
					;;
				*)
					;;
			esac
			;;
		*PE*)
			uses_ico=true
			;;
	esac

	# add a selfpack
	cp "$t/darkplaces.zip" "$t/darkplaces-this.zip"

	if $uses_xpm; then
		cp "$icon_xpm" "$t/darkplaces-icon.xpm"
		cd "$t"
		zip -9r darkplaces-this.zip darkplaces-icon.xpm
		cd "$d"
	fi

	if $uses_ico; then
		cp "$icon_ico" "$t/darkplaces-icon.ico"
		cp "$EXECUTABLE" "$t/darkplaces.exe"
		cat >"$t/darkplaces.rc" <<EOF
#include <windows.h> // include for version info constants

A ICON MOVEABLE PURE LOADONCALL DISCARDABLE "darkplaces-icon.ico"

1 VERSIONINFO
FILEVERSION 1,0,0,0
PRODUCTVERSION 1,0,0,0
FILETYPE VFT_APP
{
  BLOCK "StringFileInfo"
	 {
		 BLOCK "040904E4"
		 {
			 VALUE "CompanyName", "Forest Hale Digital Services"
			 VALUE "FileVersion", "1.0"
			 VALUE "FileDescription", "$name"
			 VALUE "InternalName", "${EXECUTABLE##*/}"
			 VALUE "LegalCopyright", "id Software, Forest Hale, and contributors"
			 VALUE "LegalTrademarks", ""
			 VALUE "OriginalFilename", "${EXECUTABLE##*/}"
			 VALUE "ProductName", "$name"
			 VALUE "ProductVersion", "1.0"
		 }
	 }
}
EOF
		cd "$t"
		wine "c:/Program Files/ResEdit/ResEdit.exe" -convert darkplaces.rc darkplaces.exe
		cd "$d"
		mv "$t/darkplaces.exe" "$EXECUTABLE"
	fi

	if $uses_icns; then
		# OS X is special here
		case "$EXECUTABLE" in
			*/*)
				pkgdir="${EXECUTABLE%/*}/.."
				;;
			*)
				pkgdir=..
				;;
		esac
		cp "$icon_icns" "$pkgdir/Resources/Darkplaces.icns"
		cat <<EOF >"$pkgdir/Resources/English.lproj/InfoPlist.strings"
/* Localized versions of Info.plist keys */

CFBundleName = "$name";
CFBundleShortVersionString = "$name";
CFBundleGetInfoString = "Darkplaces by Forest 'LordHavoc' Hale";
NSHumanReadableCopyright = "Copyright `date +%Y`";
EOF
	fi

	cat "$t/darkplaces-this.zip" >> "$EXECUTABLE"
done

rm -rf "$t"

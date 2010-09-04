#!/bin/sh

d=`pwd`
t=`mktemp -d -t change-icon-of-exe.XXXXXX`
cp "$1" "$t/darkplaces-icon.ico"
cp "$2" "$t/darkplaces.exe"
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
			 VALUE "FileDescription", "DarkPlaces Game Engine"
			 VALUE "InternalName", "darkplaces.exe"
			 VALUE "LegalCopyright", "id Software, Forest Hale, and contributors"
			 VALUE "LegalTrademarks", ""
			 VALUE "OriginalFilename", "darkplaces.exe"
			 VALUE "ProductName", "DarkPlaces"
			 VALUE "ProductVersion", "1.0"
		 }
	 }
}
EOF
cd "$t"
wine "c:/Program Files/ResEdit/ResEdit.exe" -convert darkplaces.rc darkplaces.exe
cd "$d"
mv "$t/darkplaces.exe" "$EXECUTABLE"
rm -rf "$t"

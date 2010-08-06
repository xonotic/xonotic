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

flags="$flags -customgamename \"$name\" -customgamedirname1 \"$dirname1\" -customgamedirname2 \"$dirname2\" -customgamescreenshotname \"$screenshotname\" -customuserdirname \"$userdirname\""
echo "$flags" > darkplaces.opt

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
	rm -f darkplaces.zip
	zip -9r darkplaces.zip darkplaces.opt

	if $uses_xpm; then
		cp "$icon_xpm" darkplaces-icon.xpm
		zip -9r darkplaces.zip darkplaces-icon.xpm
		rm -f darkplaces-icon.xpm
	fi

#	if $uses_ico; then
#		e=$EXECUTABLE \
#		i=$icon_ico \
#		n=$name \
#		perl <<'EOF'
#		use strict;
#		use warnings;
#		use Win32::Exe;
#
#		my $n = $ENV{n};
#		my $i = $ENV{i};
#		my $e = $ENV{e};
#
#		my $exe = Win32::Exe->new($e)
#			or die "Win32::Exe->new: $!";
#		$exe = $exe->create_resource_section()
#			unless $exe->has_resource_section();
#		$exe->update(icon => $i);
#		$exe->update(info => ["InternalName=$e"]);
#		$exe->update(info => ["OriginalFilename=$e"]);
#		$exe->update(info => ["ProductName=$n"]);
#		$exe->write($e)
#			or die "Win32::Exe->write: $!";
#EOF
#	fi

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

	cat darkplaces.zip >> "$EXECUTABLE"
	rm -f darkplaces.zip
done

rm -f darkplaces.opt

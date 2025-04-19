#!/bin/sh

path=$(dirname "${0}")
link=$(readlink -f "${0}")

[ -n "${link}" ] && path=$(dirname "${link}")
cd "${path}" || exit 1

case "${0##*/}" in
  *dedicated*)  mode="dedicated" ;;
  *)            mode="sdl" ;;
esac

case $(uname):$(uname -m) in
  Linux:x86_64)  arch="linux64" ;;
  *)             arch="local"   ;;  # Not pre-built but you can build your own
esac

# prefer locally built binary if available (see: Makefile)
xonotic="xonotic-${mode}"
[ -x "$xonotic" ] || xonotic="xonotic-${arch}-${mode}"
echo "Executing: $xonotic ${*}"

set -- ./${xonotic} "${@}"

xserver=
xlayout=

setdisplay()
{
	VALUE=$1
	VALUE=${VALUE#\"}
	VALUE=${VALUE%\"}
	case "$VALUE" in
		:*)
			;;
		*)
			VALUE=:$VALUE
			;;
	esac
	VALUE="$VALUE/"
	xserver="${VALUE%%/*}"
	xserver=${xserver#:}
	xlayout=${VALUE#*/}
	xlayout=${xlayout%/}
}

# now how do we execute it?
if [ -r ~/.xonotic/data/config.cfg ]; then
	while read -r CMD KEY VALUE; do
		case "$CMD:$KEY" in
			seta:vid_x11_display)
				setdisplay "$VALUE"
				;;
		esac
	done < ~/.xonotic/data/config.cfg
fi

m=0
for X in "$@"; do
	case "$m:$X" in
		0:+vid_x11_display)
			m=1
			;;
		0:+vid_x11_display\ *)
			setdisplay "${X#+vid_x11_display }"
			;;
		1:*)
			setdisplay "$X"
			m=0
			;;
		*)
			;;
	esac
done

case "$xserver" in
	'')
		;;
	*[!0-9]*)
		echo "Not using display ':$xserver': evil characters"
		;;
	*)
		msg=
		lf='
'
		prefix=

		# check for a listening X server on that socket
		if netstat -nl | grep -F " /tmp/.X11-unix/X$xserver" >/dev/null; then
			# X server already exists
			export DISPLAY=:$xserver
			prefix="DISPLAY=:$xserver "
			msg=$msg$lf"- Running Xonotic on already existing display :$xserver"
		else
			set -- startx "$@" -fullscreen -- ":$xserver"
			msg=$msg$lf"- Running Xonotic on a newly created X server :$xserver."
			case "$xlayout" in
				'')
					;;
				*[!A-Za-z0-9]*)
					echo >&2 "Not using layout '$xlayout': evil characters"
					xlayout=
					;;
				*)
					set -- "$@" -layout "$xlayout"
					msg=$msg$lf"- Using the ServerLayout section named $xlayout."
					;;
			esac
		fi

		echo "X SERVER OVERRIDES IN EFFECT:$msg"
		echo
		echo "Resulting command line:"
		echo "  $prefix$*"
		echo
		echo "To undo these overrides, edit ~/.xonotic/data/config.cfg and remove the line"
		echo "starting with 'seta vid_x11_display'."
		echo
		echo
		;;
esac

if which "$1" > /dev/null
then
	exec "$@"
else
	echo "Could not find $1 to exec"
	if [ "$arch" = "local" ]
	then
		printf "%b\n%b\n" "Xonotic does not currently provide pre-built $(uname):$(uname -m) builds, please compile one using make" \
			"More info is available at \e[1;36mhttps://gitlab.com/xonotic/xonotic/-/wikis/Compiling\e[m"
	fi
fi

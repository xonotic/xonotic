#!/bin/sh

path=`dirname "${0}"`
link=`readlink -f "${0}"`

[ -n "${link}" ] && path=`dirname "${link}"`
cd "${path}"

case "${0##*/}" in
  *dedicated*)	mode="dedicated" ;;
  *sdl*)	mode="sdl" ;;
  *)		mode="glx" ;;
esac

case "$(uname -m)" in
  i?86)	arch="linux32" ;;  # Not supported anymore but you can build your own.
  *)	arch="linux64" ;;
esac

xonotic="xonotic-${arch}-${mode}"

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

# if pulseaudio
if [ -z "$SDL_AUDIODRIVER" ]; then
	if ps -C pulseaudio >/dev/null; then
		if ldd /usr/lib/libSDL.so 2>/dev/null | grep pulse >/dev/null; then
			export SDL_AUDIODRIVER=pulse
		fi
	fi
fi

exec "$@"

#!/bin/sh

use_magnet_to_acquire_checksum_faster()
#             ___________________
#        ,--'' ~~~~~~~^^^~._     '.
#    ,.-' ~~~~~~~~~~^^^^^~~~._._   \
#    |   /^^^^^|    /^^^^^^^^\\ \   \
#  ,/___  <  o>      <  (OO) > _     \
# /'/,         |-         .       ----.\
# |(|-'^^;,-  ,|     __    ^~~^^^^^^^; |\
# \\`  |    <;_    __ |`---  ..-^^/- | ||
#  \`-|Oq-.____`________~='^^|__,/  ' //
#   \ || | |   |  |    \ ..-;|  /    '/
#   | ||#|#|the|==|game!|'^` |/'    /'
#   | \\\\^\***|***|    \ ,,;'     /
#   |  `-=\_\__\___\__..-' ,.- - ,/
#   | . `-_  ------   _,-'^-'^,-'
#   | `-._________..--''^,-''^
#   \             ,...-'^
#    `----------'^              PROBLEM?
{
	magnet=`GIT_DIR="$git_src_repo/.git" git ls-files -s "$1"`
	if [ -n "$magnet" ]; then
		magnet=${magnet#* }
		magnet=${magnet%% *}
		echo "$magnet"
	else
		git hash-object "$1"
	fi
}

lastinfiles=
lastinfileshash=
acquire_checksum()
{
	if [ x"$1/../$2" = x"$lastinfiles" ]; then
		_a_s=$lastinfileshash
	else
		_a_e=false
		for _a_f in "$1" "$2"; do
			case "$_a_f" in
				*/background_l2.tga|*/background_ingame_l2.tga)
					_a_e=true
					;;
			esac
		done
		if [ -n "$git_src_repo" ] && ! $_a_e; then
			_a_s=`use_magnet_to_acquire_checksum_faster "${1#./}"`
			if [ -n "$2" ]; then
				_a_s=$_a_s`use_magnet_to_acquire_checksum_faster "${2#./}"`
			fi
		else
			_a_s=`git hash-object "$1"`
			if [ -n "$2" ]; then
				_a_s=$_a_s`git hash-object "$2"`
			fi
		fi
		lastinfileshash=$_a_s
		lastinfiles="$1/../$2"
	fi
	echo "$_a_s"
}

make_relative_path()
{
	from=$1
	to=$2
	pre=
	post=
	while :; do
		case "$from" in
			*/*)
				case "$to" in
					*/*)
						fromfirst=${from%%/*}
						fromrest=${from#*/}
						tofirst=${to%%/*}
						torest=${to#*/}
						if [ x"$fromfirst" = x"$tofirst" ]; then
							from=$fromrest
							to=$torest
						else
							to=$tofirst
							post=/$torest
							pre=../$pre
							from=$fromrest # now we can only hit the ../ path or the bottom one
						fi
						;;
					*)
						# from has path, to does not
						# we need a ../ component then try again
						pre=../$pre
						from=${from#*/}
						;;
				esac
				;;
			*)
				echo "$pre$to$post"
				break
				;;
		esac
	done
}

killed=0
while IFS= read -r L; do
	s=`acquire_checksum "$L"`
	eval first=\$first_$s
	if [ -n "$first" ]; then
		first_r=`make_relative_path "$L" "$first"`
		killed=$((`stat -c %s "$L"` + $killed))
		ln -vsnf "$first_r" "$L"
	else
		eval first_$s=\$L
	fi
done
echo "Killed $(($killed / 1048576)) MiB"

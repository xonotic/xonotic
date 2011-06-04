#!/bin/sh

case "$(uname -m)" in
  x86_64)	executable="xonotic-linux64-dedicated" ;;
  *)		executable="xonotic-linux32-dedicated" ;;
esac

cd "`dirname "${0}"`"

if ! [ -x "$executable" ]; then
	if [ -x "../$executable" ] && { [ -f ~/.xonotic/data/server.cfg ] || [ -f ../data/server.cfg ]; }; then
		cd ..
	else
		echo "This script is not properly set up yet."
		echo "Please refer to the instructions in readme.txt."
		echo "In short:"
		echo "- copy server.cfg to the data directory and adjust its settings"
		echo "- move this file to the main directory of your Xonotic installation"
		exit 1
	fi
fi

exec ./${executable} +serverconfig server.cfg "${@}"

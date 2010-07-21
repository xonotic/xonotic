#!/bin/sh

case "$0" in
	/*)
		me=$0
		;;
	*)
		me="$PWD/$0"
		;;
esac
export me

case "$1" in
	inner)
		git config core.autocrlf input
		git reset --hard
		git for-each-ref 'refs/remotes/origin' | while read -r HASH TYPE REFNAME; do
			git checkout -t "${REFNAME#refs/remotes/}" || git checkout "${REFNAME#refs/remotes/origin/}"
			git reset --hard "$REFNAME"
			cp "${me%/*}/.gitattributes" .
			git update-index --refresh
			git commit -a -m"CRLF"
		done
		;;
	*)
		./all each "$me" inner
		;;
esac

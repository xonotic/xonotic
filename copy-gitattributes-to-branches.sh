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
			case "$REFNAME" in
				refs/remotes/origin/HEAD)
					continue
					;;
			esac
			git checkout -t "${REFNAME#refs/remotes/}" || git checkout "${REFNAME#refs/remotes/origin/}"
			git reset --hard "$REFNAME"
			echo "$attr" > ".gitattributes"
			find . -type f -exec touch {} \+
			git update-index --refresh
			git add .gitattributes
			git commit -a -m"CRLF fixes, .gitattributes file updated"
		done
		git checkout master
		true
		;;
	*)
		attr=`cat .gitattributes`
		export attr
		./all each "$me" inner
		./all checkout
		;;
esac

#!/bin/sh

set -e

#exec >/dev/null 2>&1

mkdir -p /var/cache/git/xonotic
cd /var/cache/git/xonotic
ssh xonotic@git.xonotic.org ./send-git-configs.sh | tar xvf -

for X in /var/cache/git/*/*.git; do
	cd "$X"
	git config remote.origin.fetch "+refs/*:refs/*"
	git config remote.origin.mirror "true"
	git config remote.origin.url "git://nl.git.xonotic.org/${X#/var/cache/git/}"
	git fetch
	git remote prune origin
	git gc --auto
	touch git-daemon-export-ok
done

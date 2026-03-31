#!/bin/sh

url="$1"
desc="$2"

set -e
. /data/common.sh
LockAndLog ~/"$(basename "${0%.*}").log" 600

cd /data/git/xonotic

if [ -n "$url" ]; then
	repo=$(basename "$url")

	# If the push was to a repo that's not mirrored, mirror it now
	if ! [ -d "$repo" ]; then
		printf "\n\tCloning new mirror of $repo ...\n"
		git clone --bare "$url" "$repo" # not using --mirror as we'll use our own refspec config
	fi

	# Copy gitlab repo description (first line only)
	printf "\n\tUpdating description of $repo ...\n"
	printf "%s\n" "$desc" | sed -E 's/(\n|\r|\\n|\\r).*//' > $repo/description
fi

printf "\n\tUpdating all existing mirrors in parallel...\n"
git_mirror_fetch()
{
	cd "$1"
	# git clone --mirror sets +refs/*:refs/* but we don't want misc/temp refs from gitlab features
	git config set --all remote.origin.fetch "+refs/heads/*:refs/heads/*"
	git config set --append remote.origin.fetch "+refs/tags/*:refs/tags/*"
	git config set core.logAllRefUpdates true # off by default in bare/mirror clones so push_ts is "" until 1st push :)
#	git config remote.origin.mirror "true"
#	git config remote.origin.url "https://gitlab.com/xonotic/$1"
	git fetch --prune
	git gc --auto
	touch git-daemon-export-ok
	git config set uploadpack.allowFilter true

	# https://git.zx2c4.com/cgit/tree/contrib/hooks/post-receive.agefile
	agefile=info/web/last-modified
	mkdir -p "$(dirname "$agefile")"
	push_ts=$(git log -g -n 1 --format='format:%gd' --date=iso8601 $(git reflog list) | sed -E 's/.*@\{(.*)\}.*/\1/')
	if [ -n "$push_ts" ]; then
		echo "$push_ts" > "$agefile"
	else
		git for-each-ref \
			--sort=-committerdate --count=1 \
			--format='%(committerdate:iso8601)' \
			>"$agefile"
	fi
}
pids=
for R in *.git; do
	git_mirror_fetch "$R" &
	pids="$pids $!"
done
# Fail if any mirror update fails
for pid in $pids; do
	wait $pid
done


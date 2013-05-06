#!/bin/sh

set -e

action=$1
outdir=$2
repodir=$3

branches()
{
	git for-each-ref 'refs/remotes' | grep -vE '	refs/remotes/([^/]*/HEAD|.*/archived/.*)$'
}

escape_html()
{
	sed -e 's/&/\&amp;/g; s/</&lt;/g; s/>/&gt;/g'
}

to_rss()
{
	outdir=$1
	name=$2
	masterhash=$3
	masterbranch=$4
	hash=$5
	branch=$6
	repo=$7

	filename=`echo -n "$name" | tr -c 'A-Za-z0-9' '_'`.rss
	outfilename="$outdir/$filename"
	masterbranch=`echo -n "$masterbranch" | escape_html`
	branch=`echo -n "$branch" | escape_html`
	repo=`echo -n "$repo" | escape_html`

	if [ -n "$repo" ]; then
		repotxt=" in $repo"
	else
		repotxt=
	fi
	against="$masterbranch at $masterhash"

	if ! [ -f "$outfilename" ]; then
		datetime=`date --rfc-2822`
		cat >"$outfilename" <<EOF
<?xml version="1.0" encoding="UTF-8" ?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
<channel>
	<title>XonCW: $name</title>
	<link>http://git.xonotic.org/</link>
	<description>Xonotic Conflict Watch for branches by $name</description>
	<ttl>10800</ttl>
	<atom:link href="http://nl.git.xonotic.org/xoncw/$filename" rel="self" type="application/rss+xml" />
	<lastBuildDate>$datetime</lastBuildDate>
EOF
	fi
	cat >>"$outfilename" <<EOF
	<item>
		<title>$branch$repotxt</title>
		<link>http://git.xonotic.org/?p=$repo;a=shortlog;h=refs/heads/$branch</link>
		<guid isPermaLink="false">http://nl.git.xonotic.org/xoncw/$filename#$hash</guid>
		<description><![CDATA[
		Conflicts of $branch at $hash against $against:
EOF
 
	echo -n "<pre>" >>"$outfilename"
	escape_html >>"$outfilename"
	echo "</pre>" >>"$outfilename"

	cat >>"$outfilename" <<EOF
		]]></description>
	</item>
EOF
}

clear_rss()
{
	datetime=`date --rfc-2822`
	sed -i -e '/<lastBuildDate>/,$d' "$1"
	cat <<EOF >>"$1"
	<lastBuildDate>$datetime</lastBuildDate>
EOF
}

finish_rss()
{
	cat <<EOF >>"$1"
</channel>
</rss>
EOF
}

if [ -z "$outdir" ]; then
	set --
fi

repo=$(
	(
		if [ -n "$repodir" ]; then
			cd "$repodir"
		fi
		git config remote.origin.url | cut -d / -f 4-
	)
)

case "$action" in
	--init)
		mkdir -p "$outdir"
		for f in "$outdir"/*; do
			[ -f "$f" ] || continue
			clear_rss "$f"
		done
		;;
	--finish)
		for f in "$outdir"/*; do
			[ -f "$f" ] || continue
			finish_rss "$f"
		done
		;;
	--add)
		masterhash=$(
			(
				if [ -n "$repodir" ]; then
					cd "$repodir"
				fi
				git rev-parse HEAD
			)
		)
		masterbranch=$(
			(
				if [ -n "$repodir" ]; then
					cd "$repodir"
				fi
				git symbolic-ref HEAD
			)
		)
		masterbranch=${masterbranch#refs/heads/}

		masterhash2=$(
			(
				if [ -n "$repodir" ]; then
					cd "$repodir"
				fi
				git rev-parse master
			)
		)
		masterbranch2=master

		(
		 	if [ -n "$repodir" ]; then
				cd "$repodir"
			fi
			branches
		) | while read -r HASH TYPE REFNAME; do
			echo >&2 -n "$repo $REFNAME..."
			case "$repo:$REFNAME" in
				xonotic/netradiant.git:refs/remotes/origin/divVerent/zeroradiant) continue ;;
				xonotic/netradiant.git:refs/remotes/origin/divVerent/zeroradiant-original) continue ;;
				xonotic/netradiant.git:refs/remotes/origin/divVerent/zeroradiant-split-up-the-q3map2-commit) continue ;;
				xonotic/netradiant.git:refs/remotes/origin/divVerent/zeroradiant-split-up-the-q3map2-commit-goal) continue ;;
				xonotic/darkplaces.git:refs/remotes/origin/dp-mqc-render) continue ;;
			esac

			if [ x"$masterhash" = x"$masterhash2" ]; then
				thismasterhash=$masterhash
				thismasterbranch=$masterbranch
			else
				l=$(
					if [ -n "$repodir" ]; then
						cd "$repodir"
					fi
					git rev-list "$masterhash".."$REFNAME" | wc -l
				)
				l2=$(
					if [ -n "$repodir" ]; then
						cd "$repodir"
					fi
					git rev-list "$masterhash2".."$REFNAME" | wc -l
				)
				if [ $l -gt $l2 ]; then
					thismasterhash=$masterhash2
					thismasterbranch=$masterbranch2
				else
					thismasterhash=$masterhash
					thismasterbranch=$masterbranch
				fi
			fi
				
			out=$(
				(
					if [ -n "$repodir" ]; then
						cd "$repodir"
					fi
					git reset --hard "$thismasterhash" >/dev/null 2>&1
					if out=`git merge --no-commit -- "$REFNAME" 2>&1`; then
						good=true
					else
						good=false
						echo "$out"
					fi
					git reset --hard "$masterhash" >/dev/null 2>&1
				)
			)
			if [ -n "$out" ]; then
				b=${REFNAME#refs/remotes/[!/]*/}
				case "$b" in
					*/*)
						n=${b%%/*}
						;;
					*)
						n=divVerent
						;;
				esac
				echo "$out" | to_rss "$outdir" "$n" "$thismasterhash" "$thismasterbranch" "$HASH" "$b" "$repo"
				echo >&2 " CONFLICT"
			else
				echo >&2 " ok"
			fi
		done
		;;
	*)
		echo "Usage: $0 --init OUTDIR"
		echo "       $0 --add OUTDIR [REPODIR]"
		echo "       $0 --finish OUTDIR"
		exit 1
		;;
esac

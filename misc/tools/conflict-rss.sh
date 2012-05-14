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

	if ! [ -f "$outfilename" ]; then
		datetime=`date --rfc-2822`
		cat >"$outfilename" <<EOF
<?xml version="1.0" encoding="UTF-8" ?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
<channel>
	<title>XonCW: $name</title>
	<link>http://git.xonotic.org/</link>
	<description>Xonotic Conflict Watch for branches by $name</description>
	<ttl>3600</ttl>
	<atom:link href="http://de.git.xonotic.org/conflicts/$filename" rel="self" type="application/rss+xml" />
	<lastBuildDate>$datetime</lastBuildDate>
EOF
	fi
	cat >>"$outfilename" <<EOF
	<item>
		<title>$branch$repotxt</title>
		<link>http://git.xonotic.org/?p=$repo;a=shortlog;h=refs/heads/$name/$branch</link>
		<guid isPermaLink="false">http://de.git.xonotic.org/conflicts/$filename#$hash</guid>
		<description><![CDATA[
		Conflicts of $branch at $hash against $masterbranch at $masterhash:
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
		(
		 	if [ -n "$repodir" ]; then
				cd "$repodir"
			fi
			branches
		) | while read -r HASH TYPE REFNAME; do
			echo >&2 -n "$repo $REFNAME..."
			out=$(
				(
					if [ -n "$repodir" ]; then
						cd "$repodir"
					fi
					git reset --hard "$masterhash" >/dev/null 2>&1
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
				b=${REFNAME#refs/remotes/[^/]*/}
				case "$b" in
					*/*)
						n=${b%%/*}
						;;
					*)
						n=divVerent
						;;
				esac
				echo "$out" | to_rss "$outdir" "$n" "$masterhash" "$masterbranch" "$HASH" "$b" "$repo"
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

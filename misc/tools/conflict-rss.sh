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
	hash=$3
	branch=$4

	filename=$outdir/`echo -n "$name" | tr -c 'A-Za-z0-9' '_'`.xml
	datetime=`date --rfc-2822`
	branch=`echo "$branch" | escape_html`

	if ! [ -f "$filename" ]; then
		cat >"$filename" <<EOF
<?xml version="1.0" encoding="UTF-8" ?>
<rss version="2.0">
<channel>
	<title>Merge conflicts for $name</title>
	<link>...</link>
	<description>...</description>
	<lastBuildDate>$datetime</lastBuildDate>
	<ttl>3600</ttl>
EOF
	fi
	cat >>"$filename" <<EOF
	<item>
		<title>$branch ($hash)</title>
		<link>...</link>
		<description><![CDATA[
EOF

	escape_html >>"$filename"

	cat >>"$filename" <<EOF
		]]></description>
	</item>
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

case "$action" in
	--init)
		rm -rf "$outdir"
		mkdir -p "$outdir"
		;;
	--finish)
		for f in "$outdir"/*; do
			[ -f "$f" ] || continue
			finish_rss "$f"
		done
		;;
	--add)
		(
		 	if [ -n "$repodir" ]; then
				cd "$repodir"
			fi
			branches
		) | while read -r HASH TYPE REFNAME; do
			echo >&2 -n "$repodir $REFNAME..."
			out=$( (
				if [ -n "$repodir" ]; then
					cd "$repodir"
				fi
				git reset --hard >/dev/null 2>&1
				if out=`git merge --no-commit -- "$REFNAME" 2>&1`; then
					good=true
				else
					good=false
					echo "$out"
				fi
				git reset --hard >/dev/null 2>&1
			) )
			if [ -n "$out" ]; then
				n=${REFNAME#refs/remotes/[^/]*/}
				case "$n" in
					*/*)
						b=${n#*/}
						n=${n%%/*}
						;;
					*)
						b="/$n"
						n=divVerent
						;;
				esac
				echo "$out" | to_rss "$outdir" "$n" "$HASH" "$b"
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

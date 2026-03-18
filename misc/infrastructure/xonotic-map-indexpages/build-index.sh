#!/bin/bash

echo "Content-type: text/html"
echo

#exec 2>/tmp/x.log
#set -x
#id

own()
{
	[ \! -f "$1" ] || [ -w "$1" ] || { mv "$1" "$1.own" && cat "$1.own" > "$1" && rm -f "$1.own"; }
}

template()
{
	cat <<EOF
<!DOCTYPE html>
<html>
<head>
<title>Map compile server</title>
<script type="text/javascript" src="../jquery-1.4.2.min.js"></script>
<script type="text/javascript">
function hide(s)
{
	\$("#" + s).hide(200);
	return false;
}
function show(s, u)
{
	\$("#" + s).empty().attr("href", u).append(\$(document.createElement("img")).attr("src", u).attr("alt", s)).show(200);
	return false;
}
\$(function()
{
	\$(".area").click(function(event) { if(event.which != 1) return true; return show("$basename", \$(this).attr("href")); });
	\$(".full").click(function(event) { if(event.which != 1) return true; return hide("$basename"); });
});
</script>
<link rel="stylesheet" href="../style.css">
</head>
<body>
<h1>Screenshots of $basename [<a class="back" href="../">back</a>]</h1>

<ul>
<li>Download as PK3 for the map's git branch <!--
##BRANCHES##

-->: <a href="../$bspk3">$bspk3</a></li>
<li>Download as PK3 for any branch: <a href="../$fullpk3">$fullpk3</a></li>
</ul>

<div class="block">
<a class="area area0" href="$basename-000000.jpg"><img src="$basename-000000-s.jpg" alt="$basename"></a>
<a class="area area1" href="$basename-000001.jpg"><img src="$basename-000001-s.jpg" alt="$basename"></a>
<a class="area area2" href="$basename-000002.jpg"><img src="$basename-000002-s.jpg" alt="$basename"></a>
<a class="area area3" href="$basename-000003.jpg"><img src="$basename-000003-s.jpg" alt="$basename"></a>
<a class="area area4" href="$basename-000004.jpg"><img src="$basename-000004-s.jpg" alt="$basename"></a>
<a class="area area5" href="$basename-000005.jpg"><img src="$basename-000005-s.jpg" alt="$basename"></a>
<a class="area area6" href="$basename-000006.jpg"><img src="$basename-000006-s.jpg" alt="$basename"></a>
<a class="area area7" href="$basename-000007.jpg"><img src="$basename-000007-s.jpg" alt="$basename"></a>
<a class="area area8" href="$basename-000008.jpg"><img src="$basename-000008-s.jpg" alt="$basename"></a>
<a class="full" href="#" id="$basename"></a>
</div>

</body>
</html>
EOF
}

dowrite=false
if mkdir .lock 2>/dev/null; then
	dowrite=true
	trap 'rmdir .lock' EXIT
	trap 'exit 1' INT HUP TERM
fi

cleanup()
{
	now=`date +%s`
	deltime=$(($now + 86400))
	own .to_delete
	grep -l -- '-->(none)<!--' */index.html | cut -d / -f 1 | while IFS= read -r D; do
		for F in "$D" "$D.pk3" "`echo "$D" | rev | cut -d - -f 3- | rev`-full-`echo "$D" | rev | cut -d - -f 1-2 | rev`.pk3"; do
			echo "$deltime $F" >> .to_delete
		done
	done
	while IFS=' ' read -r d f; do
		if [ $d -lt $now ]; then
			rm -rf "$f"
		else
			echo "$d $f"
		fi
	done < .to_delete > .to_delete_new
	mv .to_delete_new .to_delete
}

minnumber=3
sscnt=9

decade=315569520
year=31556952
month=2629746
week=604800
day=86400
hour=3600
minute=60
second=1

case "$QUERY_STRING" in
	nq)
		ignore_master=true
		ignore_dupes=true
		sort_mapname=n
		sort_date=d
		sort="-k 2,2 -k 3nr"
		;;
	dq)
		ignore_master=true
		ignore_dupes=true
		sort_mapname=n
		sort_date=d
		sort="-k 3nr -k 2,2"
		;;
	nr)
		ignore_master=false
		ignore_dupes=false
		sort_mapname=n
		sort_date=d
		sort="-k 2,2r -k 3nr"
		;;
	n)
		ignore_master=false
		ignore_dupes=false
		sort_mapname=nr
		sort_date=d
		sort="-k 2,2 -k 3nr"
		;;
	dr)
		ignore_master=false
		ignore_dupes=false
		sort_mapname=n
		sort_date=d
		sort="-k 3n -k 2,2"
		;;
	d|*)
		ignore_master=false
		ignore_dupes=false
		sort_mapname=n
		sort_date=dr
		sort="-k 3nr -k 2,2"
		;;
esac

cat <<EOF
<!DOCTYPE html>
<html>
<head>
<title>Map compile server</title>
<link rel="stylesheet" href="style.css">
</head>
<body>
<h1>Map compile server</h1>
<table>
<tr>
<th class="mapname"><a href="index-$sort_mapname.html">Map name</a></td>
<th class="branches">Branches</td>
<th class="date"><a href="index-$sort_date.html">Date</a></td>
<th class="bspk3">BSP-only pk3</td>
<th class="fullpk3">Full pk3</td>
<th class="sshot">Screenshots</td>
</tr>
EOF

force_update=false
if [ branches.idx.new -nt branches.idx ] || ! [ -f branches.idx ]; then
	own branches.idx
	cat branches.idx.new > branches.idx
	force_update=true
fi

get_branches()
{
	hash=${M#$basename-}
	branches=`grep "^$basename $hash " branches.idx | while read -r _ _ _ branch; do
		branch=${branch##refs/heads/}
		branch=${branch##refs/remotes/}
		branch=${branch##origin/}
		echo "$branch"
	done | sort -u | xargs echo`
	case " $branches " in
		*" master "*)
			branches="master"
			;;
		*)
			;;
	esac
	echo "$branches"
}

get_branches_html()
{
	branches=$1
	sep=$2
	if [ -z "$branches" ]; then
		branches_html='(none)'
	else
		branches_html=
		for b in $branches; do
			if [ -n "$branches_html" ]; then
				branches_html="$branches_html$sep$b"
			else
				branches_html="$b"
			fi
		done
		branches_html="<code>$branches_html</code>"
	fi
	echo "$branches_html"
}

update_index_html()
{
	if [ -f "$M/index.html" ]; then
		if ! $force_update; then
			return
		fi
	else
		template > "$M/index.html"
	fi
	branches=`get_branches`
	branches_html=`get_branches_html "$branches" ", "`
	own "$M/index.html"
	ed "$M/index.html" <<EOF
/^##BRANCHES##\$/+1 c
-->$branches_html<!--
.
w
q
EOF
	replace="-->$branches<!--"
}

d0=`date +%s`
for M in *-????????????????????????????????????????-????????????????????????????????????????/; do
	basename=${M%%-????????????????????????????????????????-????????????????????????????????????????/}
	date=`stat -c %Y "${M%/}.pk3"`
	echo "${M%/} $basename $date"
done | sort $sort | {
	seen=
	last=
	rowidx=0
	while read -r M basename date; do
		if $ignore_dupes; then
			case "$seen " in
				*" $basename "*)
					continue
					;;
			esac
		fi
		seen=$seen" $basename"
		dd=$(($d0 - $date))
		datestring=
		for interval in second minute hour day week month year decade; do
			eval "vv=\$$interval"
			if [ -z "$datestring" ] || [ $(($dd / $vv)) -ge $minnumber ]; then
				datestring=$(($dd / $vv))
				if [ $datestring -gt 1 ]; then
					datestring="$datestring $interval""s ago"
				else
					datestring="$datestring $interval ago"
				fi
			fi
		done
		for X in "$M/$basename-"??????".jpg"; do
			thumb=${X%.jpg}-t.jpg
			small=${X%.jpg}-s.jpg
			if $dowrite; then
				[ -f "$small" ] || convert "$X" -geometry 336x252 "$small"
				[ -f "$thumb" ] || convert "$X" -geometry 100x75 "$thumb"
			fi
		done
		bspk3=$M.pk3
		fullpk3=$basename-full-${M#$basename-}.pk3
		if $dowrite; then
			update_index_html
		fi
		branches=`get_branches`
		if $ignore_master; then
			case "$branches" in
				master|'')
					continue
					;;
			esac
		fi
		if [ x"$last" = x"$basename" ]; then
			thisname=
		else
			thisname=$basename
			last=$basename
			rowidx=$((($rowidx + 1) % 2))
		fi
		branches_html=`get_branches_html "$branches" "<br>"`
		ssid=0 # $(($RANDOM % $sscnt))
		ssid=`printf "%06d" $ssid`
		cat <<EOF
		<tr class="row$rowidx">
			<td class="mapname">$thisname</td>
			<td class="branches">$branches_html</td>
			<td class="date">$datestring</td>
			<td class="bspk3"><a href="$bspk3">bspk3</a></td>
			<td class="fullpk3"><a href="$fullpk3">fullpk3</a></td>
			<td class="sshot"><a href="$M/"><img src="$M/$basename-$ssid-t.jpg" width="100" height="75" alt="gallery"></a></td>
		</tr>
EOF
	done
}

cat <<EOF
</table>
</body>
</html>
EOF

if $dowrite; then
	t=`date +%s`
	if [ "$t" -gt "`cat .cleanup`" ]; then
		cleanup
		own .cleanup
		echo "$(($t+3600))" > .cleanup
	fi
fi

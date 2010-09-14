#!/bin/sh

set -e

d0="$PWD"
NEXLOC=$1
XONLOC=$2
COMPATLOC=$3

rewrite()
{
	case "$1" in
		scripts/*.shader) echo "scripts/nexcompat-${1#scripts/}" ;;
		*) echo "$1" ;;
	esac
}

unrewrite()
{
	case "$1" in
		scripts/nexcompat-*.shader) echo "scripts/${1#scripts/nexcompat-}" ;;
		*) echo "$1" ;;
	esac
}

ignorefile()
{
	case "$1" in
		.gitattributes) return 0 ;;
		scripts/nexcompat-trak4.shader) return 0 ;;
		scripts/nexcompat-trak5.shader) return 0 ;;
		scripts/nexcompat-eX.shader) return 0 ;;
		textures/trak4/*) return 0 ;;
		textures/trak5/*) return 0 ;;
		textures/eX/*) return 0 ;;
	esac
	return 1
}

wantfile()
{
	case "$1" in
		*.ase) return 1 ;;
		*.blend) return 1 ;;
		*.cfg) return 1 ;;
		demos/*) return 1 ;;
		font-*.pk3dir/*) return 1 ;;
		gfx/*) return 1 ;;
		*.map) return 1 ;;
		maps/*) return 1 ;;
		models/player/*) return 1 ;;
		models/weapons/*) return 1 ;;
		*.modinfo) return 1 ;;
		*.pk3) return 1 ;;
		qcsrc/*) return 1 ;;
		*.sh) return 1 ;;
		sound/*) return 1 ;;
		textures/carni*) return 1 ;;
		textures/fb*) return 1 ;;
		textures/fricka*) return 1 ;;
		textures/grunt*) return 1 ;;
		textures/headhunter*) return 1 ;;
		textures/heroine*) return 1 ;;
		textures/insurrectionist*) return 1 ;;
		textures/lurk*) return 1 ;;
		textures/lycanthrope*) return 1 ;;
		textures/marine*) return 1 ;;
		textures/mulder*) return 1 ;;
		textures/nexgun*) return 1 ;;
		textures/nexus*) return 1 ;;
		textures/quark*) return 1 ;;
		textures/shock*) return 1 ;;
		textures/skadi*) return 1 ;;
		textures/specop*) return 1 ;;
		textures/uzi*) return 1 ;;
		textures/xolar*) return 1 ;;
		*.txt) return 1 ;;
	esac
	if ! [ -f "$NEXLOC/$1" ]; then
		return 1
	fi
	R=`rewrite "$1"`
	for f in "$XONLOC"/*/"$R" "$XONLOC"/*/"$1"; do
		case "$f" in
			"$XONLOC"/\*/"$R") continue ;;
			"$XONLOC"/xonotic-nexcompat.pk3dir/"$R") continue ;;
			"$XONLOC"/\*/"$1") continue ;;
			"$XONLOC"/xonotic-nexcompat.pk3dir/"$1") continue ;;
		esac
		return 1
	done
	return 0
}

cd "$d0"
cd "$COMPATLOC"

# 1. clear deleted files from the compat pack
git reset --hard
git clean -xdf
git ls-files | while IFS= read -r L; do
	if ignorefile "$L"; then
		continue
	fi
	if ! wantfile "`unrewrite "$L"`"; then
		echo "D $L"
		git rm -f "$L"
	fi
done

CR=""
LF="
"
KILL="[K"
UP="[A"

# 2. add new files to the compat pack
echo "* -crlf" > .gitattributes
git add .gitattributes
find "$NEXLOC" -type f | while IFS= read -r L; do
	L0=${L#$NEXLOC/}
	echo "$UP$L0$KILL" >&2
	LR=`rewrite "$L0"`
	if ignorefile "$LR"; then
		continue
	fi
	if wantfile "$L0"; then
		newhash=`cd "$NEXLOC"; git rev-parse ":data/$L0"`
		if oldhash=`git rev-parse ":$LR" 2>/dev/null`; then
			if [ x"$oldhash" != x"$newhash" ]; then
				echo "$UP""U $LR$LF"
				cp "$L" "$LR"
				git add "$LR"
			fi
		else
			echo "$UP""A $LR$LF"
			mkdir -p "$LR"
			rmdir "$LR"
			cp "$L" "$LR"
			git add "$LR"
		fi
	fi
done

git status
#git commit

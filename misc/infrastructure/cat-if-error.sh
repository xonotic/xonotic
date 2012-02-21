#!/bin/sh

logfile=$1
shift

if ! lockfile-create "$logfile.lock" >/dev/null 2>&1; then
	exit 1
fi
lockfile-touch "$logfile.lock" & lockpid=$!

if "$@" >"$logfile" 2>&1; then
	: # all is well
else
	cat "$logfile"
fi

kill $lockpid
lockfile-remove "$logfile.lock"

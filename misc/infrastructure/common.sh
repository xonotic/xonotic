# common funcs for xonotic automation

LockAndLog()
{
	local logfile="$1" # also used as lock file, we want exclusive write access
	local timeout="$2" # give up on acquiring the lock after this many seconds
	local verbose="$3" # print all the shell commands

	exec 9>>"$logfile"
	printf "$0 PID $$: waiting to get lock on $logfile with $timeout second timeout...\n"
	flock_stdout="$(flock --verbose -w "$timeout" 9)" || exit 9

	# portable logging + stdout
	exec 2>"$logfile"
	tail -f "$logfile" &
	trap "kill $!" EXIT HUP INT QUIT SEGV PIPE TERM
	exec 1>&2

	# bash-only logging + stdout
	#exec &> >(tee ~/"$logfile") 2>&1

	printf "$0 PID $$: logging started at $(date -u)\n"
	printf "$flock_stdout\n"
}

AtomicDeployment()
{
	local -
	set +x
	set -e

	local srcpath="$1"   # directory to be deployed (will be moved to backend storage)
	local pubpath="$2"   # absolute path of production symlink (link will be relative)
	local storepath="$3" # absolute path of backend storage location
	local label="$4"     # prefix for backend storage directories

	local targ1="$storepath/_${label}_prod1"
	local targ2="$storepath/_${label}_prod2"
	# realpath not readlink, to support `ln -r` even with relocated web roots
	if [ "$(realpath "$pubpath")" = "$(realpath "$targ2")" ]; then
		local newtarg="$targ1"
		local oldtarg="$targ2"
	else
		local newtarg="$targ2"
		local oldtarg="$targ1"
	fi

	# create temp link in dir where last $pubpath component exists to support `ln -r`
	local templink="$(dirname "$pubpath")/.${label}_temp_symlink"

	# both `rm -rf` should be safe, worst case: `/__prod1` or `*/*__prod1` or `/*/*__prod1`
	rm -rf "$newtarg"                # shouldn't exist but if it does mv will fail
	mv -fTv "$srcpath" "$newtarg"
	ln -sfnTr "$newtarg" "$templink" # ln -f is not atomic so create first then move
	mv -fTv "$templink" "$pubpath"   # fails (safe) if a dir exists there
	rm -rf "$oldtarg"
}

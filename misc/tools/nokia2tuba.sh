#!/bin/sh

bpm=120
transpose=0
defaultoctave=1
defaultlength=4
baseoctave=1
gato=-0.1
mingato=0.034
maxgato=-0.034

tuba_note_42="moveleft back crouch fire"
tuba_note_43="back crouch fire"
tuba_note_44="moveright back crouch fire"
tuba_note_47="forward moveright crouch fire"
tuba_note_48="crouch fire"
tuba_note_49="moveleft back crouch fire2"
tuba_note_50="moveright crouch fire"
tuba_note_51="forward moveleft crouch fire"
tuba_note_52="forward crouch fire"
tuba_note_53="moveleft crouch fire"
tuba_note_54="moveleft back fire"
tuba_note_55="back fire"
tuba_note_56="back moveright fire"
tuba_note_57="moveright crouch fire2"
tuba_note_58="forward moveleft crouch fire2"
tuba_note_59="forward moveright fire"
tuba_note_60="fire"
tuba_note_61="moveleft back fire2"
tuba_note_62="moveright fire"
tuba_note_63="forward moveleft fire"
tuba_note_64="forward fire"
tuba_note_65="moveleft fire"
tuba_note_66="forward moveright fire2"
tuba_note_67="fire2"
tuba_note_68="back moveright jump fire"
tuba_note_69="moveright fire2"
tuba_note_70="forward moveleft fire2"
tuba_note_71="forward fire2"
tuba_note_72="moveleft fire2"
tuba_note_73="moveleft back jump fire2"
tuba_note_74="moveright jump fire"
tuba_note_75="forward moveleft jump fire"
tuba_note_76="forward jump fire"
tuba_note_77="moveleft jump fire"
tuba_note_78="forward moveright jump fire2"
tuba_note_79="jump fire2"
tuba_note_81="moveright jump fire2"
tuba_note_82="forward moveleft jump fire2"
tuba_note_83="forward jump fire2"
tuba_note_84="moveleft jump fire2"

tuba() {
	plusminus=$1
	eval "tuba_note=\$tuba_note_$pitch"
	if [ -z "$tuba_note" ]; then
		echo >&2 "Cannot play note $pitch"
	fi
	semi=
	for n in $tuba_note; do
		echo -n "${semi}${plusminus}${n}"
		semi=';'
	done
}

time=0
playnote() {
	# Move the dot where it belongs.
	case "$octave" in
		*.)
			octave=${octave%.}
			length=$length.
			;;
	esac
	# Normalize the note.
	pitch=''
	case "$note" in
		[Cc]_|_[Cc]) pitch=-1 ;;
		[Cc]) pitch=0 ;;
		[Cc][#+]|[#+][Cc]|[Dd]_|_[Dd]) pitch=1 ;;
		[Dd]) pitch=2 ;;
		[Dd][#+]|[#+][Dd]|[Ee]_|_[Ee]) pitch=3 ;;
		[Ee]|[Ff]_|_[Ff]) pitch=4 ;;
		[Ff]|[Ee][#+]|[#+][Ee]) pitch=5 ;;
		[Ff][#+]|[#+][Ff]|[Gg]_|_[Gg]) pitch=6 ;;
		[Gg]) pitch=7 ;;
		[Gg][#+]|[#+][Gg]|[Aa]_|_[Aa]) pitch=8 ;;
		[Aa]) pitch=9 ;;
		[Aa][#+]|[#+][Aa]|[Bb]_|_[Bb]) pitch=10 ;;
		[Bb]) pitch=11 ;;
		[Bb][#+]|[#+][Bb]) pitch=12 ;;
		[p-]) pitch='' ;;
		*) echo >&2 "Unrecognized note: $note" ;;
	esac
	echo "// $length$note$octave"
	# Calculate the duration.
	case "$length" in
		.)
			length=$defaultlength
			f=1.5
			;;
		'')
			length=$defaultlength
			f=1
			;;
		*.)
			f=1.5
			;;
		*)
			f=1
			;;
	esac
	duration=$(echo "240 / $bpm / ${length%.} * $f" | bc -l)
	if [ -n "$pitch" ]; then
	# Calculate the MIDI pitch.
		if [ -z "$octave" ]; then
			octave=$defaultoctave
		fi
		pitch=$((pitch + (octave - baseoctave) * 12 + transpose + 60))
		case "$gato" in
			-*)
				noteoff=$(echo "$time + $duration + $gato" | bc -l)
				;;
			*)
				noteoff=$(echo "$time + $gato" | bc -l)
				;;
		esac
		noteoff=$(echo "
			minnoteoff = $time + $mingato;
			maxnoteoff = $time + $duration + $maxgato;
			noteoff = $noteoff;
			if (noteoff > maxnoteoff) { noteoff = maxnoteoff; }
			if (noteoff < minnoteoff) { noteoff = minnoteoff; }
			noteoff;
		" | bc -l)
		echo "defer $time \"$(tuba +)\""
		echo "defer $noteoff \"$(tuba -)\""
	fi
	time=$(echo "$time + $duration" | bc -l)
}

notes=$*
case "$notes" in
	*:*)
		notes=${notes#*:}
		baseoctave=5
		;;
esac
while [ -n "$notes" ]; do
	note=${notes%%[:, ]*}
	notes=${notes#$note}
	notes=${notes#?}
	case "$note" in
		ml)
			gato=-0.04
			;;
		ms)
			gato=0.04
			;;
		mn)
			gato=-0.1
			;;
		b=*)
			bpm=${note#*=}
			;;
		d=*)
			defaultlength=${note#*=}
			;;
		t=*)
			transpose=${note#*=}
			;;
		o=*)
			defaultoctave=${note#*=}
			;;
		O=*)
			baseoctave=${note#*=}
			;;
		*)
			octave=${note##*[cCdDeEfFgGaAbBp-]}
			octave=${octave##[#+_]}
			note=${note%$octave}
			length=${note%[cCdDeEfFgGaAbBp-]*}
			length=${length%%[#+_]}
			note=${note#$length}
			playnote
			;;
	esac
done

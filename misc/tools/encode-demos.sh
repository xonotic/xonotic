#!/bin/bash
# name: encode-demos.sh
# version: 0.6.3
# author: Tyler "-z-" Mulligan <z@xnz.me>
# license: GPL & MIT
# date: 01-04-2017
# description: headless encoding of demo files to HD video concurrently with Xfvb and parallel
#
# The encoding is done with a full Xonotic client inside Xfvb.
# parallel is acting as a job queue.
# You may want to create a new userdir such as `~/.xonotic-clean` for encoding.
# If you don't want certain details of your player config carrying over.
#
# The following is a good starting point for 1080p videos:
#
# ```
# // autoexec.cfg
# bgmvolume 1
#
# vid_height 1080
# vid_width 1920
# scr_screenshot_gammaboost 1
# cl_capturevideo_width 1920
# cl_capturevideo_height 1080
# cl_capturevideo_fps 60
# cl_capturevideo_ogg 1
# cl_capturevideo_ogg_theora_quality 63
# cl_capturevideo_ogg_theora_bitrate -1
# cl_capturevideo_ogg_theora_keyframe_bitrate_multiplier 2
# cl_capturevideo_ogg_theora_keyframe_maxinterval 500
# cl_capturevideo_ogg_theora_keyframe_mininterval 1
# cl_capturevideo_ogg_theora_keyframe_auto_threshold 80
# cl_capturevideo_ogg_theora_noise_sensitivity 0
# cl_capturevideo_ogg_vorbis_quality 10
#
# // HUD stuff
# defer 5 "menu_watermark \"\""
# set cl_allow_uid2name 0; set cl_allow_uidtracking 0
# con_notify 0; con_notifysize 0; con_notifytime 0; showspeed 0; showfps 0
# ```
#

# Customize
USERDIR=${HOME}/.xonotic-clean                      # path to Xonotic userdir for client that does encoding
GAMEDIR=${USERDIR}/data                             # path to Xonotic gamedir for client that does encoding
XONOTIC_BIN="./all"                                 # binary used to launch Xonotic
JOB_TIMEOUT="4h"                                    # if demo doesn't quit itself or hangs
JOBS=4                                              # number of concurrent jobs
DEFAULT_DEMO_LIST_FILE="demos.txt"                  # for batch
DISPLAY=:1.0                                        # display for Xvfb
DIMENSIONS=1920x1080                                # dimensions of virtual display
COMPRESS=false                                      # whether to compress by default
KILLER_KEYWORD_WATCHER=true                         # watch server logs for keyword, kill worker if true
KILLER_KEYWORD="Server Disconnected"                # keyword
KILLER_KEYWORD_WAIT="10s"                           # time to wait between polling watchers
LIST_JOBS_FOLLOW_WAIT="10s"                         # how often to poll the job list with -f

# Internal Constants
SCRIPT_NAME=$(basename $0 .sh)
VERSION=$(awk 'NR == 3 {print $3; exit}' $0)
FFMPEG=$(which ffmpeg)
QUEUE_FILE_DEMOS="/tmp/${SCRIPT_NAME}.jobqueue"
QUEUE_FILE_COMPRESSING="/tmp/${SCRIPT_NAME}_compress.jobqueue"
LOCK_FILE="/tmp/${SCRIPT_NAME}.lock"
LOCK_FILE_COMPRESSING="/tmp/${SCRIPT_NAME}.lock"
LOG_FILE="${SCRIPT_NAME}.log"
REGEX_DEMOLIST_FILE="^[[:alnum:]]+\.txt$"
REGEX_DURATION="^[0-9]+(d|h|m|s)$"
REGEX_VIDEO_TYPES="^(mp4|webm)$"

# State
export KILLER_KEYWORD_WATCHING=true

# Xonotic Helpers

_check_xonotic_dir() {
    local xon_dir=$1
    if [[ ! -d ${xon_dir} ]]; then
        echo "[ ERROR ] Unable to locate Xonotic"; exit 1
    fi
}

_get_xonotic_dir() {
    relative_dir=$(dirname $0)/../..
    _check_xonotic_dir ${relative_dir}
    export XONOTIC_DIR="$(cd ${relative_dir}; pwd)"
}

_kill_xonotic() {
    pkill -f "\-simsound \-sessionid xonotic_${SCRIPT_NAME}_"
}

# Data Helpers
###############

_get_compression_command() {
    if [[ ${FFMPEG} == "" ]]; then
        echo "[ ERROR ] ffmpeg or avconv required"
        exit 1
    fi
    if [[ ! $1 ]]; then
        echo "[ ERROR ] Video name required"
        exit 1
    fi
    local video_file=$1
    local type="mp4"
    if [[ $2 =~ ${REGEX_VIDEO_TYPES} ]]; then
        type=$2
    fi
    # compress
    if [[ ${type} == "mp4" ]]; then
        local output_video_file=$(echo ${video_file} | sed 's/\.ogv$/\.mp4/')
        command="${FFMPEG} -i ${video_file} -y -codec:v libx264 -crf 21 -bf 2 -flags +cgop -pix_fmt yuv420p -codec:a aac -strict -2 -b:a 384k -r:a 48000 -movflags faststart ${output_video_file}"
    elif [[ ${type} == "webm" ]]; then
        local output_video_file=$(echo ${video_file} | sed 's/\.ogv$/\.webm/')
        command="${FFMPEG} -i ${video_file} -y -acodec libvorbis -aq 5 -ac 2 -qmax 25 -threads 2 ${output_video_file}"
    fi
    echo ${command}
}

_get_demo_command() {
    local demo_file=$1
    local index=$2
    name_format=$(basename "${demo_file}" .dem)
    command="${XONOTIC_DIR}/${XONOTIC_BIN} run sdl -simsound -sessionid xonotic_${SCRIPT_NAME}_${index} -userdir \"${USERDIR}\" \
        +log_file \"xonotic_${SCRIPT_NAME}_${index}_${name_format}.log\" \
        +cl_capturevideo_nameformat \"${name_format}_\" \
        +cl_capturevideo_number 0 \
        +playdemo \"${demo_file}\" \
        +toggle cl_capturevideo \
        +alias cl_hook_shutdown quit \
        > /dev/null 2>&1"
    echo ${command}
}

_get_demos_from_file() {
    local file=$1
    if [[ -f ${file} ]]; then
        local lines
        OLD_IFS=${IFS}
        IFS=$'\n' read -d '' -r -a lines < ${file}
        IFS=${OLD_IFS}
        echo ${lines[@]}
    fi
}

# Queue Helpers
################

_queue_add_job() {
    local queue_file=$1;
    local command=$2;
    local nice_name=${command};
    local nice_queue_name=${queue_file##*/};
    if [[ $3 ]]; then
        nice_name=$3
    fi
    echo "[ INFO ] '${nice_queue_name/.jobqueue/}' new job: ${nice_name}"
    echo "${command}" >> ${queue_file}
}

_queue_add_compression_jobs() {
    local queue_file=$1; shift
    local type=$1; shift
    local videos="$@"
    for video_file in ${videos[@]}; do
        local command=$(_get_compression_command ${GAMEDIR}/${video_file} ${type})
        _queue_add_job ${queue_file} "${command}" ${video_file}
    done
}

_queue_add_demo_jobs() {
    local queue_file=$1; shift
    local timeout=$1; shift
    local demos=$@
    local i=0
    for demo_file in ${demos[@]}; do
        local command=$(_get_demo_command ${demo_file} ${i})
        command="timeout ${timeout} ${command}"
        _queue_add_job ${queue_file} "${command}" ${demo_file}
        ((i++))
    done
}

_get_active_demo_jobs() {
    if [[ $(pgrep -caf "\-simsound \-sessionid xonotic_${SCRIPT_NAME}_") -gt 0 ]]; then
        pgrep -af "\-simsound \-sessionid xonotic_${SCRIPT_NAME}_" |grep "dev/null" |awk '{ print $17 }' |sed 's/"//g;s/_$/\.dem/'
    else
        echo ""
    fi
}

_get_active_demo_workers() {
    if [[ $(pgrep -caf "\-simsound \-sessionid xonotic_${SCRIPT_NAME}_") -gt 0 ]]; then
        pgrep -af "\-simsound \-sessionid xonotic_${SCRIPT_NAME}_" |grep "dev/null" |awk '{ print $11"_"$17 }' |sed 's/"//g;s/_$//'
    else
        echo ""
    fi
}

_get_queue_jobs() {
    local queue_file=$1
    if [[ -f ${queue_file} ]]; then
        cat ${queue_file} |awk '{ print $14 }'|sed 's/"//g;s/_$/\.dem/'
    else
        echo ""
    fi
}

_get_completed_jobs() {
    if [[ -f ${LOG_FILE} ]]; then
        cat ${LOG_FILE} |awk '{ print $22 }'|sed 's/"//g;s/_$/\.dem/'
    else
        echo ""
    fi
}

_run_compress_jobs() {
    local queue_file=${QUEUE_FILE_COMPRESSING}
    if [[ $1 ]]; then
        queue_file=$1
    fi
    local start=$(date +%s)
    (
        flock -n 9 || exit 99
        trap _cleanup_compress EXIT
        if [[ -f ${queue_file} ]]; then
            parallel -j${JOBS} --progress --eta --joblog "${LOG_FILE}" < ${queue_file}
        else
            echo "[ ERROR ] No jobs found"
        fi
    ) 9>${LOCK_FILE_COMPRESSING}
    if [[ $? -eq 99 ]]; then
        echo "[ ERROR ] lockfile exists, remove if you're sure jobs aren't running: ${LOCK_FILE_COMPRESSING}"
        exit 1
    fi
    local end=$(date +%s)
    local runtime=$((end-start))
    printf 'Video Compression Time: %02dh:%02dm:%02ds\n' $((runtime/3600)) $((runtime%3600/60)) $((runtime%60))
}

_run_demo_jobs() {
    local queue_file=${QUEUE_FILE_DEMOS}
    if [[ $1 ]]; then
        queue_file=$1
    fi
    local start=$(date +%s)
    if [[ ${KILLER_KEYWORD_WATCHER} ]]; then
        (sleep 5 && _log_killer_keyword_watcher ${KILLER_KEYWORD}) > /dev/null 2>&1 &
    fi
    if [[ $2 == "summary" ]]; then
        (sleep 5 && echo && list_jobs) &
    fi
    (
        flock -n 9 || exit 99
        trap _cleanup EXIT
        if [[ -f ${queue_file} ]]; then
            parallel -j${JOBS} --progress --eta --joblog "${LOG_FILE}" < ${queue_file}
        else
            echo "[ ERROR ] No jobs found"
        fi
    ) 9>${LOCK_FILE}
    if [[ $? -eq 99 ]]; then
        echo "[ ERROR ] lockfile exists, remove if you're sure jobs aren't running: ${LOCK_FILE}"
        exit 1
    fi
    local end=$(date +%s)
    local runtime=$((end-start))
    printf 'Demo Encoding Time: %02dh:%02dm:%02ds\n' $((runtime/3600)) $((runtime%3600/60)) $((runtime%60))
}

# Cleanup Helpers
##################

_cleanup() {
    rm -f ${QUEUE_FILE_DEMOS}
    rm -f ${LOCK_FILE}
    rm -f ${GAMEDIR}/*.log
    export KILLER_KEYWORD_WATCHING=false
    sleep 1
    _kill_xonotic
}

_cleanup_children() {
    kill $(jobs -pr)
}

_cleanup_compress() {
    rm -f ${QUEUE_FILE_COMPRESSING}
}

# Application Helpers
######################

_check_if_compress() {
    local compress=$1; shift
    local videos=$@
    trap _cleanup_children SIGINT SIGTERM EXIT
    if [[ ${compress} == "true" ]]; then
        _run_compress_jobs ${QUEUE_FILE_COMPRESSING}
    fi
}

_log_killer_keyword_watcher() {
    local keyword="$@"
    until [[ ${KILLER_KEYWORD_WATCHING} != "true" ]]; do
        log_killer_keyword ${keyword}
        sleep ${KILLER_KEYWORD_WAIT}
    done
}

# Commands
###########

_run_xvfb() {
    if [[ ! -f /tmp/.X1-lock ]]; then
        /usr/bin/Xvfb :1 -screen 0 ${DIMENSIONS}x16 +extension RENDER & xvfb_pid=$!
    else
        xvfb_pid=$(pgrep -f Xvfb)
    fi
    echo "[ INFO ] Xvfb PID: ${xvfb_pid}"
}

compress() {
    if [[ ${FFMPEG} == "" ]]; then
        echo "[ ERROR ] ffmpeg or avconv required"
        exit 1
    fi
    if [[ ! $1 ]]; then
        echo "[ ERROR ] Video name required"
        exit 1
    fi
    local video_file=$1; shift
    local type="mp4"
    local cleanup=""
    if [[ $1 =~ ${REGEX_VIDEO_TYPES} ]]; then
        type=$2
        if [[ $2 == "--cleanup" ]]; then
            cleanup=$2
        fi
    elif [[ $1 == "--cleanup" ]]; then
        cleanup=$1
    else
        echo "[ ERROR ] Invalid type specified"
    fi

    # compress
    local command=$(_get_compression_command ${GAMEDIR}/${video_file} ${type})
    echo ${command}
    echo "[ INFO ] Compressing '${video_file}'"
    _queue_add_compression_jobs ${QUEUE_FILE_COMPRESSING} ${type} ${video_file[@]}
    cat ${QUEUE_FILE_COMPRESSING}
    _run_compress_jobs ${QUEUE_FILE_COMPRESSING}

    if [[ ${cleanup} == "--cleanup" ]]; then
        echo "[ INFO ] Cleaning up"
        echo rm ${video_file}
    fi
}

create_gif() {
    local video=$1
    local fps=${2:-15}
    local width=${3:-320}
    local start=${4:-0}
    local length=${5:-999999}
    local loop=${6:-1}
    local output=$(basename ${video%.*}.gif)

    # Generate palette for better quality
    ${FFMPEG} -i ${GAMEDIR}/${video} -vf fps=${fps},scale=${width}:-1:flags=lanczos,palettegen ${GAMEDIR}/tmp_palette.png

    # Generate gif using palette
    ${FFMPEG} -i ${GAMEDIR}/${video} -i ${GAMEDIR}/tmp_palette.png -ss ${start} -t ${length} -loop ${loop} -filter_complex "fps=${fps},scale=${width}:-1:flags=lanczos[x];[x][1:v]paletteuse" ${GAMEDIR}/${output}

    rm ${GAMEDIR}/tmp_palette.png
}

list_jobs() {
    completed_jobs=$(_get_completed_jobs)
    active_jobs=$(_get_active_demo_jobs)
    all_jobs=$(_get_queue_jobs ${QUEUE_FILE_DEMOS})

    echo -e "\nActive Jobs:\n-----------"
    if [[ ${active_jobs} == "" ]]; then
        echo "<None>"
    else
        echo ${active_jobs} |tr ' ' '\n' |sort |uniq -u
    fi

    echo -e "\nQueued Jobs:\n-----------"
    if [[ ${#all_jobs[@]} -eq 0 ]]; then
        echo "<None>"
    else
        if [[ ${active_jobs} == "" ]]; then
            echo "<None>"
        else
            non_queued_jobs=$(echo "${active_jobs[@]}" "${completed_jobs[@]}" |tr ' ' '\n' |sort |uniq -u)
            queued_jobs=$(echo "${all_jobs[@]}" "${non_queued_jobs[@]}" |tr ' ' '\n' |sort |uniq -u)
            if [[ ${queued_jobs} == "" ]]; then
                echo "<None>"
            else
                echo ${queued_jobs} | tr ' ' '\n' | sort | uniq -u
            fi
        fi
    fi

    echo -e "\nCompleted Jobs:\n--------------"
    if [[ ${completed_jobs} == "" ]]; then
        echo "<None>"
    else
        echo ${completed_jobs} | tr ' ' '\n' | sort | uniq -u
    fi

    echo

    if  [[ $1 == "-f" ]]; then
        sleep ${LIST_JOBS_FOLLOW_WAIT}
        clear
        date
        list_jobs $1
    fi
}

log_completed_jobs() {
    local extra_flags=""
    if [[ $1 ]]; then
        extra_flags=$1
    fi
    tail ${extra_flags} ${LOG_FILE}
}

log_killer_keyword() {
    local keyword="$@"
    local workers=$(log_keyword_grep "worker" "${keyword}")
    for z in ${workers[@]}; do
        local process=${z[0]}
        local pid=$(pgrep -fo ${process})
        echo "killing PID: ${pid} | ${process}"
        kill ${pid}
     done
}

log_keyword_grep() {
    if [[ ! $2 ]]; then
        echo "[ ERROR ] Keyword required"
        exit 1
    fi
    local type=${1:-worker}; shift
    local keyword="$@"
    for worker in $(_get_active_demo_workers); do
        local log_file="${worker}.log"
        local keyword_count=$(grep -c "${keyword}" "${GAMEDIR}/${log_file}")
        if [[ ${keyword_count} > 0 ]]; then
            if [[ ${type} == "worker" ]]; then
                echo "${worker}"
            else
                echo "[ worker ] ${worker}"
                grep "${keyword}" "${GAMEDIR}/${log_file}"
            fi
        fi
    done
}

process_batch() {
    local demo_list_file=${DEFAULT_DEMO_LIST_FILE}
    local timeout=${JOB_TIMEOUT}
    local -a videos=()
    if [[ $1 =~ ${REGEX_DEMOLIST_FILE} ]]; then
        demo_list_file=$1; shift
    fi
    if [[ $1 =~ ${REGEX_DURATION} ]]; then
        timeout=$1; shift
    fi
    local compress=${COMPRESS}
    if [[ $1 == "--compress" ]]; then
        compress="true"
    fi
    echo "[ INFO ] Using '${demo_list_file}' with a timeout of ${timeout}"
    local demos=$(_get_demos_from_file ${demo_list_file})
    _queue_add_demo_jobs ${QUEUE_FILE_DEMOS} ${timeout} ${demos[@]}
    if [[ ${compress} == "true" ]]; then
        for v in ${demos[@]}; do
            videos+=("video/$(basename ${v} | sed 's/.dem$/_000.ogv/')")
        done
        _queue_add_compression_jobs ${QUEUE_FILE_COMPRESSING} "mp4" "${videos[@]}"
    fi
    _run_demo_jobs ${QUEUE_FILE_DEMOS} "summary" && \
        _check_if_compress ${compress} "${videos[@]}"
}

process_single() {
    if [[ ! $1 ]]; then
        echo "[ ERROR ] Demo name required"
        exit 1
    fi
    local demo_file=$1
    local timeout=${JOB_TIMEOUT}
    if [[ $2 =~ ${REGEX_DURATION} ]]; then
        timeout=$2; shift
    fi
    local compress=${COMPRESS}
    if [[ $2 == "--compress" ]]; then
        compress="true"
    fi
    echo "[ INFO ] Using '${demo_file}' with a timeout of ${timeout}"
    _queue_add_demo_jobs ${QUEUE_FILE_DEMOS} ${timeout} ${demo_file}
    if [[ ${compress} == "true" ]]; then
        local video_file="video/$(basename "${demo_file}" .dem)_000.ogv"
        _queue_add_compression_jobs ${QUEUE_FILE_COMPRESSING} "mp4" "${video_file}"
    fi
    _run_demo_jobs ${QUEUE_FILE_DEMOS} "summary" && \
        _check_if_compress ${compress} ${video_file}
}

_version() {
    echo ${VERSION}
}

_help() {
    echo "./encode-demos.sh

FLAGS

    --version                                   prints the version string

COMMANDS

    Encoding
    --------
    batch  [demos.txt] [timeout] [--compress]           batch process a list of demos from file relative to \$USERDIR/data
    single <demo> [timeout] [--compress]                process a single demo file in \$USERDIR/data. ex: demos/cool.dem
                                                        'timeout' does not include '--compress', compress starts a new job
    Compression
    -----------
    compress <video> [mp4|webm] [--cleanup]             compress an encoded ogv in \$USERDIR/data, ex: video/cool.ogv

    Convert
    -----------
    gif <video> [fps] [width] [start] [length] [loop]   convert a video to gif in \$USERDIR/data, ex: video/cool.ogv

    Job Management
    --------------
    grep <keyword>                                      grep the server logs of the workers
    kkill <keyword>                                     keyword kill, kill a worker if string is matched
    list [-f]                                           list currently active/queued/completed jobs
    log [-f]                                            tail the current log (-f follows log)

EXAMPLES

    # outputs \$USERDIR/data/video/2015-06-11_00-26_solarium.ogv (very large)
    ./encode-demos.sh single demos/2015-06-11_00-26_solarium.dem

    # outputs \$USERDIR/data/video/2015-06-11_00-26_solarium.mp4 (optimal for youtube)
    ./encode-demos.sh single demos/2015-06-11_00-26_solarium.dem --compress

    # batch
    ./encode-demos.sh batch demos.txt --compress

    # compress a video in \$USERDIR/data (outputs test.mp4, and deletes the original)
    ./encode-demos.sh compress video/test.ogv --cleanup

    # convert video to gif (14 fps, 640 width, start at 4s, length of 4s, loop 100 times)
    ./encode-demos.sh gif video/2017-04-01_11-53_afterslime_000.ogv 14 640 4 4 100

    # list jobs
    ./encode-demos.sh list

    # inspect worker server logs
    ./encode-demos.sh grep \"connected\"

    # follow a completed job log
    ./encode-demos.sh log -f

    # Override the path to Xonotic (assumed from relative location of this script)
    XONOTIC_DIR=\$HOME/some/other/dir; ./misc/tools/encode-demos.sh --version
"
}

# Init
######

# Allow for overriding the path assumption
# XONOTIC_DIR=$HOME/some/other/dir; ./misc/tools/encode-demos.sh --version
if [[ -z ${XONOTIC_DIR} ]]; then
    _get_xonotic_dir
else
    _check_xonotic_dir ${XONOTIC_DIR}
fi

case $1 in
    # flags
    '--version')        _version;;
    ## commands
    # encoding
    'batch')            _run_xvfb; process_batch $2 $3 $4;;
    'single')           _run_xvfb; process_single $2 $3 $4;;
    # compression
    'compress')         compress $2 $3 $4;;
    # convert
    'gif')              create_gif $2 $3 $4 $5 $6 $7;;
    # monitoring/management
    'grep')             log_keyword_grep 'normal' $2;;
    'kkill')            log_killer_keyword $2;;
    'list')             list_jobs $2;;
    'log')              log_completed_jobs $2;;
    # default
    *)                  _help; exit 0;;
esac

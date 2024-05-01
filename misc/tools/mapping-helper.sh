#!/usr/bin/env bash

# Tiny script to set up and package standalone maps

list () {
    for PK3DIR in $(find ${BASEDIR} -type d -name "map-*.pk3dir"); do
        PK3DIR=${PK3DIR%.pk3dir}
        PK3DIR=${PK3DIR##${BASEDIR}/map-}
        echo $PK3DIR
    done
}

create_stub () {
    MAPNAME=$1
    [[ -z "${MAPNAME}" ]] && { echo "Please specify mapname"; exit -1; }
    [[ -d "${BASEDIR}/map-${MAPNAME}.pk3dir" ]] && { echo "Map ${MAPNAME} already exists"; exit -1; }
    TEMP=$(find ${BASEDIR} -maxdepth 1 -type d -name "map-"${MAPNAME}"_[[:digit:]].[[:digit:]][[:digit:]].pk3dir")
    [[ -n "${TEMP}" ]] && { echo "Map ${MAPNAME} already exists"; exit -1; }
    mkdir -p "${BASEDIR}/map-${MAPNAME}_0.01.pk3dir/"{cubemaps,env,maps,models,scripts,sounds,textures}
    touch "${BASEDIR}/map-${MAPNAME}_0.01.pk3dir/maps/${MAPNAME}_0.01.map"
}

package () {
    MAPNAME=$1
    [[ -z "${MAPNAME}" ]] && { echo "Please specify mapname"; exit -1; }
    [[ ! -d "${BASEDIR}/map-${MAPNAME}.pk3dir" ]] && { echo "Map ${MAPNAME} not found"; exit -1; }
    # TODO: check for License, mapinfo and mapshot
    pushd ${BASEDIR}/map-${MAPNAME}.pk3dir
    zip -r -D ${BASEDIR}/map-${MAPNAME}.pk3 * -x "*.srf" "*.prt" "*.bak"
    popd
}

while getopts "b:" FLAG; do
    case "${FLAG}" in
        b)
            BASEDIR=$OPTARG
            ;;
    esac
done

shift $( expr ${OPTIND} - 1 )

case $(uname -s) in
    Linux*)
        DEFAULT_BASEDIR="${HOME}/.xonotic/data"
        ;;
    Darwin*)
        DEFAULT_BASEDIR="~/Library/Application Support/xonotic/data"
        ;;
    CYGWIN*|MINGW*)
        echo "WINDOWS NOT SUPPORTED (YET?)" && exit -1
        ;;
    *)
        echo "Unknown platform, assuming posix"
        DEFAULT_BASEDIR="${HOME}/.xonotic/data"
        ;;
esac

BASEDIR=${BASEDIR:-$DEFAULT_BASEDIR}

TASK=$1

shift

case "${TASK}" in
    ls|list)
        list
        ;;
    stub)
        create_stub $@
        ;;
    package)
        package $@
        ;;
    # TODO: increment version command
    *)
        echo "Unsupported option" && exit -1
        ;;
esac


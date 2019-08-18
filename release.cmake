# release requirements:
# a graphical environment
# vorbis-tools: vorbiscomment, oggdec, oggenc
# imagemagick: convert
# https://github.com/divVerent/s2tc.git: s2tc_compress

add_custom_target(release)

string(TIMESTAMP stamp "%Y%m%d")
string(TIMESTAMP filestamp "%Y-%m-%d")

file(STRINGS data/xonotic-data.pk3dir/xonotic-common.cfg _contents REGEX "^gameversion ")
if (NOT _contents)
    message(FATAL_ERROR "xonotic-common.cfg does not contain gameversion")
else ()
    string(REGEX REPLACE ".*gameversion ([0-9]+).*" "\\1" versionstr "${_contents}")
    math(EXPR versionstr_major "${versionstr} / 10000")
    math(EXPR versionstr_minor "${versionstr} / 100 - ${versionstr_major} * 100")
    math(EXPR versionstr_patch "${versionstr} - ${versionstr_major} * 10000 - ${versionstr_minor} * 100")
    set(versionstr "${versionstr_major}.${versionstr_minor}.${versionstr_patch}")
    message("game version: ${versionstr}")
endif ()

# foreach repo: git tag "xonotic-v${versionstr}"

function(getbinary artifact)
    find_package(Git REQUIRED)
    get_filename_component(dpname ${artifact} NAME)
    string(REGEX REPLACE "^xonotic" "darkplaces" dpname ${dpname})
    execute_process(
            COMMAND ${GIT_EXECUTABLE} rev-parse HEAD
            WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}/darkplaces
            OUTPUT_VARIABLE rev
            OUTPUT_STRIP_TRAILING_WHITESPACE)
    message(STATUS "Downloading http://beta.xonotic.org/autobuild-bin/${rev}/${dpname}")
    file(DOWNLOAD "http://beta.xonotic.org/autobuild-bin/${rev}/${dpname}"
            "${PROJECT_BINARY_DIR}/${artifact}"
            SHOW_PROGRESS)
endfunction()

if (0)
    # TODO: build from source
    message(STATUS "Downloading NetRadiant")

    file(DOWNLOAD http://www.icculus.org/netradiant/files/netradiant-1.5.0-20120301.tar.bz2
            "${PROJECT_BINARY_DIR}/netradiant-1.5.0-20120301.tar.bz2"
            SHOW_PROGRESS
            EXPECTED_HASH SHA256=5e720cd8ebd2379ee5d388dfb8f2613bfd5798fb33d16bc7415d44a11fb4eadb)

    file(DOWNLOAD http://www.icculus.org/netradiant/files/netradiant-1.5.0-20120301-win32-7z.exe
            "${PROJECT_BINARY_DIR}/netradiant-1.5.0-20120301-win32-7z.exe"
            SHOW_PROGRESS
            EXPECTED_HASH SHA256=c4bb30b6f14c3f71f1ed29fa38cddac209a7bc2ab5b38e5bf5b442106279b5c4)
endif ()

if (0)
    # TODO: build from source
    message(STATUS "Downloading Darkplaces")

    getbinary(Xonotic/xonotic-x86.exe)
    getbinary(Xonotic/xonotic-x86-dedicated.exe)
    getbinary(Xonotic/xonotic.exe)
    getbinary(Xonotic/xonotic-dedicated.exe)

    getbinary(Xonotic/Xonotic.app/Contents/MacOS/xonotic-osx-sdl-bin) # +x
    getbinary(Xonotic/xonotic-osx-dedicated) # +x

    getbinary(Xonotic/xonotic-linux64-sdl) # +x
    getbinary(Xonotic/xonotic-linux64-glx) # +x
    getbinary(Xonotic/xonotic-linux64-dedicated) # +x
endif ()

function(buildpk3s src)
    set(dir data/${src})
    string(REGEX REPLACE "\\.pk3dir$" "" name ${src})
    if (name MATCHES "^xonotic-")
        string(REGEX REPLACE "^xonotic-" "xonotic-${stamp}-" name ${name})
    else ()
        set(name "${name}-${stamp}")
    endif ()
    file(GLOB_RECURSE files RELATIVE "${PROJECT_SOURCE_DIR}/${dir}" "${dir}/*")
    string(REGEX REPLACE "\\.git/[^;]+;?" "" files "${files}")
    #    string(REGEX REPLACE "[^;]+(qh|inc|txt|cfg|sh|po|pl|yml|cmake);?" "" files "${files}")
    foreach (pair ${ARGN})
        list(GET pair 0 filter)
        list(GET pair 1 flavor)
        buildpk3(${name}${flavor}.pk3)
    endforeach ()
endfunction()

function(buildpk3 pk3)
    message("registered pk3 ${pk3}")
    set(deps)
    foreach (file IN LISTS files)
        set(marker "done.data/${pk3}dir/${file}")
        string(REPLACE "#" "_" marker ${marker})  # OUTPUT cannot contain '#'
        list(APPEND deps "${marker}")
        get_filename_component(rel ${file} DIRECTORY)
        add_custom_command(OUTPUT ${marker}
                DEPENDS "${dir}/${file}"
                COMMAND ${CMAKE_COMMAND}
                "-Dsrc=${PROJECT_SOURCE_DIR}/${dir}/${file}"
                "-Ddst=data/${pk3}dir/${rel}"
                "-Dconv=data/${pk3}dir/${file}"
                -P "transform-${filter}.cmake"
                VERBATIM)
    endforeach ()
    add_custom_target(${pk3}dir DEPENDS ${deps})
    add_custom_target(${pk3}dir-zip DEPENDS ${pk3})
    add_dependencies(release ${pk3}dir-zip)
    add_custom_command(OUTPUT ${pk3}
            DEPENDS ${pk3}dir
            COMMAND ${CMAKE_COMMAND} -E tar cvf "../../${pk3}" --mtime=${filestamp} --format=zip -- *  # TODO: no wildcard
            WORKING_DIRECTORY "data/${pk3}dir")
endfunction()

function(deftransform name)
    file(WRITE ${PROJECT_BINARY_DIR}/transform-${name}.cmake "")
    set(pairs "${ARGN}")
    list(APPEND pairs "del_src\;true")
    foreach (pair IN LISTS pairs)
        list(GET pair 0 k)
        list(GET pair 1 v)
        file(APPEND ${PROJECT_BINARY_DIR}/transform-${name}.cmake "set(ENV{${k}} \"${v}\")\n")
    endforeach ()
    file(APPEND ${PROJECT_BINARY_DIR}/transform-${name}.cmake
            "execute_process(\n"
            "        COMMAND ${CMAKE_COMMAND} -E copy \${src} \${conv}\n"
            "        COMMAND ${PROJECT_SOURCE_DIR}/misc/tools/cached-converter.sh \${conv}\n"
            "        COMMAND ${CMAKE_COMMAND} -E make_directory done.\${conv}\n"
            "        COMMAND ${CMAKE_COMMAND} -E touch done.\${conv}\n"
            "        RESULT_VARIABLE res_var\n"
            ")")
endfunction()
file(WRITE ${PROJECT_BINARY_DIR}/transform-raw.cmake
        "execute_process(\n"
        "        COMMAND ${CMAKE_COMMAND} -E copy \${src} \${conv}\n"
        "        COMMAND ${CMAKE_COMMAND} -E make_directory done.\${conv}\n"
        "        COMMAND ${CMAKE_COMMAND} -E touch done.\${conv}\n"
        ")")

# default to "del_src\;true"
deftransform(normal
        # texture: convert to jpeg and dds
        "do_jpeg\;true"
        "jpeg_qual_rgb\;97"
        "jpeg_qual_a\;99"
        "do_dds\;false"
        "do_ogg\;true"
        "ogg_ogg\;false")
deftransform(normaldds
        # texture: convert to jpeg and dds
        # music: reduce bitrate
        "do_jpeg\;false"
        "do_jpeg_if_not_dds\;true"
        "jpeg_qual_rgb\;95"
        "jpeg_qual_a\;99"
        "do_dds\;true"
        "dds_flags\;"
        "do_ogg\;true"
        "ogg_ogg\;false")
deftransform(low
        # texture: convert to jpeg and dds
        # music: reduce bitrate
        "do_jpeg\;true"
        "jpeg_qual_rgb\;80"
        "jpeg_qual_a\;97"
        "do_dds\;false"
        "do_ogg\;true"
        "ogg_qual\;1")
deftransform(webp
        # texture: convert to jpeg and dds
        "do_jpeg\;false"
        "do_webp\;true"
        "do_dds\;false"
        "do_ogg\;false"
        "ogg_ogg\;false")
deftransform(lowdds
        # texture: convert to jpeg and dds
        # music: reduce bitrate
        "do_jpeg\;false"
        "do_jpeg_if_not_dds\;true"
        "jpeg_qual_rgb\;80"
        "jpeg_qual_a\;99"
        "do_dds\;true"
        "dds_flags\;"
        "do_ogg\;true"
        "ogg_qual\;1")
deftransform(mapping
        # texture: convert to jpeg and dds
        # music: reduce bitrate
        "do_jpeg\;true"
        "jpeg_qual_rgb\;80"
        "jpeg_qual_a\;97"
        "do_dds\;false"
        "do_ogg\;true"
        "ogg_qual\;1"
        )

## remove stuff radiant has no use for
#verbose find . -name \*_norm.\* -exec rm -f {} \;
#verbose find . -name \*_bump.\* -exec rm -f {} \;
#verbose find . -name \*_glow.\* -exec rm -f {} \;
#verbose find . -name \*_gloss.\* -exec rm -f {} \;
#verbose find . -name \*_pants.\* -exec rm -f {} \;
#verbose find . -name \*_shirt.\* -exec rm -f {} \;
#verbose find . -name \*_reflect.\* -exec rm -f {} \;
#verbose find . -not \( -name \*.tga -o -name \*.png -o -name \*.jpg \) -exec rm -f {} \;

buildpk3s(font-unifont.pk3dir "raw\;")
buildpk3s(font-xolonium.pk3dir "raw\;")
buildpk3s(xonotic-data.pk3dir "low\;-low" "normaldds\;" "normal\;-high")
buildpk3s(xonotic-maps.pk3dir "low\;-low" "normaldds\;" "normal\;-high" "mapping\;-mapping")
buildpk3s(xonotic-music.pk3dir "raw\;" "low\;-low")
buildpk3s(xonotic-nexcompat.pk3dir "normaldds\;")

message("CMake may appear to halt at '-- Configuring done', this is not the case")

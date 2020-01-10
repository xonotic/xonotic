cmake_minimum_required(VERSION 2.8.12 FATAL_ERROR)
project(xonotic)

option(DOWNLOAD_MAPS "Download new maps from the build server" ON)
option(BUILD_RELEASE "Package a release" OFF)

function(subproject id name)
    if ($ENV{XON_NO_${id}})
        return()
    endif ()
    if (EXISTS "${PROJECT_SOURCE_DIR}/${name}/CMakeLists.txt")
        add_subdirectory(${name} ${ARGN})
    endif ()
endfunction()

subproject(PKI d0_blind_id)
subproject(DAEMON daemon-glue)
subproject(DP darkplaces)
subproject(QCC gmqcc)
subproject(RADIANT netradiant)
subproject(DATA data/xonotic-data.pk3dir)

if (DOWNLOAD_MAPS)
    add_custom_target(update-maps ALL
            COMMAND ${PROJECT_SOURCE_DIR}/misc/tools/xonotic-map-compiler-autobuild download
            WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
            )
endif ()

if (BUILD_RELEASE)
    include(release.cmake)
endif ()

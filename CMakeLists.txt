cmake_minimum_required(VERSION 2.8.11 FATAL_ERROR)
project(xonotic)

option(DOWNLOAD_MAPS "Download new maps from the build server" ON)
option(BUILD_RELEASE "Package a release" OFF)

macro(subproject id name)
    if (EXISTS "${PROJECT_SOURCE_DIR}/${name}/CMakeLists.txt" AND NOT DEFINED ENV{XON_NO_${id}})
        add_subdirectory(${name} ${ARGN})
    endif ()
endmacro()

subproject(DAEMON  daemon)
subproject(PKI     d0_blind_id)
subproject(DP      darkplaces)
subproject(DATA    data/xonotic-data.pk3dir)
subproject(QCC     gmqcc)
subproject(RADIANT netradiant)

if (DOWNLOAD_MAPS)
    add_custom_target(update-maps ALL
            COMMAND ${PROJECT_SOURCE_DIR}/misc/tools/xonotic-map-compiler-autobuild download
            WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
            )
endif ()

if (BUILD_RELEASE)
    include(release.cmake)
endif ()

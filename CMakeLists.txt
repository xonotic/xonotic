cmake_minimum_required(VERSION 2.8.11)
project(xonotic)

add_subdirectory(darkplaces)
add_subdirectory(data/xonotic-data.pk3dir)
add_subdirectory(gmqcc)
add_subdirectory(netradiant)

add_custom_target(update-maps ALL
        COMMAND ${PROJECT_SOURCE_DIR}/misc/tools/xonotic-map-compiler-autobuild download
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        )

include(release.cmake)

# sdl2 cmake project-config input for ./configure scripts

set(prefix "/var/home/rpolzer/xonotic/misc/buildsrc/tmp/SDL2-2.0.10/../64") 
set(exec_prefix "${prefix}")
set(libdir "${exec_prefix}/lib")
set(SDL2_PREFIX "/var/home/rpolzer/xonotic/misc/buildsrc/tmp/SDL2-2.0.10/../64")
set(SDL2_EXEC_PREFIX "/var/home/rpolzer/xonotic/misc/buildsrc/tmp/SDL2-2.0.10/../64")
set(SDL2_LIBDIR "${exec_prefix}/lib")
set(SDL2_INCLUDE_DIRS "${prefix}/include/SDL2")
set(SDL2_LIBRARIES "-L${SDL2_LIBDIR}  -lmingw32 -lSDL2main -lSDL2 -mwindows")
string(STRIP "${SDL2_LIBRARIES}" SDL2_LIBRARIES)

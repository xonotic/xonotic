# nix-build
with import <nixpkgs> {}; { xonoticEnv =
stdenv.mkDerivation rec {

  version = "0.8.1";

  name = "xonotic-${version}";

  src = lib.sourceFilesBySuffices ./. [
    ".txt" ".cmake" ".in"
    ".c" ".cpp" ".h"
    ".inc" ".def"
    ".qc" ".qh"
    ".sh"
  ];

  enableParallelBuilding = true;

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
    "-DDOWNLOAD_MAPS=0"
  ];

  postPatch = ''
    NIX_CFLAGS_COMPILE="$NIX_CFLAGS_COMPILE ${lib.concatStringsSep " " [
      "-I${SDL2}/include/SDL2"  # for darkplaces
    ]}"
  '';

  buildInputs = [
    cmake  # for building
    git  # for versioning
    openssl  # for d0_blind_id
    SDL2  # for darkplaces
    # unzip  # for downloading maps
  ];

  runtimeInputs = [
    zlib
    curl

    libjpeg
    libpng

    freetype

    libogg
    libtheora
    libvorbis
  ];

  installPhase = ''
    mkdir $out
    exe=darkplaces/darkplaces
    rpath=$(patchelf --print-rpath $exe)
    rpath_firstparty=$out/d0_blind_id
    rpath_thirdparty=${lib.makeLibraryPath runtimeInputs}
    rpath=$rpath:$rpath_firstparty:$rpath_thirdparty
    patchelf --set-rpath $rpath $exe
    cp -r . $out
  '';
  dontPatchELF = true;
};}

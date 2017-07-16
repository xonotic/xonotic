# nix-shell -A xonotic
{
    nixpkgs ? <nixpkgs>,
    pkgs ? (import nixpkgs) {}
}:
with pkgs;
let
    VERSION = "0.8.2";
    targets = rec {
        xonotic = stdenv.mkDerivation rec {

            XON_NO_DAEMON = true;
            XON_NO_RADIANT = true;

            XON_NO_QCC = true;
            QCC = "${gmqcc}/gmqcc";

            version = VERSION;

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
                "-DDOWNLOAD_MAPS=0"
            ];

            nativeBuildInputs = [
                cmake   # for building
                git     # for versioning
                # unzip # for downloading maps
            ];

            buildInputs = [
                openssl # for d0_blind_id
                SDL2    # for darkplaces
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

            shellHook = ''
                export LD_LIBRARY_PATH=''${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}${lib.makeLibraryPath runtimeInputs}
            '';

            installPhase = ''
                mkdir $out

                exe=darkplaces/darkplaces
                rpath=$(patchelf --print-rpath $exe)
                rpath_firstparty=$out/d0_blind_id
                rpath_thirdparty=${lib.makeLibraryPath runtimeInputs}
                rpath=''${rpath:+$rpath:}$rpath_firstparty:$rpath_thirdparty
                patchelf --set-rpath $rpath $exe

                cp -r . $out
            '';

            dontPatchELF = true;
        };

        gmqcc = stdenv.mkDerivation rec {
            version = "xonotic-${VERSION}";

            name = "gmqcc-${version}";

            src = ./gmqcc;

            enableParallelBuilding = true;

            installPhase = ''
                mkdir $out
                cp -r . $out
            '';
        };
    };
in targets

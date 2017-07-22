# nix-shell -A xonotic
# --argstr cc clang
{
    nixpkgs ? <nixpkgs>,
    pkgs ? (import nixpkgs) {},
    cc ? null,
}:
with pkgs;
let
    VERSION = "0.8.2";
    stdenv = if (cc != null) then overrideCC pkgs.stdenv pkgs."${cc}" else pkgs.stdenv;
    targets = rec {
        xonotic = stdenv.mkDerivation rec {
            name = "xonotic-${version}";
            version = VERSION;

            XON_NO_DAEMON = true;
            XON_NO_RADIANT = true;

            XON_NO_QCC = true;
            QCC = "${gmqcc}/gmqcc";

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
            name = "gmqcc-${version}";
            version = "xonotic-${VERSION}";

            src = ./gmqcc;

            enableParallelBuilding = true;

            installPhase = ''
                mkdir $out
                cp -r . $out
            '';
        };

        netradiant = stdenv.mkDerivation rec {
            name = "netradiant-${version}";
            version = VERSION;

            XON_NO_DAEMON = true;
            XON_NO_DP = true;
            XON_NO_PKI = true;
            XON_NO_QCC = true;
            XON_NO_DATA = true;

            src = ./netradiant;

            enableParallelBuilding = true;

            cmakeFlags = [
                "-DDOWNLOAD_MAPS=0"
                "-DGTK_NS=GTK"
            ];

            nativeBuildInputs = [
                cmake   # for building
                git     # for versioning
            ];

            buildInputs = [
                pkgconfig
                glib
                libxml2
                ncurses
                libjpeg
                libpng

                mesa

                xorg.libXt
                xorg.libXmu
                xorg.libSM
                xorg.libICE

                gnome2.gtk
                gnome2.gtkglext
            ];
        };
    };
in targets

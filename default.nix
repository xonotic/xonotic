# nix-shell -A shell
# --argstr cc clang
{
    nixpkgs ? <nixpkgs>,
    pkgs ? (import nixpkgs) {},
    cc ? null
}:
with pkgs;
let
    VERSION = "0.8.2";
    cmake = pkgs.cmake_2_8;
    targets = rec {
        xonotic = mkDerivation { pki = true; dp = true; data = true; } rec {
            name = "xonotic-${version}";
            version = VERSION;

            src = lib.sourceFilesBySuffices ./. [
                ".txt" ".cmake" ".in"
                ".c" ".cpp" ".h"
                ".inc" ".def"
                ".qc" ".qh"
                ".sh"
            ];

            env = {
                QCC = "${gmqcc}/bin/gmqcc";
            };

            nativeBuildInputs = [
                cmake   # for building
                git     # for versioning
                # unzip # for downloading maps
            ];

            cmakeFlags = [
                "-DDOWNLOAD_MAPS=0"
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

        gmqcc = mkDerivation { qcc = true; } rec {
            name = "gmqcc-${version}";
            version = "xonotic-${VERSION}";

            src = ./gmqcc;

            installPhase = ''
                mkdir -p $out/bin
                cp gmqcc $out/bin
            '';
        };

        netradiant = mkDerivation { radiant = true; } rec {
            name = "netradiant-${version}";
            version = VERSION;

            src = ./netradiant;

            nativeBuildInputs = [
                cmake   # for building
                git     # for versioning
            ];

            cmakeFlags = [
                "-DDOWNLOAD_MAPS=0"
            ];

            buildInputs = [
                pkgconfig
                glib
                pcre
                libxml2
                ncurses
                libjpeg
                libpng
                minizip

                mesa

                xorg.libXt
                xorg.libXmu
                xorg.libSM
                xorg.libICE
                xorg.libpthreadstubs
                xorg.libXdmcp

                gnome3.gtk
                gnome2.gtk
                gnome2.gtkglext
            ];
        };
    };
    stdenv = if (cc != null) then overrideCC pkgs.stdenv pkgs."${cc}" else pkgs.stdenv;
    mkEnableTargets = args: {
        XON_NO_PKI = !args?pki;
        XON_NO_DP = !args?dp;
        XON_NO_DATA = !args?data;
        XON_NO_QCC = !args?qcc;
        XON_NO_RADIANT = !args?radiant;
    };
    mkDerivation = targets: {env ? {}, shellHook ? "", runtimeInputs ? [], ...}@args:
        stdenv.mkDerivation (
            (mkEnableTargets targets)
            // { enableParallelBuilding = true; }
            // (removeAttrs args ["env" "shellHook" "runtimeInputs"])  # passthru
            // env
            // {
                shellHook = ''
                    ${shellHook}
                    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (n: v: "export ${n}=${v}") env)}
                    export LD_LIBRARY_PATH=''${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}${lib.makeLibraryPath runtimeInputs}
                '';
            }
        );
    shell = let inputs = (lib.mapAttrsToList (n: v: v) targets); in stdenv.mkDerivation (rec {
        name = "xon-shell";
        XON_NO_DAEMON = true;
        nativeBuildInputs = builtins.map (it: it.nativeBuildInputs) inputs;
        buildInputs = builtins.map (it: it.buildInputs) inputs;
        shellHook = builtins.map (it: it.shellHook) (builtins.filter (it: it?shellHook) inputs);
    });
in { inherit shell; } // targets

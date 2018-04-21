# nix-shell -A shell
# nix-build -A xonotic
# --argstr cc clang
# for it in $(nix-build -A dockerImage --no-out-link); do docker load -i $it; done
{
    pkgs, lib,
    cc ? null,
    cmake ? pkgs.cmake_2_8,
}:
let
    VERSION = "0.8.2";

    srcs = {
        # https://gitlab.com/xonotic/xonotic
        "xonotic" = localFilesMain ./.;
        "data/font-dejavu" = localFiles ./data/font-dejavu.pk3dir;
        "data/font-nimbussansl" = localFiles ./data/font-nimbussansl.pk3dir;
        "data/font-unifont" = localFiles ./data/font-unifont.pk3dir;
        "data/font-xolonium" = localFiles ./data/font-xolonium.pk3dir;

        # https://gitlab.com/xonotic/d0_blind_id
        "d0_blind_id" = localFiles ./d0_blind_id;

        # https://gitlab.com/xonotic/darkplaces
        "darkplaces" = localFiles ./darkplaces;

        # https://gitlab.com/xonotic/gmqcc
        "gmqcc" = localFiles ./gmqcc;

        # https://gitlab.com/xonotic/netradiant
        "netradiant" = localFiles ./netradiant;

        # https://gitlab.com/xonotic/xonotic-data.pk3dir
        "data/xonotic-data" = localFilesCustom ./data/xonotic-data.pk3dir (name: type: type == "directory" || !(isCode name));
        "data/xonotic-data/qcsrc" = localFilesCustom ./data/xonotic-data.pk3dir (name: type: type == "directory" || (isCode name));

        # https://gitlab.com/xonotic/xonotic-maps.pk3dir
        "data/xonotic-maps" = localFiles ./data/xonotic-maps.pk3dir;

        # https://gitlab.com/xonotic/xonotic-music.pk3dir
        "data/xonotic-music" = localFiles ./data/xonotic-music.pk3dir;

        # https://gitlab.com/xonotic/xonotic-nexcompat.pk3dir
        "data/xonotic-nexcompat" = localFiles ./data/xonotic-nexcompat.pk3dir;
    };

    localFilesMain = src: let
        project = toString ./.;
        cleanSourceFilterMain = name: type: let
            baseName = baseNameOf (toString name);
            result = (cleanSourceFilter name type)
                && !(name == "${project}/release")
                && !(name == "${project}/d0_blind_id")
                && !(name == "${project}/daemon")
                && !(name == "${project}/darkplaces")
                && !(name == "${project}/data")
                && !(name == "${project}/gmqcc")
                && !(name == "${project}/netradiant")
                && !(name == "${project}/wiki" || name == "${project}/wiki.yes")
                && !(name == "${project}/xonstat" || name == "${project}/xonstat.yes")
            ;
        in result;
    in builtins.filterSource cleanSourceFilterMain src;

    isCode = name: let
        baseName = baseNameOf (toString name);
        result = !(false
            || (lib.hasSuffix ".ase" baseName)
            || (lib.hasSuffix ".dem" baseName)
            || (lib.hasSuffix ".dpm" baseName)
            || (lib.hasSuffix ".framegroups" baseName)
            || (lib.hasSuffix ".iqm" baseName)
            || (lib.hasSuffix ".jpg" baseName)
            || (lib.hasSuffix ".lmp" baseName)
            || (lib.hasSuffix ".md3" baseName)
            || (lib.hasSuffix ".mdl" baseName)
            || (lib.hasSuffix ".obj" baseName)
            || (lib.hasSuffix ".ogg" baseName)
            || (lib.hasSuffix ".png" baseName)
            || (lib.hasSuffix ".shader" baseName)
            || (lib.hasSuffix ".skin" baseName)
            || (lib.hasSuffix ".sounds" baseName)
            || (lib.hasSuffix ".sp2" baseName)
            || (lib.hasSuffix ".spr" baseName)
            || (lib.hasSuffix ".spr32" baseName)
            || (lib.hasSuffix ".svg" baseName)
            || (lib.hasSuffix ".tga" baseName)
            || (lib.hasSuffix ".wav" baseName)
            || (lib.hasSuffix ".width" baseName)
            || (lib.hasSuffix ".zym" baseName)
        );
    in result;

    pk3 = drv: mkDerivation {
        name = "${drv.name}.pk3";
        version = drv.version;

        nativeBuildInputs = with pkgs; [
            zip
        ];

        phases = [ "installPhase" ];
        installPhase = ''
            (cd ${drv} && zip -r ${drv.pk3args or ""} $out .)
        '';
    };

    targets = rec {
        font-dejavu = mkDerivation rec {
            name = "font-dejavu-${version}";
            version = VERSION;

            src = srcs."data/font-dejavu";

            phases = [ "installPhase" ];
            installPhase = ''
                cp -r $src $out
            '';
        };

        font-nimbussansl = mkDerivation rec {
            name = "font-nimbussansl-${version}";
            version = VERSION;

            src = srcs."data/font-nimbussansl";

            phases = [ "installPhase" ];
            installPhase = ''
                cp -r $src $out
            '';
        };

        font-unifont = mkDerivation rec {
            name = "font-unifont-${version}";
            version = VERSION;

            src = srcs."data/font-unifont";

            phases = [ "installPhase" ];
            installPhase = ''
                cp -r $src $out
            '';
        };

        font-xolonium = mkDerivation rec {
            name = "font-xolonium-${version}";
            version = VERSION;

            src = srcs."data/font-xolonium";

            phases = [ "installPhase" ];
            installPhase = ''
                cp -r $src $out
            '';
        };

        d0_blind_id = mkDerivation rec {
            name = "d0_blind_id-${version}";
            version = "xonotic-${VERSION}";

            src = srcs."d0_blind_id";

            nativeBuildInputs = [
                cmake
            ];

            buildInputs = with pkgs; [
                openssl
            ];

            installPhase = ''
                mkdir -p $out/lib
                cp libd0_blind_id.so $out/lib

                mkdir -p $out/include/d0_blind_id
                (cd $src; cp d0_blind_id.h d0.h $out/include/d0_blind_id)
            '';
        };

        darkplaces = let
            unwrapped = mkDerivation rec {
                name = "darkplaces-unwrapped-${version}";
                version = "xonotic-${VERSION}";

                src = srcs."darkplaces";

                nativeBuildInputs = [
                    cmake
                ];

                buildInputs = with pkgs; [
                    SDL2

                    zlib
                    libjpeg
                ];

                installPhase = ''
                    mkdir -p $out/bin
                    cp darkplaces-{dedicated,sdl} $out/bin
                '';
            };
            result = mkDerivation rec {
                name = "darkplaces-${version}";
                version = "xonotic-${VERSION}";

                buildInputs = unwrapped.buildInputs ++ runtimeInputs;
                runtimeInputs = with pkgs; [
                    d0_blind_id

                    freetype

                    curl
                    zlib

                    libjpeg
                    libpng

                    libogg
                    libtheora
                    libvorbis
                ];

                phases = [ "installPhase" ];
                installPhase = ''
                    mkdir -p $out/bin

                    cp -r ${unwrapped}/bin .
                    chmod +w bin/*
                    cd bin

                    for exe in darkplaces-sdl; do
                        rpath=$(patchelf --print-rpath $exe)
                        rpath=''${rpath:+$rpath:}${lib.makeLibraryPath runtimeInputs}
                        patchelf --set-rpath $rpath $exe
                    done

                    for exe in dedicated sdl; do
                        cp darkplaces-$exe $out/bin/xonotic-linux64-$exe
                    done
                '';
            };
        in result;

        gmqcc = mkDerivation rec {
            name = "gmqcc-${version}";
            version = "xonotic-${VERSION}";

            src = srcs."gmqcc";

            nativeBuildInputs = [
                cmake
            ];

            installPhase = ''
                mkdir -p $out/bin
                cp gmqcc $out/bin
            '';
        };

        netradiant = mkDerivation rec {
            name = "netradiant-${version}";
            version = VERSION;

            src = srcs."netradiant";

            nativeBuildInputs = with pkgs; [
                cmake
                git
            ];

            buildInputs = with pkgs; [
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

                gnome2.gtk
                gnome2.gtkglext
                gnome3.gtk
            ];
        };

        xonotic-data = mkDerivation rec {
            name = "xonotic-data-${version}";
            version = "xonotic-${VERSION}";

            src = srcs."data/xonotic-data";

            phases = [ "installPhase" ];
            installPhase = ''
                mkdir $out
                cp -r $src/. $out
                chmod -R +w $out
                find $out -depth -type d -empty -exec rmdir {} \;
            '';
        };

        xonotic-data-code = mkDerivation rec {
            name = "xonotic-data-code-${version}";
            version = "xonotic-${VERSION}";

            src = srcs."data/xonotic-data/qcsrc";

            env = {
                QCC = "${gmqcc}/bin/gmqcc";
            };

            nativeBuildInputs = with pkgs; [
                cmake
                git
            ];

            installPhase = ''
                mkdir $out
                cp -r $src/. $out
                chmod -R +w $out
                cp {menu,progs,csprogs}.{dat,lno} $out
                find $out -depth -type d -empty -exec rmdir {} \;
            '';
        };

        # todo: build
        xonotic-maps = mkDerivation rec {
            name = "xonotic-maps-${version}";
            version = "xonotic-${VERSION}";

            src = srcs."data/xonotic-maps";

            phases = [ "installPhase" ];
            installPhase = ''
                mkdir $out
                cp -r $src/. $out
            '';
        };

        xonotic-music = mkDerivation rec {
            name = "xonotic-music-${version}";
            version = "xonotic-${VERSION}";

            src = srcs."data/xonotic-music";

            phases = [ "installPhase" ];
            installPhase = ''
                mkdir $out
                cp -r $src/. $out
            '';

            passthru.pk3args = "-0";
        };

        xonotic-nexcompat = mkDerivation rec {
            name = "xonotic-nexcompat-${version}";
            version = "xonotic-${VERSION}";

            src = srcs."data/xonotic-nexcompat";

            phases = [ "installPhase" ];
            installPhase = ''
                mkdir $out
                cp -r $src/. $out
            '';
        };

        xonotic = mkDerivation rec {
            name = "xonotic-${version}";
            version = VERSION;

            src = srcs."xonotic";

            env = {
                XON_NO_DAEMON = "1";
            };

            passthru.paks = {
                inherit
                    font-dejavu
                    font-nimbussansl
                    font-unifont
                    font-xolonium
                    xonotic-data
                    xonotic-data-code
                    xonotic-maps
                    xonotic-music
                    xonotic-nexcompat
                ;
            };

            phases = [ "installPhase" ];

            installPhase = ''
                mkdir $out
                cp -r $src/. $out
                cp ${darkplaces}/bin/* $out

                mkdir -p $out/data
                ${lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v:
                    # "cp ${pk3 v} $out/data/${k}.pk3"
                    "ln -s ${v} $out/data/${k}.pk3dir"
                ) passthru.paks)}

                mkdir -p $out/mapping
                ln -s ${netradiant} $out/mapping/${netradiant.name}
            '';
        };

        dockerImage = let
            main = pkgs.dockerTools.buildImage {
                name = "xonotic";
                tag = VERSION;
                contents = mkDerivation {
                    name = "xonotic-init";
                    phases = [ "installPhase" ];
                    installPhase = ''
                        mkdir -p $out
                        cat > $out/init <<EOF
                        #!${stdenv.shell}
                        ${pkgs.coreutils}/bin/ls -l /data
                        exec ${darkplaces}/bin/xonotic-linux64-dedicated
                        EOF
                        chmod +x $out/init
                    '';
                };
                config.Entrypoint = "/init";
            };
            unpackImage = { name, from, to }: pkgs.dockerTools.buildImage {
                name = "xonotic_${name}";
                tag = VERSION;
                contents = mkDerivation {
                    name = "xonotic-${name}-init";
                    phases = [ "installPhase" ];
                    installPhase = ''
                        mkdir -p $out
                        cat > $out/init <<EOF
                        #!${stdenv.shell}
                        ${pkgs.coreutils}/bin/cp -r ${from} /data/${to}
                        EOF
                        chmod +x $out/init
                    '';
                };
                config.Entrypoint = "/init";
            };
        in { main = main; }
            // (lib.mapAttrs (k: v: unpackImage { name = k; from = pk3 v; to = "${k}.pk3"; }) xonotic.paks)
        ;
    };

    cleanSourceFilter = name: type: let
        baseName = baseNameOf (toString name);
        result = (lib.cleanSourceFilter name type)
            && !(lib.hasSuffix ".nix" baseName)
            && !(type == "directory" && baseName == ".git")
            && !(type == "directory" && baseName == ".idea")
            && !(type == "directory" && (lib.hasPrefix "cmake-build-" baseName))
        ;
    in result;

    localFilesCustom = src: filter:
        builtins.filterSource (name: type: (cleanSourceFilter name type) && (filter name type)) src
    ;

    localFiles = src: localFilesCustom src (name: type: true);

    stdenv = if (cc == null) then pkgs.stdenv
            else pkgs.overrideCC pkgs.stdenv pkgs."${cc}";

    mkDerivation = {env ? {}, shellHook ? "", runtimeInputs ? [], ...}@args: stdenv.mkDerivation ({}
        // { enableParallelBuilding = true; }
        // (removeAttrs args ["env" "shellHook" "runtimeInputs"])
        // env
        // {
            shellHook = ''
                ${shellHook}
                ${lib.concatStringsSep "\n" (lib.mapAttrsToList (n: v: "export ${n}=${v}") env)}
                export LD_LIBRARY_PATH=''${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}${lib.makeLibraryPath runtimeInputs}
            '';
        }
    );

    shell = let inputs = (lib.mapAttrsToList (k: v: v) targets); in stdenv.mkDerivation (rec {
        name = "xonotic-shell";
        nativeBuildInputs = builtins.map (it: it.nativeBuildInputs) (builtins.filter (it: it?nativeBuildInputs) inputs);
        buildInputs = builtins.map (it: it.buildInputs) (builtins.filter (it: it?buildInputs) inputs);
        shellHook = builtins.map (it: it.shellHook) (builtins.filter (it: it?shellHook) inputs);
    });
in { inherit shell; } // targets

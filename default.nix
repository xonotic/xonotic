# nix-shell .
# dst=.
# cmake -GNinja -H. -B $dst && (cd $dst && cmake --build .)
# nix-shell . --run './all compile'
# nix-shell . --run 'LD_LIBRARY_PATH="$HOME/.nix-profile/lib:${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" LD_PRELOAD=/run/opengl-driver/lib/libGL.so.1 ./all run'
with import <nixpkgs> {}; {
	xonoticEnv = stdenv.mkDerivation {
		name = "xonotic";
		buildInputs = [
			alsaLib
			freetype
			libjpeg
			libpng
			mesa
			xorg.libX11
			xorg.libXext
			xorg.libXpm
			xorg.libXxf86vm
			zlib
		];
	};
}

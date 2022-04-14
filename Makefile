DPSRC = source/darkplaces
D0SRC = source/d0_blind_id
CLIENT = xonotic-local-sdl
SERVER = xonotic-local-dedicated

# CC and MAKEFLAGS are always set so ?= has no effect, therefore
# use CFLAGS to set default optimisations and support user override
CFLAGS ?= -pipe -march=native -mtune=native -flto=auto
# user can override this with make -j
MAKEFLAGS = -j$(shell nproc)
# DP makefile overrides CFLAGS (exporting CFLAGS does work for d0_blind_id but so does this)
export CC += $(CFLAGS)

# d0_blind_id header location
export CC += -I$(PWD)/source/
# d0_blind_id static libs location
export CC += -L$(PWD)/$(D0SRC)/.libs/
# Player IDs: DP_LINK_CRYPTO needs to be set (else it defaults to "dlopen"),
# it should be set to "shared" but then LIB_CRYPTO gets overridden in DP makefile,
# and we need to set LIB_CRYPTO such that libgmp gets linked
export DP_LINK_CRYPTO=foo
export CFLAGS_CRYPTO=-DLINK_TO_CRYPTO
export LIB_CRYPTO=-ld0_blind_id -lgmp
# AES
export DP_LINK_CRYPTO_RIJNDAEL=shared


.PHONY: help
help:
	@echo
	@echo "  ===== Xonotic Makefile for stable and beta releases ====="
	@echo
	@echo "The DarkPlaces engine builds will be named $(CLIENT) and $(SERVER) and"
	@echo "will be preferred by the xonotic-linux-sdl.sh and xonotic-linux-dedicated.sh scripts."
	@echo
	@echo "For more info, see https://gitlab.com/xonotic/xonotic/-/wikis/Compiling"
	@echo
	@echo "-O3 is already enabled for DarkPlaces. Do not add any math flags!"
	@echo
	@echo "MAKEFLAGS=$(MAKEFLAGS)"
	@echo "CFLAGS= $(CFLAGS)"
	@echo
	@echo "  make clean-sources         Delete build objects"
	@echo "  make clean                 Delete engine builds and build objects"
	@echo
	@echo "  make update-stable         Update to the latest stable release via rsync"
	@echo "  make update-beta           Update to the latest daily autobuild via rsync"
	@echo
	@echo "  make server                Compile $(SERVER)"
	@echo "  make client                Compile $(CLIENT)"
	@echo "  make both"
	@echo

.PHONY: nogit
nogit:
	@if [ -d .git ]; then \
		echo "To compile from git sources, please use ./all instead!"; \
		exit 1; \
	fi

.PHONY: clean-sources
clean-sources: nogit
	$(MAKE) -C $(DPSRC) clean
	$(MAKE) -C $(D0SRC) clean

.PHONY: clean
clean: clean-sources
	$(RM) $(CLIENT) $(SERVER)

.PHONY: update-stable
update-stable: nogit
	misc/tools/rsync-updater/update-to-release.sh

.PHONY: update-beta
update-beta: nogit
	misc/tools/rsync-updater/update-to-autobuild.sh

$(D0SRC)/Makefile:
	( cd $(D0SRC) && ./autogen.sh && ./configure --enable-static --disable-shared )

.PHONY: d0_blind_id
d0_blind_id: nogit $(D0SRC)/Makefile
	$(MAKE) -C $(D0SRC)

.PHONY: server
server: d0_blind_id
	$(MAKE) -C $(DPSRC) sv-release
	cp -v $(DPSRC)/darkplaces-dedicated $(SERVER)

.PHONY: client
client: d0_blind_id
	$(MAKE) -C $(DPSRC) sdl-release
	cp -v $(DPSRC)/darkplaces-sdl $(CLIENT)

.PHONY: both
both: client server


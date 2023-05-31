DPSRC = source/darkplaces
D0SRC = source/d0_blind_id
CLIENT = xonotic-local-sdl
SERVER = xonotic-local-dedicated

# CC and MAKEFLAGS are always set so ?= has no effect, therefore
# we use CFLAGS to set default optimisations which users may override
CFLAGS ?= -pipe -march=native -mtune=native -flto=auto
# user can override this with make -j
MAKEFLAGS := -j$(shell nproc)
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
	@printf "     \e[1;33m===== Xonotic Makefile for stable and beta releases =====\e[m\n"
	@echo
	@printf "The DarkPlaces Engine builds will be named \e[1m$(CLIENT) \e[mand \e[1m$(SERVER)\e[m\n"
	@printf "and will be preferred by \e[1mxonotic-linux-sdl.sh \e[mand \e[1mxonotic-linux-dedicated.sh \e[mscripts.\n"
	@echo
	@printf "More info is available at \e[1;36mhttps://gitlab.com/xonotic/xonotic/-/wikis/Compiling\e[m\n"
	@echo
	@echo   "-O3 is already enabled for DarkPlaces Engine. Do not add any math flags!"
	@echo
	@echo   "MAKEFLAGS=$(MAKEFLAGS)"
	@echo   "CFLAGS= $(CFLAGS)"
	@echo
	@echo   "  make clean-sources         Delete build objects"
	@echo   "  make clean                 Delete engine builds and build objects"
	@echo
	@echo   "  make update-stable         Update to the latest stable release via rsync"
	@echo   "  make update-beta           Update to the latest daily autobuild via rsync"
	@echo
	@printf "  make server                Compile \e[1m$(SERVER)\e[m\n"
	@printf "  make client                Compile \e[1m$(CLIENT)\e[m\n"
	@echo   "  make both"
	@echo

GIT := $(shell [ -d .git ] && printf "\e[1;31mThis Makefile only supports stable releases and autobuilds, whereas you are using a git repository.  To compile from git, please read https://gitlab.com/xonotic/xonotic/-/wikis/Repository_Access\e[m")
ifdef GIT
  $(error $(GIT))
endif

.EXTRA_PREREQS := $(findstring update-stable,$(MAKECMDGOALS)) $(findstring update-beta,$(MAKECMDGOALS))

.PHONY: clean-sources
clean-sources:
	$(MAKE) -C $(DPSRC) clean
	$(MAKE) -C $(D0SRC) clean

.PHONY: clean
clean: clean-sources
	$(RM) $(CLIENT) $(SERVER)

.PHONY: update-stable
update-stable:
	misc/tools/rsync-updater/update-to-release.sh

.PHONY: update-beta
update-beta:
	misc/tools/rsync-updater/update-to-autobuild.sh

$(D0SRC)/Makefile:
	( cd $(D0SRC) && ./autogen.sh && ./configure --enable-static --disable-shared )

.PHONY: d0_blind_id
d0_blind_id: $(D0SRC)/Makefile
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


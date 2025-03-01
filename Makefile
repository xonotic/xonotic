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
# Player IDs
export DP_LINK_CRYPTO=static
# AES
export DP_LINK_CRYPTO_RIJNDAEL=static


.PHONY: help
help:
	@echo
	@printf "     \e[1;33m===== Xonotic Makefile for stable and beta releases =====\e[m\n"
	@echo
	@printf "The DarkPlaces Engine builds will be named \e[1;32m$(CLIENT) \e[mand \e[1;32m$(SERVER)\e[m\n"
	@printf "and will be preferred by \e[1;32mxonotic-linux-sdl.sh \e[mand \e[1;32mxonotic-linux-dedicated.sh \e[mscripts\n"
	@echo   "which should be used to play with the SDL client or host a dedicated server (respectively)."
	@echo
	@echo   "Moving binaries or data files outside of this directory is not officially supported as"
	@echo   "this isn't compatible with the included updater and the working directory may be incorrect."
	@printf "The above \e[1;32mscripts\e[m may be called from elsewhere via symlinks, .desktop files, or other scripts.\n"
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
	@echo   "  make update-beta           Update to the latest beta autobuild via rsync"
	@echo
	@printf "  make server                Compile \e[1;32m$(SERVER)\e[m\n"
	@printf "  make client                Compile \e[1;32m$(CLIENT)\e[m\n"
	@echo   "  make both"
	@echo

GIT := $(shell [ -d .git ] && printf "\e[1;31mThis Makefile only supports stable releases and autobuilds, whereas you are using a git repository.  To compile from git, please read https://gitlab.com/xonotic/xonotic/-/wikis/Repository_Access\e[m")
ifdef GIT
  $(error $(GIT))
endif


# If requested, these targets must always run first:
.EXTRA_PREREQS := $(filter clean update-stable update-beta, $(MAKECMDGOALS))

.PHONY: clean-sources
clean-sources:
	$(MAKE) -C $(DPSRC) clean
	( $(MAKE) -C $(D0SRC) clean || true ) # autotools may not have created the Makefile yet
clean-sources: .EXTRA_PREREQS =  # prevents circular dependency

.PHONY: clean
clean: clean-sources
	$(RM) $(CLIENT) $(SERVER)

.PHONY: update-stable
update-stable:
	misc/tools/rsync-updater/update-to-release.sh

.PHONY: update-beta
update-beta:
	misc/tools/rsync-updater/update-to-autobuild.sh


$(D0SRC)/.libs/libd0_blind_id.a $(D0SRC)/.libs/libd0_rijndael.a:
	( cd $(D0SRC) && ./autogen.sh && ./configure --enable-static --disable-shared )
	$(MAKE) -C $(D0SRC) clean  # ensures missing .a files are created FIXME WORKAROUND
	$(MAKE) -C $(D0SRC)

$(DPSRC)/darkplaces-dedicated: $(D0SRC)/.libs/libd0_blind_id.a
	$(MAKE) -C $(DPSRC) sv-release
$(SERVER): $(DPSRC)/darkplaces-dedicated
	cp $(DPSRC)/darkplaces-dedicated $(SERVER)

$(DPSRC)/darkplaces-sdl: $(D0SRC)/.libs/libd0_blind_id.a
	$(MAKE) -C $(DPSRC) sdl-release
$(CLIENT): $(DPSRC)/darkplaces-sdl
	cp $(DPSRC)/darkplaces-sdl $(CLIENT)


.PHONY: server
server: $(SERVER)

.PHONY: client
client: $(CLIENT)

.PHONY: both
both: client server


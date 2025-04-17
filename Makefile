DPSRC = source/darkplaces
D0SRC = source/d0_blind_id
CLIENTBIN ?= xonotic-sdl
SERVERBIN ?= xonotic-dedicated

# CC and MAKEFLAGS are always set so ?= has no effect, therefore
# we use CFLAGS to set default optimisations which users may override
CFLAGS ?= -march=native -mtune=native
CFLAGS += -flto=auto
# user can override this with make -j
MAKEFLAGS := -j$(shell nproc)
# DP makefile overrides CFLAGS (exporting CFLAGS does work for d0_blind_id but so does this)
export CC += $(CFLAGS)

.PHONY: help
help:
	@echo
	@printf "     \e[1;33m===== Xonotic Makefile for stable and beta releases =====\e[m\n"
	@echo
	@printf "The new executables will be named \e[1;32m$(CLIENTBIN) \e[mand \e[1;32m$(SERVERBIN)\e[m\n"
	@printf "and will be preferred by the \e[1;32mxonotic-linux-sdl.sh \e[mand \e[1;32mxonotic-linux-dedicated.sh \e[mscripts\n"
	@echo   "which are used to play with the SDL client or host a dedicated server (respectively)."
	@echo
	@echo   "Moving files outside of this directory isn't officially supported as it's"
	@echo   "incompatible with the included updater and the working directory may be incorrect."
	@printf "Instead the above \e[1;32mscripts\e[m may be called from elsewhere via symlinks, .desktop files, etc.\n"
	@echo
	@printf "More info is available at \e[1;36mhttps://gitlab.com/xonotic/xonotic/-/wikis/Compiling\e[m\n"
	@echo
	@echo   "-O3 and all optimisations for your CPU are enabled by default. Do not add any math flags!"
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
	@printf "  make server                Compile \e[1;32m$(SERVERBIN)\e[m\n"
	@printf "  make client                Compile \e[1;32m$(CLIENTBIN)\e[m\n"
	@echo   "  make all                   Compile both client and server"
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
# autotools may not have created the Makefile yet so check first and don't fail
	( [ -f $(D0SRC)/Makefile ] && $(MAKE) -C $(D0SRC) clean || true )
clean-sources: .EXTRA_PREREQS =  # prevents circular dependency

.PHONY: clean
clean: clean-sources
	$(RM) $(CLIENTBIN) $(SERVERBIN)

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

export DP_LINK_CRYPTO=static
export DP_LINK_CRYPTO_RIJNDAEL=static
# d0_blind_id/d0_blind_id.h and .a locations (respectively)
D0INC=-I"$(PWD)/source/" -L"$(PWD)/$(D0SRC)/.libs/"

.PHONY: all both
all both: client server

.PHONY: server
server: $(SERVERBIN)
$(DPSRC)/darkplaces-dedicated: $(D0SRC)/.libs/libd0_blind_id.a
	CC='$(CC) $(D0INC)' $(MAKE) -C $(DPSRC) sv-release
$(SERVERBIN): $(DPSRC)/darkplaces-dedicated
	cp $(DPSRC)/darkplaces-dedicated $(SERVERBIN)

.PHONY: client
client: $(CLIENTBIN)
$(DPSRC)/darkplaces-sdl: $(D0SRC)/.libs/libd0_blind_id.a
	CC='$(CC) $(D0INC)' $(MAKE) -C $(DPSRC) sdl-release
$(CLIENTBIN): $(DPSRC)/darkplaces-sdl
	cp $(DPSRC)/darkplaces-sdl $(CLIENTBIN)


# GNU make standard directory variables for install targets
DESTDIR ?=
prefix ?= /usr/local
exec_prefix ?= $(prefix)
bindir ?= $(exec_prefix)/bin
libdir ?= $(exec_prefix)/lib
datarootdir ?= $(prefix)/share
datadir ?= $(datarootdir)
docdir ?= $(datarootdir)/doc/xonotic

# $BASEDIR is where data/*.pk3 will be installed.
# By default this will be located at runtime by installing the engine there and symlinking to it in $bindir.
# If $BASEDIR (preferred) or $DP_FS_BASEDIR (compat synonym) was defined externally the engine will be installed to $bindir,
# the value of $BASEDIR / $DP_FS_BASEDIR will be compiled into it, and no symlinks are needed.
ifdef BASEDIR
	export DP_FS_BASEDIR = $(BASEDIR)
else
	# don't put spaces after the commas, they end up in the path!
	BASEDIR = $(if $(DP_FS_BASEDIR),$(DP_FS_BASEDIR),$(datadir)/xonotic)
endif

INSTALL ?= install
INSTALL_PROGRAM ?= $(INSTALL) -vD
INSTALL_DATA ?= $(INSTALL) -vDm644

.PHONY: install
install: install-data install-engine install-desktop install-doc
.PHONY: install-client
install-client: install-data install-engine-client install-desktop-client install-doc-client
.PHONY: install-server
install-server: install-data install-engine-server install-desktop-server install-doc-server
.PHONY: install-engine
install-engine: install-engine-client install-engine-server
.PHONY: install-desktop
install-desktop: install-desktop-client install-desktop-server
.PHONY: install-doc
install-doc: install-doc-client install-doc-server

.PHONY: install-help
install-help:
	@echo
	@printf "     \e[1;33m===== Xonotic Makefile: install target list =====\e[m\n"
	@echo
	@printf "More info is available at \e[1;36mhttps://gitlab.com/xonotic/xonotic/-/wikis/Compiling\e[m\n"
	@echo
	@echo   "  install: install-data install-engine install-desktop install-doc"
	@echo   "  install-client: install-data install-engine-client install-desktop-client install-doc-client"
	@echo   "  install-server: install-data install-engine-server install-desktop-server install-doc-server"
	@echo
	@echo   "  install-data:                                                    data/*.pk3 VFS contents, pubkey"
	@echo   "  install-engine: install-engine-client install-engine-server      Main binaries"
	@echo   "  install-desktop: install-desktop-client install-desktop-server   desktop icon, metainfo"
	@echo   "  install-doc: install-doc-client install-doc-server"

.PHONY: install-data
install-data:
	$(RM) -rf $(DESTDIR)$(BASEDIR)/data
	for p in data/*.pk3; do $(INSTALL_DATA) $$p $(DESTDIR)$(BASEDIR)/$$p || exit 1; done
	$(INSTALL_DATA) key_0.d0pk $(DESTDIR)$(BASEDIR)/key_0.d0pk

# TODO: when the .sh scripts are fully obsolete, make install-engine-* not PHONY (hint: declare the target inside the ifdef)
.PHONY: install-engine-client
install-engine-client: client
ifdef DP_FS_BASEDIR # path for distro package builds that define $BASEDIR / $DP_FS_BASEDIR
	$(INSTALL_PROGRAM) source/darkplaces/darkplaces-sdl $(DESTDIR)$(bindir)/xonotic-sdl
else # end users aren't expected to `make install` but if they do this path makes their install functional
	$(INSTALL_PROGRAM) source/darkplaces/darkplaces-sdl $(DESTDIR)$(BASEDIR)/xonotic-sdl
	# install-links
	$(INSTALL_PROGRAM) xonotic-linux-sdl.sh $(DESTDIR)$(BASEDIR)/xonotic-linux-sdl.sh
	$(INSTALL) -d $(DESTDIR)$(bindir)
	ln -snf $(BASEDIR)/xonotic-linux-sdl.sh $(DESTDIR)$(bindir)/xonotic-sdl
endif

.PHONY: install-engine-server
install-engine-server: server
ifdef DP_FS_BASEDIR # path for distro package builds that define $BASEDIR / $DP_FS_BASEDIR
	$(INSTALL_PROGRAM) source/darkplaces/darkplaces-dedicated $(DESTDIR)$(bindir)/xonotic-dedicated
else # end users aren't expected to `make install` but if they do this path makes their install functional
	$(INSTALL_PROGRAM) source/darkplaces/darkplaces-dedicated $(DESTDIR)$(BASEDIR)/xonotic-dedicated
	# install-links
	$(INSTALL_PROGRAM) xonotic-linux-dedicated.sh $(DESTDIR)$(BASEDIR)/xonotic-linux-dedicated.sh
	$(INSTALL) -d $(DESTDIR)$(bindir)
	ln -snf $(BASEDIR)/xonotic-linux-dedicated.sh $(DESTDIR)$(bindir)/xonotic-dedicated
endif

# Flathub requires these file names to be changed, which requires editing files that reference them.
# No file extensions in the values because desktop files omit them from Icon=
FILENAME_ICON_CLIENT ?= xonotic
FILENAME_DESKTOP_CLIENT ?= xonotic
.PHONY: install-desktop-client
install-desktop-client:
	$(INSTALL_DATA) misc/logos/xonotic_icon.svg $(DESTDIR)$(datarootdir)/icons/hicolor/scalable/apps/$(FILENAME_ICON_CLIENT).svg
	$(INSTALL_DATA) misc/logos/xonotic.desktop $(DESTDIR)$(datarootdir)/applications/$(FILENAME_DESKTOP_CLIENT).desktop
	$(INSTALL_DATA) misc/logos/org.xonotic.Xonotic.metainfo.xml $(DESTDIR)$(datarootdir)/metainfo/org.xonotic.Xonotic.metainfo.xml
	sed -i 's/Icon=xonotic/Icon=$(FILENAME_ICON_CLIENT)/' $(DESTDIR)$(datarootdir)/applications/$(FILENAME_DESKTOP_CLIENT).desktop
	sed -i 's/<launchable type=\"desktop-id\">xonotic.desktop<\/launchable>/<launchable type=\"desktop-id\">$(FILENAME_DESKTOP_CLIENT).desktop<\/launchable>/' $(DESTDIR)$(datarootdir)/metainfo/org.xonotic.Xonotic.metainfo.xml

.PHONY: install-desktop-server
install-desktop-server: # TODO https://gitlab.com/xonotic/xonotic/-/issues/216

.PHONY: install-doc-client
install-doc-client:
	$(INSTALL) -d $(DESTDIR)$(docdir)
	cp -R Docs/* $(DESTDIR)$(docdir)/

.PHONY: install-doc-server
install-doc-server:
	$(INSTALL) -d $(DESTDIR)$(docdir)
	cp -R server $(DESTDIR)$(docdir)/

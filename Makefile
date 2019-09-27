DESTDIR ?=
PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
LIBDIR ?= $(PREFIX)/lib/xonotic
DOCDIR ?= $(PREFIX)/share/doc/xonotic
ZIP ?= zip -9
INSTALL ?= install
ARCH ?= $(shell if [ x"`uname -m`" = x"x86_64" ]; then echo linux64; else echo linux32; fi)
LN ?= ln
CP ?= cp
BINARY ?= yes
SUFFIX ?= $(shell if [ -d .git ]; then echo git; elif [ x"$(BINARY)" = x"yes" ]; then echo zip-binary; else echo zip-source; fi)
RIJNDAELDETECT_CONFIGURE ?= $(shell if ! [ -f source/d0_blind_id/d0_rijndael.c ]; then echo --disable-rijndael; fi)
RIJNDAELDETECT_MAKE_DP ?= $(shell if [ -f source/d0_blind_id/d0_rijndael.c ]; then echo DP_CRYPTO_RIJNDAEL_STATIC_LIBDIR=$(CURDIR)/source/d0_blind_id/.libs; fi)


.PHONY: all
all: all-$(SUFFIX)

.PHONY: all-git
all-git:
	./all compile

.PHONY: all-zip-binary
all-zip-binary:
	@echo Nothing to do

.PHONY: all-zip-source
all-zip-source:
	( cd source/d0_blind_id && ./configure --enable-static --disable-shared $(RIJNDAELDETECT_CONFIGURE) )
	$(MAKE) -C source/d0_blind_id
	$(MAKE) -C source/gmqcc
	$(MAKE) -C source/qcsrc QCC=$(CURDIR)/source/gmqcc/gmqcc
	$(MAKE) -C source/darkplaces sv-release DP_CRYPTO_STATIC_LIBDIR=$(CURDIR)/source/d0_blind_id/.libs
	$(MAKE) -C source/darkplaces cl-release DP_CRYPTO_STATIC_LIBDIR=$(CURDIR)/source/d0_blind_id/.libs
	$(MAKE) -C source/darkplaces sdl-release DP_CRYPTO_STATIC_LIBDIR=$(CURDIR)/source/d0_blind_id/.libs


.PHONY: clean
clean: clean-$(SUFFIX)

.PHONY: clean-git
clean-git:
	./all clean

.PHONY: clean-zip
clean-zip-binary:
	@echo Nothing to do

.PHONY: clean-zip
clean-zip-source:
	$(MAKE) -C source/d0_blind_id distclean
	$(MAKE) -C source/gmqcc clean
	$(MAKE) -C source/qcsrc clean
	$(MAKE) -C source/darkplaces clean


.PHONY: install-data
install-data: install-data-$(SUFFIX)

.PHONY: install-data-git
install-data-git: all-git
	$(RM) -rf $(DESTDIR)$(LIBDIR)/data
	$(INSTALL) -d $(DESTDIR)$(LIBDIR)/data
	for p in data/*.pk3; do $(INSTALL) $$p $(DESTDIR)$(LIBDIR)/$$p || exit 1; done
	for p in data/*.pk3dir; do ( cd $$p && $(ZIP) -r $(DESTDIR)$(LIBDIR)/$${p%dir} * ) || exit 1; done

.PHONY: install-data-zip-binary
install-data-zip-binary: all-zip-binary
	$(RM) -rf $(DESTDIR)$(LIBDIR)/data
	$(INSTALL) -d $(DESTDIR)$(LIBDIR)/data
	for p in data/*.pk3; do $(INSTALL) $$p $(DESTDIR)$(LIBDIR)/$$p || exit 1; done

.PHONY: install-data-zip-source
install-data-zip-source: all-zip-source
	$(RM) -rf $(DESTDIR)$(LIBDIR)/data
	$(INSTALL) -d $(DESTDIR)$(LIBDIR)/data
	for p in data/*.pk3; do $(INSTALL) $$p $(DESTDIR)$(LIBDIR)/$$p || exit 1; done
	for p in data/xonotic-*-data*.pk3; do cd source && $(ZIP) $(DESTDIR)$(LIBDIR)/$$p progs.dat menu.dat csprogs.dat; done


.PHONY: install-engine
install-engine: install-engine-$(SUFFIX)

.PHONY: install-engine-git
install-engine-git: all-git
	$(INSTALL) -d $(DESTDIR)$(LIBDIR)
	$(INSTALL) xonotic-linux-glx.sh $(DESTDIR)$(LIBDIR)/xonotic-linux-glx.sh
	$(INSTALL) xonotic-linux-sdl.sh $(DESTDIR)$(LIBDIR)/xonotic-linux-sdl.sh
	$(INSTALL) xonotic-linux-dedicated.sh $(DESTDIR)$(LIBDIR)/xonotic-linux-dedicated.sh
	$(INSTALL) darkplaces/darkplaces-sdl $(DESTDIR)$(LIBDIR)/xonotic-$(ARCH)-sdl
	$(INSTALL) darkplaces/darkplaces-glx $(DESTDIR)$(LIBDIR)/xonotic-$(ARCH)-glx
	$(INSTALL) darkplaces/darkplaces-dedicated $(DESTDIR)$(LIBDIR)/xonotic-$(ARCH)-dedicated

.PHONY: install-engine-zip-binary
install-engine-zip-binary: all-zip-binary
	$(INSTALL) -d $(DESTDIR)$(LIBDIR)
	$(INSTALL) xonotic-linux-glx.sh $(DESTDIR)$(LIBDIR)/xonotic-linux-glx.sh
	$(INSTALL) xonotic-linux-sdl.sh $(DESTDIR)$(LIBDIR)/xonotic-linux-sdl.sh
	$(INSTALL) xonotic-linux-dedicated.sh $(DESTDIR)$(LIBDIR)/xonotic-linux-dedicated.sh
	$(INSTALL) xonotic-$(ARCH)-sdl $(DESTDIR)$(LIBDIR)/xonotic-$(ARCH)-sdl
	$(INSTALL) xonotic-$(ARCH)-glx $(DESTDIR)$(LIBDIR)/xonotic-$(ARCH)-glx
	$(INSTALL) xonotic-$(ARCH)-dedicated $(DESTDIR)$(LIBDIR)/xonotic-$(ARCH)-dedicated

.PHONY: install-engine-zip-source
install-engine-zip-source: all-zip-source
	$(INSTALL) -d $(DESTDIR)$(LIBDIR)
	$(INSTALL) xonotic-linux-glx.sh $(DESTDIR)$(LIBDIR)/xonotic-linux-glx.sh
	$(INSTALL) xonotic-linux-sdl.sh $(DESTDIR)$(LIBDIR)/xonotic-linux-sdl.sh
	$(INSTALL) xonotic-linux-dedicated.sh $(DESTDIR)$(LIBDIR)/xonotic-linux-dedicated.sh
	$(INSTALL) source/darkplaces/darkplaces-sdl $(DESTDIR)$(LIBDIR)/xonotic-$(ARCH)-sdl
	$(INSTALL) source/darkplaces/darkplaces-glx $(DESTDIR)$(LIBDIR)/xonotic-$(ARCH)-glx
	$(INSTALL) source/darkplaces/darkplaces-dedicated $(DESTDIR)$(LIBDIR)/xonotic-$(ARCH)-dedicated


.PHONY: install-links
install-links:
	$(INSTALL) -d $(BINDIR)
	$(LN) -snf $(LIBDIR)/xonotic-linux-sdl.sh $(DESTDIR)$(BINDIR)/xonotic-sdl
	$(LN) -snf $(LIBDIR)/xonotic-linux-glx.sh $(DESTDIR)$(BINDIR)/xonotic-glx
	$(LN) -snf $(LIBDIR)/xonotic-linux-dedicated.sh $(DESTDIR)$(BINDIR)/xonotic-dedicated


.PHONY: install-doc
install-doc:
	$(INSTALL) -d $(DESTDIR)$(DOCDIR)/server
	$(CP) -R Docs/* $(DESTDIR)$(DOCDIR)/
	$(CP) -R server/* $(DESTDIR)$(DOCDIR)/server


.PHONY: install
install: install-data install-engine install-links install-doc

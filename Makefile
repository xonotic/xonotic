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


.PHONY: all
all: all-$(SUFFIX)

.PHONY: all-git
all-git:
	./all compile -r

.PHONY: all-zip-binary
all-zip-binary:
	@echo Nothing to do

.PHONY: all-zip-source
all-zip-source:
	$(MAKE) -C source/fteqcc
	$(MAKE) -C source/qcsrc FTEQCC=$(CURDIR)/source/fteqcc/fteqcc.bin
	$(MAKE) -C source/darkplaces sv-release
	$(MAKE) -C source/darkplaces cl-release
	$(MAKE) -C source/darkplaces sdl-release


.PHONY: clean
clean: clean-$(SUFFIX)

.PHONY: clean-git
clean-git:
	./all clean

.PHONY: clean-zip
clean-binary:
	@echo Nothing to do

.PHONY: clean-zip
clean-source:
	@echo Sorry, this is not implemented yet
	@false


.PHONY: install-data
install-data: install-data-$(SUFFIX)

.PHONY: install-data-git
install-data-git: all-git
	$(RM) -rf $(LIBDIR)/data
	$(INSTALL) -d $(LIBDIR)/data
	for p in data/*.pk3; do $(INSTALL) $$p $(LIBDIR)/$$p || exit 1; done
	for p in data/*.pk3dir; do ( cd $$p; $(ZIP) -r $(LIBDIR)/$${p%dir} * ) || exit 1; done

.PHONY: install-data-zip-binary
install-data-zip-binary: all-zip-binary
	$(RM) -rf $(LIBDIR)/data
	$(INSTALL) -d $(LIBDIR)/data
	for p in data/*.pk3; do $(INSTALL) $$p $(LIBDIR)/$$p || exit 1; done

.PHONY: install-data-zip-source
install-data-zip-source: all-zip-source
	$(RM) -rf $(LIBDIR)/data
	$(INSTALL) -d $(LIBDIR)/data
	for p in data/*.pk3; do $(INSTALL) $$p $(LIBDIR)/$$p || exit 1; done
	for p in data/xonotic-*-data*.pk3; do cd source; $(ZIP) $(LIBDIR)/$$p progs.dat menu.dat csprogs.dat; done


.PHONY: install-engine
install-engine: install-engine-$(SUFFIX)

.PHONY: install-engine-git
install-engine-git: all-git
	$(INSTALL) -d $(LIBDIR)
	$(INSTALL) xonotic-linux-glx.sh $(LIBDIR)/xonotic-linux-glx.sh
	$(INSTALL) xonotic-linux-sdl.sh $(LIBDIR)/xonotic-linux-sdl.sh
	$(INSTALL) xonotic-linux-dedicated.sh $(LIBDIR)/xonotic-linux-dedicated.sh
	$(INSTALL) darkplaces/darkplaces-sdl $(LIBDIR)/xonotic-$(ARCH)-sdl
	$(INSTALL) darkplaces/darkplaces-glx $(LIBDIR)/xonotic-$(ARCH)-glx
	$(INSTALL) darkplaces/darkplaces-dedicated $(LIBDIR)/xonotic-$(ARCH)-dedicated

.PHONY: install-engine-zip-binary
install-engine-zip: all-zip
	$(INSTALL) -d $(LIBDIR)
	$(INSTALL) xonotic-linux-glx.sh $(LIBDIR)/xonotic-linux-glx.sh
	$(INSTALL) xonotic-linux-sdl.sh $(LIBDIR)/xonotic-linux-sdl.sh
	$(INSTALL) xonotic-linux-dedicated.sh $(LIBDIR)/xonotic-linux-dedicated.sh
	$(INSTALL) xonotic-$(ARCH)-sdl $(LIBDIR)/xonotic-$(ARCH)-sdl
	$(INSTALL) xonotic-$(ARCH)-glx $(LIBDIR)/xonotic-$(ARCH)-glx
	$(INSTALL) xonotic-$(ARCH)-dedicated $(LIBDIR)/xonotic-$(ARCH)-dedicated

.PHONY: install-engine-zip-source
install-engine-zip: all-zip
	$(INSTALL) -d $(LIBDIR)
	$(INSTALL) xonotic-linux-glx.sh $(LIBDIR)/xonotic-linux-glx.sh
	$(INSTALL) xonotic-linux-sdl.sh $(LIBDIR)/xonotic-linux-sdl.sh
	$(INSTALL) xonotic-linux-dedicated.sh $(LIBDIR)/xonotic-linux-dedicated.sh
	$(INSTALL) source/darkplaces/xonotic-sdl $(LIBDIR)/xonotic-$(ARCH)-sdl
	$(INSTALL) source/darkplaces/darkplaces-sdl $(LIBDIR)/xonotic-$(ARCH)-glx
	$(INSTALL) source/darkplaces/darkplaces-dedicated $(LIBDIR)/xonotic-$(ARCH)-dedicated


.PHONY: install-links
install-links:
	$(INSTALL) -d $(BINDIR)
	$(LN) -snf $(LIBDIR)/xonotic-linux-sdl.sh $(BINDIR)/xonotic-sdl
	$(LN) -snf $(LIBDIR)/xonotic-linux-glx.sh $(BINDIR)/xonotic-glx
	$(LN) -snf $(LIBDIR)/xonotic-linux-dedicated.sh $(BINDIR)/xonotic-dedicated


.PHONY: install-doc
install-doc:
	$(INSTALL) -d $(DOCDIR)/server
	$(CP) -R Docs/* $(DOCDIR)/
	$(CP) -R server/* $(DOCDIR)/server


.PHONY: install
install: install-data install-engine install-links install-doc

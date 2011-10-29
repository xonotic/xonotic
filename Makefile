PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
LIBDIR ?= $(PREFIX)/lib/xonotic
DOCDIR ?= $(PREFIX)/share/doc/xonotic
ZIP ?= zip -9
INSTALL ?= install
ARCH ?= $(shell if [ x"`uname -m`" = x"x86_64" ]; then echo linux64; else echo linux32; fi)
LN ?= ln
SUFFIX ?= $(shell if [ -d .git ]; then echo -git; else echo -zip; fi)
CP ?= cp

.PHONY: all
all:
	./all compile -r

.PHONY: clean
clean:
	./all clean

.PHONY: install-data-git
install-data-git: all
	$(INSTALL) -d $(LIBDIR)/data
	for p in data/*.pk3dir; do $(ZIP) -r $(LIBDIR)/data/$${p%dir} data/$$p/*; done

.PHONY: install-data-zip
install-data-git: all
	$(INSTALL) -d $(LIBDIR)/data
	for p in data/*.pk3; do $(INSTALL) data/$$p $(LIBDIR)/data/$$p; done

.PHONY: install-data
install-data: install-data-$(SUFFIX)

.PHONY: install-engine-git
install-engine-git: all
	$(INSTALL) -d $(LIBDIR)
	$(INSTALL) xonotic-linux-glx.sh $(LIBDIR)/xonotic-linux-glx.sh
	$(INSTALL) xonotic-linux-sdl.sh $(LIBDIR)/xonotic-linux-sdl.sh
	$(INSTALL) xonotic-linux-dedicated.sh $(LIBDIR)/xonotic-linux-dedicated.sh
	$(INSTALL) darkplaces/xonotic-sdl $(LIBDIR)/xonotic-$(ARCH)-sdl
	$(INSTALL) darkplaces/xonotic-glx $(LIBDIR)/xonotic-$(ARCH)-glx
	$(INSTALL) darkplaces/xonotic-dedicated $(LIBDIR)/xonotic-$(ARCH)-dedicated

.PHONY: install-engine-zip
install-engine-git: all
	$(INSTALL) -d $(LIBDIR)
	$(INSTALL) xonotic-linux-glx.sh $(LIBDIR)/xonotic-linux-glx.sh
	$(INSTALL) xonotic-linux-sdl.sh $(LIBDIR)/xonotic-linux-sdl.sh
	$(INSTALL) xonotic-linux-dedicated.sh $(LIBDIR)/xonotic-linux-dedicated.sh
	$(INSTALL) xonotic-$(ARCH)-sdl $(LIBDIR)/xonotic-$(ARCH)-sdl
	$(INSTALL) xonotic-$(ARCH)-glx $(LIBDIR)/xonotic-$(ARCH)-glx
	$(INSTALL) xonotic-$(ARCH)-dedicated $(LIBDIR)/xonotic-$(ARCH)-dedicated

.PHONY: install-engine
install-engine: install-engine-$(SUFFIX)

.PHONY: install-links
install-links: all
	$(INSTALL) -d $(BINDIR)
	$(LN) -snf $(LIBDIR)/xonotic-$(ARCH)-sdl $(BINDIR)/xonotic-sdl
	$(LN) -snf $(LIBDIR)/xonotic-$(ARCH)-glx $(BINDIR)/xonotic-glx
	$(LN) -snf $(LIBDIR)/xonotic-$(ARCH)-dedicated $(BINDIR)/xonotic-dedicated

.PHONY: install-doc
install-doc:
	$(INSTALL) -d $(DOCDIR)/server
	$(CP) -R Docs/* $(DOCDIR)/
	$(CP) -R server/* $(DOCDIR)/server

.PHONY: install
install: install-data install-engine install-links install-doc

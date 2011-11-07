PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
LIBDIR ?= $(PREFIX)/lib/xonotic
DOCDIR ?= $(PREFIX)/share/doc/xonotic
ZIP ?= zip -9
INSTALL ?= install
ARCH ?= $(shell if [ x"`uname -m`" = x"x86_64" ]; then echo linux64; else echo linux32; fi)
LN ?= ln
SUFFIX ?= $(shell if [ -d .git ]; then echo git; else echo zip; fi)
CP ?= cp


.PHONY: all
all: all-$(SUFFIX)

.PHONY: all-git
all-git:
	./all compile -r

.PHONY: all-zip
all-zip:
	@echo Sorry, this is not implemented yet
	@false


.PHONY: clean
clean: clean-$(SUFFIX)

.PHONY: clean-git
clean-git:
	./all clean

.PHONY: clean-zip
clean-zip:
	@echo Sorry, this is not implemented yet
	@false


.PHONY: install-data
install-data: install-data-$(SUFFIX)

.PHONY: install-data-git
install-data-git:
	$(RM) -rf $(LIBDIR)/data
	$(INSTALL) -d $(LIBDIR)/data
	for p in data/*.pk3; do $(INSTALL) $$p $(LIBDIR)/$$p || exit 1; done
	for p in data/*.pk3dir; do ( cd $$p; $(ZIP) -r $(LIBDIR)/$${p%dir} * ) || exit 1; done

.PHONY: install-data-zip
install-data-zip:
	$(RM) -rf $(LIBDIR)/data
	$(INSTALL) -d $(LIBDIR)/data
	for p in data/*.pk3; do $(INSTALL) $$p $(LIBDIR)/$$p || exit 1; done


.PHONY: install-engine
install-engine: install-engine-$(SUFFIX)

.PHONY: install-engine-git
install-engine-git:
	$(INSTALL) -d $(LIBDIR)
	$(INSTALL) xonotic-linux-glx.sh $(LIBDIR)/xonotic-linux-glx.sh
	$(INSTALL) xonotic-linux-sdl.sh $(LIBDIR)/xonotic-linux-sdl.sh
	$(INSTALL) xonotic-linux-dedicated.sh $(LIBDIR)/xonotic-linux-dedicated.sh
	$(INSTALL) darkplaces/darkplaces-sdl $(LIBDIR)/xonotic-$(ARCH)-sdl
	$(INSTALL) darkplaces/darkplaces-glx $(LIBDIR)/xonotic-$(ARCH)-glx
	$(INSTALL) darkplaces/darkplaces-dedicated $(LIBDIR)/xonotic-$(ARCH)-dedicated

.PHONY: install-engine-zip
install-engine-zip:
	$(INSTALL) -d $(LIBDIR)
	$(INSTALL) xonotic-linux-glx.sh $(LIBDIR)/xonotic-linux-glx.sh
	$(INSTALL) xonotic-linux-sdl.sh $(LIBDIR)/xonotic-linux-sdl.sh
	$(INSTALL) xonotic-linux-dedicated.sh $(LIBDIR)/xonotic-linux-dedicated.sh
	$(INSTALL) xonotic-$(ARCH)-sdl $(LIBDIR)/xonotic-$(ARCH)-sdl
	$(INSTALL) xonotic-$(ARCH)-glx $(LIBDIR)/xonotic-$(ARCH)-glx
	$(INSTALL) xonotic-$(ARCH)-dedicated $(LIBDIR)/xonotic-$(ARCH)-dedicated


.PHONY: install-links
install-links:
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

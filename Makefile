# © 2007-2013 David Given.
# WordGrinder is licensed under the MIT open source license. See the COPYING
# file in this distribution for the full text.

hide = @

PREFIX = $(HOME)
CC = gcc
WINCC = mingw32-gcc.exe
WINDRES = windres.exe
MAKENSIS = makensis

VERSION := 0.4
FILEFORMAT := 3
DATE := 17\ March\ 2013

override CFLAGS += \
	-DVERSION='"$(VERSION)"' \
	-DFILEFORMAT=$(FILEFORMAT) \
	-DPREFIX='"$(HOME)"' \
	-Isrc/c \
	-Wall \
	--std=c99

override LDFLAGS += \

WININSTALLER := bin/WordGrinder\ $(VERSION)\ setup.exe

all: unix

unix: \
	bin/wordgrinder \
	bin/wordgrinder-debug \
	bin/wordgrinder-static \
	bin/wordgrinder.1
.PHONY: unix
	
windows: \
	bin/wordgrinder.exe \
	bin/wordgrinder-debug.exe \
	$(WININSTALLER)
.PHONY: windows

wininstaller: $(WININSTALLER)
.PHONY: wininstaller

install: bin/wordgrinder bin/wordgrinder.1
	@echo INSTALL
	$(hide)install -D -m 755 bin/wordgrinder   $(PREFIX)/bin/wordgrinder
	$(hide)install -D -m 644 bin/wordgrinder.1 $(PREFIX)/man/man1/wordgrinder.1
	$(hide)install -D -m 644 README.wg         $(PREFIX)/share/doc/wordgrinder/README.wg
	
# --- Builds the script blob ------------------------------------------------

LUASCRIPTS := \
	src/lua/_prologue.lua \
	src/lua/utils.lua \
	src/lua/events.lua \
	src/lua/redraw.lua \
	src/lua/document.lua \
	src/lua/forms.lua \
	src/lua/ui.lua \
	src/lua/browser.lua \
	src/lua/html.lua \
	src/lua/margin.lua \
	src/lua/fileio.lua \
	src/lua/export.lua \
	src/lua/export/text.lua \
	src/lua/export/html.lua \
	src/lua/export/latex.lua \
	src/lua/export/troff.lua \
	src/lua/import.lua \
	src/lua/navigate.lua \
	src/lua/addons/goto.lua \
	src/lua/addons/autosave.lua \
	src/lua/addons/docsetman.lua \
	src/lua/addons/scrapbook.lua \
	src/lua/menu.lua \
	src/lua/main.lua \

.obj/luascripts.c: $(LUASCRIPTS)
	@echo SCRIPTS
	@mkdir -p .obj
	@lua tools/multibin2c.lua script_table $^ > $@
	
clean::
	@echo CLEAN .obj/luascripts.c
	@rm -f .obj/luascripts.c
	
# --- Builds a single C file ------------------------------------------------

define cfile

$(objdir)/$(1:.c=.o): $1 Makefile
	@echo CC $$@
	@mkdir -p $$(dir $$@)
	$(hide)$(cc) $(CFLAGS) $(cflags) $(INCLUDES) -c -o $$@ $1

DEPENDS += $(objdir)/$(1:.c=.d)
objs += $(objdir)/$(1:.c=.o)

endef

# --- Builds a single RC file -----------------------------------------------

define rcfile

$(objdir)/$(1:.rc=.o): $1 Makefile
	@echo WINDRES $$@
	@mkdir -p $$(dir $$@)
	$(hide)$(WINDRES) $1 $$@

objs += $(objdir)/$(1:.rc=.o)

endef

# --- Links WordGrinder -----------------------------------------------------

define build-wordgrinder

$(exe): $(objs) Makefile
	@echo LINK $$@
	@mkdir -p $$(dir $$@)
	$(hide)$(cc) $(CFLAGS) $(cflags) $(LDFLAGS) -o $$@ $(objs) $(ldflags) 

clean::
	@echo CLEAN $(exe)
	@rm -f $(exe) $(objs)
	
endef

# --- Builds the WordGrinder core code --------------------------------------

define build-wordgrinder-core

$(call cfile, src/c/utils.c)
$(call cfile, src/c/main.c)
$(call cfile, src/c/lua.c)
$(call cfile, src/c/word.c)
$(call cfile, src/c/screen.c)
$(call cfile, .obj/luascripts.c)

endef

# --- Builds the LFS library ------------------------------------------------

define build-wordgrinder-lfs

$(call cfile, src/c/lfs/lfs.c)

endef

# --- Builds emulation routines ---------------------------------------------

define build-wordgrinder-emu

$(call cfile, src/c/emu/wcwidth.c)

endef

# --- Builds the ncurses front end ------------------------------------------

define build-wordgrinder-ncurses

$(call cfile, src/c/arch/unix/cursesw/dpy.c)

endef

# --- Builds the Windows front end ------------------------------------------

define build-wordgrinder-windows

$(call cfile, src/c/arch/win32/gdi/dpy.c)
$(call cfile, src/c/arch/win32/gdi/glyphcache.c)
$(call cfile, src/c/arch/win32/gdi/realmain.c)
$(call rcfile, src/c/arch/win32/wordgrinder.rc)

endef

# --- Unix ------------------------------------------------------------------

cc := gcc
INCLUDES := -I/usr/include/lua5.2

UNIXCFLAGS := \
	-D_XOPEN_SOURCE_EXTENDED \
	-D_XOPEN_SOURCE \
	-D_GNU_SOURCE \
	-I/usr/include/ncursesw
	
ldflags := \
	-lncursesw \
	-llua5.2 \
	-lz \
	-lm

cflags := $(UNIXCFLAGS) -Os -DNDEBUG
objdir := .obj/release
exe := bin/wordgrinder
objs :=
$(eval $(build-wordgrinder-core))
$(eval $(build-wordgrinder-ncurses))
$(eval $(build-wordgrinder))

cflags := $(UNIXCFLAGS) -g
objdir := .obj/debug
exe := bin/wordgrinder-debug
objs :=
$(eval $(build-wordgrinder-core))
$(eval $(build-wordgrinder-ncurses))
$(eval $(build-wordgrinder))

cflags := $(UNIXCFLAGS) -g -DEMULATED_WCWIDTH -DBUILTIN_LFS
objdir := .obj/debug-static
exe := bin/wordgrinder-static
objs :=
$(eval $(build-wordgrinder-core))
$(eval $(build-wordgrinder-ncurses))
$(eval $(build-wordgrinder-lfs))
$(eval $(build-wordgrinder-emu))
$(eval $(build-wordgrinder))


bin/wordgrinder.1: wordgrinder.man
	@echo MANPAGE
	$(hide)sed -e 's/@@@DATE@@@/$(DATE)/g; s/@@@VERSION@@@/$(VERSION)/g' $< > $@
	
# --- Windows ---------------------------------------------------------------

cc := $(WINCC)

WINDOWSCFLAGS := \
	-DEMULATED_WCWIDTH \
	-DBUILTIN_LFS \
	-DWIN32 \
	-DWINVER=0x0500 \
	-Dmain=appMain \
	-mwindows
	
ldflags := \
	-static \
	-llua \
	-lz \
	-lm

cflags := $(WINDOWSCFLAGS) -Os -DNDEBUG
objdir := .obj/win32-release
exe := bin/wordgrinder.exe
objs :=
$(eval $(build-wordgrinder-core))
$(eval $(build-wordgrinder-lfs))
$(eval $(build-wordgrinder-emu))
$(eval $(build-wordgrinder-windows))
$(eval $(build-wordgrinder))


cflags := $(WINDOWSCFLAGS) -g
objdir := .obj/win32-debug
exe := bin/wordgrinder-debug.exe
objs :=
$(eval $(build-wordgrinder-core))
$(eval $(build-wordgrinder-lfs))
$(eval $(build-wordgrinder-emu))
$(eval $(build-wordgrinder-windows))
$(eval $(build-wordgrinder))

src/c/arch/win32/wordgrinder.rc: src/c/arch/win32/icon.ico


$(WININSTALLER): extras/windows-installer.nsi bin/wordgrinder.exe
	@echo INSTALLER
	@mkdir -p bin # $(dir) doesn't work with spaces
	$(hide)$(MAKENSIS) -v2 -nocd -dVERSION=$(VERSION) -dOUTFILE=$(WININSTALLER) $<

clean::
	@echo CLEAN $(WININSTALLER)
	@rm -f $(WININSTALLER)
	
# --- Final setup -----------------------------------------------------------

-include $(DEPENDS)
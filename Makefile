.PHONY: all install uninstall build test potfiles
PREFIX ?= /usr

scrobbling ?= 1
# Remove the devel headerbar style:
# make release=1
release ?=

ifeq ($(scrobbling),0)
    SCROBBLING = -Dscrobbling=false
else
    SCROBBLING = -Dscrobbling=true
endif


all: build

build:
	meson setup builddir --prefix=$(PREFIX)
	meson configure builddir -Ddevel=$(if $(release),false,true) $(SCROBBLING)
	meson compile -C builddir

install:
	meson install -C builddir

uninstall:
	sudo ninja uninstall -C builddir

test:
	ninja test -C builddir

potfiles:
	find ./ -not -path '*/.*' -type f -name "*.in" | sort > po/POTFILES
	echo "" >> po/POTFILES
	find ./ -not -path '*/.*' -type f -name "*.ui" -exec grep -l "translatable=\"yes\"" {} \; | sort >> po/POTFILES
	echo "" >> po/POTFILES
	find ./ -not -path '*/.*' -type f -name "*.vala" -exec grep -l "_(\"\|ngettext" {} \; | sort >> po/POTFILES

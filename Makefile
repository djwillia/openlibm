include ../../../Makecommon
SOLO5_KERNEL=$(abspath ../..)
SOLO5_CC=$(CROSS_DIR)/x86_64-elf-gcc
SOLO5_CFLAGS=-ffreestanding	\
	-mcmodel=large			\
	-mno-red-zone			\
	-mno-3dnow				\
	-std=gnu99 -O0  		\
	-g \
	-D__SOLO5__
SOLO5_LDFLAGS=-ffreestanding -O0 -nostdlib -lgcc -z max-page-size=0x1000 -r
SOLO5_LDLIBS=-lgcc


OPENLIBM_HOME=$(abspath .)
include ./Make.inc

SUBDIRS = src $(ARCH) bsdsrc
ifneq ($(ARCH), arm)
SUBDIRS += ld80
endif

define INC_template
TEST=test
override CUR_SRCS = $(1)_SRCS
include $(1)/Make.files
SRCS += $$(addprefix $(1)/,$$($(1)_SRCS))
endef

DIR=test

$(foreach dir,$(SUBDIRS),$(eval $(call INC_template,$(dir))))

DUPLICATE_NAMES = $(filter $(patsubst %.S,%,$($(ARCH)_SRCS)),$(patsubst %.c,%,$(src_SRCS)))
DUPLICATE_SRCS = $(addsuffix .c,$(DUPLICATE_NAMES))

OBJS =  $(patsubst %.f,%.f.o,\
	$(patsubst %.S,%.S.o,\
	$(patsubst %.c,%.c.o,$(filter-out $(addprefix src/,$(DUPLICATE_SRCS)),$(SRCS)))))

# solo5
solo5.h:
	echo "#include \"$(SOLO5_KERNEL)/kernel.h\"" > solo5.h
app_solo5.o: solo5.h $(OBJS)
	$(SOLO5_CC) $(SOLO5_LDFLAGS) $(OBJS) $(SOLO5_LDLIBS) -o app_solo5.o 


.PHONY: all check test clean distclean install

all: libopenlibm.a libopenlibm.$(SHLIB_EXT) app_solo5.o

check test: test/test-double test/test-float
	test/test-double
	test/test-float

libopenlibm.a: $(OBJS)  
	$(AR) -rcs libopenlibm.a $(OBJS)

libopenlibm.$(SHLIB_EXT): $(OBJS)
ifeq ($(OS),WINNT)
	$(CC) -shared $(OBJS) $(LDFLAGS) $(LDFLAGS_add) -Wl,$(SONAME_FLAG),libopenlibm.$(SHLIB_EXT) -o libopenlibm.$(SHLIB_EXT)
else
	$(CC) -shared $(OBJS) $(LDFLAGS) $(LDFLAGS_add) -Wl,$(SONAME_FLAG),libopenlibm.$(SHLIB_EXT).$(SOMAJOR) -o libopenlibm.$(SHLIB_EXT).$(SOMAJOR).$(SOMINOR)
	ln -sf libopenlibm.$(SHLIB_EXT).$(SOMAJOR).$(SOMINOR) libopenlibm.$(SHLIB_EXT).$(SOMAJOR)
	ln -sf libopenlibm.$(SHLIB_EXT).$(SOMAJOR).$(SOMINOR) libopenlibm.$(SHLIB_EXT)
endif

test/test-double: libopenlibm.$(SHLIB_EXT)
	$(MAKE) -C test test-double

test/test-float: libopenlibm.$(SHLIB_EXT)
	$(MAKE) -C test test-float

clean:
	rm -f amd64/*.o arm/*.o bsdsrc/*.o i387/*.o ld128/*.o ld80/*.o src/*.o
	rm -f libopenlibm.a libopenlibm.$(SHLIB_EXT)*
	$(MAKE) -C test clean
	@rm -f solo5.h

openlibm.pc: openlibm.pc.in Make.inc Makefile
	echo "prefix=${prefix}" > openlibm.pc
	echo "version=${VERSION}" >> openlibm.pc
	cat openlibm.pc.in >> openlibm.pc

install: all openlibm.pc
	mkdir -p $(DESTDIR)$(shlibdir)
	mkdir -p $(DESTDIR)$(libdir)/pkgconfig
	mkdir -p $(DESTDIR)$(includedir)/openlibm
	cp -f -a libopenlibm.$(SHLIB_EXT)* $(DESTDIR)$(shlibdir)/
	cp -f -a libopenlibm.a $(DESTDIR)$(libdir)/
	cp -f -a include/openlibm*.h $(DESTDIR)$(includedir)/
	cp -f -a openlibm.pc $(DESTDIR)$(libdir)/pkgconfig/

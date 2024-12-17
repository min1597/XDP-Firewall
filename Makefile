CC = clang
LLC = llc

ARCH := $(shell uname -m | sed 's/x86_64/x86/')

# Main directories.
BUILDDIR = build
SRCDIR = src
MODULEDIR = modules

# XDP Tools directory.
XDPTOOLSDIR = $(MODULEDIR)/xdp-tools
XDPTOOLSHEADERS = $(XDPTOOLSDIR)/headers

# LibXDP and LibBPF directories.
LIBXDPDIR = $(XDPTOOLSDIR)/lib/libxdp

LIBBPFDIR = $(XDPTOOLSDIR)/lib/libbpf
LIBBPFSRC = $(LIBBPFDIR)/src

# LibBPF objects.
LIBBPFOBJS = $(LIBBPFSRC)/staticobjs/bpf_prog_linfo.o $(LIBBPFSRC)/staticobjs/bpf.o $(LIBBPFSRC)/staticobjs/btf_dump.o
LIBBPFOBJS += $(LIBBPFSRC)/staticobjs/btf.o $(LIBBPFSRC)/staticobjs/gen_loader.o $(LIBBPFSRC)/staticobjs/hashmap.o
LIBBPFOBJS += $(LIBBPFSRC)/staticobjs/libbpf_errno.o $(LIBBPFSRC)/staticobjs/libbpf_probes.o $(LIBBPFSRC)/staticobjs/libbpf.o
LIBBPFOBJS += $(LIBBPFSRC)/staticobjs/linker.o $(LIBBPFSRC)/staticobjs/netlink.o $(LIBBPFSRC)/staticobjs/nlattr.o
LIBBPFOBJS += $(LIBBPFSRC)/staticobjs/relo_core.o $(LIBBPFSRC)/staticobjs/ringbuf.o $(LIBBPFSRC)/staticobjs/str_error.o
LIBBPFOBJS += $(LIBBPFSRC)/staticobjs/strset.o $(LIBBPFSRC)/staticobjs/usdt.o $(LIBBPFSRC)/staticobjs/zip.o

# LibXDP objects.
# To Do: Figure out why static objects produces errors relating to unreferenced functions with dispatcher.
LIBXDPOBJS = $(LIBXDPDIR)/sharedobjs/xsk.o $(LIBXDPDIR)/sharedobjs/libxdp.o

# Main program's objects.
CONFIGSRC = config.c
CONFIGOBJ = config.o
CMDLINESRC = cmdline.c
CMDLINEOBJ = cmdline.o

XDPFWSRC = xdpfw.c
XDPFWOUT = xdpfw

XDPPROGSRC = xdpfw_kern.c
XDPPROGLL = xdpfw_kern.ll
XDPPROGOBJ = xdpfw_kern.o

OBJS = $(BUILDDIR)/$(CONFIGOBJ) $(BUILDDIR)/$(CMDLINEOBJ)

# LD flags and includes.
LDFLAGS += -lconfig -lelf -lz
INCS = -I $(LIBBPFSRC)
INCS += -I /usr/include -I /usr/local/include

# All chain.
all: xdpfw xdpfw_filter utils

# User space application chain.
xdpfw: utils libxdp $(OBJS)
	mkdir -p $(BUILDDIR)/
	$(CC) $(LDFLAGS) $(INCS) -o $(BUILDDIR)/$(XDPFWOUT) $(LIBBPFOBJS) $(LIBXDPOBJS) $(OBJS) $(SRCDIR)/$(XDPFWSRC)

# XDP program chain.
xdpfw_filter:
	mkdir -p $(BUILDDIR)/
	$(CC) $(INCS) -D__BPF__ -D __BPF_TRACING__ -Wno-unused-value -Wno-pointer-sign -Wno-compare-distinct-pointer-types -O2 -emit-llvm -c -g -o $(BUILDDIR)/$(XDPPROGLL) $(SRCDIR)/$(XDPPROGSRC)
	$(LLC) -march=bpf -filetype=obj -o $(BUILDDIR)/$(XDPPROGOBJ) $(BUILDDIR)/$(XDPPROGLL)
	
# Utils chain.
utils:
	mkdir -p $(BUILDDIR)/
	$(CC) -O2 -c -o $(BUILDDIR)/$(CONFIGOBJ) $(SRCDIR)/$(CONFIGSRC)
	$(CC) -O2 -c -o $(BUILDDIR)/$(CMDLINEOBJ) $(SRCDIR)/$(CMDLINESRC)

# LibXDP chain. We need to install objects here since our program relies on installed object files and such.
libxdp:
	$(MAKE) -C $(XDPTOOLSDIR) libxdp
	sudo $(MAKE) -C $(LIBBPFSRC) install
	sudo $(MAKE) -C $(LIBXDPDIR) install

# Clean chain.
clean:
	$(MAKE) -C $(LIBBPFSRC) clean
	$(MAKE) -C $(XDPTOOLSDIR) clean
	rm -f $(BUILDDIR)/*.o $(BUILDDIR)/*.bc
	rm -f $(BUILDDIR)/$(XDPFWOUT)

# Install chain.
install:
	mkdir -p /etc/xdpfw/
	cp -n xdpfw.conf.example /etc/xdpfw/xdpfw.conf
	cp $(BUILDDIR)/$(XDPPROGOBJ) /etc/xdpfw/$(XDPPROGOBJ)
	cp $(BUILDDIR)/$(XDPFWOUT) /usr/bin/$(XDPFWOUT)
	cp -n other/xdpfw.service /etc/systemd/system/
.PHONY: libxdp all
.DEFAULT: all
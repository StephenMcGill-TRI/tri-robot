.PHONY: all clean
OBJS=lua_signal.o
TARGET=signal.so

ifndef OSTYPE
OSTYPE = $(shell uname -s | tr '[:upper:]' '[:lower:]')
endif

LUA = $(shell pkg-config --list-all | egrep -o "^lua-?(jit|5\.?[1234])" | sort -r | head -n1)
LUA_INCDIR ?= . $(shell pkg-config $(LUA) --cflags-only-I)
LUA_LIBDIR ?= . $(shell pkg-config $(LUA) --libs-only-L)
CCWARN= -Wall
CCWARN+= -Wextra -Wdeclaration-after-statement -Wredundant-decls -Wshadow -Wpointer-arith
CCWARN += -Werror=vla
CFLAGS ?= $(CCWARN) -fPIC -O2 $(shell pkg-config $(LUA) --cflags-only-other)

ifeq ($(OSTYPE),darwin)
LDFLAGS ?= -bundle -undefined dynamic_lookup -all_load -macosx_version_min 10.13
else # Linux linking and installation
LDFLAGS ?= -shared
endif

all: $(TARGET)
	@echo LUA: $(LUA)
	@echo --- build
	@echo CFLAGS: $(CFLAGS)
	@echo LDFLAGS: $(LDFLAGS)
	@echo LUA_LIBDIR: $(LUA_LIBDIR)
	@echo LUA_BINDIR: $(LUA_BINDIR)
	@echo LUA_INCDIR: $(LUA_INCDIR)

$(TARGET): $(OBJS)
	$(LD) $(LDFLAGS) -o $@ -L$(LUA_LIBDIR) $(OBJS)

%.o: %.c
	$(CC) -c -o $@ $< -I$(LUA_INCDIR) $(CFLAGS)

install: $(TARGET)
	@echo --- install
	@echo INST_PREFIX: $(INST_PREFIX)
	@echo INST_BINDIR: $(INST_BINDIR)
	@echo INST_LIBDIR: $(INST_LIBDIR)
	@echo INST_LUADIR: $(INST_LUADIR)
	@echo INST_CONFDIR: $(INST_CONFDIR)
	@echo Copying $< ...
	cp $< $(INST_LIBDIR)

clean:
	-rm -f $(OBJS)
	-rm -f $(TARGET)

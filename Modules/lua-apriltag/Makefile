.PHONY: all clean

# https://www.gnu.org/software/make/manual/html_node/Implicit-Variables.html

OBJS=lua_apriltag.o
TARGET=apriltag.so

# NOTE: Only Linux has a v4l2 API
ifndef OSTYPE
OSTYPE = $(shell uname -s | tr '[:upper:]' '[:lower:]')
endif

LUA = $(shell pkg-config --list-all | egrep -o "^lua-?(jit|5\.?[123])" | sort -r | head -n1)
LUA_INCDIR ?= . $(shell pkg-config $(LUA) --cflags-only-I)
LUA_LIBDIR ?= . $(shell pkg-config $(LUA) --libs-only-L)

ifeq ($(OSTYPE),darwin)
LDFLAGS ?= -bundle -undefined dynamic_lookup -all_load -macosx_version_min 10.14
else # Linux linking and installation
LDFLAGS ?= -shared -lrt
endif

CCWARN = -Wall
CCWARN += -Wextra -Wdeclaration-after-statement -Wredundant-decls -Wshadow -Wpointer-arith
CCWARN += -Werror=vla
CFLAGS ?= $(CCWARN) -fPIC -O2 $(shell pkg-config $(LUA) --cflags-only-other) $(shell pkg-config --cflags apriltag)
# CFLAGS += -g -DDEBUG

LDLIBS=-lm $(shell pkg-config --libs apriltag)

all: $(TARGET)
	@echo LUA: $(LUA)
	@echo --- build
	@echo CFLAGS: $(CFLAGS)
	@echo LDFLAGS: $(LDFLAGS)
	@echo LUA_LIBDIR: $(LUA_LIBDIR)
	@echo LUA_BINDIR: $(LUA_BINDIR)
	@echo LUA_INCDIR: $(LUA_INCDIR)

$(TARGET): $(OBJS)
	$(LD) $(LDFLAGS) -o $@ -L$(LUA_LIBDIR) $(OBJS) $(LDLIBS)

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

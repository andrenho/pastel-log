# Variables that can be set:
#   RELEASE=1        create a release build
#   PROJECT_VERSION

#
# compiler configuration
#

CFLAGS += -D_GNU_SOURCE
CPPFLAGS += -MMD -MP   # generate dependencies
CXXFLAGS += -std=c++20
LDFLAGS += -lm

ifdef RELEASE
	CPPFLAGS += -Ofast -flto -fdata-sections -ffunction-sections -flto
	#LDFLAGS += -flto -Wl,--gc-sections
	LDFLAGS += -flto -Wl,-dead_strip
else
	CPPFLAGS += -Wall -Wextra -Wformat-nonliteral -Wshadow -Wwrite-strings -Wmissing-format-attribute -Wswitch-enum -Wmissing-noreturn -Wno-unused-parameter -Wno-unused
	ifeq ($(CXX),gcc)
		CPPFLAGS += -Wsuggest-attribute=pure -Wsuggest-attribute=const -Wsuggest-attribute=noreturn -Wsuggest-attribute=malloc -Wsuggest-attribute=format -Wsuggest-attribute=cold
	endif
	CPPFLAGS += -ggdb -O0
endif

CPPFLAGS += -DPROJECT_VERSION=\"$(PROJECT_VERSION)\"

#
# generate embedded files (require LuaJIT)
#

CONFIG_MK_DIR:= $(dir $(lastword $(MAKEFILE_LIST)))
GENHEADER := $(CONFIG_MK_DIR)/genheader.lua
%.h: %
	$(GENHEADER) $^ > $@
.DELETE_ON_ERROR=%.h

#
# generate rule dependencies
#

DEPENDS = $(shell find . -name *.d)
-include $(DEPENDS)
CLEANFILES := $(DEPENDS) libluajit.a

#
# leak check command
#

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)  # Apple
	APPLE := 1
	LEAKS_CMD := MallocStackLogging=1 leaks --atExit --
	MACOS_VERSION := $(shell cut -d '.' -f 1,2 <<< $$(sw_vers -productVersion))
	CFLAGS += -std=c2x
	CPPFLAGS += -mmacosx-version-min=$(MACOS_VERSION)
	export MACOSX_DEPLOYMENT_TARGET=$(MACOS_VERSION)
else
	CFLAGS += -std=c23
	LEAKS_CMD := valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes --fair-sched=yes --suppressions=valgrind.supp
endif

#
# rule to print config
#

.PHONY: config
config:
	@echo ===============================
	@echo CC            = $(CC)
	@echo CXX           = $(CXX)
	@echo CFLAGS        = $(CFLAGS)
	@echo CPPFLAGS      = $(CPPFLAGS)
	@echo CXXFLAGS      = $(CXXFLAGS)
	@echo LDFLAGS       = $(LDFLAGS)
	@echo DEPENDS       = $(DEPENDS)
	@echo CONFIG_MK_DIR = $(CONFIG_MK_DIR)
	@echo ===============================

deepclean:
	git clean -fdx

update:
	git submodule update --init --remote --merge --recursive

#
# LuaJIT
#

LUAJIT_PATH = $(CONFIG_MK_DIR)LuaJIT
SDL3_PATH = $(CONFIG_MK_DIR)SDL3
CPPFLAGS += -I$(LUAJIT_PATH)/src

libluajit.a:
	mkdir -p $(LUAJIT_PATH)
	git clone --depth=1 https://github.com/LuaJIT/LuaJIT.git $(LUAJIT_PATH) || true
	rm -rf !$/.git
	$(MAKE) -C $(LUAJIT_PATH)/src MACOSX_DEPLOYMENT_TARGET=$(MACOS_VERSION) libluajit.a
	cp $(LUAJIT_PATH)/src//libluajit.a .
	rm -rf $(LUAJIT_PATH)

libSDL3.a:
	mkdir -p $(SDL3_PATH)
	git clone --depth=1 https://github.com/libsdl-org/SDL $(SDL3_PATH) || true
	rm -rf !$/.git
	cmake -B build-sdl3 -S $(SDL3_PATH) -DCMAKE_OSX_DEPLOYMENT_TARGET=${MACOS_VERSION} -DCMAKE_BUILD_TYPE=Release -DSDL_SHARED=OFF -DSDL_STATIC=ON && cd ..
	$(MAKE) -C build-sdl3
	cp build-sdl3/libSDL3.a .
	rm -rf $(SDL3_PATH) build-sdl3

clean-lua:
	$(MAKE) -C $(CONFIG_MK_DIR)/LuaJIT MACOSX_DEPLOYMENT_TARGET=$(MACOS_VERSION) clean

#
# generate compile_commands.json
#

compile_commands: clean
	bear -- $(MAKE)


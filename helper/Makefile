# Thin wrapper around helper/build.sh (cross-compile linux x86_64 + aarch64).
#   make -C helper
#   make -C helper clean
#   ./helper/build.sh --help

.PHONY: all clean x86_64 aarch64

all:
	./build.sh

x86_64:
	./build.sh --arch=x86_64

aarch64:
	./build.sh --arch=aarch64

clean:
	./build.sh --clean

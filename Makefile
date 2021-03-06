prefix ?= /usr/local
bindir = $(prefix)/bin
libdir = $(prefix)/lib

build:
	swift build -c release --disable-sandbox

install: build
	install -d "$(bindir)"
	install ".build/release/xcode-simulator-cert" "$(bindir)"

uninstall:
	rm -rf "$(bindir)/xcode-simulator-cert"

clean:
	rm -rf .build

.PHONY: build install uninstall clean

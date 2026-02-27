PREFIX ?= $(HOME)/.local

all: build install

build:
	swiftc retrackt.swift -o retrackt -O

install:
	install -d $(PREFIX)/bin
	install retrackt $(PREFIX)/bin/retrackt
	@case ":$$PATH:" in *:$(PREFIX)/bin:*) ;; *) \
	  echo ""; \
	  echo "Note: $(PREFIX)/bin is not in your PATH. Add it with:"; \
	  echo ""; \
	  echo "  echo 'export PATH=\"$(PREFIX)/bin:\$$PATH\"' >> ~/.zshrc"; \
	  echo ""; \
	esac

uninstall:
	rm -f $(PREFIX)/bin/retrackt

.PHONY: all build install uninstall

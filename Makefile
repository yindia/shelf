# Shelf — build, bundle, sign, run. No Xcode project required.
APP      := Shelf
BUNDLE   := build/$(APP).app
CONFIG   := release
BINARY   := .build/$(CONFIG)/ShelfApp

.PHONY: all build bundle run test clean

all: bundle

build:
	swift build -c $(CONFIG)

# Assemble a proper .app bundle with Info.plist + entitlements, then ad-hoc sign.
bundle: build
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS $(BUNDLE)/Contents/Resources
	cp $(BINARY) $(BUNDLE)/Contents/MacOS/ShelfApp
	cp Resources/Info.plist $(BUNDLE)/Contents/Info.plist
	printf 'APPL????' > $(BUNDLE)/Contents/PkgInfo
	codesign --force --deep \
		--sign - \
		--entitlements Resources/Shelf.entitlements \
		$(BUNDLE)
	@echo "Built $(BUNDLE)"

run: bundle
	open $(BUNDLE)

test:
	cd Packages/Core && swift test

clean:
	rm -rf .build build

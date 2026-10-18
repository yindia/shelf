# Shelf — build, bundle, sign, run. No Xcode project required.
APP      := Shelf
BUNDLE   := build/$(APP).app
DMG      := build/$(APP).dmg
CONFIG   := release
BINARY   := .build/$(CONFIG)/ShelfApp
# Universal (Apple Silicon + Intel) build output.
UBINARY  := .build/apple/Products/Release/ShelfApp

.PHONY: all build build-universal bundle run test clean dmg dist icon

all: bundle

build:
	swift build -c $(CONFIG)

# Universal binary for distribution (runs on Apple Silicon AND Intel).
# Build each slice with the native backend (avoids the xcodebuild multi-arch
# path, which mishandles Swift 6 language mode) and lipo them together.
build-universal:
	swift build -c $(CONFIG) --triple arm64-apple-macosx --scratch-path .build-arm64
	swift build -c $(CONFIG) --triple x86_64-apple-macosx --scratch-path .build-x86
	mkdir -p $(dir $(UBINARY))
	lipo -create -output $(UBINARY) \
		.build-arm64/$(CONFIG)/ShelfApp \
		.build-x86/$(CONFIG)/ShelfApp
	@lipo -archs $(UBINARY)

# Assemble a proper .app bundle with Info.plist + entitlements, then ad-hoc sign.
bundle: build
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS $(BUNDLE)/Contents/Resources
	cp $(BINARY) $(BUNDLE)/Contents/MacOS/ShelfApp
	cp Resources/Info.plist $(BUNDLE)/Contents/Info.plist
	cp Resources/AppIcon.icns $(BUNDLE)/Contents/Resources/AppIcon.icns
	printf 'APPL????' > $(BUNDLE)/Contents/PkgInfo
	codesign --force --deep \
		--sign - \
		--entitlements Resources/Shelf.entitlements \
		$(BUNDLE)
	@echo "Built $(BUNDLE)"

run: bundle
	open $(BUNDLE)

# Full universal release: universal build -> bundle -> DMG.
dist: build-universal
	$(MAKE) bundle BINARY=$(UBINARY)
	$(MAKE) dmg
	@lipo -archs $(BUNDLE)/Contents/MacOS/ShelfApp

# Package the built .app into a compressed, drag-to-install DMG.
# Requires `make bundle` first (the release workflow patches the version between).
dmg:
	rm -f $(DMG)
	rm -rf build/dmg && mkdir -p build/dmg
	cp -R $(BUNDLE) build/dmg/
	ln -s /Applications build/dmg/Applications
	hdiutil create -volname "$(APP)" -srcfolder build/dmg -ov -format UDZO "$(DMG)"
	rm -rf build/dmg
	@echo "Built $(DMG)"

test:
	cd Packages/Core && swift test

# Regenerate the app icon (Resources/AppIcon.icns).
icon:
	mkdir -p build
	swift Tools/makeicon.swift
	iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns
	@echo "Built Resources/AppIcon.icns"

clean:
	rm -rf .build build

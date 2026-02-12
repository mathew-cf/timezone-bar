APP_NAME := TimezoneBar
BUNDLE   := build/$(APP_NAME).app
BIN_DIR  := .build/release

.PHONY: all build bundle test install run clean

all: bundle

build:
	swift build -c release

test:
	swift test -v

bundle: build
	@mkdir -p "$(BUNDLE)/Contents/MacOS" "$(BUNDLE)/Contents/Resources"
	cp "$(BIN_DIR)/$(APP_NAME)" "$(BUNDLE)/Contents/MacOS/"
	cp Info.plist "$(BUNDLE)/Contents/"
	codesign --force -s - "$(BUNDLE)"
	@echo "✓ $(BUNDLE) is ready"

install: bundle
	cp -R "$(BUNDLE)" /Applications/
	@echo "✓ Installed to /Applications/$(APP_NAME).app"

run: bundle
	open "$(BUNDLE)"

clean:
	swift package clean
	rm -rf build

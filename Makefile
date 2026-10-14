# Builds iPadView.dylib on a Mac or GitHub Actions macos runner. No Theos needed.

SDK = $(shell xcrun --sdk iphoneos --show-sdk-path)
CC  = xcrun --sdk iphoneos clang
OUT = build/iPadView.dylib

all: $(OUT)

$(OUT): iPadView.m
	@mkdir -p build
	$(CC) -arch arm64 -isysroot $(SDK) -miphoneos-version-min=12.0 \
		-dynamiclib -fobjc-arc -Os \
		-framework UIKit -framework Foundation -framework CoreGraphics -framework QuartzCore \
		-install_name @executable_path/Frameworks/iPadView.dylib \
		-o $(OUT) iPadView.m
	strip -x $(OUT)
	codesign -f -s - $(OUT)

clean:
	rm -rf build

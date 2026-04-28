.PHONY: build test

build_all:
	zig build keyboards-build -Dkeyboard=molekula
	zig build keyboards-build -Dkeyboard=leonardo_keycaprio
	zig build keyboards-build -Dkeyboard=clacky_chan
	zig build test

test:
	@zig build test

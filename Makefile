.PHONY: build test

build:
	cd keyboards
	@zig build -Dkeyboard=molekula
	@zig build -Dkeyboard=leonardo_keycaprio
	@zig build -Dkeyboard=clacky_chan
	@zig build -Dkeyboard=encoder_demo

test:
	@zig build test

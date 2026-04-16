.PHONY: build run test

build:
	@zig build test_compile_only

test:
	@zig build test

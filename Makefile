.PHONY: build run test

build:
	zig build test_compile

run:
	zig build test_compile_run

test:
	zig build test_compile_run

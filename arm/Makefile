all: armforth hello

armforth: armforth.S
	gcc -nostdlib -static -Wl,--build-id=none -o armforth armforth.S

hello:
	gcc -nostdlib -static -Wl,--build-id=none -o hello hello.S

run:
	cat patch.f ../x86/jonesforth.f - | ./armforth

check:
	cat check.f | ./armforth

clean:
	rm -rf armforth hello

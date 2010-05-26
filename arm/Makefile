all: armforth run

armforth: armforth.S
	gcc -nostdlib -static -Wl,-Ttext,0 -Wl,--build-id=none -o armforth armforth.S

run:
	cat ../x86/jonesforth.f - | ./armforth

clean:
	rm -rf armforth

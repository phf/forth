all: jonesforth run

jonesforth: jonesforth.S
	gcc -m32 -nostdlib -static -Wl,-Ttext,0 -Wl,--build-id=none -o jonesforth jonesforth.S

run:
	cat jonesforth.f - | ./jonesforth

clean:
	rm -rf jonesforth

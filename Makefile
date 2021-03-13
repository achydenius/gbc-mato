all: fix

fix: build
	rgbfix -v -p 0 -C mato.gb

build: mato.o
	rgblink -o mato.gb mato.o

mato.o: mato.asm
	rgbasm -o mato.o mato.asm

clean:
	rm -f mato.gb *.o

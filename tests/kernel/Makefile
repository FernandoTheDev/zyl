all: os.img

boot.bin: boot.asm
	nasm -f bin boot.asm -o boot.bin

kernel.o: kernel.c
	zyl -C "-m32 -ffreestanding -c" kernel.zl --of kernel.o

kernel.bin: kernel.o
	ld -m elf_i386 -Ttext 0x1000 --oformat binary kernel.o -o kernel.bin

os.img: boot.bin kernel.bin
	cat boot.bin kernel.bin > os.img
	truncate -s 1440K os.img

run: os.img
	qemu-system-x86_64 -drive format=raw,file=os.img,index=0,media=disk

clean:
	rm -f *.bin *.o os.img

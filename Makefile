all:
	gcc -g3 -O3 foo.c bar.c
	objdump -Sd a.out >OBJDUMP_WITH_S_FLAG.txt
	objdump -d a.out >OBJDUMP.txt
	dwarfdump a.out >DWARFDUMP.txt

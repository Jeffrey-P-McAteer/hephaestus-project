
all: build/minimal-container

build/minimal-container: dodos-builder
	./dodos-builder --out build/minimal-container --flavor minimal

dodos-builder: dodos-builder.c
	gcc -o dodos-builder -std=c17 dodos-builder.c



OUTPUT_DIR := build
SRC_DIR := src
IMAGE := $(OUTPUT_DIR)/DeOS.img

ASM_SOURCES := $(shell find $(SRC_DIR) -type f -name '*.asm')
ASM_BINARIES := $(patsubst $(SRC_DIR)/%.asm,$(OUTPUT_DIR)/%.bin,$(ASM_SOURCES))

BOOTLOADER := $(OUTPUT_DIR)/bootloader/stage1.bin

.PHONY: all build install image debug clean

all: clean install build image debug

build: $(ASM_BINARIES)

$(OUTPUT_DIR)/%.bin: $(SRC_DIR)/%.asm
	mkdir -p $(dir $@)
	fasm $< $@

install:
	command -v fasm >/dev/null 2>&1 || pacman -S --needed --noconfirm fasm
	command -v qemu-system-x86_64 >/dev/null 2>&1 || pacman -S --needed --noconfirm mingw-w64-x86_64-qemu

image: build
	dd if=/dev/zero of=$(IMAGE) bs=512 count=2880
	dd if=$(BOOTLOADER) of=$(IMAGE) bs=512 seek=0 conv=notrunc

debug: image
	qemu-system-x86_64 -drive format=raw,file=$(IMAGE)

clean:
	rm -rf $(OUTPUT_DIR)

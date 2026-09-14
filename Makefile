OUTPUT_DIR := build
DIST_DIR := dist
SRC_DIR := src
IMAGE := $(DIST_DIR)/DeOS.img

ASM_SOURCES := $(shell find $(SRC_DIR) -type f -name '*.asm')
ASM_BINARIES := $(patsubst $(SRC_DIR)/%.asm,$(OUTPUT_DIR)/%.bin,$(ASM_SOURCES))

C_SOURCES := $(shell find $(SRC_DIR) -type f -name '*.c')
C_BINARIES := $(patsubst $(SRC_DIR)/%.c,$(OUTPUT_DIR)/%.exe,$(C_SOURCES))

STAGE1 := $(OUTPUT_DIR)/bootloader/stages/stage1.bin
STAGE2 := $(OUTPUT_DIR)/bootloader/stages/stage2.bin
MAKEBOOT := $(OUTPUT_DIR)/utility/makeboot/makeboot.exe

.PHONY: all build install image debug clean

all: clean install build image debug

build: $(ASM_BINARIES) $(C_BINARIES)

$(OUTPUT_DIR)/%.bin: $(SRC_DIR)/%.asm
	mkdir -p $(dir $@)
	fasm $< $@

$(OUTPUT_DIR)/%.exe: $(SRC_DIR)/%.c
	mkdir -p $(dir $@)
	clang -Wall -Wextra -O2 $< -o $@

install:
	@set -e; \
	if command -v pacman >/dev/null 2>&1; then \
		PACKAGES="fasm mingw-w64-x86_64-clang mingw-w64-x86_64-qemu gdisk"; \
		for package in $$PACKAGES; do \
			pacman -S --needed --noconfirm $$package; \
		done; \
	elif command -v apt >/dev/null 2>&1; then \
		sudo apt update; \
		PACKAGES="fasm clang qemu-system-x86 gdisk"; \
		sudo apt install -y $$PACKAGES; \
	else \
		echo "Error: Neither pacman nor apt was found."; \
		exit 1; \
	fi

image: build
	mkdir -p $(DIST_DIR)
	dd if=/dev/zero of=$(IMAGE) bs=1048576 count=10
	sgdisk --clear --new=1:2048:+8M --typecode=1:EF00 $(IMAGE)
	dd if=$(STAGE1) of=$(IMAGE) bs=512 seek=0 conv=notrunc
	dd if=$(STAGE2) of=$(IMAGE) bs=512 seek=1 conv=notrunc
	$(MAKEBOOT) $(IMAGE) $(STAGE1)

debug: image
	qemu-system-x86_64 -drive format=raw,file=$(IMAGE)

clean:
	sudo umount $(OUTPUT_DIR)/img 2>/dev/null || true
	sudo losetup -D
	rm -rf $(OUTPUT_DIR) $(DIST_DIR)

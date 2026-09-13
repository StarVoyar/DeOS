OUTPUT_DIR := build
DIST_DIR := dist
SRC_DIR := src
IMAGE := $(DIST_DIR)/DeOS.img

ASM_SOURCES := $(shell find $(SRC_DIR) -type f -name '*.asm')
ASM_BINARIES := $(patsubst $(SRC_DIR)/%.asm,$(OUTPUT_DIR)/%.bin,$(ASM_SOURCES))

C_SOURCES := $(shell find $(SRC_DIR) -type f -name '*.c')
C_BINARIES := $(patsubst $(SRC_DIR)/%.c,$(OUTPUT_DIR)/%.exe,$(C_SOURCES))

BOOTLOADER := $(OUTPUT_DIR)/bootloader/stage1.bin
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
	dd if=$(BOOTLOADER) of=$(IMAGE) bs=512 seek=0 conv=notrunc
	sudo losetup -D
	sudo losetup -fP --direct-io=off $(IMAGE)
	### TODO: Make second.bin creation automatic ####
	printf '\364\034Hello, World!' > build/second.bin
	#################################################
	LOOP=$$(losetup -a | grep $(IMAGE) | cut -d: -f1); \
	sudo mkfs.vfat -I -F 16 -n EFI_SYSTEM $$LOOP; \
	mkdir -p $(OUTPUT_DIR)/img; \
	sudo mount -t vfat $$LOOP $(OUTPUT_DIR)/img; \
	sudo mkdir -p $(OUTPUT_DIR)/img/BIOS/BOOT; \
	sudo cp $(OUTPUT_DIR)/second.bin $(OUTPUT_DIR)/img/BIOS/BOOT/STAGE2.BIN; \
	sudo umount $(OUTPUT_DIR)/img; \
	rmdir $(OUTPUT_DIR)/img
	$(MAKEBOOT) $(IMAGE) $(BOOTLOADER)
	sudo losetup -D

debug: image
	qemu-system-x86_64 -drive format=raw,file=$(IMAGE)

clean:
	sudo umount $(OUTPUT_DIR)/img 2>/dev/null || true
	sudo losetup -D
	rm -rf $(OUTPUT_DIR) $(DIST_DIR)

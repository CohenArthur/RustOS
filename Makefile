NAME = RustOS

LD := ld.lld
BUILD_DIR := build

IMAGE := $(BUILD_DIR)/$(NAME).img
IMAGE_DEBUG := $(BUILD_DIR)/$(NAME)_debug.img

KERNEL = target/x86_64-RustOS/release/rust_os
KERNEL_DEBUG = target/x86_64-RustOS/debug/rust_os

SRC = $(wildcard src/*.rs)

.PHONY: run debug clean


#
# Release
#

run: $(IMAGE)
	qemu-system-x86_64 -fda $(IMAGE) -boot a

# Create image with bootloader on first sector and kernel on the first sector onwards
$(IMAGE): $(BUILD_DIR)/boot_loader.bin $(BUILD_DIR)/kernel.bin
	dd if=$< of=$@
	dd if=$(BUILD_DIR)/kernel.bin of=$@ conv=notrunc bs=512 seek=1

# Convert kernel to binary
$(BUILD_DIR)/kernel.bin:$(KERNEL)
	llvm-objcopy -O binary --binary-architecture=i386:x86-64 $< $@

# Compile rust kernel
$(KERNEL): $(SRC)
	cargo xbuild --bin rust_os --release

#
# Debug
#

# Launch qemu and attach gdb to it
debug: $(IMAGE_DEBUG)
	qemu-system-x86_64 -S -s -fda $(IMAGE_DEBUG) &
	gdb -ex "target remote localhost:1234" -ex "file $(KERNEL_DEBUG)"

# Create image with bootloader on first sector and kernel on the first sector onwards
$(IMAGE_DEBUG): $(BUILD_DIR)/boot_loader.bin $(BUILD_DIR)/kernel_debug.bin
	dd if=$< of=$@
	dd if=$(BUILD_DIR)/kernel_debug.bin of=$@ conv=notrunc bs=512 seek=1

# link kernel and kernel start to binary
$(BUILD_DIR)/kernel_debug.bin: $(KERNEL_DEBUG)
	llvm-objcopy -O binary --binary-architecture=i386:x86-64 $< $@

# Compile rust kernel in debug mode
$(KERNEL_DEBUG): $(SRC)
	cargo xbuild --bin rust_os

#
# Intermediate
#

#.bin from .asm
$(BUILD_DIR)/%.bin: src/boot/%.asm
	mkdir -p $(BUILD_DIR)
	nasm -f bin -o $@ $<


clean:
	cargo clean
	${RM} $(BUILD_DIR)/*

# 定义虚目标
.PHONY: clean build user
# 默认第一个目标为 build
all: build

# 如果LOG没有被定义，则将其定义为error
LOG ?= error

K = os

TOOLPREFIX = riscv64-unknown-elf-
# 编译器为gcc
CC = $(TOOLPREFIX)gcc
# 汇编器使用gcc
AS = $(TOOLPREFIX)gcc
# 链接器使用ld
LD = $(TOOLPREFIX)ld
OBJCOPY = $(TOOLPREFIX)objcopy
OBJDUMP = $(TOOLPREFIX)objdump
PY = python3
GDB = $(TOOLPREFIX)gdb
CP = cp
MKDIR_P = mkdir -p

# 构建产出目录
BUILDDIR = build
# os目录下所有的.c文件
C_SRCS = $(wildcard $K/*.c)
# os目录下所有的.S文件
AS_SRCS = $(wildcard $K/*.S)
# 将所有构建出来的.o文件置于 build/os/
C_OBJS = $(addprefix $(BUILDDIR)/, $(addsuffix .o, $(basename $(C_SRCS))))
# 将汇编构建出来的.o文件置于 build/os/
AS_OBJS = $(addprefix $(BUILDDIR)/, $(addsuffix .o, $(basename $(AS_SRCS))))
# 所有的构建出来的 .o 文件
OBJS = $(C_OBJS) $(AS_OBJS)

# 依据.c文件 计算出其依赖项，保存至同名 .d 文件
HEADER_DEP = $(addsuffix .d, $(basename $(C_OBJS)))

# 将.d文件（伪目标）都导入
-include $(HEADER_DEP)

CFLAGS = -Wall -Werror -O -fno-omit-frame-pointer -ggdb
CFLAGS += -MD
CFLAGS += -mcmodel=medany
CFLAGS += -ffreestanding -fno-common -nostdlib -mno-relax
CFLAGS += -I$K
CFLAGS += $(shell $(CC) -fno-stack-protector -E -x c /dev/null >/dev/null 2>&1 && echo -fno-stack-protector)

ifeq ($(LOG), error)
CFLAGS += -D LOG_LEVEL_ERROR
else ifeq ($(LOG), warn)
CFLAGS += -D LOG_LEVEL_WARN
else ifeq ($(LOG), info)
CFLAGS += -D LOG_LEVEL_INFO
else ifeq ($(LOG), debug)
CFLAGS += -D LOG_LEVEL_DEBUG
else ifeq ($(LOG), trace)
CFLAGS += -D LOG_LEVEL_TRACE
endif

# Disable PIE when possible (for Ubuntu 16.10 toolchain)
ifneq ($(shell $(CC) -dumpspecs 2>/dev/null | grep -e '[^f]no-pie'),)
CFLAGS += -fno-pie -no-pie
endif
ifneq ($(shell $(CC) -dumpspecs 2>/dev/null | grep -e '[^f]nopie'),)
CFLAGS += -fno-pie -nopie
endif

LDFLAGS = -z max-page-size=4096

# 构建 os/ 所有的 .S文件
$(AS_OBJS): $(BUILDDIR)/$K/%.o : $K/%.S
	@mkdir -p $(@D)
	$(CC) $(CFLAGS) -c $< -o $@

# 构建 os/ 所有的 .c 文件
$(C_OBJS): $(BUILDDIR)/$K/%.o : $K/%.c  $(BUILDDIR)/$K/%.d
	@mkdir -p $(@D)
	$(CC) $(CFLAGS) -c $< -o $@

# 根据 os/ 下的.c 生成 .d
$(HEADER_DEP): $(BUILDDIR)/$K/%.d : $K/%.c
	@mkdir -p $(@D)
	@set -e; rm -f $@; $(CC) -MM $< $(INCLUDEFLAGS) > $@.$$$$; \
        sed 's,\($*\)\.o[ :]*,\1.o $@ : ,g' < $@.$$$$ > $@; \
        rm -f $@.$$$$

build: build/kernel

# 构建
# 依赖所有的.c 和 .S 的构建（make会隐含的自动构建）
# 链接、输出汇编代码
build/kernel: $(OBJS)
	$(LD) $(LDFLAGS) -T os/kernel.ld -o $(BUILDDIR)/kernel $(OBJS)
	$(OBJDUMP) -S $(BUILDDIR)/kernel > $(BUILDDIR)/kernel.asm
	$(OBJDUMP) -t $(BUILDDIR)/kernel | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > $(BUILDDIR)/kernel.sym
	@echo 'Build kernel done'

clean:
	rm -rf $(BUILDDIR)

# BOARD
BOARD		?= qemu
SBI			?= rustsbi
BOOTLOADER	:= ./bootloader/rustsbi-qemu.bin

QEMU = qemu-system-riscv64
# -nographic 表示模拟器不使用图形界面，只需要对外输出字符流
# -machine virt 计算机设置名为virt
# -bios 设置 qemu 模拟器开机时用来初始化的引导加载程序(bootloader)
QEMUOPTS = \
	-nographic \
	-machine virt \
	-bios $(BOOTLOADER) \
	-kernel build/kernel	\
#	-device loader,file=target/riscv64gc-unknown-none-elf/release/os.bin,addr=0x80200000

# 依赖 build/kernel
run: build/kernel
	$(QEMU) $(QEMUOPTS)

# QEMU's gdb stub command line changed in 0.11
QEMUGDB = $(shell if $(QEMU) -help | grep -q '^-gdb'; \
	then echo "-gdb tcp::15234"; \
	else echo "-s -p 15234"; fi)

debug: build/kernel .gdbinit
	$(QEMU) $(QEMUOPTS) -S $(QEMUGDB) &
	sleep 1
	$(GDB)

/* 控制内核内存布局的链接脚本以使内核运行在 qemu 虚拟机上 */
OUTPUT_ARCH(riscv)
ENTRY(_entry)               /* 入口地址为_entry */
BASE_ADDRESS = 0x80200000;

SECTIONS
{
    . = BASE_ADDRESS;
    skernel = .;

    s_text = .;
    .text : {
        *(.text.entry)
        *(.text .text.*)
        . = ALIGN(0x1000);
        *(trampsec)
        . = ALIGN(0x1000);
    }

    . = ALIGN(4K);
    e_text = .;
    s_rodata = .;
    .rodata : {
        *(.rodata .rodata.*)
    }

    . = ALIGN(4K);
    e_rodata = .;
    s_data = .;
    .data : {
        *(.data.apps)
        *(.data .data.*)
        *(.sdata .sdata.*)
    }

    . = ALIGN(4K);
    e_data = .;
    .bss : {
        *(.bss.stack)
        s_bss = .;
        *(.bss .bss.*)
        *(.sbss .sbss.*)
    }

    . = ALIGN(4K);
    e_bss = .;
    ekernel = .;

    /DISCARD/ : {
        *(.eh_frame)
    }
}
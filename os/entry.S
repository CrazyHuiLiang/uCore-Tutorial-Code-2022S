    .section .text.entry        # emit section
    .globl _entry               # emit _entry symbol to symbol table(scope GLOBAL)
_entry:
    la sp, boot_stack_top       # load boot_stack_top symbol address to sp
    call main                   # call subroutines

    .section .bss.stack
    .globl boot_stack           # emit boot_stack symbol to symbol table(scope GLOBAL)
boot_stack:
    .space 4096 * 16            # 申请8k空间？
    .globl boot_stack_top
boot_stack_top:

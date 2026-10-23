/* link.ld - where every part of a program goes in memory (block S1)
 * Owner: Priyank (G3)
 *
 *   IMEM 0x0000_0000, 16 KB : code (.text), starting with crt0's _start
 *   DMEM 0x0001_0000, 16 KB : constants, globals, then .bss, then the stack,
 *                             which starts at the very top (0x0001_4000)
 *                             and grows down
 */
OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
    IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 16K
    DMEM (rw)  : ORIGIN = 0x00010000, LENGTH = 16K
}

SECTIONS
{
    .text : {
        *(.text.init)
        *(.text .text.*)
    } > IMEM

    .data : {
        *(.rodata .rodata.* .srodata .srodata.*)
        *(.data .data.*)
        *(.sdata .sdata.*)
        . = ALIGN(4);
    } > DMEM

    .bss (NOLOAD) : {
        __bss_start = .;
        *(.sbss .sbss.*)
        *(.bss .bss.*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
        /* 512-byte private stack for the security handler */
        . = . + 512;
        __trap_stack_top = .;
    } > DMEM

    __global_pointer$ = ADDR(.data) + 0x800;
    __stack_top = ORIGIN(DMEM) + LENGTH(DMEM);

    /DISCARD/ : { *(.comment) *(.riscv.attributes) *(.note*) *(.eh_frame*) }
}

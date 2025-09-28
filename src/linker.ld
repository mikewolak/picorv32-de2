/* Minimal RISC-V Linker Script
 * Clean memory layout for 32KB system
 */

ENTRY(_start)

MEMORY {
    ram : ORIGIN = 0x00000000, LENGTH = 0x00008000  /* 32KB */
}

SECTIONS {
    /* Code section starts at 0x0000 - _start must be first */
    .text 0x00000000 : {
        KEEP(*(.text.start))  /* _start function must be at address 0 */
        *(.text)
        *(.text.*)
        *(.rodata)
        *(.rodata.*)
    } > ram

    /* Data section */
    .data : {
        *(.data)
    } > ram

    /* BSS section */
    .bss : {
        *(.bss)
        *(COMMON)
    } > ram

    /* Stack at end of memory - within 32KB bounds */
    .stack 0x7C00 : {
        _stack_start = .;
        . = . + 0x3FC;  /* Stack to 0x7FFC (within 32KB) */
        _stack_end = .;
    } > ram

    /* Discard debug info */
    /DISCARD/ : {
        *(.comment)
        *(.debug*)
    }
}
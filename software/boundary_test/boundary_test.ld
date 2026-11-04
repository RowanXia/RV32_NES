/* Boundary-test image: reserve the final 4 KiB of 48 KiB RAM for trap stack. */
ENTRY(_start)
MEMORY { RAM (rwx) : ORIGIN = 0x80000000, LENGTH = 48K }
SECTIONS {
  . = ORIGIN(RAM);
  .text : { *(.text.init) *(.text*) } > RAM
  .rodata : { *(.rodata*) } > RAM
  .data : { *(.data*) *(.sdata*) } > RAM
  .bss (NOLOAD) : { *(.bss*) *(.sbss*) *(COMMON) } > RAM
  . = ALIGN(16);
  _end = .;
  _stack_top = ORIGIN(RAM) + 44K;
}

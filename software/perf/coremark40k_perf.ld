/* Standalone performance image: 40 KiB payload plus an 8 KiB stack reserve. */
OUTPUT_ARCH(riscv)
ENTRY(_start)
STACK_SIZE = 8K;
MEMORY { RAM (rwx) : ORIGIN = 0x80000000, LENGTH = 40K }
PHDRS { text PT_LOAD FLAGS(5); data PT_LOAD FLAGS(6); }
SECTIONS {
  .text : { KEEP(*(.text.init)) *(.text*) *(.rodata*) } > RAM :text
  .data : { *(.data*) *(.sdata*) } > RAM :data
  .bss (NOLOAD) : {
    . = ALIGN(4); __bss_start = .;
    *(.bss*) *(.sbss*) *(COMMON)
    . = ALIGN(4); __bss_end = .;
  } > RAM :data
  . = ALIGN(16);
  _end = .;
  _stack_top = ORIGIN(RAM) + LENGTH(RAM);
  _stack_limit = _stack_top - STACK_SIZE;
  ASSERT(_end <= _stack_limit, "CoreMark image leaves less than 8 KiB for the runtime stack")
}

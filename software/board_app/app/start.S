# Firmware reset entry for the combined CoreMark-then-NES image.
#
# The linker script supplies __global_pointer$, _stack_top, _sbss and _ebss.
# This code establishes the RV32 freestanding C ABI, clears only .bss, disables
# interrupts, and transfers control to main().  No C global may be read before
# the clear loop completes.  Returning from main deliberately falls into the
# trap_stop loop because this board image has no operating-system exit path.
.section .text.start,"ax",@progbits
.globl _start
_start:
 .option push
 .option norelax
 la gp, __global_pointer$
 .option pop
 la sp, _stack_top
 la t0, trap_stop
 csrw mtvec,t0
 csrw mie,zero
 csrw mstatus,zero
 la t0,_sbss
 la t1,_ebss
1:
 bgeu t0,t1,2f
 sw zero,0(t0)
 addi t0,t0,4
 j 1b
2:
 call main
trap_stop:
 j trap_stop

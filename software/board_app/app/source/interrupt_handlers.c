/*
 * Machine-mode interrupt compatibility callback for the existing board
 * firmware.  The production boot path disables interrupts, so this hook keeps
 * the ABI expected by the runtime without claiming or changing device state.
 */
#include "SOC_ADDR.h"
#include "uart.h"


/** Return the unchanged saved-register frame to the common trap return path. */
__attribute__((used)) u32* irq(u32 *saved_registers, u32 pending_irqs)
{
    (void)pending_irqs;
    return saved_registers;
}

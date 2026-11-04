/* Exercise CLINT software/timer interrupts and PLIC GPIO/UART interrupt paths. */
#include <stdint.h>

#define REG32(a) (*(volatile uint32_t *)(a))
#define CLINT_MSIP       REG32(0x02000000u)
#define CLINT_MTIMECMPLO REG32(0x02004000u)
#define CLINT_MTIMECMPHI REG32(0x02004004u)
#define CLINT_MTIMELO    REG32(0x0200BFF8u)
#define CLINT_MTIMEHI    REG32(0x0200BFFCu)
#define PLIC_PRIO_GPIO   REG32(0x0C00000Cu)
#define PLIC_PRIO_UART   REG32(0x0C000028u)
#define PLIC_ENABLE      REG32(0x0C002000u)
#define PLIC_THRESHOLD   REG32(0x0C200000u)
#define PLIC_CLAIM       REG32(0x0C200004u)
#define GPIO_INPUT_EN    REG32(0x10060004u)
#define GPIO_OUTPUT_EN   REG32(0x10060008u)
#define GPIO_OUTPUT_VAL  REG32(0x1006000Cu)
#define GPIO_RISE_IE     REG32(0x10060018u)
#define GPIO_RISE_IP     REG32(0x1006001Cu)
#define UART_DATA        REG32(0x10000400u)
#define RESULT           REG32(0x40000000u)

static volatile uint32_t msi_seen, mti_seen, gpio_seen, uart_seen, unexpected;

static inline uint32_t csr_read_mcause(void) {
  uint32_t value; __asm__ volatile("csrr %0, mcause" : "=r"(value)); return value;
}
static inline void csr_set_mie(uint32_t mask) { __asm__ volatile("csrs mie, %0" :: "r"(mask)); }
static inline void csr_enable_global(void) { uint32_t x=8; __asm__ volatile("csrs mstatus, %0" :: "r"(x)); }

/** Acknowledge each interrupt source and count only the expected causes. */
void machine_trap_handler(void) {
  uint32_t cause = csr_read_mcause();
  if (cause == 0x80000003u) { CLINT_MSIP = 0; msi_seen++; }
  else if (cause == 0x80000007u) {
    CLINT_MTIMECMPHI = 0xFFFFFFFFu; CLINT_MTIMECMPLO = 0xFFFFFFFFu; mti_seen++;
  } else if (cause == 0x8000000Bu) {
    uint32_t id = PLIC_CLAIM;
    if (id == 3) { GPIO_RISE_IP = 1; gpio_seen++; }
    else if (id == 10) uart_seen++;
    else unexpected++;
    PLIC_CLAIM = id;
  } else unexpected++;
}

static int wait_nonzero(volatile uint32_t *flag) {
  for (uint32_t i=0; i<20000; ++i) if (*flag) return 1;
  return 0;
}

/** Write a stable pass/fail signature to RESULT for RTL or board observation. */
int main(void) {
  RESULT = 0xBAD00000u;
  csr_set_mie((1u<<3)|(1u<<7)|(1u<<11));
  csr_enable_global();

  CLINT_MSIP = 1;
  if (!wait_nonzero(&msi_seen)) { RESULT=0xBAD00001u; for(;;); }

  uint32_t now_hi=CLINT_MTIMEHI, now_lo=CLINT_MTIMELO;
  CLINT_MTIMECMPHI=0xFFFFFFFFu;
  CLINT_MTIMECMPLO=now_lo+128u;
  CLINT_MTIMECMPHI=now_hi+(now_lo>0xFFFFFF7Fu);
  if (!wait_nonzero(&mti_seen)) { RESULT=0xBAD00002u; for(;;); }

  PLIC_PRIO_GPIO=1; PLIC_ENABLE=(1u<<3); PLIC_THRESHOLD=0;
  GPIO_INPUT_EN=1; GPIO_OUTPUT_EN=1; GPIO_OUTPUT_VAL=0; GPIO_RISE_IP=1; GPIO_RISE_IE=1;
  GPIO_OUTPUT_VAL=1;
  if (!wait_nonzero(&gpio_seen)) { RESULT=0xBAD00003u; for(;;); }

  PLIC_PRIO_UART=1; PLIC_ENABLE=(1u<<3)|(1u<<10);
  UART_DATA=0x55u;
  if (!wait_nonzero(&uart_seen)) { RESULT=0xBAD00004u; for(;;); }
  RESULT = unexpected ? 0xBAD00005u : 0x600D1A11u;
  for (;;) __asm__ volatile("wfi");
}

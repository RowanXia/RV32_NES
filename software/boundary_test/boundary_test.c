/* Validate final-line cache refill and precise exceptions at the 48 KiB RAM edge. */
#include <stdint.h>

#define RESULT (*(volatile uint32_t *)0x40000000u)

static volatile uint32_t load_faults;
static volatile uint32_t store_faults;
static volatile uint32_t unexpected_faults;

static inline uint32_t read_csr_mcause(void) {
  uint32_t value;
  __asm__ volatile ("csrr %0, mcause" : "=r"(value));
  return value;
}

static inline uint32_t read_csr_mtval(void) {
  uint32_t value;
  __asm__ volatile ("csrr %0, mtval" : "=r"(value));
  return value;
}

static inline uint32_t read_csr_mepc(void) {
  uint32_t value;
  __asm__ volatile ("csrr %0, mepc" : "=r"(value));
  return value;
}

/** Classify expected invalid-load/store traps and skip their one instruction. */
void machine_trap_handler(void) {
  uint32_t cause = read_csr_mcause();
  uint32_t value = read_csr_mtval();
  if (cause == 5u && value == 0x8000C000u)
    load_faults++;
  else if (cause == 7u && value == 0x8000C000u)
    store_faults++;
  else
    unexpected_faults++;
  __asm__ volatile ("csrw mepc, %0" :: "r"(read_csr_mepc() + 4u));
}

__attribute__((noinline)) static void probe_invalid_load(void) {
  __asm__ volatile ("lw zero, 0(%0)" :: "r"(0x8000C000u) : "memory");
}

__attribute__((noinline)) static void probe_invalid_store(void) {
  uint32_t value = 0xDEADBEEFu;
  __asm__ volatile ("sw %0, 0(%1)" :: "r"(value), "r"(0x8000C000u) : "memory");
}

/** Publish 0x600DB00D to RESULT only if boundary and exception checks pass. */
int main(void) {
  volatile uint32_t *last_line = (volatile uint32_t *)0x8000BFF0u;
  RESULT = 0xBADB0000u;

  // A cold access to the final 16-byte line forces an INCR4 cache refill that
  // must remain wholly inside the 48-KiB local main-memory window.
  uint32_t cold = last_line[3];
  (void)cold;
  last_line[0] = 0x10203040u;
  last_line[1] = 0x50607080u;
  last_line[2] = 0x90A0B0C0u;
  last_line[3] = 0xD0E0F000u;
  __asm__ volatile ("fence rw, rw" ::: "memory");
  if (last_line[0] != 0x10203040u || last_line[1] != 0x50607080u ||
      last_line[2] != 0x90A0B0C0u || last_line[3] != 0xD0E0F000u) {
    RESULT = 0xBADB0001u;
    for (;;) {}
  }

  probe_invalid_load();
  probe_invalid_store();
  RESULT = (load_faults == 1u && store_faults == 1u && unexpected_faults == 0u)
             ? 0x600DB00Du : 0xBADB0002u;
  for (;;) __asm__ volatile ("wfi");
}

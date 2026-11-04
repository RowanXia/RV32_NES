/* EEMBC CoreMark port contract: required definitions and public hook signatures. */
#ifndef RV32_COMBINED_CORE_PORTME_H
#define RV32_COMBINED_CORE_PORTME_H


#define HAS_FLOAT       0
#define HAS_TIME_H      0
#define USE_CLOCK       0
#define HAS_STDIO       0
#define HAS_PRINTF      0
#define SEED_METHOD     SEED_VOLATILE
#define MEM_METHOD      MEM_STATIC
#define MULTITHREAD     1
#define USE_PTHREAD     0
#define USE_FORK        0
#define USE_SOCKET      0
#define MAIN_HAS_NOARGC 1
#define MAIN_HAS_NORETURN 0

#define COMPILER_VERSION "xPack GCC 15.2.0-1"
#define COMPILER_FLAGS   "-O3 -march=rv32im_zicsr_zifencei_zba_zbb_zbc_zbs -mabi=ilp32"
#define MEM_LOCATION     "48 KiB on-chip SRAM"

typedef signed short       ee_s16;
typedef unsigned short     ee_u16;
typedef signed int         ee_s32;
typedef unsigned int       ee_u32;
typedef unsigned long long ee_u64;
typedef unsigned char      ee_u8;
typedef unsigned int       ee_ptr_int;
typedef unsigned int       ee_size_t;
typedef ee_u64             CORE_TICKS;
#define CORETIMETYPE ee_u64

#ifndef NULL
#define NULL ((void *)0)
#endif

#define align_mem(x) (void *)(4 + (((ee_ptr_int)(x) - 1) & ~3u))

typedef struct CORE_PORTABLE_S {
    ee_u8 portable_id;
} core_portable;

extern ee_u32 default_num_contexts;

void portable_init(core_portable *portable, int *argc, char *argv[]);
void portable_fini(core_portable *portable);
int ee_printf(const char *format, ...);

#endif

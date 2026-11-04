/* Firmware-visible CoreMark validation/result records and status constants. */
#ifndef RV32_COREMARK_RESULT_EXPORT_H
#define RV32_COREMARK_RESULT_EXPORT_H

typedef unsigned int benchmark_u32;
typedef unsigned long long benchmark_u64;

#define COMBINED_COREMARK_DONE_MAGIC 0xc0de600du
#define COMBINED_COREMARK_RESULT_MAGIC 0x434d5231u
#define COMBINED_COREMARK_RESULT_VERSION 1u

#define COMBINED_FIELD_SIZE       (1u << 0)
#define COMBINED_FIELD_ITERATIONS (1u << 1)
#define COMBINED_FIELD_TICKS      (1u << 2)
#define COMBINED_FIELD_SECONDS    (1u << 3)
#define COMBINED_FIELD_SEEDCRC    (1u << 4)
#define COMBINED_FIELD_CRCLIST    (1u << 5)
#define COMBINED_FIELD_CRCMATRIX  (1u << 6)
#define COMBINED_FIELD_CRCSTATE   (1u << 7)
#define COMBINED_FIELD_CRCFINAL   (1u << 8)
#define COMBINED_FIELD_VALIDATED  (1u << 9)

#define COMBINED_REQUIRED_FIELDS \
    (COMBINED_FIELD_SIZE | COMBINED_FIELD_ITERATIONS | \
     COMBINED_FIELD_TICKS | COMBINED_FIELD_SECONDS | \
     COMBINED_FIELD_SEEDCRC | COMBINED_FIELD_CRCLIST | \
     COMBINED_FIELD_CRCMATRIX | COMBINED_FIELD_CRCSTATE | \
     COMBINED_FIELD_CRCFINAL | COMBINED_FIELD_VALIDATED)

enum benchmark_validation_code {
    COMBINED_VALIDATION_NOT_RUN = 0,
    COMBINED_VALIDATION_PASS = 1,
    COMBINED_VALIDATION_FAIL = 2
};


typedef struct benchmark_result_record_s {
    benchmark_u32 magic;
    benchmark_u32 version;
    benchmark_u32 valid_mask;
    benchmark_u32 validation;
    benchmark_u32 error_count;
    benchmark_u32 coremark_size;
    benchmark_u32 iterations;
    benchmark_u32 seconds_floor;
    benchmark_u32 ticks_lo;
    benchmark_u32 ticks_hi;
    benchmark_u32 seedcrc;
    benchmark_u32 crclist;
    benchmark_u32 crcmatrix;
    benchmark_u32 crcstate;
    benchmark_u32 crcfinal;
} benchmark_result_record_t;

extern volatile benchmark_u32 benchmark_done_flag;
extern volatile benchmark_u32 benchmark_check_state;
extern volatile benchmark_u64 benchmark_cycle_count;
extern volatile benchmark_result_record_t benchmark_result_record;

#endif

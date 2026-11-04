// Converts pipeline and cache activity into countable performance events.
// Qualifies events so holds and invalid cycles are not counted incorrectly.


`include "perf_defs.vh"

module perf_event_adapter (
  input  wire instr_valid_m,  // Instruction word, decoded field, or validity qualifier.
  input  wire hold_w,  // Backpressure condition preventing writeback advancement.
  input  wire kill_w,  // Suppresses writeback for invalid or trapped instructions.
  input  wire [3:0] instruction_class_m,  // Instruction word, decoded field, or validity qualifier.
  input  wire prediction_wrong_m,  // Branch prediction mismatch used for recovery.
  input  wire i_cache_miss,  // Cache miss indication for line refill processing.
  input  wire d_cache_miss,  // Cache miss indication for line refill processing.
  input  wire i_cache_access,  // Cache-side data, address, or operation control.
  input  wire d_cache_access,  // Cache-side data, address, or operation control.
  input  wire hold_f,  // Holds the fetch PC and prevents front-end advancement.
  input  wire fetch_hold_f,  // Indicates that instruction delivery is not ready.
  input  wire i_cache_hold_f,  // Backpressure caused by an unresolved cache operation.
  input  wire memory_hold_m,  // Indicates that the data-memory request is still pending.
  input  wire d_cache_hold_m,  // Backpressure caused by an unresolved cache operation.
  input  wire div_busy_e,  // Indicates an outstanding iterative division.
  input  wire structural_hold_d,  // Decode-side dependency or structural hazard request.
  input  wire perf_i_cache_request_accept,  // Cache-side data, address, or operation control.
  input  wire perf_i_cache_miss_start,  // Cache miss indication for line refill processing.
  input  wire perf_d_cache_load_accept,  // Cache-side data, address, or operation control.
  input  wire perf_d_cache_load_miss_start,  // Cache-side data, address, or operation control.
  input  wire perf_d_cache_store_accept,  // Cache-side data, address, or operation control.
  input  wire perf_d_cache_store_miss_start,  // Cache-side data, address, or operation control.
  input  wire perf_d_cache_writeback_start,  // Cache-side data, address, or operation control.
  input  wire ahb_wait,  // Provides ahb wait for this module.
  input  wire external_hold,  // External backpressure request that suspends pipeline progression.
  input  wire wait_m,  // Memory-side wait condition used by pipeline hazard control.
  output wire [`PERF_COUNTER_COUNT-1:0] event_vector  // Qualified performance events for cycle accounting.
);

  wire retire_event;
  wire conditional_branch_event;

  // Count only valid instructions that are not held or killed.
  // Qualified event pulses distinguish useful work from stalled or killed cycles.
  assign retire_event = instr_valid_m & ~hold_w & ~kill_w;
  assign conditional_branch_event = retire_event & instruction_class_m[0];

  assign event_vector[`PERF_ID_CYCLES] = 1'b1;
  assign event_vector[`PERF_ID_INSTRET] = retire_event;
  assign event_vector[`PERF_ID_COND_BRANCH] = conditional_branch_event;
  assign event_vector[`PERF_ID_COND_BRANCH_MISS] = conditional_branch_event & prediction_wrong_m;
  assign event_vector[`PERF_ID_ALL_CFI_MISS] = retire_event & prediction_wrong_m;
  // Control cache line update or writeback activity.
  assign event_vector[`PERF_ID_ICACHE_REFILL_DONE] = i_cache_miss;
  assign event_vector[`PERF_ID_DCACHE_REFILL_DONE] = d_cache_miss;
  assign event_vector[`PERF_ID_ICACHE_ACCESS_OBSERVED] = i_cache_access;
  assign event_vector[`PERF_ID_DCACHE_ACCESS_OBSERVED] = d_cache_access;
  assign event_vector[`PERF_ID_FRONTEND_HOLD_CYCLES] = hold_f;
  assign event_vector[`PERF_ID_FETCH_PATH_WAIT_CYCLES] = fetch_hold_f;
  assign event_vector[`PERF_ID_ICACHE_BUSY_CYCLES] = i_cache_hold_f;
  assign event_vector[`PERF_ID_MEM_PATH_WAIT_CYCLES] = memory_hold_m;
  assign event_vector[`PERF_ID_DCACHE_BUSY_CYCLES] = d_cache_hold_m;
  assign event_vector[`PERF_ID_DIVISION_BUSY_CYCLES] = div_busy_e;
  assign event_vector[`PERF_ID_DEPENDENCY_STALL_CYCLES] = structural_hold_d;
  assign event_vector[`PERF_ID_ICACHE_REQUEST_ACCEPT] = perf_i_cache_request_accept;
  // Assert a cache miss event for the selected request.
  assign event_vector[`PERF_ID_ICACHE_MISS_START] = perf_i_cache_miss_start;
  assign event_vector[`PERF_ID_DCACHE_LOAD_ACCEPT] = perf_d_cache_load_accept;
  assign event_vector[`PERF_ID_DCACHE_LOAD_MISS_START] = perf_d_cache_load_miss_start;
  assign event_vector[`PERF_ID_DCACHE_STORE_ACCEPT] = perf_d_cache_store_accept;
  assign event_vector[`PERF_ID_DCACHE_STORE_MISS_START] = perf_d_cache_store_miss_start;
  assign event_vector[`PERF_ID_DCACHE_WRITEBACK_START] = perf_d_cache_writeback_start;
  assign event_vector[`PERF_ID_AHB_WAIT_CYCLES] = ahb_wait;

  
  // Qualify pipeline backpressure with the current request or stage state.
  assign event_vector[`PERF_ID_HOLD_EXCL_EXTERNAL] = hold_f & external_hold;
  assign event_vector[`PERF_ID_HOLD_EXCL_WFI] = hold_f & ~external_hold & wait_m;
  assign event_vector[`PERF_ID_HOLD_EXCL_MEMORY] = hold_f & ~external_hold & ~wait_m & memory_hold_m;
  assign event_vector[`PERF_ID_HOLD_EXCL_FETCH] = hold_f & ~external_hold & ~wait_m & ~memory_hold_m & fetch_hold_f;
  assign event_vector[`PERF_ID_HOLD_EXCL_DIVISION] = hold_f & ~external_hold & ~wait_m & ~memory_hold_m & ~fetch_hold_f & div_busy_e;
  assign event_vector[`PERF_ID_HOLD_EXCL_DEPENDENCY] = hold_f & ~external_hold & ~wait_m & ~memory_hold_m & ~fetch_hold_f & ~div_busy_e & structural_hold_d;
  assign event_vector[`PERF_ID_HOLD_EXCL_OTHER] = hold_f & ~external_hold & ~wait_m & ~memory_hold_m & ~fetch_hold_f & ~div_busy_e & ~structural_hold_d;

endmodule

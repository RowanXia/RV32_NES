// Connects event generation, counters, snapshots, and software-visible controls.
// Coordinates performance measurement windows and report data.


`include "perf_defs.vh"

module perf_monitor_top (
  input  wire clk,  // Clock used for synchronous state updates.
  input  wire reset,  // Resets the local state and pipeline registers.
  input  wire window_marker,  // Provides window marker for this module.
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
  output wire window_active,  // Provides window active for this module.
  output wire [(`PERF_COUNTER_COUNT*`PERF_COUNTER_WIDTH)-1:0] live_counter_values,  // Provides live counter values for this module.
  output wire [(`PERF_COUNTER_COUNT*`PERF_COUNTER_WIDTH)-1:0] snapshot_values,  // Performance counter snapshot or completion state.
  output wire [`PERF_COUNTER_COUNT-1:0] snapshot_overflow,  // Performance counter snapshot or completion state.
  output wire [31:0] snapshot_id,  // Performance counter snapshot or completion state.
  output wire snapshot_valid,  // Performance counter snapshot or completion state.
  output wire snapshot_done  // Performance counter snapshot or completion state.
);

  reg active_node;
  reg marker_q_node;
  wire start;
  wire stop;
  wire clear_counters;
  wire capture_snapshot;
  wire [`PERF_COUNTER_COUNT-1:0] event_vector;
  wire [`PERF_COUNTER_COUNT-1:0] live_overflow;

`ifdef CFG_ILA_PROBES_EXTRA
  // Observation-only probe bundle for internal debug and waveform capture.
  wire [`PERF_COUNTER_COUNT-1:0] ila_perf_events /* synthesis PAP_MARK_DEBUG="true" */;
  assign ila_perf_events = event_vector;
`endif

  // Detect the start and end of a measurement window.
  assign start = window_marker & ~marker_q_node;
  assign stop = ~window_marker & marker_q_node;
  // Derive the performance counter update conditions.
  assign clear_counters = start & ~active_node;
  assign capture_snapshot = stop & active_node;
  assign window_active = active_node;

  
  // Exclude the stop edge from the completed measurement.
  // Updates sequential state on the specified clock event.
  // Clock the active, marker_q state under the specified reset and enable conditions.
  always @(posedge clk) begin
    if (reset) begin
      active_node <= 1'b0;
      marker_q_node <= 1'b0;
    end else begin
      marker_q_node <= window_marker;
      if (capture_snapshot)
        active_node <= 1'b0;
      else if (clear_counters)
        active_node <= 1'b1;
    end
  end

  // Convert execution events into one-cycle count pulses.
  // Translate pipeline, branch, cache, and bus activity into performance pulses.
  perf_event_adapter event_adapter_i_u(
    .instr_valid_m(instr_valid_m), .hold_w(hold_w), .kill_w(kill_w),
    .instruction_class_m(instruction_class_m), .prediction_wrong_m(prediction_wrong_m),
    .i_cache_miss(i_cache_miss), .d_cache_miss(d_cache_miss),
    .i_cache_access(i_cache_access), .d_cache_access(d_cache_access),
    .hold_f(hold_f), .fetch_hold_f(fetch_hold_f), .i_cache_hold_f(i_cache_hold_f),
    .memory_hold_m(memory_hold_m), .d_cache_hold_m(d_cache_hold_m),
    .div_busy_e(div_busy_e), .structural_hold_d(structural_hold_d),
    .perf_i_cache_request_accept(perf_i_cache_request_accept),
    .perf_i_cache_miss_start(perf_i_cache_miss_start),
    .perf_d_cache_load_accept(perf_d_cache_load_accept),
    .perf_d_cache_load_miss_start(perf_d_cache_load_miss_start),
    .perf_d_cache_store_accept(perf_d_cache_store_accept),
    .perf_d_cache_store_miss_start(perf_d_cache_store_miss_start),
    .perf_d_cache_writeback_start(perf_d_cache_writeback_start),
    .ahb_wait(ahb_wait), .external_hold(external_hold), .wait_m(wait_m),
    .event_vector(event_vector));

  // Accumulate events during the active measurement window.
  // Accumulate qualified performance events into programmable counters.
  perf_counter_bank counter_bank_i_u(
    .clk(clk), .reset(reset), .clear(clear_counters),
    .count_enable(active_node & ~stop), .event_vector(event_vector),
    .counter_values(live_counter_values), .overflow_flags(live_overflow));

  // Freeze measured counters for software readout.
  // Latch counter values for coherent software retrieval.
  perf_snapshot snapshot_i_u(
    .clk(clk), .reset(reset), .capture(capture_snapshot),
    .counter_values(live_counter_values), .overflow_flags(live_overflow),
    .snapshot_values(snapshot_values), .snapshot_overflow(snapshot_overflow),
    .snapshot_id(snapshot_id), .snapshot_valid(snapshot_valid),
    .snapshot_done(snapshot_done));

endmodule

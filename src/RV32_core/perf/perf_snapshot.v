// Latches a coherent view of performance counters for software retrieval.
// Produces snapshot validity, identifier, and completion status.


`include "perf_defs.vh"

module perf_snapshot (
  input  wire clk,  // Clock used for synchronous state updates.
  input  wire reset,  // Resets the local state and pipeline registers.
  input  wire capture,  // Provides capture for this module.
  input  wire [(`PERF_COUNTER_COUNT*`PERF_COUNTER_WIDTH)-1:0] counter_values,  // Provides counter values for this module.
  input  wire [`PERF_COUNTER_COUNT-1:0] overflow_flags,  // Counter overflow indication.
  output reg  [(`PERF_COUNTER_COUNT*`PERF_COUNTER_WIDTH)-1:0] snapshot_values,  // Performance counter snapshot or completion state.
  output reg  [`PERF_COUNTER_COUNT-1:0] snapshot_overflow,  // Performance counter snapshot or completion state.
  output reg  [31:0] snapshot_id,  // Performance counter snapshot or completion state.
  output reg  snapshot_valid,  // Performance counter snapshot or completion state.
  output reg  snapshot_done  // Performance counter snapshot or completion state.
);

  // Update registered pipeline or controller state on the clock edge.
  // Update validity state on the active clock edge with reset and enable priority.
  always @(posedge clk) begin
    if (reset) begin
      snapshot_values <= {(`PERF_COUNTER_COUNT*`PERF_COUNTER_WIDTH){1'b0}};
      snapshot_overflow <= {`PERF_COUNTER_COUNT{1'b0}};
      snapshot_id <= 32'b0;
      snapshot_valid <= 1'b0;
      snapshot_done <= 1'b0;
    end else begin
      snapshot_done <= 1'b0;
      if (capture) begin
        snapshot_values <= counter_values;
        snapshot_overflow <= overflow_flags;
        snapshot_id <= snapshot_id + 32'd1;
        snapshot_valid <= 1'b1;
        snapshot_done <= 1'b1;
      end
    end
  end

endmodule

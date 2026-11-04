// Accumulates selected microarchitectural performance events.
// Handles counter enable, reset, overflow, and snapshot inputs.


`include "perf_defs.vh"

module perf_counter_bank (
  input  wire clk,  // Clock used for synchronous state updates.
  input  wire reset,  // Resets the local state and pipeline registers.
  input  wire clear,  // Provides clear for this module.
  input  wire count_enable,  // Provides count enable for this module.
  input  wire [`PERF_COUNTER_COUNT-1:0] event_vector,  // Qualified performance events for cycle accounting.
  output wire [(`PERF_COUNTER_COUNT*`PERF_COUNTER_WIDTH)-1:0] counter_values,  // Provides counter values for this module.
  output wire [`PERF_COUNTER_COUNT-1:0] overflow_flags  // Counter overflow indication.
);

  genvar counter_index;
  // Select the configured hardware implementation.
  // Elaborate the selected parameter-dependent hardware structure.
  generate
    // Apply the same combinational operation to each configured element.
    for (counter_index = 0; counter_index < `PERF_COUNTER_COUNT; counter_index = counter_index + 1) begin : counter_gen
      reg [`PERF_COUNTER_WIDTH-1:0] counter_value_node;
      reg overflow_node;

      // Updates sequential state on the specified clock event.
      // Update the counter state only on qualified clock cycles.
      always @(posedge clk) begin
        if (reset | clear) begin
          counter_value_node <= {`PERF_COUNTER_WIDTH{1'b0}};
          overflow_node <= 1'b0;
        end else if (count_enable & event_vector[counter_index]) begin
          counter_value_node <= counter_value_node + {{(`PERF_COUNTER_WIDTH-1){1'b0}}, 1'b1};
          if (&counter_value_node)
            overflow_node <= 1'b1;
        end
      end

      // Derive the performance counter update conditions.
      assign counter_values[(counter_index*`PERF_COUNTER_WIDTH) +: `PERF_COUNTER_WIDTH] = counter_value_node;
      assign overflow_flags[counter_index] = overflow_node;
    end
  endgenerate

endmodule

// Exposes performance counters through memory-mapped AHB reads and writes.
// Implements address decoding and transfer handshakes for the monitor.


`include "perf_defs.vh"

module perf_mmio_ahb #(
  parameter [31:0] BASE = 32'h3000_0000
) (
  input  wire clk,  // Clock used for synchronous state updates.
  input  wire reset_n,  // Provides reset n for this module.
  input  wire hsel,  // Provides hsel for this module.
  input  wire hready,  // AHB transfer-ready handshake.
  input  wire [31:0] haddr,  // AHB address for the active transfer.
  input  wire [1:0] htrans,  // AHB transfer-type control.
  input  wire hwrite,  // AHB read/write direction.
  input  wire [2:0] hsize,  // Provides hsize for this module.
  input  wire [31:0] hwdata,  // AHB write data.
  input  wire [3:0] hwstrb,  // Provides hwstrb for this module.
  output reg  [31:0] hrdata,  // Provides hrdata for this module.
  output wire hreadyout,  // AHB transfer-ready handshake.
  output wire hresp,  // AHB transfer error/response status.
  output reg  window_marker,  // Provides window marker for this module.
  input  wire window_active,  // Provides window active for this module.
  input  wire [(`PERF_COUNTER_COUNT*`PERF_COUNTER_WIDTH)-1:0] snapshot_values,  // Performance counter snapshot or completion state.
  input  wire [`PERF_COUNTER_COUNT-1:0] snapshot_overflow,  // Performance counter snapshot or completion state.
  input  wire [31:0] snapshot_id,  // Performance counter snapshot or completion state.
  input  wire snapshot_valid,  // Performance counter snapshot or completion state.
  input  wire snapshot_done  // Performance counter snapshot or completion state.
);
  localparam [11:0] REG_ID            = 12'h000;
  localparam [11:0] REG_VERSION       = 12'h004;
  localparam [11:0] REG_FEATURES      = 12'h008;
  localparam [11:0] REG_CONTROL       = 12'h00c;
  localparam [11:0] REG_STATUS        = 12'h010;
  localparam [11:0] REG_SNAPSHOT_ID   = 12'h014;
  localparam [11:0] REG_COUNTER_INDEX = 12'h018;
  localparam [11:0] REG_COUNTER_LO    = 12'h01c;
  localparam [11:0] REG_COUNTER_HI    = 12'h020;
  localparam [11:0] REG_OVERFLOW_LO   = 12'h024;
  localparam [11:0] REG_OVERFLOW_HI   = 12'h028;
  localparam [11:0] REG_COUNTER_COUNT = 12'h02c;
  localparam [4:0] COUNTER_COUNT_VALUE = `PERF_COUNTER_COUNT;

  reg pending_valid;
  reg pending_write;
  reg pending_static_error;
  reg [11:0] pending_offset;
  reg [4:0] counter_index;
  reg [31:0] selected_counter_lo;
  reg [31:0] selected_counter_hi;

  wire address_phase_valid = hsel & htrans[1];
  wire address_in_window = (haddr >= BASE) && (haddr <= (BASE + 32'h0000_0fff));
  wire aligned_word = (haddr[1:0] == 2'b00) && (hsize == 3'b010);
  wire address_known = (haddr[11:0] == REG_ID) ||
                       (haddr[11:0] == REG_VERSION) ||
                       (haddr[11:0] == REG_FEATURES) ||
                       (haddr[11:0] == REG_CONTROL) ||
                       (haddr[11:0] == REG_STATUS) ||
                       (haddr[11:0] == REG_SNAPSHOT_ID) ||
                       (haddr[11:0] == REG_COUNTER_INDEX) ||
                       (haddr[11:0] == REG_COUNTER_LO) ||
                       (haddr[11:0] == REG_COUNTER_HI) ||
                       (haddr[11:0] == REG_OVERFLOW_LO) ||
                       (haddr[11:0] == REG_OVERFLOW_HI) ||
                       (haddr[11:0] == REG_COUNTER_COUNT);
  wire write_address_allowed = (haddr[11:0] == REG_CONTROL) ||
                               (haddr[11:0] == REG_COUNTER_INDEX);
  wire control_data_valid = ((hwdata == 32'h0000_0001) ||
                             (hwdata == 32'h0000_0002));
  wire index_data_valid = (hwdata < `PERF_COUNTER_COUNT);
  wire write_data_error = pending_write &&
                          ((hwstrb != 4'b1111) ||
                           ((pending_offset == REG_CONTROL) && !control_data_valid) ||
                           ((pending_offset == REG_COUNTER_INDEX) && !index_data_valid));

  // Qualify transfer completion with the bus handshake.
  assign hreadyout = 1'b1;
  assign hresp = pending_valid & (pending_static_error | write_data_error);

  // Respond to memory-mapped performance monitor reads.
  // Computes combinational outputs using decoded operation and state selections.
  // Compute the combinational next-state/output decisions from the current control state.
  always @* begin
    selected_counter_lo = 32'b0;
    selected_counter_hi = 32'b0;
    if (counter_index < `PERF_COUNTER_COUNT) begin
      selected_counter_lo = snapshot_values[(counter_index*`PERF_COUNTER_WIDTH) +: 32];
      selected_counter_hi = snapshot_values[(counter_index*`PERF_COUNTER_WIDTH+32) +: 32];
    end
  end

  // Compute combinational control and data selections.
  // Compute the combinational next-state/output decisions from the current control state.
  always @* begin
    // Select the output behavior according to pending_offset.
    case (pending_offset)
      REG_ID:            hrdata = 32'h5045_5246; 
      REG_VERSION:       hrdata = 32'h0001_0000;
      REG_FEATURES:      hrdata = {16'd0, 8'd64, 3'd0, COUNTER_COUNT_VALUE};
      REG_CONTROL:       hrdata = {31'b0, window_marker};
      REG_STATUS:        hrdata = {28'b0, snapshot_done, snapshot_valid,
                                   window_active, window_marker};
      REG_SNAPSHOT_ID:   hrdata = snapshot_id;
      REG_COUNTER_INDEX: hrdata = {27'b0, counter_index};
      REG_COUNTER_LO:    hrdata = selected_counter_lo;
      REG_COUNTER_HI:    hrdata = selected_counter_hi;
      REG_OVERFLOW_LO:   hrdata = {{(32-`PERF_COUNTER_COUNT){1'b0}}, snapshot_overflow};
      REG_OVERFLOW_HI:   hrdata = 32'b0;
      REG_COUNTER_COUNT: hrdata = `PERF_COUNTER_COUNT;
      default:           hrdata = 32'b0;
    endcase
  end

  // Update registered pipeline or controller state on the clock edge.
  // Update the counter state only on qualified clock cycles.
  always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      pending_valid <= 1'b0;
      pending_write <= 1'b0;
      pending_static_error <= 1'b0;
      pending_offset <= 12'b0;
      counter_index <= 5'b0;
      window_marker <= 1'b0;
    end else if (hready) begin
      if (pending_valid && pending_write && !pending_static_error && !write_data_error) begin
        if (pending_offset == REG_CONTROL)
          window_marker <= hwdata[0];
        else if (pending_offset == REG_COUNTER_INDEX)
          counter_index <= hwdata[4:0];
      end

      pending_valid <= address_phase_valid;
      pending_write <= hwrite;
      pending_offset <= haddr[11:0];
      pending_static_error <= address_phase_valid &&
          (!address_in_window || !aligned_word || !address_known ||
           (hwrite && !write_address_allowed));
    end
  end
endmodule

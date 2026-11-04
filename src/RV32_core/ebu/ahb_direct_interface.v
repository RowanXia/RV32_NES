// Maps direct memory requests onto AHB control, address, and data signals.
// Returns transfer completion and response status to the requester.


module ahb_direct_interface #(
  parameter [0:0] DATA_PORT = 1'b0
)(
  input wire hclk,  // Clock forwarded to the AHB interface.
  input wire hrese_tn,  // Active-low AHB reset generated from the core reset.
  input wire hready,  // AHB transfer-completion handshake from the selected slave.
  input wire hresp,  // AHB response status returned by the selected slave.
  output wire [1:0] htrans,  // AHB transfer type for the selected bus request.
  output wire hwrite,  // Indicates an AHB write transfer.
  input wire [31:0] hrdata,  // AHB read-data bus returned by the selected target.
  output wire [31:0] hwdata,  // AHB write-data bus.
  output wire [3:0] hwstrb,  // Byte-lane strobes for the AHB write transaction.
  input wire hold,  // Prevents the corresponding pipeline stage from advancing.
  input wire kill,  // Cancels invalid or wrong-path pipeline work.
  input wire [1:0] bus_rw,  // Provides bus rw for this module.
  input wire [3:0] byte_mask,  // Active byte lanes for a memory write.
  input wire [31:0] write_data,  // Data value to be written to the target.
  output wire bus_hold,  // Prevents the corresponding pipeline stage from advancing.
  output wire bus_committed,  // Provides bus committed for this module.
  output wire bus_error,  // Provides bus error for this module.
  output wire [31:0] fetch_buffer  // Instruction-fetch request, response, or control.
);

  wire capture_en;

  if (DATA_PORT) ffen  #(32) DirectReadFF(.clk(hclk), .en(capture_en), .d(hrdata), .q(fetch_buffer));
  else     ffenr #(32) DirectReadFF(.clk(hclk), .reset(~hrese_tn), .en(capture_en), .d(hrdata), .q(fetch_buffer));

  if (DATA_PORT) begin
    // Register stage data under the supplied clock, reset, and enable controls.
    ff #(32/8) hwstrb_reg_u(hclk, byte_mask, hwstrb);
    // Register stage data under the supplied clock, reset, and enable controls.
    ff #(32)   wdreg_u(hclk, write_data, hwdata);
  end else begin
    assign hwdata = 1'b0;
    assign hwstrb = 1'b0;
  end

  // Sequence uncached transfers and completion/error handling on AHB.
  ahb_direct_fsm #(~DATA_PORT) ahb_direct_fsm_i_u(.hclk(hclk), .hrese_tn(hrese_tn), .kill(kill), .bus_rw(bus_rw),
    .bus_committed(bus_committed), .hold(hold), .bus_hold(bus_hold), .capture_en(capture_en), .hready(hready), .hresp(hresp), .bus_error(bus_error), .htrans(htrans), .hwrite(hwrite));
endmodule

// Preserves an AHB request while bus ownership or completion is delayed.
// Supports request save, restore, and output qualification.


module ahb_request_buffer #(
  parameter SAVE_ENABLED = 1           
)(
  input wire hclk,  // Clock forwarded to the AHB interface.
  input wire hrese_tn,  // Active-low AHB reset generated from the core reset.
  input wire save,  // Provides save for this module.
  input wire restore,  // Provides restore for this module.
  input wire disable_request,  // Suppresses acceptance while another request owns the bus.
  output wire request,  // Provides request for this module.
  
  input wire [1:0] HTRANSIn,  // AHB transfer-type control.
  input wire hwrite_in,  // AHB read/write direction.
  input wire [2:0] hsize_in,  // AHB interface hsize in signal.
  input wire [2:0] hburst_in,  // AHB burst encoding.
  input wire [31:0] haddr_in,  // AHB address for the active transfer.
  output wire hready_out,  // AHB transfer-ready handshake.
  
  output wire [1:0] HTRANSOut,  // AHB transfer-type control.
  output wire hwrite_out,  // AHB read/write direction.
  output wire [2:0] hsize_out,  // AHB interface hsize out signal.
  output wire [2:0] hburst_out,  // AHB burst encoding.
  output wire [31:0] haddr_out,  // AHB address for the active transfer.
  input wire hready_in  // AHB transfer-ready handshake.
);

  wire hwrite_save_node;
  wire [2:0] hsize_save_node;
  wire [2:0] hburst_save_node;
  wire [1:0] htrans_save_node;
  wire [31:0] haddr_save_node;

  if (SAVE_ENABLED) begin
    // Register stage data under the supplied clock, reset, and enable controls.
    ffenr #(1+3+3+2+32) save_reg_u(hclk, ~hrese_tn, save,
      {hwrite_in, hsize_in, hburst_in, HTRANSIn, haddr_in},
      {hwrite_save_node, hsize_save_node, hburst_save_node, htrans_save_node, haddr_save_node});
    // Select the appropriate datapath value from the available inputs.
    mux2 #(1+3+3+2+32) restor_mux_u({hwrite_in, hsize_in, hburst_in, HTRANSIn, haddr_in},
      {hwrite_save_node, hsize_save_node, hburst_save_node, htrans_save_node, haddr_save_node},
      restore,
      {hwrite_out, hsize_out, hburst_out, HTRANSOut, haddr_out});
  end else begin
    assign hwrite_out = hwrite_in;
    assign hsize_out = hsize_in;
    assign hburst_out = hburst_in;
    assign HTRANSOut = HTRANSIn;
    assign haddr_out = haddr_in;
  end

  // Qualify transfer completion with the bus handshake.
  assign hready_out = hready_in & ~disable_request;
  assign request = HTRANSOut != 2'b00;

endmodule

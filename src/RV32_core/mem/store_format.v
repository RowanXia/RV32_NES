// Aligns write data to the selected memory byte lanes.
// Supports byte, halfword, and word store placement.


module store_format (
  input wire [2:0] store_funct3_m,  // Store function-3 used by the memory-stage datapath or control.
  input wire [31:0] store_data_m,  // Store data used by the memory-stage datapath or control.
  output reg [31:0] little_endian_write_data_m  // Data value to be written to the target.
);

  
  // Compute combinational control and data selections.
  // Compute the combinational next-state/output decisions from the current control state.
  always @*
    // Select the datapath operation from the decoded instruction function field.
    case(store_funct3_m[1:0])
      2'b00:   little_endian_write_data_m = {4{store_data_m[7:0]}};  
      2'b01:   little_endian_write_data_m = {2{store_data_m[15:0]}}; 
      default: little_endian_write_data_m = store_data_m;            
    endcase
endmodule

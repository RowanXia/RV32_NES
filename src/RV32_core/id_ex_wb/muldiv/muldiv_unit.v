// Coordinates multiplication and division execution with the integer pipeline.
// Selects the requested arithmetic result and indicates busy or completion status.


`include "config.vh"

module muldiv_unit    (
  input wire clk,  // Clock used for synchronous state updates.
  input wire reset,  // Resets the local state and pipeline registers.
  input wire hold_m,  // Holds the memory-stage transaction and state.
  input wire hold_w,  // Backpressure condition preventing writeback advancement.
  input wire kill_e,  // Cancels younger execute-stage work or injects a bubble.
  input wire kill_m,  // Invalidates the instruction entering the memory stage.
  input wire kill_w,  // Suppresses writeback for invalid or trapped instructions.
  input wire [31:0] forwarded_src_ae,  // Operand value after bypass/forwarding selection.
  input wire [31:0] forwarded_src_be,  // Operand value after bypass/forwarding selection.
  input wire [2:0] funct3_e,  // Function-3 used by the execute-stage datapath or control.
  input wire [2:0] funct3_m,  // Function-3 used by the memory-stage datapath or control.
  input wire int_div_e,  // Selects integer division/remainder operations in execute.
  input wire mul_div_active_e,  // Multiplication division active used by the execute-stage datapath or control.
  output wire [31:0] mul_div_result_w,  // Multiplication division result used by the writeback-stage datapath or control.
  output wire div_busy_e  // Indicates an outstanding iterative division.
);

  wire [63:0] prod_m;                          
  wire [31:0] quot_m;
  wire [31:0] rem_m;                    
  reg [31:0] prelim_result_m_node;                  
  wire [31:0] mul_div_result_m_node;

  
  if (!`CFG_M_SUPPORTED) begin : nodiv
    assign quot_m = 1'b0;
    assign rem_m = 1'b0;
    assign div_busy_e = 1'b0;
  end else begin : div_u
    // Sequence signed and unsigned iterative quotient/remainder operations.
    divider div_u(.clk(clk), .reset(reset), .hold_m(hold_m), .kill_e(kill_e), .div_signed_e(~funct3_e[0]), .int_div_e(int_div_e),
        .forwarded_src_ae(forwarded_src_ae), .forwarded_src_be(forwarded_src_be), .div_busy_e(div_busy_e), .quot_m(quot_m), .rem_m(rem_m));
  end

  
  // Calculate integer products using the supported multiplication modes.
  multiplier mul_u(.clk(clk), .reset(reset), .hold_m(hold_m), .kill_m(kill_m), .forwarded_src_ae(forwarded_src_ae), .forwarded_src_be(forwarded_src_be), .funct3_e(funct3_e), .prod_m(prod_m));

  
  // Compute combinational control and data selections.
  // Compute the combinational next-state/output decisions from the current control state.
  always @*
    // Select the datapath operation from the decoded instruction function field.
    case (funct3_m)
      3'b000: prelim_result_m_node = prod_m[31:0];          
      3'b001: prelim_result_m_node = prod_m[63:32];   
      3'b010: prelim_result_m_node = prod_m[63:32];   
      3'b011: prelim_result_m_node = prod_m[63:32];   
      3'b100: prelim_result_m_node = quot_m;                      
      3'b101: prelim_result_m_node = quot_m;                      
      3'b110: prelim_result_m_node = rem_m;                       
      3'b111: prelim_result_m_node = rem_m;                       
    endcase

  assign mul_div_result_m_node = prelim_result_m_node;

  
  // Register the computed result for the next pipeline stage.
  ffenrc #(32) mul_div_result_w_reg_u(clk, reset, kill_w, ~hold_w, mul_div_result_m_node, mul_div_result_w);
endmodule 

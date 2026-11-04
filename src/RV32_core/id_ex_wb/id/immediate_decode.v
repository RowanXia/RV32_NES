// Extracts and sign-extends immediate fields from instruction encodings.
// Supports immediate formats required by decoded RV32 instructions.


`include "config.vh"

module immediate_decode    (
  input wire [31:7] instr_d,  // Decoded-stage instruction word.
  input wire [2:0] imm_src_d,  // Immediate field or immediate selection.
  output reg [31:0] extended_immediate_d);  // Immediate operand extracted from an instruction.

  localparam [31:0] undefined_node = {32{1'bx}}; 

  // Compute combinational control and data selections.
  // Compute the combinational next-state/output decisions from the current control state.
  always @*
    // Select the output behavior according to imm_src_d.
    case (imm_src_d)
      
      3'b000:   extended_immediate_d = {{20{instr_d[31]}}, instr_d[31:20]};
      
      3'b001:   extended_immediate_d = {{20{instr_d[31]}}, instr_d[31:25], instr_d[11:7]};
      
      3'b010:   extended_immediate_d = {{20{instr_d[31]}}, instr_d[7], instr_d[30:25], instr_d[11:8], 1'b0};
      
      3'b011:   extended_immediate_d = {{12{instr_d[31]}}, instr_d[19:12], instr_d[20], instr_d[30:21], 1'b0};
      
      3'b100:   extended_immediate_d = {{1{instr_d[31]}}, instr_d[30:12], 12'b0};
      
      3'b101:  extended_immediate_d = undefined_node;
      default: extended_immediate_d = undefined_node; 
    endcase

endmodule

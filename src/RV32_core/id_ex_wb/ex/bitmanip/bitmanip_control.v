// Decodes bit-manipulation instruction fields into subunit controls.
// Selects the required result path for supported extension operations.


`include "config.vh"

module bitmanip_control    (
  input wire clk,  // Clock used for synchronous state updates.
  input wire reset,  // Resets the local state and pipeline registers.
  
  input wire [31:0] instr_d,  // Decoded-stage instruction word.
  input wire alu_op_d,  // ALU operation selection, operand, or result.
  output wire b_reg_write_d,  // Register-file write-enable control.
  output wire balu_src_bd,  // Second ALU operand or operand selector.
  output wire b_sub_arith_d,  // B sub arith used by the decode-stage datapath or control.
  output wire illegal_bitmanip_instr_d,  // Instruction word, decoded field, or validity qualifier.
  
  input wire hold_e,  // Holds execute-stage operands and control until accepted.
  input wire kill_e,  // Cancels younger execute-stage work or injects a bubble.
  output wire [2:0] alu_select_d,  // ALU operation selection, operand, or result.
  output wire [3:0] b_select_e,  // B select used by the execute-stage datapath or control.
  output wire [3:0] zbb_select_e,  // Zbb select used by the execute-stage datapath or control.
  output wire [2:0] balu_control_e,  // Bit-manipulation alu control used by the execute-stage datapath or control.
  output wire bitmanip_active_e  // Bitmanip active used by the execute-stage datapath or control.
);

  wire [6:0] op_d_node;                             
  wire [2:0] funct3_d_node;                         
  wire [6:0] funct7_d_node;                         
  wire [4:0] rs2_d;                            
  wire rotate_d_node;                         
  wire mask_d_node;                           
  wire pre_shift_d_node;                       
  wire [2:0] balu_control_d_node;                    
  wire [2:0] balu_select_d_node;                     
  wire balu_op_d_node;                         
  wire [3:0] b_select_d_node;                        
  wire [3:0] zbb_select_d_node;                      

  `define BITMANIP_CTRL_WIDTH 21

  wire [`BITMANIP_CTRL_WIDTH-1:0] bitmanip_controls_d_node;          

  
  assign op_d_node = instr_d[6:0];
  assign funct3_d_node = instr_d[14:12];
  assign funct7_d_node = instr_d[31:25];
  assign rs2_d = instr_d[24:20];

  
  // Select this hardware path from the active configuration.
  if (`CFG_ZBA_SUPPORTED | `CFG_ZBB_SUPPORTED |
      `CFG_ZBC_SUPPORTED | `CFG_ZBS_SUPPORTED) begin : bitmanip_decode_enabled
    reg [`BITMANIP_CTRL_WIDTH-1:0] decoded_bitmanip_controls_d_node;
    assign bitmanip_controls_d_node = decoded_bitmanip_controls_d_node;
    // Compute combinational control and data selections.
    // Compute the combinational next-state/output decisions from the current control state.
    always @* begin
    
    decoded_bitmanip_controls_d_node = `BITMANIP_CTRL_WIDTH'b000_00_000_0_0_0_0_0_0_0_0_1;

    // Select this hardware path from the active configuration.
    if (`CFG_ZBA_SUPPORTED)
      // Select the datapath operation from the decoded instruction function field.
      casez({op_d_node, funct7_d_node, funct3_d_node})
        17'b0110011_0010000_010: decoded_bitmanip_controls_d_node = `BITMANIP_CTRL_WIDTH'b000_0001_0000_1_0_0_0_1_0_0_0_1_0; 
        17'b0110011_0010000_100: decoded_bitmanip_controls_d_node = `BITMANIP_CTRL_WIDTH'b000_0001_0000_1_0_0_0_1_0_0_0_1_0; 
        17'b0110011_0010000_110: decoded_bitmanip_controls_d_node = `BITMANIP_CTRL_WIDTH'b000_0001_0000_1_0_0_0_1_0_0_0_1_0; 
      endcase

    // Select this hardware path from the active configuration.
    if (`CFG_ZBB_SUPPORTED)
      // Select control behavior for the decoded state or operation.
      // Select the datapath operation from the decoded instruction function field.
      casez({op_d_node, funct7_d_node, funct3_d_node})
        17'b0010011_0110000_001:
          if (rs2_d[4:1] == 4'b0010)
            decoded_bitmanip_controls_d_node = `BITMANIP_CTRL_WIDTH'b000_0010_0001_1_1_0_0_1_0_0_0_0_0;
          else if ((rs2_d[4:2] == 3'b000) & ~(rs2_d[1] & rs2_d[0]))
            decoded_bitmanip_controls_d_node = `BITMANIP_CTRL_WIDTH'b000_0010_0000_1_1_0_0_1_0_0_0_0_0;
        17'b0010011_0010100_101: if (rs2_d == 5'b00111) decoded_bitmanip_controls_d_node = `BITMANIP_CTRL_WIDTH'b000_0010_0010_1_1_0_0_1_0_0_0_0_0; 
        17'b0110011_0000101_110: decoded_bitmanip_controls_d_node = `BITMANIP_CTRL_WIDTH'b000_0010_0111_1_0_0_0_1_1_0_0_0_0; 
        17'b0110011_0000101_111: decoded_bitmanip_controls_d_node = `BITMANIP_CTRL_WIDTH'b000_0010_0111_1_0_0_0_1_1_0_0_0_0; 
        17'b0110011_0000101_100: decoded_bitmanip_controls_d_node = `BITMANIP_CTRL_WIDTH'b000_0010_0011_1_0_0_0_1_1_0_0_0_0; 
        17'b0110011_0000101_101: decoded_bitmanip_controls_d_node = `BITMANIP_CTRL_WIDTH'b000_0010_0011_1_0_0_0_1_1_0_0_0_0; 
        17'b0110011_0000100_100: if (rs2_d == 5'b0) decoded_bitmanip_controls_d_node = `BITMANIP_CTRL_WIDTH'b000_0010_0001_1_1_0_0_1_0_0_0_0_0; 
      endcase

    // Select this hardware path from the active configuration.
    if (`CFG_ZBC_SUPPORTED)
      // Select the datapath operation from the decoded instruction function field.
      casez({op_d_node, funct7_d_node, funct3_d_node})
        17'b0110011_0000101_010: decoded_bitmanip_controls_d_node = `BITMANIP_CTRL_WIDTH'b000_0011_0001_1_0_0_0_1_0_0_0_0_0; 
        17'b0110011_0000101_0?1: decoded_bitmanip_controls_d_node = `BITMANIP_CTRL_WIDTH'b000_0011_0000_1_0_0_0_1_0_0_0_0_0; 
      endcase

    // Select this hardware path from the active configuration.
    if (`CFG_ZBS_SUPPORTED)
      // Select the datapath operation from the decoded instruction function field.
      casez({op_d_node, funct7_d_node, funct3_d_node})
        17'b0110011_0100100_001: decoded_bitmanip_controls_d_node = `BITMANIP_CTRL_WIDTH'b111_0001_0000_1_0_0_0_1_1_0_1_0_0; 
        17'b0110011_0100100_101: decoded_bitmanip_controls_d_node = `BITMANIP_CTRL_WIDTH'b101_0001_0000_1_0_0_0_1_0_0_1_0_0; 
        17'b0110011_0110100_001: decoded_bitmanip_controls_d_node = `BITMANIP_CTRL_WIDTH'b100_0001_0000_1_0_0_0_1_0_0_1_0_0; 
        17'b0110011_0010100_001: decoded_bitmanip_controls_d_node = `BITMANIP_CTRL_WIDTH'b110_0001_0000_1_0_0_0_1_0_0_1_0_0; 
        17'b0010011_0100100_001: decoded_bitmanip_controls_d_node = `BITMANIP_CTRL_WIDTH'b111_0001_0000_1_1_0_0_1_1_0_1_0_0; 
        17'b0010011_0100100_101: decoded_bitmanip_controls_d_node = `BITMANIP_CTRL_WIDTH'b101_0001_0000_1_1_0_0_1_0_0_1_0_0; 
        17'b0010011_0110100_001: decoded_bitmanip_controls_d_node = `BITMANIP_CTRL_WIDTH'b100_0001_0000_1_1_0_0_1_0_0_1_0_0; 
        17'b0010011_0010100_001: decoded_bitmanip_controls_d_node = `BITMANIP_CTRL_WIDTH'b110_0001_0000_1_1_0_0_1_0_0_1_0_0; 
      endcase

    // Select this hardware path from the active configuration.
    if (`CFG_ZBB_SUPPORTED | `CFG_ZBS_SUPPORTED)
      // Select the datapath operation from the decoded instruction function field.
      casez({op_d_node, funct7_d_node, funct3_d_node})
        17'b0110011_0000000_001: decoded_bitmanip_controls_d_node = `BITMANIP_CTRL_WIDTH'b001_0000_0000_1_0_0_0_1_0_0_0_0_0; 
        17'b0110011_0?00000_101: decoded_bitmanip_controls_d_node = `BITMANIP_CTRL_WIDTH'b001_0000_0000_1_0_0_0_1_0_0_0_0_0; 
        17'b0010011_000000?_001: if (!funct7_d_node[0]) decoded_bitmanip_controls_d_node = `BITMANIP_CTRL_WIDTH'b001_0000_0000_1_1_0_0_1_0_0_0_0_0; 
        17'b0010011_0?0000?_101: if (!funct7_d_node[0]) decoded_bitmanip_controls_d_node = `BITMANIP_CTRL_WIDTH'b001_0000_0000_1_1_0_0_1_0_0_0_0_0; 
      endcase

    // Select this hardware path from the active configuration.
    if (`CFG_ZBB_SUPPORTED)
      // Select the datapath operation from the decoded instruction function field.
      casez({op_d_node, funct7_d_node, funct3_d_node})
        17'b0110011_0110000_001: decoded_bitmanip_controls_d_node = `BITMANIP_CTRL_WIDTH'b001_0001_0111_1_0_0_0_1_0_1_0_0_0; 
        17'b0110011_0110000_101: decoded_bitmanip_controls_d_node = `BITMANIP_CTRL_WIDTH'b001_0001_0111_1_0_0_0_1_0_1_0_0_0; 
        17'b0110011_0100000_111: decoded_bitmanip_controls_d_node = `BITMANIP_CTRL_WIDTH'b111_0001_0111_1_0_0_0_1_1_0_0_0_0; 
        17'b0110011_0100000_110: decoded_bitmanip_controls_d_node = `BITMANIP_CTRL_WIDTH'b110_0001_0111_1_0_0_0_1_1_0_0_0_0; 
        17'b0110011_0100000_100: decoded_bitmanip_controls_d_node = `BITMANIP_CTRL_WIDTH'b100_0001_0111_1_0_0_0_1_1_0_0_0_0; 
        17'b0010011_011010?_101: if ((!funct7_d_node[0]) & (rs2_d == 5'b11000)) decoded_bitmanip_controls_d_node = `BITMANIP_CTRL_WIDTH'b000_0010_0010_1_1_0_0_1_0_0_0_0_0; 
        17'b0010011_0110000_101: decoded_bitmanip_controls_d_node = `BITMANIP_CTRL_WIDTH'b001_0000_0111_1_1_0_0_1_0_1_0_0_0; 
      endcase
  end
  end else begin : bitmanip_decode_disabled
    
    assign bitmanip_controls_d_node = `BITMANIP_CTRL_WIDTH'b000_00_000_0_0_0_0_0_0_0_0_1;
  end

  
  assign balu_select_d_node = bitmanip_controls_d_node[20:18];
  assign b_select_d_node = bitmanip_controls_d_node[17:14];
  assign zbb_select_d_node = bitmanip_controls_d_node[13:10];
  assign b_reg_write_d = bitmanip_controls_d_node[9];
  assign balu_src_bd = bitmanip_controls_d_node[8];
  assign balu_op_d_node = bitmanip_controls_d_node[5];
  assign b_sub_arith_d = bitmanip_controls_d_node[4];
  assign rotate_d_node = bitmanip_controls_d_node[3];
  assign mask_d_node = bitmanip_controls_d_node[2];
  assign pre_shift_d_node = bitmanip_controls_d_node[1];
  // Select or format the instruction for the next pipeline stage.
  assign illegal_bitmanip_instr_d = bitmanip_controls_d_node[0];

  
  assign balu_control_d_node = {rotate_d_node, mask_d_node, pre_shift_d_node};

  
  assign alu_select_d = balu_op_d_node ? balu_select_d_node : (alu_op_d ? funct3_d_node : 3'b000);

  
  // Register stage data under the supplied clock, reset, and enable controls.
  ffenrc #(12) bitmanip_control_reg_u(clk, reset, kill_e, ~hold_e, {b_select_d_node, zbb_select_d_node, balu_control_d_node, ~illegal_bitmanip_instr_d}, {b_select_e, zbb_select_e, balu_control_e, bitmanip_active_e});
endmodule

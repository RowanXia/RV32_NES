// Decodes instruction fields into ALU, memory, branch, and register-write controls.
// Detects source dependencies and generates forwarding and structural Hold requests.


`include "config.vh"

module pipeline_control    (
  input wire clk,  // Clock used for synchronous state updates.
  input wire reset,  // Resets the local state and pipeline registers.
  
  input wire hold_d,  // Holds the decode-stage instruction and control state.
  input wire kill_d,  // Invalidates decoded work on redirects and pipeline cancellation.
  input wire [31:0] instr_d,  // Decoded-stage instruction word.
  output wire [2:0] imm_src_d,  // Immediate field or immediate selection.
  input wire illegal_instr_d,  // Instruction word, decoded field, or validity qualifier.
  output wire illegal_base_instr_d,  // Instruction word, decoded field, or validity qualifier.
  output wire jump_d,  // Decode-stage jump classification.
  output wire branch_d,  // Identifies a conditional branch in decode.
  output wire structural_hold_d,  // Decode-side dependency or structural hazard request.
  output wire load_hold_d /* synthesis PAP_MARK_DEBUG="true" */,  // Prevents the corresponding pipeline stage from advancing.
  output wire store_hold_d,  // Prevents the corresponding pipeline stage from advancing.
  output wire [4:0] rs1_d,  // First source integer-register index or value.
  output wire [4:0] rs2_d,  // Second source integer-register index or value.
  output wire [4:0] rs2_e,  // Second source integer-register index or value.
  
  input wire hold_e,  // Holds execute-stage operands and control until accepted.
  input wire kill_e,  // Cancels younger execute-stage work or injects a bubble.
  input wire [1:0] flags_e,  // Flags used by the execute-stage datapath or control.
  output wire pc_src_e,  // Resolved execute-stage branch or jump redirection decision.
  output wire alu_src_ae,  // First ALU operand or operand selector.
  output wire alu_src_be,  // Second ALU operand or operand selector.
  output wire alu_result_src_e,  // ALU operation selection, operand, or result.
  output wire [2:0] alu_select_e,  // ALU operation selection, operand, or result.
  output wire [2:0] funct3_e,  // Function-3 used by the execute-stage datapath or control.
  output wire int_div_e,  // Selects integer division/remainder operations in execute.
  output wire sub_arith_e,  // Sub arith used by the execute-stage datapath or control.
  output wire jump_e,  // Execute-stage jump classification.
  output wire branch_e,  // Identifies a conditional branch in the execute stage.
  output wire branch_signed_e,  // Branch signed used by the execute-stage datapath or control.
  output wire [3:0] b_select_e,  // B select used by the execute-stage datapath or control.
  output wire [3:0] zbb_select_e,  // Zbb select used by the execute-stage datapath or control.
  output wire [2:0] balu_control_e,  // Bit-manipulation alu control used by the execute-stage datapath or control.
  output wire bitmanip_active_e,  // Bitmanip active used by the execute-stage datapath or control.
  output wire mul_div_active_e,  // Multiplication division active used by the execute-stage datapath or control.
  output reg [1:0] forward_ae /* synthesis PAP_MARK_DEBUG="true" */,  // Forwarding selection for ALU source operand A.
  output reg [1:0] forward_be /* synthesis PAP_MARK_DEBUG="true" */,  // Forwarding selection for ALU source operand B.
  
  input wire hold_m,  // Holds the memory-stage transaction and state.
  input wire kill_m,  // Invalidates the instruction entering the memory stage.
  output wire [1:0] memory_operation_e /* synthesis PAP_MARK_DEBUG="true" */,  // Load/store memory interface or pipeline control.
  output wire [1:0] memory_operation_m,  // Load/store memory interface or pipeline control.
  output wire csr_read_m,  // Control and status register access or state.
  output wire csr_write_m,  // Control and status register access or state.
  output wire privileged_m,  // Privileged used by the memory-stage datapath or control.
  output wire [2:0] funct3_m,  // Function-3 used by the memory-stage datapath or control.
  output wire invalidate_i_cache_m,  // Cache-side data, address, or operation control.
  output wire kill_d_cache_m,  // Cache-side data, address, or operation control.
  output wire instr_valid_d,  // Instruction word, decoded field, or validity qualifier.
  output wire instr_valid_e,  // Instruction word, decoded field, or validity qualifier.
  output wire instr_valid_m,  // Instruction word, decoded field, or validity qualifier.
  
  input wire hold_w,  // Backpressure condition preventing writeback advancement.
  input wire kill_w,  // Suppresses writeback for invalid or trapped instructions.
  output wire reg_write_w /* synthesis PAP_MARK_DEBUG="true" */,  // Enables writeback to the integer register file.
  output wire int_div_w,  // Interrupt division used by the writeback-stage datapath or control.
  output wire [2:0] result_src_w,  // Result source used by the writeback-stage datapath or control.
  
  output wire csr_write_fence_m,  // Serializes pipeline work around a CSR or fence operation.
  output wire [4:0] rd_e,  // Destination integer-register index.
  output wire [4:0] rd_m,  // Destination integer-register index.
  
  output wire [4:0] rd_w /* synthesis PAP_MARK_DEBUG="true" */  // Destination register index carried into writeback.
);

  wire [4:0] rs1_e_node;                      
  wire [6:0] op_d_node;                             
  wire [2:0] funct3_d_node;                         
  wire [6:0] funct7_d_node;                         
  wire [4:0] rd_d_node;                             

  `define CTRLW 20

  
  wire reg_write_d_node;
  wire reg_write_e_node;           
  wire [2:0] result_src_d_node;
  wire [2:0] result_src_e_node;
  wire [2:0] result_src_m_node; 
  wire [2:0] pre_imm_src_d_node;                     
  wire [1:0] mem_rwd_node;                         
  wire alu_op_d;                         
  wire base_reg_write_d_node;                  
  wire base_sub_arith_d_node;                  
  wire base_alu_src_bd_node;                   
  wire alu_src_ad_node;
  wire alu_src_bd_node;             
  wire alu_result_src_d_node;
  wire mul_div_d_node;            
  wire csr_zero_src_d_node;                    
  wire csr_read_d_node;                       
  wire fence_xd_node;                        
  wire invalidate_i_cache_d_node;
  wire kill_d_cache_d_node;
  wire mem_read_e_node;
  wire csr_read_e_node;             
  wire mul_div_e_node;                           
  wire csr_write_d_node;
  wire csr_write_e_node;           
  wire privileged_d_node;
  wire privileged_e_node;       
  wire invalidate_i_cache_e_node;
  wire kill_d_cache_e_node;
  reg [`CTRLW-1:0] controls_d_node;                
  wire sub_arith_d_node;                      
  wire sub_d_node;
  wire sra_d_node;
  wire slt_d_node;
  wire sltu_d_node;        
  wire branch_taken_e_node;                   
  wire eq_e_node;
  wire lt_e_node;                       
  wire unused_node;
  wire branch_flag_e_node;                    
  wire execute_reg_write_e_node;                   
  wire fence_d_node;
  wire fence_e_node;                 
  wire int_div_m_node;                        
  wire reg_write_m_node;                      
  wire i_funct_d_node;
  wire r_funct_d_node;
  wire m_funct_d_node;      
  wire l_funct_d_node;
  wire s_funct_d_node;
  wire b_funct_d_node;      
  wire jr_funct_d_node;                       
  wire fence_funct_d_node;                    
  wire p_funct_d_node;
  wire csr_funct_d_node;             
  wire fence_m_node;                         
  wire [2:0] pre_alu_select_d_node;                  
  wire [2:0] alu_select_d;                     
  // Source dependency or forwarding selection between in-flight instructions.
  wire match_de_node /* synthesis PAP_MARK_DEBUG="true" */;                        
  wire mul_div_hold_d_node;
  wire csr_rd_hold_d_node;         

  
  assign op_d_node     = instr_d[6:0];
  assign funct3_d_node = instr_d[14:12];
  assign funct7_d_node = instr_d[31:25];
  assign rs1_d    = instr_d[19:15];
  assign rs2_d    = instr_d[24:20];
  assign rd_d_node     = instr_d[11:7];

  
  if (1) begin : legalcheck 
    wire funct7_zero_d_node;
  wire funct7b5_d_node;
  wire i_shift_d_node;
  wire i_no_shift_d_node;
    wire funct7_shift_zero_d_node;
  wire funct7_shiftb5_d_node;

    assign funct7_zero_d_node      = (funct7_d_node == 7'b0000000); 
    assign funct7b5_d_node        = (funct7_d_node == 7'b0100000); 
    assign funct7_shift_zero_d_node = funct7_zero_d_node;
    assign funct7_shiftb5_d_node   = funct7b5_d_node;
    assign i_shift_d_node          = (funct3_d_node == 3'b001 & funct7_shift_zero_d_node) | (funct3_d_node == 3'b101 & (funct7_shift_zero_d_node | funct7_shiftb5_d_node)); 
    assign i_no_shift_d_node        = ((funct3_d_node != 3'b001) & (funct3_d_node != 3'b101));
    assign i_funct_d_node          = i_shift_d_node | i_no_shift_d_node;
    assign r_funct_d_node          = ((funct3_d_node == 3'b000 | funct3_d_node == 3'b101) & funct7b5_d_node) | funct7_zero_d_node;
    assign m_funct_d_node          = (funct7_d_node == 7'b0000001) & (`CFG_M_SUPPORTED | (`CFG_ZMMUL_SUPPORTED & ~funct3_d_node[2])); 
    assign l_funct_d_node          = funct3_d_node == 3'b000 | funct3_d_node == 3'b001 | funct3_d_node == 3'b010 |
                              funct3_d_node == 3'b100 | funct3_d_node == 3'b101;
    assign fence_funct_d_node      = (funct3_d_node == 3'b000) | (`CFG_ZIFENCEI_SUPPORTED & funct3_d_node == 3'b001);
    assign s_funct_d_node          = funct3_d_node == 3'b000 | funct3_d_node == 3'b001 | funct3_d_node == 3'b010;
    assign b_funct_d_node          = funct3_d_node[2:1] != 2'b01; 
    assign jr_funct_d_node         = funct3_d_node == 3'b000;
    assign p_funct_d_node          = funct3_d_node == 3'b000 & rd_d_node == 5'b0;
    assign csr_funct_d_node        = funct3_d_node[1:0] != 2'b00;
  end

  
  /* verilator lint_off CASEINCOMPLETE */
  // Decode instruction controls for each pipeline stage.
  // Combinational control includes operand forwarding and decode-derived decisions.
  // Computes combinational outputs using decoded operation and state selections.
  // Compute the combinational next-state/output decisions from the current control state.
  always @* begin
    controls_d_node = `CTRLW'b0_000_00_00_000_0_0_0_0_0_0_0_0_1; 
    // Select control behavior for the decoded state or operation.
    // Select the datapath operation from the decoded instruction function field.
    case(op_d_node)
    
      7'b0000011: if (l_funct_d_node)
                      controls_d_node = `CTRLW'b1_000_01_10_001_0_0_0_0_0_0_0_0_0; 
      7'b0001111: if (fence_funct_d_node) begin
                    // Select this hardware path from the active configuration.
                    if (`CFG_ZIFENCEI_SUPPORTED)
                      controls_d_node = `CTRLW'b0_000_00_00_000_0_0_0_0_0_0_1_0_0; 
                    else
                      controls_d_node = `CTRLW'b0_000_00_00_000_0_0_0_0_0_0_0_0_0; 
                  end
      7'b0010011: if (i_funct_d_node)
                      controls_d_node = `CTRLW'b1_000_01_00_000_0_1_0_0_0_0_0_0_0; 
      7'b0010111:     controls_d_node = `CTRLW'b1_100_11_00_000_0_0_0_0_0_0_0_0_0; 
      7'b0100011: if (s_funct_d_node)
                      controls_d_node = `CTRLW'b0_001_01_01_000_0_0_0_0_0_0_0_0_0; 
      7'b0110011: if (r_funct_d_node)
                      controls_d_node = `CTRLW'b1_000_00_00_000_0_1_0_0_0_0_0_0_0; 
                  else if (m_funct_d_node)
                      controls_d_node = `CTRLW'b1_000_00_00_011_0_0_0_0_0_0_0_1_0; 
      7'b0110111:     controls_d_node = `CTRLW'b1_100_01_00_000_0_0_0_1_0_0_0_0_0; 
      7'b1100011: if (b_funct_d_node)
                      controls_d_node = `CTRLW'b0_010_11_00_000_1_0_0_0_0_0_0_0_0; 
      7'b1100111: if (jr_funct_d_node)
                      controls_d_node = `CTRLW'b1_000_01_00_000_0_0_1_1_0_0_0_0_0; 
      7'b1101111:     controls_d_node = `CTRLW'b1_011_11_00_000_0_0_1_1_0_0_0_0_0; 
      7'b1110011: if (`CFG_ZICSR_SUPPORTED) begin
                   if (p_funct_d_node)
                      controls_d_node = `CTRLW'b0_000_00_00_000_0_0_0_0_0_1_0_0_0; 
                   else if (csr_funct_d_node)
                      controls_d_node = `CTRLW'b1_000_00_00_010_0_0_0_0_1_0_0_0_0; 
                  end
    endcase
  end
  /* verilator lint_on CASEINCOMPLETE */

  
  // Build the immediate operand for the decoded instruction.
  assign {base_reg_write_d_node, pre_imm_src_d_node, alu_src_ad_node, base_alu_src_bd_node, mem_rwd_node,
          result_src_d_node, branch_d, alu_op_d, jump_d, alu_result_src_d_node, csr_read_d_node,
          privileged_d_node, fence_xd_node, mul_div_d_node, unused_node} = illegal_instr_d ? `CTRLW'b0 : controls_d_node;

  assign csr_zero_src_d_node = instr_d[14] ? (instr_d[19:15] == 0) : (rs1_d == 0); 
  assign csr_write_d_node = csr_read_d_node & !(csr_zero_src_d_node & instr_d[13]);            
  assign fence_d_node = fence_xd_node;

  
  assign sltu_d_node = (funct3_d_node == 3'b011);
  assign sub_d_node = (funct3_d_node == 3'b000 & funct7_d_node[5] & op_d_node[5]);  
  assign sra_d_node = (funct3_d_node == 3'b101 & funct7_d_node[5]);
  assign base_sub_arith_d_node = alu_op_d & (sub_d_node | sra_d_node | slt_d_node | sltu_d_node);

  
  // Select this hardware path from the active configuration.
  if (`CFG_ZBA_SUPPORTED | `CFG_ZBB_SUPPORTED | `CFG_ZBC_SUPPORTED | `CFG_ZBS_SUPPORTED) begin : bitmanipi
    wire illegal_bitmanip_instr_d;          
    wire b_reg_write_d;                     
    wire b_sub_arith_d;                     
    wire balu_src_bd;                      

    bitmanip_control bitmanip_control_i_u(.clk(clk), .reset(reset), .instr_d(instr_d), .alu_op_d(alu_op_d),
      .b_reg_write_d(b_reg_write_d), .balu_src_bd(balu_src_bd), .b_sub_arith_d(b_sub_arith_d), .illegal_bitmanip_instr_d(illegal_bitmanip_instr_d), .hold_e(hold_e), .kill_e(kill_e),
      .alu_select_d(pre_alu_select_d_node), .b_select_e(b_select_e), .zbb_select_e(zbb_select_e), .balu_control_e(balu_control_e), .bitmanip_active_e(bitmanip_active_e));
    // Select this hardware path from the active configuration.
    if (`CFG_ZBA_SUPPORTED) begin
      
      assign slt_d_node = funct3_d_node == 3'b010 & (~funct7_d_node[4] | ~op_d_node[5]);
    end else begin
      assign slt_d_node = funct3_d_node == 3'b010;
    end

    
    // Select or format the instruction for the next pipeline stage.
    assign illegal_base_instr_d = controls_d_node[0] & illegal_bitmanip_instr_d;
    assign reg_write_d_node = base_reg_write_d_node | b_reg_write_d;
    assign alu_src_bd_node = base_alu_src_bd_node | balu_src_bd;
    assign sub_arith_d_node = base_sub_arith_d_node | b_sub_arith_d; 

  end else begin : bitmanipi
    
    
    assign pre_alu_select_d_node = alu_op_d ? funct3_d_node : 3'b000;
    assign slt_d_node = funct3_d_node == 3'b010;
    assign illegal_base_instr_d = controls_d_node[0];
    assign reg_write_d_node = base_reg_write_d_node;
    assign alu_src_bd_node = base_alu_src_bd_node;
    assign sub_arith_d_node = base_sub_arith_d_node;

    assign b_select_e = 4'b0000;
    assign zbb_select_e = 4'b0000;
    assign balu_control_e = 3'b000;
    assign bitmanip_active_e = 1'b0;
  end

  assign alu_select_d = pre_alu_select_d_node;

  
  // Select this hardware path from the active configuration.
  if (`CFG_ZIFENCEI_SUPPORTED & (`CFG_ICACHE_SUPPORTED | `CFG_DCACHE_SUPPORTED)) begin : fencei
    wire fence_id_node;
    assign fence_id_node = fence_xd_node & (funct3_d_node == 3'b001); 
    assign invalidate_i_cache_d_node = fence_id_node;
    assign kill_d_cache_d_node = fence_id_node;
  end else begin : fencei
    assign invalidate_i_cache_d_node = 1'b0;
    assign kill_d_cache_d_node = 1'b0;
  end

  assign imm_src_d = pre_imm_src_d_node;

  
  // Register stage data under the supplied clock, reset, and enable controls.
  ffenrc #(1)  controlreg_d_u(clk, reset, kill_d, ~hold_d, 1'b1, instr_valid_d);

  
  // Register stage data under the supplied clock, reset, and enable controls.
  ffenrc #(26) controlreg_e_u(clk, reset, kill_e, ~hold_e,
                           {alu_select_d, reg_write_d_node, result_src_d_node, mem_rwd_node, jump_d, branch_d, alu_src_ad_node, alu_src_bd_node, alu_result_src_d_node, csr_read_d_node, csr_write_d_node, privileged_d_node, funct3_d_node, sub_arith_d_node, mul_div_d_node, invalidate_i_cache_d_node, kill_d_cache_d_node, fence_d_node, instr_valid_d},
                           {alu_select_e, execute_reg_write_e_node, result_src_e_node, memory_operation_e, jump_e, branch_e, alu_src_ae, alu_src_be, alu_result_src_e, csr_read_e_node, csr_write_e_node, privileged_e_node, funct3_e, sub_arith_e, mul_div_e_node, invalidate_i_cache_e_node, kill_d_cache_e_node, fence_e_node, instr_valid_e});
  // Register stage data under the supplied clock, reset, and enable controls.
  ffenrc #(5)  rs1_e_reg_u(clk, reset, kill_e, ~hold_e, rs1_d, rs1_e_node);
  // Register stage data under the supplied clock, reset, and enable controls.
  ffenrc #(5)  rs2_e_reg_u(clk, reset, kill_e, ~hold_e, rs2_d, rs2_e);
  // Register stage data under the supplied clock, reset, and enable controls.
  ffenrc #(5)  rd_e_reg_u(clk, reset, kill_e, ~hold_e, rd_d_node, rd_e);

  
  // Combine prediction metadata with resolved branch control.
  assign branch_signed_e = (~(funct3_e[2:1] == 2'b11) & branch_e);
  assign {eq_e_node, lt_e_node} = flags_e;
  // Select the appropriate datapath value from the available inputs.
  mux2 #(1) branchflagmux_u(eq_e_node, lt_e_node, funct3_e[2], branch_flag_e_node);
  assign branch_taken_e_node = branch_flag_e_node ^ funct3_e[0];
  // Branch comparison and jump controls determine execute-stage redirection.
  assign pc_src_e = jump_e | branch_e & branch_taken_e_node;

  
  assign mem_read_e_node = memory_operation_e[1];
  assign mul_div_active_e = (result_src_e_node == 3'b011);
  assign reg_write_e_node = execute_reg_write_e_node;
  assign int_div_e = mul_div_e_node & funct3_e[2]; 

  
  // Register stage data under the supplied clock, reset, and enable controls.
  ffenrc #(17) controlreg_m_u(clk, reset, kill_m, ~hold_m,
                         {reg_write_e_node, result_src_e_node, memory_operation_e, csr_read_e_node, csr_write_e_node, privileged_e_node, funct3_e, invalidate_i_cache_e_node, kill_d_cache_e_node, fence_e_node, instr_valid_e, int_div_e},
                         {reg_write_m_node, result_src_m_node, memory_operation_m, csr_read_m, csr_write_m, privileged_m, funct3_m, invalidate_i_cache_m, kill_d_cache_m, fence_m_node, instr_valid_m, int_div_m_node});
  // Register stage data under the supplied clock, reset, and enable controls.
  ffenrc #(5)  rd_m_reg_u(clk, reset, kill_m, ~hold_m, rd_e, rd_m);

  
  // Register stage data under the supplied clock, reset, and enable controls.
  ffenrc #(5) controlreg_w_u(clk, reset, kill_w, ~hold_w,
                         {reg_write_m_node, result_src_m_node, int_div_m_node},
                         {reg_write_w, result_src_w, int_div_w});
  // Register stage data under the supplied clock, reset, and enable controls.
  ffenrc #(5) rd_w_reg_u(clk, reset, kill_w, ~hold_w, rd_m, rd_w);

  
  assign csr_write_fence_m = csr_write_m | fence_m_node;

  
  // Compute combinational control and data selections.
  // Decode instruction fields into stage control signals and hazard qualifications.
  always @* begin
    forward_ae = 2'b00;
    forward_be = 2'b00;
    if (rs1_e_node != 5'b0)
      if      ((rs1_e_node == rd_m) & reg_write_m_node) forward_ae = 2'b10;
      else if ((rs1_e_node == rd_w) & reg_write_w) forward_ae = 2'b01;

    if (rs2_e != 5'b0)
      if      ((rs2_e == rd_m) & reg_write_m_node) forward_be = 2'b10;
      else if ((rs2_e == rd_w) & reg_write_w) forward_be = 2'b01;
  end

  
  assign match_de_node = ((rs1_d == rd_e) | (rs2_d == rd_e)) & (rd_e != 5'b0); 
  // Detect a load-use dependency before the consumer executes.
  // Load-use detection compares decode source registers against an unfinished load.
  // A decode dependency stalls when an older load has not yet produced its result.
  // Generate decode-side dependency and structural Hold conditions.
  assign load_hold_d = mem_read_e_node & match_de_node;
  assign store_hold_d = mem_rwd_node[1] & memory_operation_e[0];   
  assign csr_rd_hold_d_node = csr_read_e_node & match_de_node;
  assign mul_div_hold_d_node = mul_div_e_node & match_de_node; 
  assign structural_hold_d = load_hold_d | store_hold_d | csr_rd_hold_d_node | mul_div_hold_d_node;
endmodule

// Expands supported compressed instruction encodings into standard instruction forms.
// Reports unsupported or illegal compressed encodings.


`include "config.vh"

module compressed_decode    (
  input wire [31:0] instr_raw_d,  // Instruction word, decoded field, or validity qualifier.
  output wire [31:0] instr_d,  // Decoded-stage instruction word.
  output wire illegal_comp_instr_d  // Instruction word, decoded field, or validity qualifier.
);

  reg [32:0] l_instr_d_node; 
  wire [15:0] instr16_node;
  wire [4:0] rds1_node;
  wire [4:0] rs2_node;
  wire [4:0] rs1p_node;
  wire [4:0] rs2p_node;
  wire [4:0] rds1p_node;
  wire [4:0] rdp_node;
  wire [11:0] imm_cilsp_node;
  wire [11:0] imm_css_node;
  wire [11:0] imm_cl_node;
  wire [11:0] imm_ci_node;
  wire [11:0] imm_cs_node;
  wire [11:0] imm_cb_node;
  wire [11:0] imm_ciasp_node;
  wire [11:0] imm_ciw_node;
  wire [19:0] imm_cj_node;
  wire [19:0] imm_cilui_node;
  wire [5:0] imm_sh_node;
  wire [1:0] op_node;
  wire legal_comp_instr_d_node;

  
  assign instr16_node = instr_raw_d[15:0]; 
  assign op_node = instr16_node[1:0];
  assign rds1_node = instr16_node[11:7];
  assign rs2_node = instr16_node[6:2];
  assign rs1p_node = {2'b01, instr16_node[9:7]};
  assign rds1p_node = {2'b01, instr16_node[9:7]};
  assign rs2p_node = {2'b01, instr16_node[4:2]};
  assign rdp_node = {2'b01, instr16_node[4:2]};

  
  // Build the immediate operand for the decoded instruction.
  assign imm_cilsp_node = {4'b0000, instr16_node[3:2], instr16_node[12], instr16_node[6:4], 2'b00};
  assign imm_css_node = {4'b0000, instr16_node[8:7], instr16_node[12:9], 2'b00};
  assign imm_cl_node = {5'b0, instr16_node[5], instr16_node[12:10], instr16_node[6], 2'b00};
  assign imm_cs_node = {5'b0, instr16_node[5], instr16_node[12:10], instr16_node[6], 2'b00};
  assign imm_cj_node = {instr16_node[12], instr16_node[8], instr16_node[10:9], instr16_node[6], instr16_node[7], instr16_node[2], instr16_node[11], instr16_node[5:3], {9{instr16_node[12]}}};
  assign imm_cb_node = {{4{instr16_node[12]}}, instr16_node[6:5], instr16_node[2], instr16_node[11:10], instr16_node[4:3], instr16_node[12]};
  assign imm_ci_node = {{7{instr16_node[12]}}, instr16_node[6:2]};
  assign imm_cilui_node = {{15{instr16_node[12]}}, instr16_node[6:2]};                                                    
  assign imm_ciasp_node = {{3{instr16_node[12]}}, instr16_node[4:3], instr16_node[5], instr16_node[2], instr16_node[6], 4'b0000};        
  assign imm_ciw_node = {2'b00, instr16_node[10:7], instr16_node[12:11], instr16_node[5], instr16_node[6], 2'b00};
  assign imm_sh_node = {instr16_node[12], instr16_node[6:2]};                                                             


  // Compute combinational control and data selections.
  // Compute the combinational next-state/output decisions from the current control state.
  always @*
    if (op_node == 2'b11) begin 
      l_instr_d_node = {1'b1, instr_raw_d};
    end else begin  
      l_instr_d_node = {1'b0, 16'b0, instr16_node}; 
      // Select the datapath operation from the decoded instruction function field.
      case ({op_node, instr16_node[15:13]})
        5'b00000: if (imm_ciw_node != 0)                      l_instr_d_node = {1'b1, imm_ciw_node, 5'b00010, 3'b000, rdp_node, 7'b0010011};                      
        5'b00010:                                       l_instr_d_node = {1'b1, imm_cl_node, rs1p_node, 3'b010, rdp_node, 7'b0000011};                           
        5'b00110:                                       l_instr_d_node = {1'b1, imm_cs_node[11:5], rs2p_node, rs1p_node, 3'b010, imm_cs_node[4:0], 7'b0100011};        
        5'b01000: if (rds1_node != 5'b0)
                    if (imm_ci_node[5:0] != 0)                l_instr_d_node = {1'b1, imm_ci_node, rds1_node, 3'b000, rds1_node, 7'b0010011};                          
                    else                                l_instr_d_node = {1'b1, 25'b0, 7'b0010011};                                              
                  else if (imm_ci_node[5:0] == 6'b0)          l_instr_d_node = {1'b1, 25'b0, 7'b0010011};                                              
                  else                                  l_instr_d_node = {1'b1, 25'b0, 7'b0010011};                                              
        5'b01001:                                       l_instr_d_node = {1'b1, imm_cj_node, 5'b00001, 7'b1101111};                                  
        5'b01010: if (rds1_node != 5'b0)                     l_instr_d_node = {1'b1, imm_ci_node, 5'b00000, 3'b000, rds1_node, 7'b0010011};                      
                  else                                  l_instr_d_node = {1'b1, 25'b0, 7'b0010011};                                              
        5'b01011: if (rds1_node == 5'b00010) begin
                     if (imm_ciasp_node[9:4] != 6'b0)         l_instr_d_node = {1'b1, imm_ciasp_node, rds1_node, 3'b000, rds1_node, 7'b0010011};                       
                  end else if (imm_cilui_node[5:0] != 0)
                    if (rds1_node != 5'b0)                   l_instr_d_node = {1'b1, imm_cilui_node, rds1_node, 7'b0110111};                                     
                    else                                l_instr_d_node = {1'b1, 25'b0, 7'b0010011};                                              
        5'b01100: if (instr16_node[11:10] == 2'b00) begin
                    if (~imm_sh_node[5])                       l_instr_d_node = {1'b1, 6'b000000, imm_sh_node, rds1p_node, 3'b101, rds1p_node, 7'b0010011};             
                  end else if (instr16_node[11:10] == 2'b01) begin
                    if (~imm_sh_node[5])                       l_instr_d_node = {1'b1, 6'b010000, imm_sh_node, rds1p_node, 3'b101, rds1p_node, 7'b0010011};             
                  end else if (instr16_node[11:10] == 2'b10) l_instr_d_node = {1'b1, imm_ci_node, rds1p_node, 3'b111, rds1p_node, 7'b0010011};                        
                  else if (instr16_node[12:10] == 3'b011) begin
                    if (instr16_node[6:5] == 2'b00)          l_instr_d_node = {1'b1, 7'b0100000, rs2p_node, rds1p_node, 3'b000, rds1p_node, 7'b0110011};             
                    else if (instr16_node[6:5] == 2'b01)     l_instr_d_node = {1'b1, 7'b0000000, rs2p_node, rds1p_node, 3'b100, rds1p_node, 7'b0110011};             
                    else if (instr16_node[6:5] == 2'b10)     l_instr_d_node = {1'b1, 7'b0000000, rs2p_node, rds1p_node, 3'b110, rds1p_node, 7'b0110011};             
                    else                                l_instr_d_node = {1'b1, 7'b0000000, rs2p_node, rds1p_node, 3'b111, rds1p_node, 7'b0110011};             
                  end
        5'b01101:                                       l_instr_d_node = {1'b1, imm_cj_node, 5'b00000, 7'b1101111}; 
        5'b01110:                                       l_instr_d_node = {1'b1, imm_cb_node[11:5], 5'b00000, rs1p_node, 3'b000, imm_cb_node[4:0], 7'b1100011};    
        5'b01111:                                       l_instr_d_node = {1'b1, imm_cb_node[11:5], 5'b00000, rs1p_node, 3'b001, imm_cb_node[4:0], 7'b1100011};    
        5'b10000: if (imm_sh_node != 0) begin
                    if (~imm_sh_node[5]) begin                                                                                    
                      if (rds1_node != 5'b0)                 l_instr_d_node = {1'b1, 6'b000000, imm_sh_node, rds1_node, 3'b001, rds1_node, 7'b0010011};               
                      else                              l_instr_d_node = {1'b1, 25'b0, 7'b0010011};                                              
                    end
                  end else                              l_instr_d_node = {1'b1, 25'b0, 7'b0010011};                                              
        5'b10010: if (rds1_node != 5'b0)                     l_instr_d_node = {1'b1, imm_cilsp_node, 5'b00010, 3'b010, rds1_node, 7'b0000011};                   
        5'b10100: if (instr16_node[12] == 0)
                    if (rs2_node == 5'b00000) begin
                      if (rds1_node != 5'b0)                 l_instr_d_node = {1'b1, 7'b0000000, 5'b00000, rds1_node, 3'b000, 5'b00000, 7'b1100111};       
                    end else
                      if (rds1_node != 5'b0)                 l_instr_d_node = {1'b1, 7'b0000000, rs2_node, 5'b00000, 3'b000, rds1_node, 7'b0110011};            
                      else                              l_instr_d_node = {1'b1, 25'b0, 7'b0010011};                                              
                  else
                    if (rs2_node == 5'b00000) begin
                      if (rds1_node == 5'b00000)             l_instr_d_node = {1'b1, 12'b1, 5'b00000, 3'b000, 5'b00000, 7'b1110011};                  
                      else                              l_instr_d_node = {1'b1, 12'b0, rds1_node, 3'b000, 5'b00001, 7'b1100111};                      
                    end else
                      if (rds1_node != 0)                    l_instr_d_node = {1'b1, 7'b0000000, rs2_node, rds1_node, 3'b000, rds1_node, 7'b0110011};                
                      else                              l_instr_d_node = {1'b1, 25'b0, 7'b0010011};                                              
        5'b10110:                                       l_instr_d_node = {1'b1, imm_css_node[11:5], rs2_node, 5'b00010, 3'b010, imm_css_node[4:0], 7'b0100011};   
        default: ; 
      endcase
    end

  
  // Select or format the instruction for the next pipeline stage.
  assign {legal_comp_instr_d_node, instr_d} = l_instr_d_node;
  assign illegal_comp_instr_d = ~legal_comp_instr_d_node;

endmodule

// Provides a multi-port memory abstraction with byte write enables.
// Supports simultaneous read and qualified write access.


module ram2p1r1wbe  #(parameter USE_SRAM=0, DEPTH=1024, WIDTH=68) (
  input wire clk,  // Clock used for synchronous state updates.
  input wire ce1,  // Provides ce1 for this module.
  input wire ce2,  // Provides ce2 for this module.
  input wire [$clog2(DEPTH)-1:0] ra1,  // Provides ra1 for this module.
  input wire [WIDTH-1:0] wd2,  // Provides wd2 for this module.
  input wire [$clog2(DEPTH)-1:0] wa2,  // Provides wa2 for this module.
  input wire we2,  // Provides we2 for this module.
  input wire [(WIDTH-1)/8:0] bwe2,  // Provides bwe2 for this module.
  output wire [WIDTH-1:0] rd1  // Provides rd1 for this module.
);

  
  if ((USE_SRAM == 1) & (WIDTH == 68) & (DEPTH == 1024)) begin

    wire [WIDTH-1:0] bit_write_mask_node;
    genvar index;
    // Apply the same combinational operation to each configured element.
    for (index = 0; index < WIDTH; index = index + 1)
      assign bit_write_mask_node[index] = bwe2[index/8];
    
    ram2p1r1wbe_1024x68 memory1(.CLKA(clk), .CLKB(clk),
      .CEBA(~ce1), .CEBB(~ce2),
      .WEBA(1'b1), .WEBB(~we2),
      .AA(ra1), .AB(wa2),
      .DA(1'b0),
      .DB(wd2),
      .BWEBA({WIDTH{1'b1}}), .BWEBB(~bit_write_mask_node),
      .QA(rd1),
      .QB());

  end else if ((USE_SRAM == 1) & (WIDTH == 36) & (DEPTH == 1024)) begin

    wire [WIDTH-1:0] bit_write_mask_node;
    genvar index;
    // Apply the same combinational operation to each configured element.
    for (index = 0; index < WIDTH; index = index + 1)
      assign bit_write_mask_node[index] = bwe2[index/8];
    
    ram2p1r1wbe_1024x36 memory1(.CLKA(clk), .CLKB(clk),
      .CEBA(~ce1), .CEBB(~ce2),
      .WEBA(1'b1), .WEBB(~we2),
      .AA(ra1), .AB(wa2),
      .DA(1'b0),
      .DB(wd2),
      .BWEBA({WIDTH{1'b1}}), .BWEBB(~bit_write_mask_node),
      .QA(rd1),
      .QB());

  end else if ((USE_SRAM == 1) & (WIDTH == 2) & (DEPTH == 1024)) begin

    
    localparam sramwidth_node = 32;
    localparam sramnumsets_node = sramwidth_node/WIDTH;
    wire [sramwidth_node-1:0] sram_read_data_node;
    wire [sramwidth_node-1:0] sram_write_data_node;
    wire [sramwidth_node-1:0] rd1_sets_node[sramnumsets_node-1:0];
    wire [sramnumsets_node-1:0] sram_bit_mask_pre_node;
    wire [sramwidth_node-1:0] sram_bit_mask_node;
    wire [$clog2(DEPTH)-1:0] ra1_q_node;

    onehotdecoder #($clog2(sramnumsets_node)) oh1(wa2[$clog2(sramnumsets_node)-1:0], sram_bit_mask_pre_node);
    genvar                    index;
    // Apply the same combinational operation to each configured element.
    for (index = 0; index < sramnumsets_node; index = index + 1) begin : readdatalinesetsmux
      assign rd1_sets_node[index] = sram_read_data_node[(index*WIDTH)+WIDTH-1 : (index*WIDTH)];
      assign sram_write_data_node[index*WIDTH +: WIDTH] = wd2;
      assign sram_bit_mask_node[index*WIDTH +: WIDTH] = {WIDTH{sram_bit_mask_pre_node[index] & bwe2[0]}};
    end
    // Register stage data under the supplied clock, reset, and enable controls.
    ffen #($clog2(DEPTH)) mem_reg1_u (clk, ce1, ra1, ra1_q_node);
    assign rd1 = rd1_sets_node[ra1_q_node[$clog2(sramnumsets_node)-1:0]];
    ram2p1r1wbe_64x32 memory2(.CLKA(clk), .CLKB(clk),
      .CEBA(~ce1), .CEBB(~ce2),
      .WEBA(1'b1), .WEBB(~we2),
      .AA(ra1[$clog2(DEPTH)-1:$clog2(sramnumsets_node)]),
      .AB(wa2[$clog2(DEPTH)-1:$clog2(sramnumsets_node)]),
      .DA(1'b0),
      .DB(sram_write_data_node),
      .BWEBA({sramwidth_node{1'b1}}), .BWEBB(~sram_bit_mask_node),
      .QA(sram_read_data_node),
      .QB());

  end else begin : ram_u

    
    reg [WIDTH-1:0] ram_node [DEPTH-1:0];

  
  function [WIDTH-1:0] RAM_two_state;
    input [WIDTH-1:0] value;  // Integer argument used to calculate the local logarithm.
    integer n_node;
    begin
      // Apply the same combinational operation to each configured element.
      for (n_node = 0; n_node < WIDTH; n_node = n_node + 1)
        RAM_two_state[n_node] = (value[n_node] === 1'b1);
    end
  endfunction
  wire [WIDTH-1:0] ram_write_clean_node;
  assign ram_write_clean_node = RAM_two_state(wd2);
  
  integer init_ram_index_node;
  initial begin
    // Apply the same combinational operation to each configured element.
    for (init_ram_index_node = 0; init_ram_index_node <= (DEPTH-1); init_ram_index_node = init_ram_index_node + 1)
      ram_node[init_ram_index_node] = {(WIDTH-1)+1{1'b0}};
  end


    wire [$clog2(DEPTH)-1:0] ra1d_node;
    // Register stage data under the supplied clock, reset, and enable controls.
    ffen #($clog2(DEPTH)) adrreg_u(clk, ce1, ra1, ra1d_node);
    assign rd1 = RAM_two_state(ram_node[ra1d_node]);

    
    // coverage off
    
    if(WIDTH >= 8) begin
      integer i_node;
      // Update registered memory and request state on the clock edge.
      // Update sequential state on the active clock edge, respecting reset and enables.
      always @(posedge clk)
        if (ce2 & we2)
          // Apply the same combinational operation to each configured element.
          for(i_node = 0; i_node < WIDTH/8; i_node = i_node + 1)
            if(bwe2[i_node]) ram_node[wa2][i_node*8 +: 8] <= ram_write_clean_node[i_node*8 +: 8];
    end
    // coverage on

    if (WIDTH%8 != 0) 
      // Updates sequential state on the specified clock event.
      // Update sequential state on the active clock edge, respecting reset and enables.
      always @(posedge clk)
        if (ce2 & we2 & bwe2[WIDTH/8])
          ram_node[wa2][WIDTH-1:WIDTH-WIDTH%8] <= ram_write_clean_node[WIDTH-1:WIDTH-WIDTH%8];
  end

endmodule

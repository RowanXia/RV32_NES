// Implements one cache way, including tag and data storage.
// Checks tag validity and manages dirty state during writes and refills.


`include "config.vh"


module cache_way  #(parameter NUMSETS=512, linelen_node = 256, taglen_node = 26,
                  offsetlen_node = 5, INDEXLEN = 9, READ_ONLY_CACHE = 0) (
  input wire clk,  // Clock used for synchronous state updates.
  input wire reset,  // Resets the local state and pipeline registers.
  input wire kill_stage,  // Cancels invalid or wrong-path pipeline work.
  input wire invalidate_kill_stage,  // Suppresses invalidation when the associated operation is cancelled.
  input wire cache_en,  // Enables a cache lookup or replacement-state access.
  input wire [$clog2(NUMSETS)-1:0] cache_set_data,  // Cache-side data, address, or operation control.
  input wire [$clog2(NUMSETS)-1:0] cache_set_tag,  // Cache-side data, address, or operation control.
  input wire [$clog2(NUMSETS)-1:0] cache_set_dirty,  // Cache-side data, address, or operation control.
  input wire [1:0] cache_word_data,  // Cache-side data, address, or operation control.
  input wire [31:0] p_adr,  // Set index used for replacement metadata updates.
  input wire [31:0] write_data,  // Data value to be written to the target.
  input wire [3:0] byte_mask,  // Active byte lanes for a memory write.
  input wire refill_write_en,  // Enables writing the fetched line into the cache.
  input wire [1:0] refill_word,  // Provides refill word for this module.
  input wire [31:0] refill_data,  // Data supplied from a cache-line refill transaction.
  input wire set_valid,  // Selects a newly valid way instead of the hit way.
  input wire clear_valid,  // Clears the valid state of the selected cache line.
  input wire set_dirty,  // Marks the selected cache line as modified.
  input wire sel_victim,  // Replacement way selected for a cache miss.
  input wire clear_dirty,  // Clears the dirty state after refill or writeback.
  input wire kill_cache,  // Cache-side data, address, or operation control.
  input wire victim_way,  // One-hot cache way selected for replacement.
  input wire kill_way,  // Cancels invalid or wrong-path pipeline work.
  input wire invalidate_cache,  // Requests invalidation of cache state.
  output wire [31:0] read_data_word_way,  // Data returned by the selected source.
  output wire hit_way,  // One-hot cache-way hit indicators.
  output reg valid_way,  // Validity bits for the ways in the selected cache set.
  output wire hit_dirty_way,  // Cache hit indication or hit-way selection.
  output wire dirty_way   ,  // Provides dirty way for this module.
  output wire [taglen_node-1:0] tag_way);  // Provides tag way for this module.

  reg [NUMSETS-1:0] valid_bits_node;
  reg [NUMSETS-1:0] dirty_bits_node;
  wire [31:0] read_data_word;
  wire [taglen_node-1:0] read_tag_node;
  wire dirty_node;
  wire selected_dirty_victim_node;
  wire selected_write_word_en_node;
  wire [8:0] data_read_addr_node;
  wire [8:0] data_write_addr_node;
  wire [31:0] data_write_data_node;
  wire [3:0] data_write_mask_node;
  wire data_write_en_node;
  wire set_valid_en_node;
  wire clear_valid_en_node;
  wire set_valid_way_node;
  wire clear_valid_way_node;
  wire set_dirty_way_node;
  wire clear_dirty_way_node;
  wire selected_way_node;
  wire invalidate_cache_delay_node;

  if (!READ_ONLY_CACHE) begin : flushlogic
    // Select the appropriate datapath value from the available inputs.
    mux2 #(1) seltagmux_u(victim_way, kill_way, kill_cache, selected_dirty_victim_node);
    // Select the appropriate datapath value from the available inputs.
    mux3 #(1) selectedmux_u(hit_way, kill_way, victim_way, {sel_victim, kill_cache}, selected_way_node);
    
    // coverage off -item e 1 -fecexprrow 3
    
  end else begin : flushlogic 
    assign selected_dirty_victim_node = victim_way;
  // Select the appropriate datapath value from the available inputs.
  mux2 #(1) selectedwaymux_u(hit_way, selected_dirty_victim_node, sel_victim , selected_way_node);
  end


  assign set_valid_way_node = set_valid & selected_way_node;
  assign clear_valid_way_node = clear_valid & selected_way_node;                             // exclusion-tag: icache clear_valid_way_node
  assign set_dirty_way_node = set_dirty & selected_way_node;                                 // exclusion-tag: icache set_dirty_way_node
  assign clear_dirty_way_node = clear_dirty & selected_way_node;
  
  
  assign selected_write_word_en_node = set_dirty_way_node & ~kill_stage;
  assign set_valid_en_node = set_valid_way_node & ~kill_stage;                           // exclusion-tag: cache set_valid_en_node
  assign clear_valid_en_node = clear_valid_way_node & ~kill_stage;                       // exclusion-tag: cache clear_valid_en_node

  
  // Provide the backing memory used by this datapath or prediction table.
  cache_tag_lutram_array #(.DEPTH(NUMSETS), .WIDTH(taglen_node)) cache_tag_mem_u(.clk(clk), .ce(cache_en),
    .addr(cache_set_tag), .array_read_data(read_tag_node),
    .array_write_data(p_adr[31:offsetlen_node+INDEXLEN]), .we(set_valid_en_node));

  
  assign tag_way = selected_way_node ? read_tag_node : 0; 
  // Compare the selected line tag and valid state.
  assign hit_dirty_way = dirty_node & valid_way;
  assign dirty_way = selected_dirty_victim_node & hit_dirty_way;                               // exclusion-tag: icache dirty_way
  // Identify the matching cache way.
  assign hit_way = valid_way & (read_tag_node == p_adr[31:offsetlen_node+INDEXLEN]) & ~invalidate_cache_delay_node; // exclusion-tag: dcache hit_way

  // Register validity metadata for the corresponding stage.
  ffenrc #(1) invalidate_cache_reg_u(clk, 1'b0, invalidate_kill_stage, 1'b1, invalidate_cache, invalidate_cache_delay_node);

  
  // Select the address associated with the active request.
  assign data_read_addr_node  = {cache_set_data, cache_word_data};
  assign data_write_addr_node = refill_write_en ? {cache_set_data, refill_word}
                                       : {cache_set_data, cache_word_data};
  assign data_write_data_node = refill_write_en ? refill_data : write_data;
  assign data_write_mask_node = refill_write_en ? 4'b1111 : byte_mask;
  assign data_write_en_node   = (refill_write_en & victim_way & ~kill_stage) |
                         selected_write_word_en_node;

  // Map a 512-word memory array onto an FPGA RAM primitive.
  pango_drm18k_512x32_sdp cache_data_mem_u(
    .clk(clk), .rd_ce(cache_en), .rd_addr(data_read_addr_node), .rd_data(read_data_word),
    .wr_ce(1'b1), .wr_addr(data_write_addr_node), .wr_data(data_write_data_node),
    .wr_strb(data_write_mask_node), .wr_en(data_write_en_node));

  
  assign read_data_word_way = selected_way_node ? read_data_word : 1'b0;  

  
  // Update cache-array metadata on the active clock edge.
  // Updates sequential state on the specified clock event.
  // Update validity state on the active clock edge with reset and enable priority.
  always @(posedge clk) begin 
    if (reset) valid_bits_node        <= 1'b0;
    if (cache_en) begin
      valid_way <= valid_bits_node[cache_set_tag];
      if(invalidate_cache & ~invalidate_kill_stage)    valid_bits_node <= 1'b0; // exclusion-tag: dcache invalidateway
      else if (set_valid_en_node) valid_bits_node[cache_set_data] <= set_valid_way_node;
      else if (clear_valid_en_node) valid_bits_node[cache_set_data] <= 1'b0; // exclusion-tag: icache ClearValidBits
    end
  end

  
  if (!READ_ONLY_CACHE) begin : dirtyarray
    reg dirty_q_node;
    assign dirty_node = dirty_q_node;
    // Update registered memory and request state on the clock edge.
    // Clock the dirty_q, dirty_q state under the specified reset and enable conditions.
    always @(posedge clk) begin
      
      
      if (cache_en) begin
        dirty_q_node <= dirty_bits_node[cache_set_tag];
        if (set_dirty_way_node & ~kill_stage) begin
          dirty_bits_node[cache_set_data] <= 1'b1; // exclusion-tag: cache UpdateDirty
          if (cache_set_data == cache_set_tag) dirty_q_node <= 1'b1;
          else dirty_q_node <= dirty_bits_node[cache_set_tag];
        end else if (clear_dirty_way_node & ~kill_stage) begin
          dirty_bits_node[cache_set_dirty] <= 1'b0;
          if (cache_set_dirty == cache_set_tag) dirty_q_node <= 1'b0;
          else dirty_q_node <= dirty_bits_node[cache_set_tag];
        end
      end
    end
  end else assign dirty_node = 1'b0;
endmodule


module cache_tag_lutram_array #(parameter DEPTH=128, WIDTH=21) (
  input wire clk,  // Clock used for synchronous state updates.
  input wire ce,  // Provides ce for this module.
  input wire [$clog2(DEPTH)-1:0] addr,  // Address operand or target address selection.
  input wire [WIDTH-1:0] array_write_data,  // Data value to be written to the target.
  input wire we,  // Provides we for this module.
  output wire [WIDTH-1:0] array_read_data  // Data returned by the selected source.
);
  reg [$clog2(DEPTH)-1:0] read_addr_q_node;

  // Updates sequential state on the specified clock event.
  // Clock the read_addr_q state under the specified reset and enable conditions.
  always @(posedge clk)
    if (ce) read_addr_q_node <= addr;

`ifndef QUESTA_WINDOWS
  if (DEPTH == 128) begin : pango_lutram
    genvar bit_index_node;
    // Apply the same combinational operation to each configured element.
    for (bit_index_node = 0; bit_index_node < WIDTH; bit_index_node = bit_index_node + 1) begin : tag_bit
      GTP_RAM128X1DP tag_ram (
        .DO(array_read_data[bit_index_node]), .DI(array_write_data[bit_index_node]),
        .RADDR(read_addr_q_node[6:0]), .WADDR(addr[6:0]),
        .WCLK(clk), .WE(ce & we));
    end
  end else begin : unsupported_depth
    initial begin
      $display("ERROR: cache_tag_lutram_array requires DEPTH=128 for Pango mapping");
      $finish;
    end
    assign array_read_data = 1'b0;
  end
`else
  reg [WIDTH-1:0] entry_q_node [DEPTH-1:0];

  
  function [WIDTH-1:0] entry_q_two_state;
    input [WIDTH-1:0] value;  // Integer argument used to calculate the local logarithm.
    integer n_node;
    begin
      // Apply the same combinational operation to each configured element.
      for (n_node = 0; n_node < WIDTH; n_node = n_node + 1)
        entry_q_two_state[n_node] = (value[n_node] === 1'b1);
    end
  endfunction
  wire [WIDTH-1:0] entry_q_write_clean_node;
  assign entry_q_write_clean_node = entry_q_two_state(array_write_data);
  
  integer init_entry_q_index_node;
  initial begin
    // Apply the same combinational operation to each configured element.
    for (init_entry_q_index_node = 0; init_entry_q_index_node <= (DEPTH-1); init_entry_q_index_node = init_entry_q_index_node + 1)
      entry_q_node[init_entry_q_index_node] = {(WIDTH-1)+1{1'b0}};
  end

  // Update sequential state on the active clock edge, respecting reset and enables.
  always @(posedge clk)
    if (ce & we) entry_q_node[addr] <= entry_q_write_clean_node;
  assign array_read_data = entry_q_two_state(entry_q_node[read_addr_q_node]);
`endif
endmodule

// Tracks recent way usage and chooses a replacement candidate.
// Updates replacement state on qualified cache accesses.


module cache_plru
  #(parameter NUMWAYS = 4, setlen_node = 9, NUMSETS = 128) (
  input wire clk,  // Clock used for synchronous state updates.
  input wire reset,  // Resets the local state and pipeline registers.
  input wire invalidate_kill_stage,  // Suppresses invalidation when the associated operation is cancelled.
  input wire cache_en,  // Enables a cache lookup or replacement-state access.
  input wire [NUMWAYS-1:0] hit_way,  // One-hot cache-way hit indicators.
  input wire [NUMWAYS-1:0] valid_way,  // Validity bits for the ways in the selected cache set.
  input wire [setlen_node-1:0] cache_set_lru,  // Set index used to read replacement metadata.
  input wire [setlen_node-1:0] p_adr,  // Set index used for replacement metadata updates.
  input wire lru_write_en,  // Enables a replacement-state update for the selected set.
  input wire set_valid,  // Selects a newly valid way instead of the hit way.
  input wire invalidate_cache,  // Requests invalidation of cache state.
  output wire [NUMWAYS-1:0] victim_way  // One-hot cache way selected for replacement.
);

  localparam                           lognumways_node = $clog2(NUMWAYS);

  reg [NUMWAYS-2:0] lru_memory_node [NUMSETS-1:0];
  wire [NUMWAYS-2:0] curr_lru_node;
  wire [NUMWAYS-2:0] next_lru_node;
  wire [NUMWAYS-2:0] read_lru_node;
  wire [NUMWAYS-2:0] bypassed_lru_node;
  wire [lognumways_node-1:0] hit_way_encoded_node;
  wire [lognumways_node-1:0] way_node;
  wire [NUMWAYS-2:0] way_expanded_node;
  wire all_valid_node;
  wire forward_lru_node;

  genvar                               row;

  /* verilator lint_off UNOPTFLAT */
  
  wire [NUMWAYS-2:0] lru_update_node;
  wire [lognumways_node-1:0] intermediate_node [NUMWAYS-2:0];
  /* verilator lint_on UNOPTFLAT */

  wire [NUMWAYS-1:0] first_zero_node;
  wire [lognumways_node-1:0] first_zero_way_node;
  wire [lognumways_node-1:0] victim_way_enc_node;

  // Encode the selected one-hot input into a binary index.
  binencoder #(NUMWAYS) hitwayencoder_u(hit_way, hit_way_encoded_node);

  // Use the replacement tree only when every way is valid; otherwise prefer an invalid way.
  assign all_valid_node = &valid_way;

  
  // coverage off
  
  function integer log2;
    input integer value;  // Integer argument used to calculate the local logarithm.
    integer val;
    begin
      val = value;
      // Count the shifts needed to determine the encoded index width.
      for (log2 = 0; val > 0; log2 = log2+1)
        val = val >> 1;
    end
  endfunction 
  // coverage on

  
  // Select the appropriate datapath value from the available inputs.
  mux2 #(lognumways_node) way_mux_enc_u(hit_way_encoded_node, victim_way_enc_node, set_valid, way_node);

  
  // Expand encoded way bits into the pseudo-LRU tree update pattern.
  for(row = 0; row < lognumways_node; row = row + 1) begin
    localparam integer duplication_factor_node = 2**(lognumways_node-row-1);
    localparam start_index_node = NUMWAYS-2 - duplication_factor_node + 1;
    localparam end_index_node = NUMWAYS-2 - 2 * duplication_factor_node + 2;
    assign way_expanded_node[start_index_node : end_index_node] = {{duplication_factor_node}{way_node[row]}};
  end

  genvar               node_node;
  // Generate tree-node enables along the path of the accessed cache way.
  assign lru_update_node[NUMWAYS-2] = 1'b1;
  // Traverse pseudo-LRU tree nodes to update the accessed replacement path.
  for(node_node = NUMWAYS-2; node_node >= NUMWAYS/2; node_node = node_node - 1) begin : enables
    localparam ctr_node = NUMWAYS - node_node - 1;
    localparam ctr_depth_node = log2(ctr_node);
    localparam lchild_node = node_node - ctr_node;
    localparam rchild_node = lchild_node - 1;
    localparam r_node = lognumways_node - ctr_depth_node;

    
    if (node_node == NUMWAYS-2) begin
      // Generate tree-node enables along the path of the accessed cache way.
      assign lru_update_node[lchild_node] = ~way_node[r_node];
      assign lru_update_node[rchild_node] = way_node[r_node];
    end else begin
      assign lru_update_node[lchild_node] = lru_update_node[node_node] & ~way_node[r_node];
      assign lru_update_node[rchild_node] = lru_update_node[node_node] & way_node[r_node];
    end
  end

  
  // Update only the pseudo-LRU tree nodes on the selected way path.
  assign next_lru_node[NUMWAYS-2] = ~way_expanded_node[NUMWAYS-2];
  if (NUMWAYS > 2) mux2 #(1) LRUMuxes[NUMWAYS-3:0](curr_lru_node[NUMWAYS-3:0], ~way_expanded_node[NUMWAYS-3:0], lru_update_node[NUMWAYS-3:0], next_lru_node[NUMWAYS-3:0]);

  
  // Traverse pseudo-LRU tree nodes to update the accessed replacement path.
  for(node_node = NUMWAYS-2; node_node >= NUMWAYS/2; node_node = node_node - 1) begin
    localparam t0_node = 2*node_node - NUMWAYS;
    localparam t1_node = t0_node + 1;
    assign intermediate_node[node_node] = curr_lru_node[node_node] ? intermediate_node[t0_node] : intermediate_node[t1_node];
  end
  // Traverse pseudo-LRU tree nodes to update the accessed replacement path.
  for(node_node = NUMWAYS/2-1; node_node >= 0; node_node = node_node - 1) begin
    localparam int0_node = (NUMWAYS/2-1-node_node)*2;
    localparam int1_node = int0_node + 1;
    assign intermediate_node[node_node] = curr_lru_node[node_node] ? int1_node[lognumways_node-1:0] : int0_node[lognumways_node-1:0];
  end

  // Convert a binary index into a one-hot selection.
  decoder #(lognumways_node) decoder (victim_way_enc_node, victim_way);
  // Select replacement metadata or a cache victim way.
  mux2 #(lognumways_node) victim_mux_u(first_zero_way_node, intermediate_node[NUMWAYS-2], all_valid_node, victim_way_enc_node);
  // Encode the selected one-hot input into a binary index.
  binencoder #(NUMWAYS) first_zero_way_encoder_u(first_zero_node, first_zero_way_node);
  // Choose the highest-priority asserted bit in a one-hot result.
  priorityonehot #(NUMWAYS) first_zero_encoder_u(~valid_way, first_zero_node);

  
  integer set_node;
  // Update registered memory and request state on the clock edge.
  // Update sequential state on the active clock edge, respecting reset and enables.
  always @(posedge clk)
    if (reset | (invalidate_cache & ~invalidate_kill_stage))
      // Apply the same combinational operation to each configured element.
      for (set_node = 0; set_node < NUMSETS; set_node = set_node + 1) lru_memory_node[set_node] <= 1'b0; // exclusion-tag: initialize
    else if (cache_en & lru_write_en) lru_memory_node[p_adr] <= next_lru_node;

  
  // Read replacement metadata from the cache set being looked up.
  assign read_lru_node = lru_memory_node[cache_set_lru];
  // Bypass a same-cycle replacement update to avoid reading stale metadata.
  assign forward_lru_node = lru_write_en & (p_adr == cache_set_lru);
  // Select the appropriate datapath value from the available inputs.
  mux2 #(NUMWAYS-1) read_lr_umux_u(read_lru_node, next_lru_node, forward_lru_node, bypassed_lru_node);
  // Register stage data under the supplied clock, reset, and enable controls.
  ff #(NUMWAYS-1) curr_lru_reg_u(clk, bypassed_lru_node, curr_lru_node);
endmodule

// Connects cache tags, data ways, access control, and the external memory path.
// Produces hit/miss, refill, writeback, and request-status signals.


module cache_unit  #(parameter linelen_node = 128,  NUMSETS = 128,  offsetlen_node = 4, setlen_node = 7, NUMWAYS = 2, LOGBWPL = 2, WORDLEN = 32, MUXINTERVAL = 32, READ_ONLY_CACHE = 0) (
  input wire clk,  // Clock used for synchronous state updates.
  input wire reset,  // Resets the local state and pipeline registers.
  input wire hold,  // Prevents the corresponding pipeline stage from advancing.
  input wire word_window_enable,  // Provides word window enable for this module.
  input wire kill_stage,  // Cancels invalid or wrong-path pipeline work.
  input wire invalidate_kill_stage,  // Suppresses invalidation when the associated operation is cancelled.
  
  input wire [1:0] cache_rw /* synthesis PAP_MARK_DEBUG="true" */,  // Cache access operation encoding (read/write).
  input wire kill_cache,  // Cache-side data, address, or operation control.
  input wire invalidate_cache,  // Requests invalidation of cache state.
  input wire [offsetlen_node+setlen_node-1:0] next_set,  // Provides next set for this module.
  input wire [31:0] p_adr,  // Set index used for replacement metadata updates.
  input wire [(WORDLEN-1)/8:0] byte_mask,  // Active byte lanes for a memory write.
  input wire [WORDLEN-1:0] write_data,  // Data value to be written to the target.
  output wire cache_committed,  // Cache-side data, address, or operation control.
  output wire cache_hold,  // Backpressure caused by an unresolved cache operation.
  output wire [WORDLEN-1:0] read_data_word,  // Data returned by the selected source.
  output wire cache_word_window_valid,  // Cache-side data, address, or operation control.
  
  output wire cache_miss,  // Cache miss indication for line refill processing.
  output wire cache_access,  // Cache-side data, address, or operation control.
  output wire perf_request_accept,  // Pulse for a newly accepted cache request.
  output wire perf_miss_start,  // Pulse on the first accepted cycle of a cache miss.
  output wire perf_load_accept,  // Pulse for a newly accepted cache load.
  output wire perf_load_miss_start,  // Pulse for a newly accepted load miss.
  output wire perf_store_accept,  // Pulse for a newly accepted cache store.
  output wire perf_store_miss_start,  // Pulse for a newly accepted store miss.
  output wire perf_writeback_start,  // Pulse when a dirty cache-line writeback starts.
  
  input wire cache_bus_ack,  // External memory transaction associated with cache control.
  input wire cache_bus_error,  // External memory transaction associated with cache control.
  input wire sel_bus_beat,  // Provides sel bus beat for this module.
  input wire writeback_prefetch_en,  // Instruction-fetch request, response, or control.
  input wire [LOGBWPL-1:0] beat_count,  // Provides beat count for this module.
  input wire [linelen_node-1:0] fetch_buffer,  // Instruction-fetch request, response, or control.
  input wire refill_write_en,  // Enables writing the fetched line into the cache.
  input wire [LOGBWPL-1:0] refill_beat,  // Provides refill beat for this module.
  input wire [31:0] refill_data,  // Data supplied from a cache-line refill transaction.
  output wire [1:0] cache_bus_rw,  // External memory transaction associated with cache control.
  output wire [31:0] cache_bus_adr  // External memory transaction associated with cache control.
);

  
  localparam                     set_offset_bits_node = setlen_node+offsetlen_node;          
  localparam                     taglen_node = 32 - set_offset_bits_node;          
  localparam                     last_kill_set_index_node = NUMSETS - 1;   

  wire sel_adr_data;
  wire sel_adr_tag;
  wire [1:0] data_set_source_sel_node;
  wire [1:0] tag_set_source_sel_node;
  wire [1:0] lru_set_source_sel_node;
  wire [setlen_node-1:0] cache_set_data;
  reg [1:0] cache_word_data;
  wire [setlen_node-1:0] cache_set_tag;
  wire [setlen_node-1:0] cache_set_lru;
  wire clear_dirty;
  wire set_dirty;
  wire set_valid;
  wire clear_valid;
  wire [NUMWAYS*32-1:0] read_data_word_way;
  wire [NUMWAYS-1:0] hit_way /* synthesis PAP_MARK_DEBUG="true" */;
  wire [NUMWAYS-1:0] valid_way;
  wire hit /* synthesis PAP_MARK_DEBUG="true" */;
  wire [NUMWAYS-1:0] victim_way;
  wire [NUMWAYS-1:0] dirty_way;
  wire [NUMWAYS-1:0] hit_dirty_way;
  wire line_dirty;
  wire [NUMWAYS*taglen_node-1:0] tag_way;
  wire [taglen_node-1:0] tag_node;
  wire [setlen_node-1:0] kill_adr_node;
  wire [setlen_node-1:0] kill_owner_adr_node;
  wire [setlen_node-1:0] cache_set_dirty;
  wire kill_adr_cnt_en;
  wire kill_cnt_rst;
  wire kill_address_at_last_set_node;
  wire kill_way_at_last_node;
  wire [NUMWAYS-1:0] kill_way;
  wire [NUMWAYS-1:0] next_kill_way_node;
  wire kill_way_cnt_en;
  wire sel_writeback;
  wire lru_write_en;
  wire [31:0] read_data_word_cache_node;
  wire [31:0] read_data_word_fetch_node;
  wire sel_fetch_buffer;
  wire cache_en;
  wire i_window_prefetch_node;
  wire i_window_read_hold_node;
  wire sel_victim;
  wire [$clog2(linelen_node/8) - $clog2(MUXINTERVAL/8) - 1:0] word_offset_addr_node;
  genvar                         index;

  
  assign data_set_source_sel_node = {kill_cache, (sel_adr_data & ~((READ_ONLY_CACHE == 1) & kill_stage))};
  // Select the appropriate datapath value from the available inputs.
  mux3 #(setlen_node) adr_sel_mux_data_u(next_set[set_offset_bits_node-1:offsetlen_node], p_adr[set_offset_bits_node-1:offsetlen_node], kill_adr_node,
    data_set_source_sel_node, cache_set_data);
  
  
  // Compute combinational control and data selections.
  // Compute the combinational outputs from the current data and control inputs.
  always @* begin
    
    
    if (cache_bus_rw[0]) cache_word_data = beat_count[1:0] + {{1{1'b0}}, writeback_prefetch_en};
    else if (sel_writeback) cache_word_data = 2'b00;
    else if (kill_cache) cache_word_data = beat_count[1:0];
    else if (sel_adr_data & ~((READ_ONLY_CACHE == 1) & kill_stage)) begin
      if (sel_bus_beat) cache_word_data = beat_count[1:0];
      else cache_word_data = p_adr[3:2];
    end else if (i_window_prefetch_node | i_window_read_hold_node) cache_word_data = next_set[3:2] + 2'b01;
    else cache_word_data = next_set[3:2];
  end
  assign tag_set_source_sel_node = {kill_cache, (sel_adr_tag & ~((READ_ONLY_CACHE == 1) & kill_stage))};
  // Select the appropriate datapath value from the available inputs.
  mux3 #(setlen_node) adr_sel_mux_tag_u(next_set[set_offset_bits_node-1:offsetlen_node], p_adr[set_offset_bits_node-1:offsetlen_node], kill_adr_node,
    tag_set_source_sel_node, cache_set_tag);

  assign lru_set_source_sel_node = {kill_cache, ((sel_adr_tag | hold) & ~((READ_ONLY_CACHE == 1) & kill_stage))};
  // Select replacement metadata or a cache victim way.
  mux3 #(setlen_node) adr_sel_mux_lru_u(next_set[set_offset_bits_node-1:offsetlen_node], p_adr[set_offset_bits_node-1:offsetlen_node], kill_adr_node,
    lru_set_source_sel_node, cache_set_lru);

  
  // Select and update the addressed cache way.
  cache_way #(NUMSETS, linelen_node, taglen_node, offsetlen_node, setlen_node, READ_ONLY_CACHE) CacheWays[NUMWAYS-1:0](
    .clk(clk), .reset(reset), .cache_en(cache_en), .cache_set_data(cache_set_data), .cache_set_tag(cache_set_tag), .cache_set_dirty(cache_set_dirty), .cache_word_data(cache_word_data), .p_adr(p_adr),
    .write_data(write_data), .byte_mask(byte_mask[3:0]), .refill_write_en(refill_write_en), .refill_word(refill_beat[1:0]), .refill_data(refill_data), .sel_victim(sel_victim),
    .set_valid(set_valid), .clear_valid(clear_valid), .set_dirty(set_dirty), .clear_dirty(clear_dirty), .victim_way(victim_way),
    .kill_way(kill_way), .kill_cache(kill_cache), .read_data_word_way(read_data_word_way), .hit_way(hit_way), .valid_way(valid_way), .dirty_way(dirty_way), .hit_dirty_way(hit_dirty_way), .tag_way(tag_way), .kill_stage(kill_stage), .invalidate_cache(invalidate_cache), .invalidate_kill_stage(invalidate_kill_stage));

  
  if (NUMWAYS > 1) begin : vict
    // Maintain per-set pseudo-LRU replacement state and choose victim ways.
    cache_plru #(NUMWAYS, setlen_node, NUMSETS) cache_plru_i_u(
      .clk(clk), .reset(reset), .cache_en(cache_en), .hit_way(hit_way), .valid_way(valid_way), .victim_way(victim_way), .cache_set_lru(cache_set_lru), .lru_write_en(lru_write_en),
      .set_valid(set_valid), .p_adr(p_adr[set_offset_bits_node-1:offsetlen_node]), .invalidate_cache(invalidate_cache), .invalidate_kill_stage(invalidate_kill_stage));
  end else begin : single_way_victim
    assign victim_way = 1'b1; 
  end

  // Combine cache tag, validity, and way-selection conditions for hit detection.
  assign hit = |hit_way;
  assign line_dirty = |dirty_way;

  
  // Reduce and combine rows of the input vector.
  or_rows #(NUMWAYS, taglen_node) tag_ao_mux_u(.generic_input_a(tag_way), .generic_result(tag_node));
  // Reduce and combine rows of the input vector.
  or_rows #(NUMWAYS, 32) read_data_ao_mux_u(.generic_input_a(read_data_word_way), .generic_result(read_data_word_cache_node));

  
  if (!READ_ONLY_CACHE)
    // Select the appropriate datapath value from the available inputs.
    mux2 #(LOGBWPL) word_adrr_mux_u(.d0(p_adr[$clog2(linelen_node/8) - 1 : $clog2(MUXINTERVAL/8)]),
      .d1(beat_count), .s(sel_bus_beat),
      .generic_result(word_offset_addr_node));
  else
    // Select the address associated with the active request.
    assign word_offset_addr_node = p_adr[$clog2(linelen_node/8) - 1 : $clog2(MUXINTERVAL/8)];

  
  // Extract the addressed word from a cache-line read result.
  cache_line_select #(linelen_node, WORDLEN, MUXINTERVAL) cache_line_select_i_u(
    .p_adr(word_offset_addr_node), .read_data_line(fetch_buffer), .read_data_word(read_data_word_fetch_node));

  if (READ_ONLY_CACHE) begin : icachewordalign
    wire [31:0] aligned_cache_word_node;
    reg [15:0] window_first_half_q_node;
    reg [31:0] window_instr_q_node;
    reg [31:0] window_pcq_node;
    reg window_return_q_node;
  reg window_saved_valid_q_node;
  wire window_new_valid_node;

    
    assign i_window_prefetch_node = word_window_enable & ~window_return_q_node & ~window_saved_valid_q_node &
                             cache_rw[1] & hit & ~cache_hold & ~kill_stage &
                             ~invalidate_cache & ~p_adr[1] &
                             (read_data_word_cache_node[1:0] != 2'b11) &
                             (next_set == (p_adr[set_offset_bits_node-1:0] + {{set_offset_bits_node-2{1'b0}}, 2'b10})) &
                             (next_set[offsetlen_node-1:0] != {{offsetlen_node-4{1'b0}}, 4'he});

    // Update registered memory and request state on the clock edge.
    // Update validity state on the active clock edge with reset and enable priority.
    always @(posedge clk) begin
      if (reset | kill_stage | invalidate_cache | invalidate_kill_stage) begin
        window_return_q_node <= 1'b0;
        window_saved_valid_q_node <= 1'b0;
        window_first_half_q_node <= 1'b0;
        window_instr_q_node <= 1'b0;
        window_pcq_node <= 1'b0;
      end else begin
        if (i_window_prefetch_node) begin
          window_return_q_node <= 1'b1;
          window_first_half_q_node <= read_data_word_cache_node[31:16];
          window_pcq_node <= {p_adr[31:set_offset_bits_node], next_set};
        end
        if (window_new_valid_node & hold) begin
          window_return_q_node <= 1'b0;
          window_saved_valid_q_node <= 1'b1;
          window_instr_q_node <= {read_data_word_cache_node[15:0], window_first_half_q_node};
        end else if (window_new_valid_node & ~hold) begin
          window_return_q_node <= 1'b0;
        end else if (window_saved_valid_q_node & ~hold) begin
          window_saved_valid_q_node <= 1'b0;
        end
      end
    end

    assign window_new_valid_node = window_return_q_node & hit & (p_adr == window_pcq_node) &
                            ~cache_hold & ~kill_stage & ~invalidate_cache;
    // Qualify pipeline backpressure with the current request or stage state.
    assign i_window_read_hold_node = window_return_q_node & (p_adr != window_pcq_node);
    assign cache_word_window_valid = window_new_valid_node | (window_saved_valid_q_node & (p_adr == window_pcq_node));
    assign aligned_cache_word_node = window_saved_valid_q_node ? window_instr_q_node :
                              window_new_valid_node ? {read_data_word_cache_node[15:0], window_first_half_q_node} :
                              p_adr[1] ? {16'b0, read_data_word_cache_node[31:16]} : read_data_word_cache_node;
    // Select the appropriate datapath value from the available inputs.
    mux2 #(32) early_return_mux_u(aligned_cache_word_node, read_data_word_fetch_node, sel_fetch_buffer, read_data_word);
  end else begin : dcachewordalign
    assign i_window_prefetch_node = 1'b0;
    assign i_window_read_hold_node = 1'b0;
    assign cache_word_window_valid = 1'b0;
    // Select the appropriate datapath value from the available inputs.
    mux2 #(32) early_return_mux_u(read_data_word_cache_node, read_data_word_fetch_node, sel_fetch_buffer, read_data_word);
  end

  
  // Select the appropriate datapath value from the available inputs.
  mux3 #(32) cache_bus_adr_mux_u(.d0({p_adr[31:offsetlen_node], {offsetlen_node{1'b0}}}),
    .d1({tag_node, p_adr[set_offset_bits_node-1:offsetlen_node], {offsetlen_node{1'b0}}}),
    .d2({tag_node, kill_adr_node, {offsetlen_node{1'b0}}}),
    .s({kill_cache, sel_writeback}), .generic_result(cache_bus_adr));

  
  if (!READ_ONLY_CACHE) begin : flushlogic 
    wire kill_counter_reset_node;
    wire [setlen_node-1:0] kill_address_next_node;
  wire [setlen_node-1:0] kill_address_plus_one_node;

    
    // Qualify pipeline cancellation using redirect or invalidation conditions.
    assign kill_counter_reset_node = reset | kill_cnt_rst;
    // Register stage data under the supplied clock, reset, and enable controls.
    ffenr #(setlen_node) kill_adr_reg_u(clk, kill_counter_reset_node, kill_adr_cnt_en, kill_address_plus_one_node, kill_address_next_node);
    // Select the appropriate datapath value from the available inputs.
    mux2    #(setlen_node) kill_adr_mux_u(kill_address_next_node, kill_address_plus_one_node, kill_adr_cnt_en, kill_adr_node);
    assign kill_address_plus_one_node = kill_address_next_node + 1'b1;
    
    
    assign kill_owner_adr_node = kill_address_next_node;
    assign kill_address_at_last_set_node = (kill_address_next_node == last_kill_set_index_node[setlen_node-1:0]);

    
    // Register stage data under the supplied clock, reset, and enable controls.
    ffenl #(NUMWAYS) kill_way_reg_u(clk, kill_way_cnt_en, kill_counter_reset_node, {{NUMWAYS-1{1'b0}}, 1'b1}, next_kill_way_node, kill_way);
    if (NUMWAYS > 1) assign next_kill_way_node = {kill_way[NUMWAYS-2:0], kill_way[NUMWAYS-1]};
    else            assign next_kill_way_node = kill_way[NUMWAYS-1];
    // Qualify pipeline cancellation using redirect or invalidation conditions.
    assign kill_way_at_last_node = kill_way[NUMWAYS-1];
  end 
  else begin : flushlogic 
    assign kill_way = 1'b0;
    assign kill_way_at_last_node = 1'b0;
    assign kill_address_at_last_set_node = 1'b0;
    assign kill_adr_node = 1'b0;
    assign kill_owner_adr_node = 1'b0;
  end

  assign cache_set_dirty = (kill_cache & clear_dirty) ? kill_owner_adr_node : cache_set_data;

  
  // Generate line-transfer and array update controls.
  // Sequence cache hits, misses, line refills, dirty writebacks, and invalidation.
  cache_control_fsm #(READ_ONLY_CACHE) cache_control_fsm_i_u(.clk(clk), .reset(reset), .cache_bus_rw(cache_bus_rw), .cache_bus_ack(cache_bus_ack), .cache_bus_error(cache_bus_error),
    .kill_stage(kill_stage), .invalidate_kill_stage(invalidate_kill_stage), .cache_rw(cache_rw), .hold(hold),
    .hit(hit), .line_dirty(line_dirty), .cache_hold(cache_hold), .cache_committed(cache_committed),
    .cache_miss(cache_miss), .cache_access(cache_access),
    .perf_request_accept(perf_request_accept), .perf_miss_start(perf_miss_start),
    .perf_load_accept(perf_load_accept), .perf_load_miss_start(perf_load_miss_start),
    .perf_store_accept(perf_store_accept), .perf_store_miss_start(perf_store_miss_start),
    .perf_writeback_start(perf_writeback_start),
    .sel_adr_data(sel_adr_data), .sel_adr_tag(sel_adr_tag), .sel_victim(sel_victim),
    .clear_dirty(clear_dirty), .set_dirty(set_dirty), .set_valid(set_valid), .clear_valid(clear_valid), .sel_writeback(sel_writeback),
    .kill_adr_cnt_en(kill_adr_cnt_en), .kill_way_cnt_en(kill_way_cnt_en), .kill_cnt_rst(kill_cnt_rst),
    .kill_adr_flag(kill_address_at_last_set_node), .kill_way_flag(kill_way_at_last_node), .kill_cache(kill_cache), .sel_fetch_buffer(sel_fetch_buffer),
    .invalidate_cache(invalidate_cache), .cache_en(cache_en), .lru_write_en(lru_write_en));
endmodule

// Sequences cache accesses, misses, line fills, victim writebacks, and invalidation.
// Issues bus requests and waits for completion before advancing dependent cache operations.


module cache_control_fsm #(parameter READ_ONLY_CACHE = 0) (
  input wire clk,  // Clock used for synchronous state updates.
  input wire reset,  // Resets the local state and pipeline registers.
  
  input wire hold,  // Prevents the corresponding pipeline stage from advancing.
  input wire kill_stage,  // Cancels invalid or wrong-path pipeline work.
  input wire invalidate_kill_stage,  // Suppresses invalidation when the associated operation is cancelled.
  output wire cache_committed,  // Cache-side data, address, or operation control.
  output wire cache_hold,  // Backpressure caused by an unresolved cache operation.
  
  input wire [1:0] cache_rw /* synthesis PAP_MARK_DEBUG="true" */,  // Cache access operation encoding (read/write).
  input wire kill_cache,  // Cache-side data, address, or operation control.
  input wire invalidate_cache,  // Requests invalidation of cache state.
  
  input wire cache_bus_ack,  // External memory transaction associated with cache control.
  input wire cache_bus_error,  // External memory transaction associated with cache control.
  output wire [1:0] cache_bus_rw,  // External memory transaction associated with cache control.
  
  output wire cache_miss,  // Cache miss indication for line refill processing.
  output wire cache_access,  // Cache-side data, address, or operation control.
  output wire perf_request_accept /* synthesis PAP_MARK_DEBUG="true" */,  // Pulse for a newly accepted cache request.
  output wire perf_miss_start /* synthesis PAP_MARK_DEBUG="true" */,  // Pulse on the first accepted cycle of a cache miss.
  output wire perf_load_accept /* synthesis PAP_MARK_DEBUG="true" */,  // Pulse for a newly accepted cache load.
  output wire perf_load_miss_start /* synthesis PAP_MARK_DEBUG="true" */,  // Pulse for a newly accepted load miss.
  output wire perf_store_accept,  // Pulse for a newly accepted cache store.
  output wire perf_store_miss_start,  // Pulse for a newly accepted store miss.
  output wire perf_writeback_start /* synthesis PAP_MARK_DEBUG="true" */,  // Pulse when a dirty cache-line writeback starts.

  
  input wire hit /* synthesis PAP_MARK_DEBUG="true" */,  // Cache hit indication or hit-way selection.
  input wire line_dirty,  // Indicates the replacement cache line contains modified data.
  input wire kill_adr_flag,  // Cancels invalid or wrong-path pipeline work.
  input wire kill_way_flag,  // Cancels invalid or wrong-path pipeline work.
  output wire sel_adr_data,  // Address operand or decoded address field.
  output wire sel_adr_tag,  // Address operand or decoded address field.
  output wire set_valid,  // Selects a newly valid way instead of the hit way.
  output wire clear_valid,  // Clears the valid state of the selected cache line.
  output wire set_dirty,  // Marks the selected cache line as modified.
  output wire clear_dirty,  // Clears the dirty state after refill or writeback.
  output wire sel_writeback,  // Provides sel writeback for this module.
  output wire lru_write_en,  // Enables a replacement-state update for the selected set.
  output wire sel_victim,  // Replacement way selected for a cache miss.
  output wire kill_adr_cnt_en,  // Cancels invalid or wrong-path pipeline work.
  output wire kill_way_cnt_en,  // Cancels invalid or wrong-path pipeline work.
  output wire kill_cnt_rst,  // Cancels invalid or wrong-path pipeline work.
  output wire sel_fetch_buffer,  // Instruction-fetch request, response, or control.
  output wire cache_en  // Enables a cache lookup or replacement-state access.
);

  wire reset_delay_node;
  wire any_update_hit_node;
  wire any_hit_node;
  wire any_miss_node;
  wire kill_flag_node;
  wire hold_conditions_node;

    localparam [3:0] state_access_node = 4'd0;
  localparam [3:0] state_fetch_node = 4'd1;
  localparam [3:0] state_writeback_setup_node = 4'd2;
  localparam [3:0] state_writeback_node = 4'd3;
  localparam [3:0] state_write_line_node = 4'd4;
  localparam [3:0] state_address_setup_node = 4'd5;
  localparam [3:0] state_kill_node = 4'd6;
  localparam [3:0] state_kill_writeback_node = 4'd7;

  reg [3:0] curr_state_node /* synthesis PAP_MARK_DEBUG="true" */;
  reg [3:0] next_state_node;

  // Recognize an enabled read/write access that misses and is not being invalidated.
  assign any_miss_node = (cache_rw[0] | cache_rw[1]) & ~hit & ~invalidate_cache; // exclusion-tag: cache any_miss_node
  assign any_update_hit_node = cache_rw[0] & hit;
  assign any_hit_node = any_update_hit_node | (cache_rw[1] & hit);                  // exclusion-tag: icache any_update_hit_node

  assign kill_flag_node = kill_adr_flag & kill_way_flag;

  
  // Qualify cache array access by current FSM state, Hold, and Kill conditions.
  assign cache_access = (|cache_rw) & ((curr_state_node == state_access_node & ~hold & ~kill_stage) | (curr_state_node == state_address_setup_node & ~hold & ~kill_stage)); // exclusion-tag: icache CacheW
  assign cache_miss = curr_state_node == state_write_line_node; 
  
  
  // Accept each new cache request once; exclude replay cycles.
  // An accepted access is counted once rather than on each replay or wait cycle.
  // Emit one performance event per newly accepted cache request, excluding replay cycles.
  assign perf_request_accept = (curr_state_node == state_access_node) & (|cache_rw) &
                                    (~hold | ~hit) & ~kill_stage & ~invalidate_cache &
                                    ~(kill_cache & ~READ_ONLY_CACHE);
  // Count the first accepted cycle of a cache miss.
  // Miss-start pulses distinguish new misses from the following refill cycles.
  // Separate the first miss cycle from later refill and wait cycles.
  assign perf_miss_start = perf_request_accept & ~hit;
  assign perf_load_accept = perf_request_accept & cache_rw[1] & ~cache_rw[0];
  assign perf_load_miss_start = perf_load_accept & ~hit;
  assign perf_store_accept = perf_request_accept & cache_rw[0] & ~cache_rw[1];
  assign perf_store_miss_start = perf_store_accept & ~hit;
  // Qualify transfer completion with the bus handshake.
  // Dirty victim replacement is recorded when writeback is initiated.
  // Count dirty victim writeback entry, including cache maintenance operations.
  assign perf_writeback_start = ~READ_ONLY_CACHE &
                                     (((curr_state_node == state_access_node) & any_miss_node & line_dirty &
                                      ~kill_stage) |
                                      ((curr_state_node == state_kill_node) & line_dirty));

  
  // Register stage data under the supplied clock, reset, and enable controls.
  ff #(1) reset_delay_reg_u(.clk(clk), .d(reset), .q(reset_delay_node));

  // Reset and invalidation return the controller to the normal access state.
  // Register the controller state; reset and transition conditions determine each update.
  always @(posedge clk)
    if (reset | kill_stage)    curr_state_node <= state_access_node;
    else curr_state_node <= next_state_node;

  // Compute combinational control and data selections.
  // Compute the combinational next-state/output decisions from the current control state.
  always @* begin
    next_state_node = state_access_node;
    // Select the next cache action from the current transfer state.
    // Choose the cache FSM transition using bus acknowledgements, misses, and invalidation state.
    case (curr_state_node)                                                                                        // exclusion-tag: icache state-case
      // Accepts a new hit or miss, or begins cache maintenance.
      state_access_node:           if(invalidate_cache & ~invalidate_kill_stage)                               next_state_node = state_access_node;     // exclusion-tag: dcache InvalidateCheck
                             else if(kill_cache & ~READ_ONLY_CACHE)            next_state_node = state_kill_node;     // exclusion-tag: icache FLUSHStatement
                             else if(any_miss_node & (READ_ONLY_CACHE | ~line_dirty)) next_state_node = state_fetch_node;     // exclusion-tag: icache FETCHStatement
                             else if(any_miss_node & ~READ_ONLY_CACHE)              next_state_node = state_writeback_setup_node;
                             else                                              next_state_node = state_access_node;
      // Requests a replacement line and collects the incoming refill data.
      state_fetch_node:           if(cache_bus_error)                                 next_state_node = state_address_setup_node;
                             else if(cache_bus_ack)                              next_state_node = state_write_line_node;
                             else                                              next_state_node = state_fetch_node;
      
      
      // Prepares victim address and data before a dirty-line writeback.
      state_writeback_setup_node:                                                   next_state_node = state_writeback_node;
      // Writes buffered refill data into the selected cache way.
      state_write_line_node:                                                        next_state_node = state_address_setup_node;
      // Restores address selection before returning to normal access.
      state_address_setup_node:       if(hold)                                         next_state_node = state_address_setup_node;
                             else                                              next_state_node = state_access_node;
      // exclusion-tag-start: icache case
      // Transfers the dirty victim to memory before beginning the refill.
      state_writeback_node:       if(cache_bus_error)                                 next_state_node = state_address_setup_node;
                             else if(cache_bus_ack)                              next_state_node = state_fetch_node;
                             else                                              next_state_node = state_writeback_node;
      
      // Walks cache entries during a maintenance or invalidation sequence.
      state_kill_node:           if(line_dirty)                                     next_state_node = state_kill_writeback_node;
                             else if (kill_flag_node)                               next_state_node = state_address_setup_node;
                             else                                              next_state_node = state_kill_node;
      // Writes dirty data while processing a cache maintenance request.
      state_kill_writeback_node: if(cache_bus_error)                                 next_state_node = state_address_setup_node;
                             else if(cache_bus_ack & ~kill_flag_node)                 next_state_node = state_kill_node;
                             else if(cache_bus_ack)                              next_state_node = state_address_setup_node;
                             else                                              next_state_node = state_kill_writeback_node;
      // exclusion-tag-end: icache case
      default:                                                                 next_state_node = state_access_node;
    endcase
  end

  
  assign cache_committed = (curr_state_node != state_access_node) & ~(READ_ONLY_CACHE & (curr_state_node == state_address_setup_node));
  assign hold_conditions_node = kill_cache | any_miss_node;                              // exclusion-tag: icache kill_cache
  // Cache Hold remains asserted while a miss, writeback, or maintenance is unresolved.
  // Keep the requesting pipeline stage held through unresolved refill or writeback activity.
  assign cache_hold = (curr_state_node == state_access_node & hold_conditions_node) | // exclusion-tag: icache StallStates
                      (curr_state_node == state_fetch_node) |
                      (curr_state_node == state_writeback_setup_node) |
                      (curr_state_node == state_writeback_node) |
                      (curr_state_node == state_write_line_node) |  
                      (curr_state_node == state_kill_node) |
                      (curr_state_node == state_kill_writeback_node);
  
  assign set_valid = curr_state_node == state_write_line_node;
  
  
  assign clear_valid = (curr_state_node == state_access_node & any_miss_node &
                       (READ_ONLY_CACHE | ~line_dirty)) |
                      (curr_state_node == state_writeback_node & cache_bus_ack);
  assign lru_write_en = ((curr_state_node == state_access_node & any_hit_node) |
                       (curr_state_node == state_write_line_node)) & ~kill_stage;
  // exclusion-tag-start: icache flushdirtycontrols
  assign set_dirty = (curr_state_node == state_access_node & any_update_hit_node) |         // exclusion-tag: icache set_dirty
                    (curr_state_node == state_write_line_node & cache_rw[0]);
  assign clear_dirty = (curr_state_node == state_write_line_node & ~(cache_rw[0])) |   // exclusion-tag: icache clear_dirty
                      (curr_state_node == state_kill_writeback_node & cache_bus_ack);
  
  assign sel_victim = (curr_state_node == state_writeback_setup_node) |
                  (curr_state_node == state_writeback_node) |
                  (curr_state_node == state_access_node & any_miss_node) |
                  (curr_state_node == state_write_line_node);
  // Generate the writeback value or eligibility condition for the current instruction.
  assign sel_writeback = (curr_state_node == state_writeback_setup_node) |
                        (curr_state_node == state_writeback_node & ~cache_bus_ack) |
                        (curr_state_node == state_access_node & any_miss_node & line_dirty);
  // coverage off -item e 1 -fecexprrow 1
  
  // Qualify pipeline cancellation using redirect or invalidation conditions.
  assign kill_adr_cnt_en = (curr_state_node == state_kill_writeback_node & kill_way_flag & cache_bus_ack) |
             (curr_state_node == state_kill_node & kill_way_flag & ~line_dirty);
  assign kill_way_cnt_en = (curr_state_node == state_kill_node & ~line_dirty) |
             (curr_state_node == state_kill_writeback_node & cache_bus_ack);
  assign kill_cnt_rst = (curr_state_node == state_kill_node & kill_flag_node & ~line_dirty) |
              (curr_state_node == state_kill_writeback_node & kill_flag_node & cache_bus_ack);
  // exclusion-tag-end: icache flushdirtycontrols
  
  assign cache_bus_rw[1] = (curr_state_node == state_access_node & any_miss_node & ~line_dirty) | // exclusion-tag: icache CacheBusRCauses
                         (curr_state_node == state_fetch_node & ~cache_bus_ack) |
                         (curr_state_node == state_writeback_node & cache_bus_ack);

  assign cache_bus_rw[0] = (curr_state_node == state_writeback_node & ~cache_bus_ack) |
                         (curr_state_node == state_kill_writeback_node & ~cache_bus_ack);

  // Select the address associated with the active request.
  assign sel_adr_data = (curr_state_node == state_access_node & (cache_rw[0] | any_miss_node)) | // exclusion-tag: icache SelAdrCauses // changes if store delay hazard removed
                  (curr_state_node == state_fetch_node) |
                  (curr_state_node == state_writeback_setup_node) |
                  (curr_state_node == state_writeback_node) |
                  (curr_state_node == state_write_line_node) |
                  reset_delay_node;
  assign sel_adr_tag = (curr_state_node == state_access_node & any_miss_node) | // exclusion-tag: icache sel_adr_tag // changes if store delay hazard removed
                  (curr_state_node == state_fetch_node) |
                  (curr_state_node == state_writeback_setup_node) |
                  (curr_state_node == state_writeback_node) |
                  (curr_state_node == state_write_line_node) |
                  reset_delay_node;
  assign sel_fetch_buffer = curr_state_node == state_write_line_node | curr_state_node == state_address_setup_node;
  assign cache_en = (~hold | hold_conditions_node) | (curr_state_node != state_access_node) | reset | invalidate_cache; // exclusion-tag: dcache cache_en

endmodule 

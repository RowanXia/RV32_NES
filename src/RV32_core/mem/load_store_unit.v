// Processes load/store addresses, cache access, and bus requests.
// Formats returned load data and reports memory access faults.


`include "config.vh"

module load_store_unit    (
  input wire clk,  // Clock used for synchronous state updates.
  input wire reset,  // Resets the local state and pipeline registers.
  input wire hold_m,  // Holds the memory-stage transaction and state.
  input wire kill_m,  // Invalidates the instruction entering the memory stage.
  input wire hold_w,  // Backpressure condition preventing writeback advancement.
  input wire kill_w,  // Suppresses writeback for invalid or trapped instructions.
  output wire memory_hold_m,  // Indicates that the data-memory request is still pending.
  
  input wire [1:0] memory_operation_m,  // Load/store memory interface or pipeline control.
  input wire [2:0] funct3_m,  // Function-3 used by the memory-stage datapath or control.
  input wire kill_d_cache_m,  // Cache-side data, address, or operation control.
  output wire committed_m,  // Indicates that a memory-stage access has committed.
  output wire d_cache_miss,  // Cache miss indication for line refill processing.
  output wire d_cache_access,  // Cache-side data, address, or operation control.
  output wire perf_d_cache_load_accept,  // Cache-side data, address, or operation control.
  output wire perf_d_cache_load_miss_start,  // Cache-side data, address, or operation control.
  output wire perf_d_cache_store_accept,  // Cache-side data, address, or operation control.
  output wire perf_d_cache_store_miss_start,  // Cache-side data, address, or operation control.
  output wire perf_d_cache_writeback_start,  // Cache-side data, address, or operation control.
  
  input wire [31:0] effective_address_e,  // Address operand or target address selection.
  output wire [31:0] effective_address_m,  // Address operand or target address selection.
  input wire [31:0] store_data_m,  // Store data used by the memory-stage datapath or control.
  output wire [31:0] load_data_w,  // Load data used by the writeback-stage datapath or control.
  output wire d_cache_hold_m,  // Backpressure caused by an unresolved cache operation.
  output wire [31:0] fault_address_m,  // Address operand or target address selection.
  
  output wire load_misaligned_fault_m,  // Load misaligned fault used by the memory-stage datapath or control.
  output wire load_access_fault_m,  // Load access fault used by the memory-stage datapath or control.
  
  output wire store_amo_misaligned_fault_m,  // Store amo misaligned fault used by the memory-stage datapath or control.
  output wire store_amo_access_fault_m,  // Store amo access fault used by the memory-stage datapath or control.
  
  output wire [31:0] memory_haddr,  // Load/store memory interface or pipeline control.
  input wire [31:0] hrdata,  // AHB read-data bus returned by the selected target.
  output wire [31:0] memory_hwdata,  // Load/store memory interface or pipeline control.
  input wire memory_hready,  // Completion handshake returned to the load/store path.
  input wire memory_hresp,  // Transfer error indication for the load/store path.
  output wire memory_hwrite,  // Load/store memory interface or pipeline control.
  output wire [2:0] memory_hsize,  // Load/store memory interface or pipeline control.
  output wire [2:0] memory_hburst,  // Load/store memory interface or pipeline control.
  output wire [1:0] memory_htrans,  // Load/store memory interface or pipeline control.
  output wire [3:0] memory_hwstrb  // Load/store memory interface or pipeline control.
);
  wire [31:0] p_adr_m;                                  
  wire [2:0] bus_transfer_size_m_node;                               

  wire data_bus_hold_m_node;                           
  wire d_cache_bus_hold_m_node;                        

  wire cacheable_m_node;                             
  wire bus_committed_m_node;                          
  wire d_cache_committed_m_node;                       

  wire [31:0] d_cache_read_data_word_m_node;                    
  wire [31:0] read_data_word_mux_m;                       
  wire [31:0] little_endian_read_data_word_m_node;              
  wire [31:0] read_data_m;                              

  wire [31:0] little_endian_write_data_m;                 
  wire [31:0] store_write_data_m_node;                          
  wire [3:0] byte_mask_m_node;                              

  wire pma_load_access_fault_m_node;                    
  wire pma_store_amo_access_fault_m_node;                
  wire memory_request_kill_w_node;                              
  wire self_fault_m_node;                             
  wire mem_bus_error_m_node;                           
  reg mem_bus_error_pending_m_node;                    
  reg mem_bus_error_load_q_node;
  reg mem_bus_error_store_q_node;
  reg [31:0] mem_bus_error_address_q_node;

  
  // Register stage data under the supplied clock, reset, and enable controls.
  ffenrc #(32) address_m_reg_u(clk, reset, kill_m, ~hold_m, effective_address_e, effective_address_m);
  
  
  // Update registered memory and request state on the clock edge.
  // Clock the mem_bus_error_pending_m, mem_bus_error_load_q state under the specified reset and enable conditions.
  always @(posedge clk) begin
    if (reset) begin
      mem_bus_error_pending_m_node <= 1'b0;
      mem_bus_error_load_q_node <= 1'b0;
      mem_bus_error_store_q_node <= 1'b0;
      mem_bus_error_address_q_node <= 1'b0;
    end else if (mem_bus_error_m_node) begin
      mem_bus_error_pending_m_node <= 1'b1;
      mem_bus_error_load_q_node <= memory_operation_m[1] & ~memory_operation_m[0];
      mem_bus_error_store_q_node <= memory_operation_m[0] | kill_d_cache_m;
      mem_bus_error_address_q_node <= effective_address_m;
    end else if (kill_m | (mem_bus_error_pending_m_node & ~hold_m)) begin
      mem_bus_error_pending_m_node <= 1'b0;
    end
  end

  // Memory request qualification combines access type, address, and bus readiness.
  assign fault_address_m = mem_bus_error_pending_m_node ? mem_bus_error_address_q_node : effective_address_m;
  assign load_access_fault_m = pma_load_access_fault_m_node |
                            (mem_bus_error_m_node & memory_operation_m[1] & ~memory_operation_m[0]) |
                            (mem_bus_error_pending_m_node & mem_bus_error_load_q_node);
  assign store_amo_access_fault_m = pma_store_amo_access_fault_m_node |
                                (mem_bus_error_m_node & (memory_operation_m[0] | kill_d_cache_m)) |
                                (mem_bus_error_pending_m_node & mem_bus_error_store_q_node);

  
  assign committed_m = d_cache_committed_m_node | bus_committed_m_node;
  assign d_cache_bus_hold_m_node = d_cache_hold_m | data_bus_hold_m_node;
  assign memory_hold_m = d_cache_bus_hold_m_node;

  
  assign bus_transfer_size_m_node = {1'b0, funct3_m[1:0]};

  
  // Select this hardware path from the active configuration.
  if(`CFG_ZICSR_SUPPORTED == 1) begin : data_pma_checks_gen 
    wire write_access_m;
    assign write_access_m = memory_operation_m[0];
    // Evaluate physical memory region permissions and access attributes.
    physical_memory_attributes #(.IMMU(0)) physical_memory_attributes_i_u(.address(effective_address_m), .size(funct3_m[1:0]),
      .physical_address(p_adr_m), .cacheable(cacheable_m_node), .idempotent(),
      .instr_access_fault_f(), .load_access_fault_m(pma_load_access_fault_m_node),
      .store_amo_access_fault_m(pma_store_amo_access_fault_m_node),
      .load_misaligned_fault_m(load_misaligned_fault_m), .store_amo_misaligned_fault_m(store_amo_misaligned_fault_m),
      .execute_access_f(1'b0),
      .write_access_m(write_access_m), .read_access_m(memory_operation_m[1]));
  end else begin  
    assign {pma_load_access_fault_m_node, pma_store_amo_access_fault_m_node, load_misaligned_fault_m, store_amo_misaligned_fault_m} = 1'b0;
    assign p_adr_m = effective_address_m[31:0];
    assign cacheable_m_node = 1'b1;
  end

  
  assign self_fault_m_node = pma_load_access_fault_m_node | pma_store_amo_access_fault_m_node |
                      load_misaligned_fault_m | store_amo_misaligned_fault_m;
  // Qualify pipeline cancellation using redirect or invalidation conditions.
  assign memory_request_kill_w_node = kill_w | self_fault_m_node;

  // Select this hardware path from the active configuration.
  if (`CFG_BUS_SUPPORTED) begin : bus
    // Select this hardware path from the active configuration.
    if(`CFG_DCACHE_SUPPORTED) begin : dcache
      localparam   llenwordsperline_node = `CFG_DCACHE_LINELENINBITS/(32'd32);             
      localparam   llenlogbwpl_node = $clog2(llenwordsperline_node);                       
      localparam   beatsperline_node = `CFG_DCACHE_LINELENINBITS/(32'd32);                 
      localparam   ahbwlogbwpl_node = $clog2(beatsperline_node);                           
      localparam   linelen_node = `CFG_DCACHE_LINELENINBITS;                             

      localparam   cachewordlen_node = (32'd32);

      wire [linelen_node-1:0] fetch_buffer;                                      
      wire [31:0] d_cache_bus_adr_node;                                     
      wire [ahbwlogbwpl_node-1:0] beat_count;                                        
      wire d_cache_bus_ack_node;                                     
      wire sel_bus_beat;                                       
      wire writeback_prefetch_en;
      wire refill_write_en;
      wire [ahbwlogbwpl_node-1:0] refill_beat;
      wire [31:0] refill_data;
      wire [1:0] cache_bus_rw;                                       
      wire [1:0] bus_rw;                                            
      wire cacheable_or_kill_cache_m;                           
      wire [1:0] cache_rwm_node;                                         
      wire kill_d_cache_node;
      assign bus_rw = ~cacheable_m_node ? memory_operation_m : 1'b0;
      assign cacheable_or_kill_cache_m = cacheable_m_node | kill_d_cache_m;
      assign cache_rwm_node = cacheable_m_node ? memory_operation_m : 1'b0;
      assign kill_d_cache_node = kill_d_cache_m;

      localparam                     linebytelen_node = `CFG_DCACHE_LINELENINBITS/8;            
      localparam                     offsetlen_node = $clog2(linebytelen_node);    
      localparam                     setlen_node = $clog2(`CFG_DCACHE_WAYSIZEINBYTES*8/linelen_node);          

      // Access the data cache or initiate a line transfer.
      cache_unit #(.linelen_node(`CFG_DCACHE_LINELENINBITS), .NUMSETS(`CFG_DCACHE_WAYSIZEINBYTES*8/linelen_node),
              .offsetlen_node(offsetlen_node), .setlen_node(setlen_node),
              .NUMWAYS(`CFG_DCACHE_NUMWAYS), .LOGBWPL(llenlogbwpl_node), .WORDLEN(cachewordlen_node), .MUXINTERVAL((32'd32)), .READ_ONLY_CACHE(0)) dcache(
        .word_window_enable(1'b0),
        .clk(clk), .reset(reset), .hold(hold_w), .sel_bus_beat(sel_bus_beat), .kill_stage(memory_request_kill_w_node),
        .cache_rw(cache_rwm_node),
        .kill_cache(kill_d_cache_node), .next_set(effective_address_e[offsetlen_node+setlen_node-1:0]), .p_adr(p_adr_m),
        .byte_mask(byte_mask_m_node), .beat_count(beat_count[ahbwlogbwpl_node-1:ahbwlogbwpl_node-llenlogbwpl_node]),
        .write_data(store_write_data_m_node),
        .cache_hold(d_cache_hold_m), .cache_miss(d_cache_miss), .cache_access(d_cache_access),
        .perf_request_accept(), .perf_miss_start(),
        .perf_load_accept(perf_d_cache_load_accept), .perf_load_miss_start(perf_d_cache_load_miss_start),
        .perf_store_accept(perf_d_cache_store_accept), .perf_store_miss_start(perf_d_cache_store_miss_start),
        .perf_writeback_start(perf_d_cache_writeback_start),
        .cache_committed(d_cache_committed_m_node),
        .cache_bus_adr(d_cache_bus_adr_node), .read_data_word(d_cache_read_data_word_m_node),
        .fetch_buffer(fetch_buffer), .refill_write_en(refill_write_en), .refill_beat(refill_beat), .refill_data(refill_data), .cache_bus_rw(cache_bus_rw),
        .cache_bus_ack(d_cache_bus_ack_node), .cache_bus_error(mem_bus_error_m_node), .writeback_prefetch_en(writeback_prefetch_en),
        .invalidate_cache(1'b0), .invalidate_kill_stage(memory_request_kill_w_node),
        .cache_word_window_valid());

      // Convert cache-line requests and responses into AHB transfer signals.
      ahb_cache_interface #(.beatsperline_node(beatsperline_node), .ahbwlogbwpl_node(ahbwlogbwpl_node), .linelen_node(linelen_node),  .READ_ONLY_CACHE(0)) ahb_cache_interface_i_u(
        .hclk(clk), .hrese_tn(~reset), .kill(memory_request_kill_w_node), .hresp(memory_hresp), .bus_error(mem_bus_error_m_node),
        .hrdata(hrdata), .hwdata(memory_hwdata), .hwstrb(memory_hwstrb),
        .hsize(memory_hsize), .hburst(memory_hburst), .htrans(memory_htrans), .hwrite(memory_hwrite), .hready(memory_hready),
        .beat_count(beat_count), .sel_bus_beat(sel_bus_beat), .writeback_prefetch_en(writeback_prefetch_en), .refill_write_en(refill_write_en), .refill_beat(refill_beat), .refill_data(refill_data),
        .cache_read_data_word_m(d_cache_read_data_word_m_node[31:0]), .store_data_m(store_write_data_m_node),
        .size(bus_transfer_size_m_node), .haddr(memory_haddr), .cache_bus_adr(d_cache_bus_adr_node), .cache_bus_rw(cache_bus_rw), .cacheable_or_kill_cache_m(cacheable_or_kill_cache_m),
        .cache_bus_ack(d_cache_bus_ack_node), .fetch_buffer(fetch_buffer), .p_adr(p_adr_m),
        .cacheable(cacheable_or_kill_cache_m), .bus_rw(bus_rw), .hold(hold_w),
        .bus_hold(data_bus_hold_m_node), .bus_committed(bus_committed_m_node));

      // Select the appropriate datapath value from the available inputs.
      mux2 #(32) un_cached_data_mux_u(.d0(d_cache_read_data_word_m_node), .d1(fetch_buffer[31:0]),
                                       .s(~cacheable_or_kill_cache_m), .generic_result(read_data_word_mux_m));
    end else begin : passthrough 
      wire [1:0] bus_rw;
      wire [31:0] fetch_buffer;
      assign bus_rw = memory_operation_m;

      assign memory_haddr = p_adr_m;
      assign memory_hsize = bus_transfer_size_m_node;

      // Convert non-cacheable fetch or data accesses into AHB transactions.
      ahb_direct_interface #(.DATA_PORT(1'b1)) ahb_direct_interface_i_u(.hclk(clk), .hrese_tn(~reset), .kill(memory_request_kill_w_node), .hready(memory_hready), .hresp(memory_hresp),
        .hrdata(hrdata), .htrans(memory_htrans), .hwrite(memory_hwrite), .hwdata(memory_hwdata),
        .hwstrb(memory_hwstrb), .bus_rw(bus_rw), .byte_mask(byte_mask_m_node[3:0]), .write_data(store_write_data_m_node[31:0]),
        .hold(hold_w), .bus_hold(data_bus_hold_m_node), .bus_committed(bus_committed_m_node), .bus_error(mem_bus_error_m_node), .fetch_buffer(fetch_buffer));

      // Select the active datapath source for this operation.
      assign read_data_word_mux_m[31:0] = fetch_buffer[31:0];
      assign memory_hburst = 3'b0;
      assign {d_cache_hold_m, d_cache_committed_m_node, d_cache_miss, d_cache_access, d_cache_read_data_word_m_node} = 1'b0;
      // Assert a cache miss event for the selected request.
      assign {perf_d_cache_load_accept, perf_d_cache_load_miss_start,
              perf_d_cache_store_accept, perf_d_cache_store_miss_start,
              perf_d_cache_writeback_start} = 5'b0;
    end
  end else begin : nobus
    // Select the address associated with the active request.
    assign {memory_hwdata, memory_haddr, memory_hwrite, memory_hsize, memory_hburst, memory_htrans, memory_hwstrb} = 1'b0;
    assign d_cache_read_data_word_m_node = 1'b0;
    assign read_data_word_mux_m = 1'b0;
    assign {data_bus_hold_m_node, bus_committed_m_node, mem_bus_error_m_node} = 1'b0;
    assign {d_cache_miss, d_cache_access} = 1'b0;
    assign {perf_d_cache_load_accept, perf_d_cache_load_miss_start,
            perf_d_cache_store_accept, perf_d_cache_store_miss_start,
            perf_d_cache_writeback_start} = 5'b0;
    // Qualify pipeline backpressure with the current request or stage state.
    assign {d_cache_hold_m, d_cache_committed_m_node} = 1'b0;
  end

  
  // Align and extend load data according to size and signedness.
  load_format load_format_i_u(.read_data_word_mux_m(little_endian_read_data_word_m_node), .p_adr_m(p_adr_m[1:0]),
    .funct3_m(funct3_m), .read_data_m(read_data_m));
  // Align store data to the addressed memory byte lanes.
  store_format store_format_i_u(.store_funct3_m(funct3_m), .store_data_m(store_data_m), .little_endian_write_data_m(little_endian_write_data_m));

  
  // Produce byte-lane write enables from transfer size and address.
  store_byte_mask #(32, 0) store_byte_mask_i_u(.size(funct3_m), .adr(p_adr_m[1:0]),
    .byte_mask(byte_mask_m_node), .byte_mask_extended());

  
  // Register stage data under the supplied clock, reset, and enable controls.
  ffen #(32) read_data_mw_reg_u(clk, ~hold_w, read_data_m, load_data_w);

  assign store_write_data_m_node = little_endian_write_data_m;
  assign little_endian_read_data_word_m_node = read_data_word_mux_m;
endmodule

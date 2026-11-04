// Maintains fetch PC and instruction alignment through the fetch and decode boundary.
// Coordinates prediction, instruction-cache access, pipeline Hold/Kill, and redirect recovery.


`include "config.vh"

module fetch_frontend    (
  input wire clk,  // Clock used for synchronous state updates.
  input wire reset,  // Resets the local state and pipeline registers.
  input wire hold_f,  // Holds the fetch PC and prevents front-end advancement.
  input wire hold_d,  // Holds the decode-stage instruction and control state.
  input wire hold_e,  // Holds execute-stage operands and control until accepted.
  input wire hold_m,  // Holds the memory-stage transaction and state.
  input wire hold_w,  // Backpressure condition preventing writeback advancement.
  input wire kill_d,  // Invalidates decoded work on redirects and pipeline cancellation.
  input wire kill_e,  // Cancels younger execute-stage work or injects a bubble.
  input wire kill_m,  // Invalidates the instruction entering the memory stage.
  input wire kill_w,  // Suppresses writeback for invalid or trapped instructions.
  output wire fetch_hold_f,  // Indicates that instruction delivery is not ready.
  
  input wire invalidate_i_cache_m,  // Cache-side data, address, or operation control.
  input wire csr_write_fence_m,  // Serializes pipeline work around a CSR or fence operation.
  input wire instr_valid_d,  // Instruction word, decoded field, or validity qualifier.
  input wire instr_valid_e,  // Instruction word, decoded field, or validity qualifier.
  input wire branch_d,  // Identifies a conditional branch in decode.
  input wire branch_e,  // Identifies a conditional branch in the execute stage.
  input wire jump_d,  // Decode-stage jump classification.
  input wire jump_e,  // Execute-stage jump classification.
  
  output wire [31:0] fetch_haddr,  // Instruction-fetch request, response, or control.
  input wire [31:0] hrdata,  // AHB read-data bus returned by the selected target.
  input wire fetch_hready,  // Completion handshake returned to the instruction fetch path.
  input wire fetch_hresp,  // Transfer error indication for instruction fetch.
  output wire fetch_hwrite,  // Instruction-fetch request, response, or control.
  output wire [2:0] fetch_hsize,  // Instruction-fetch request, response, or control.
  output wire [2:0] fetch_hburst,  // Instruction-fetch request, response, or control.
  output wire [1:0] fetch_htrans,  // Instruction-fetch request, response, or control.

  output wire [31:0] pc_spill_f /* synthesis PAP_MARK_DEBUG="true" */,  // Fetch PC after instruction-alignment selection.
  
  output wire [31:0] link_address_e,  // Address operand or target address selection.
  input wire pc_src_e,  // Resolved execute-stage branch or jump redirection decision.
  input wire [31:0] resolved_control_flow_address_e,  // Address operand or target address selection.
  input wire [31:0] effective_address_m,  // Address operand or target address selection.
  output wire [31:0] pce /* synthesis PAP_MARK_DEBUG="true" */,  // PC paired with the execute-stage instruction.
  output wire prediction_wrong_e,  // Branch prediction mismatch used for recovery.
  output wire prediction_wrong_m,  // Branch prediction mismatch used for recovery.
  
  output wire committed_f,  // Indicates that the fetch-side request was accepted or committed.
  input wire [31:0] epcm,  // Exception return PC read from machine exception state.
  input wire [31:0] trap_vector_m,  // Exception/interrupt control or trap entry information.
  input wire ret_m,  // Requests machine-mode return from a trap.
  input wire trap_m,  // Requests entry into a machine-mode exception or interrupt handler.
  output wire [31:0] instr_d /* synthesis PAP_MARK_DEBUG="true" */,  // Decoded-stage instruction word.
  output wire [31:0] instr_m /* synthesis PAP_MARK_DEBUG="true" */,  // Instruction word carried into the memory stage.
  output wire [31:0] original_instr_m,  // Instruction word, decoded field, or validity qualifier.
  output wire [31:0] pcm /* synthesis PAP_MARK_DEBUG="true" */,  // PC paired with the memory-stage instruction.
  output wire [31:0] pc_spill_m /* synthesis PAP_MARK_DEBUG="true" */,  // Memory-stage PC adjusted for split instruction handling.
  
  output wire [3:0] instruction_class_m /* synthesis PAP_MARK_DEBUG="true" */,  // Instruction word, decoded field, or validity qualifier.
  output wire direction_prediction_wrong_m,  // Branch prediction mismatch used for recovery.
  output wire target_prediction_wrong_m,  // Branch prediction mismatch used for recovery.
  output wire return_prediction_wrong_m,  // Branch prediction mismatch used for recovery.
  output wire instruction_class_wrong_m,  // Instruction word, decoded field, or validity qualifier.
  output wire i_cache_hold_f,  // Backpressure caused by an unresolved cache operation.
  
  input wire illegal_base_instr_d,  // Instruction word, decoded field, or validity qualifier.
  output wire illegal_instr_d,  // Instruction word, decoded field, or validity qualifier.
  output wire instr_misaligned_fault_m /* synthesis PAP_MARK_DEBUG="true" */,  // Instruction word, decoded field, or validity qualifier.
  output wire instr_access_fault_f,  // Instruction word, decoded field, or validity qualifier.
  output wire i_cache_access,  // Cache-side data, address, or operation control.
  output wire i_cache_miss,  // Cache miss indication for line refill processing.
  output wire perf_i_cache_request_accept /* synthesis PAP_MARK_DEBUG="true" */,  // Cache-side data, address, or operation control.
  output wire perf_i_cache_miss_start /* synthesis PAP_MARK_DEBUG="true" */  // Cache miss indication for line refill processing.
);

  localparam [31:0]            nop_node = 32'h00000013;                       
  localparam            linelen_node = `CFG_ICACHE_SUPPORTED ? `CFG_ICACHE_LINELENINBITS : (32'd32);

  wire [31:0] pc_next_f /* synthesis PAP_MARK_DEBUG="true" */;                                  
  wire [31:0] pc1_next_f;                                 
  wire [31:0] pc2_next_f_node;                                 
  wire [31:0] unaligned_pc_next_f_node;                         
  wire instr_misaligned_fault_e_node;                    
  wire [31:0] pc_plus2or4_f;                              
  wire [31:0] pc_spill_next_f;                             
  wire [31:2] pc_plus4_f;                                 
  // Program counter associated with the decode-stage instruction.
  wire [31:0] pcd /* synthesis PAP_MARK_DEBUG="true" */;                                      
  wire [31:0] next_valid_pce;                             
  // Current fetch-stage program counter.
  wire [31:0] pcf /* synthesis PAP_MARK_DEBUG="true" */;                                      
  wire [31:0] pcpf_node;                                     

  wire [31:0] i_cache_instr_f_node;                             
  wire [31:0] instr_raw_f;                                
  wire compressed_f;
  wire compressed_e_node;                 
  wire [31:0] post_spill_instr_raw_f /* synthesis PAP_MARK_DEBUG="true" */;                       
  wire [31:0] instr_raw_d;                                
  wire illegal_integer_instr_d_node;                         

  wire [1:0] fetch_read_command_f_node;                                   
  wire [31:0] instr_e_node /* synthesis PAP_MARK_DEBUG="true" */;                                   
  wire [31:0] next_instr_d_node;
  wire [31:0] next_instr_e_node;                   

  wire cacheable_f;                               
  wire sel_spill_next_f;                            
  wire sel_spill_f;
  wire bus_hold;                                 
  wire fetch_cache_bus_hold_f;                        
  wire gated_hold_d_node;                              
  
  wire bus_committed_f_node;                            
  wire cache_committed_f_node;                          
  wire cached_spill_ready_f;                        
  wire [linelen_node-1:0] fetch_buffer;
  wire [31:0] shift_uncached_instr_node;
  wire fetch_fault_f_node;                                
  wire instr_access_fault_raw_f_node;                     
  wire fetch_bus_error_f_node;                             
  reg fetch_bus_error_pending_f_node;                      

  
  // Select this hardware path from the active configuration.
  if(`CFG_ZCA_SUPPORTED) begin : Spill
    wire [31:0] pc_spill_d_node;
  wire [31:0] pc_spill_e_node;
    wire [31:0] pc_incr_m_node;
    wire sel_spill_d_node;
  wire sel_spill_e_node;
  wire sel_spill_m_node;
    // Combine fetched instruction fragments across alignment boundaries.
    instruction_assemble  spill_u(.clk(clk), .reset(reset), .hold_f(hold_f), .kill_d(kill_d), .pcf(pcf), .pc_plus4_f(pc_plus4_f), .pc_next_f(pc_next_f), .instr_raw_f(instr_raw_f),  .cacheable_f(cacheable_f),
      .instr_access_fault_f(instr_access_fault_raw_f_node),
      .fetch_cache_bus_hold_f(fetch_cache_bus_hold_f), .cached_spill_ready_f(cached_spill_ready_f), .pc_spill_next_f(pc_spill_next_f), .pc_spill_f(pc_spill_f), .sel_spill_next_f(sel_spill_next_f), .sel_spill_f(sel_spill_f),
      .post_spill_instr_raw_f(post_spill_instr_raw_f), .compressed_f(compressed_f));
    
    
    // Register stage data under the supplied clock, reset, and enable controls.
    ffenr #(1) spill_d_reg_u(clk, reset, ~hold_d, sel_spill_f, sel_spill_d_node);
    // Register stage data under the supplied clock, reset, and enable controls.
    ffenr #(1) spill_e_reg_u(clk, reset, ~hold_e, sel_spill_d_node, sel_spill_e_node);
    // Register stage data under the supplied clock, reset, and enable controls.
    ffenr #(1) spill_m_reg_u(clk, reset, ~hold_m, sel_spill_e_node, sel_spill_m_node);
    // Select the next fetch address from sequential progression or control-flow redirection.
    assign pc_incr_m_node = pcm + 'd2;
    // Select the PC source for the next fetch or recovery path.
    mux2 #(32) pcspillmmux_u(pcm, pc_incr_m_node, sel_spill_m_node, pc_spill_m);

  end else begin : NoSpill
    assign pc_spill_next_f = pc_next_f;
    assign pc_spill_f = pcf;
    // Assemble and validate the instruction presented to decode.
    // Align and select the instruction word passed to the next pipeline stage.
    assign post_spill_instr_raw_f = instr_raw_f;
    assign {sel_spill_next_f, sel_spill_f, compressed_f} = 1'b0;
    assign pc_spill_m = pcm;
  end

  
  // Update registered pipeline or controller state on the clock edge.
  // Clock the fetch_bus_error_pending_f, fetch_bus_error_pending_f state under the specified reset and enable conditions.
  always @(posedge clk) begin
    if (reset | kill_d) fetch_bus_error_pending_f_node <= 1'b0;
    else if (fetch_bus_error_f_node) fetch_bus_error_pending_f_node <= 1'b1;
    else if (~hold_d) fetch_bus_error_pending_f_node <= 1'b0;
  end
  // Align and select the instruction word passed to the next pipeline stage.
  assign instr_access_fault_f = instr_access_fault_raw_f_node | fetch_bus_error_f_node | fetch_bus_error_pending_f_node;

  
  // Evaluate physical memory region permissions and access attributes.
  physical_memory_attributes #(.IMMU(1)) pma_u(.address(pc_spill_f), .size(2'b10), .physical_address(pcpf_node),
       .cacheable(cacheable_f), .idempotent(),
       .instr_access_fault_f(instr_access_fault_raw_f_node), .load_access_fault_m(), .store_amo_access_fault_m(),
       .load_misaligned_fault_m(), .store_amo_misaligned_fault_m(),
       .execute_access_f(1'b1), .write_access_m(1'b0), .read_access_m(1'b0));

  
  // Align and select the instruction word passed to the next pipeline stage.
  assign fetch_fault_f_node = instr_access_fault_f;

  
  assign committed_f = cache_committed_f_node | bus_committed_f_node;

  assign fetch_read_command_f_node = 2'b10;
  // Select this hardware path from the active configuration.
  if (`CFG_BUS_SUPPORTED) begin : bus
    localparam   beatsperline_node = `CFG_ICACHE_SUPPORTED ? `CFG_ICACHE_LINELENINBITS/(32'd32) : 1;
    localparam   ahbwlogbwpl_node = `CFG_ICACHE_SUPPORTED ? $clog2(beatsperline_node) : 1;

    // Select this hardware path from the active configuration.
    if(`CFG_ICACHE_SUPPORTED) begin : icache

      localparam            linebytelen_node = `CFG_ICACHE_LINELENINBITS/8;            
      localparam            offsetlen_node = $clog2(linebytelen_node);    
      localparam            setlen_node = $clog2(`CFG_ICACHE_WAYSIZEINBYTES*8/linelen_node);          
      wire [31:0] i_cache_bus_adr_node;
      wire i_cache_bus_ack_node;
      wire [1:0] cache_bus_rw;
  wire [1:0] bus_rw;
  wire [1:0] cache_rwf_node;
      wire refill_write_en;
      wire [ahbwlogbwpl_node-1:0] refill_beat;
      wire [31:0] refill_data;

      assign bus_rw = ~cacheable_f & ~fetch_fault_f_node ? fetch_read_command_f_node : 1'b0;
      assign cache_rwf_node = cacheable_f & ~fetch_fault_f_node ? fetch_read_command_f_node : 1'b0;
      cache_unit #(.linelen_node(`CFG_ICACHE_LINELENINBITS),
              .NUMSETS(`CFG_ICACHE_WAYSIZEINBYTES*8/`CFG_ICACHE_LINELENINBITS),
              .offsetlen_node(offsetlen_node), .setlen_node(setlen_node),
              .NUMWAYS(`CFG_ICACHE_NUMWAYS), .LOGBWPL(ahbwlogbwpl_node), .WORDLEN(32), .MUXINTERVAL(16), .READ_ONLY_CACHE(1))
      icache(.clk(clk), .reset(reset), .kill_stage(kill_d), .hold(gated_hold_d_node),
             .word_window_enable(~sel_spill_f),
             .fetch_buffer(fetch_buffer), .cache_bus_ack(i_cache_bus_ack_node), .cache_bus_error(fetch_bus_error_f_node),
             .refill_write_en(refill_write_en), .refill_beat(refill_beat), .refill_data(refill_data),
             .cache_bus_adr(i_cache_bus_adr_node), .cache_hold(i_cache_hold_f),
             .cache_bus_rw(cache_bus_rw),
             .read_data_word(i_cache_instr_f_node),
             .cache_word_window_valid(cached_spill_ready_f),
             .cache_miss(i_cache_miss), .cache_access(i_cache_access),
             .perf_request_accept(perf_i_cache_request_accept), .perf_miss_start(perf_i_cache_miss_start),
             .perf_load_accept(), .perf_load_miss_start(), .perf_store_accept(),
             .perf_store_miss_start(), .perf_writeback_start(),
             .byte_mask(1'b0), .beat_count(1'b0), .sel_bus_beat(1'b0), .writeback_prefetch_en(1'b0),
             .write_data(1'b0),
             .cache_rw(cache_rwf_node),
             .kill_cache(1'b0),
             .next_set(pc_spill_next_f[offsetlen_node+setlen_node-1:0]),
             .p_adr(pcpf_node),
             .cache_committed(cache_committed_f_node), .invalidate_cache(invalidate_i_cache_m), .invalidate_kill_stage(kill_w));

      ahb_cache_interface #(.beatsperline_node(beatsperline_node), .ahbwlogbwpl_node(ahbwlogbwpl_node), .linelen_node(linelen_node), .READ_ONLY_CACHE(1))
      ahb_cache_interface_i_u(.hclk(clk), .hrese_tn(~reset),
            .hrdata(hrdata), .hresp(fetch_hresp), .bus_error(fetch_bus_error_f_node),
            .kill(kill_d), .cache_bus_rw(cache_bus_rw), .hsize(fetch_hsize), .hburst(fetch_hburst), .htrans(fetch_htrans), .hwstrb(),
            .size(3'b010), .haddr(fetch_haddr), .hready(fetch_hready), .hwrite(fetch_hwrite), .cache_bus_adr(i_cache_bus_adr_node),
            .beat_count(), .cacheable(cacheable_f), .sel_bus_beat(), .writeback_prefetch_en(),
            .refill_write_en(refill_write_en), .refill_beat(refill_beat), .refill_data(refill_data), .store_data_m(1'b0),
            .cache_bus_ack(i_cache_bus_ack_node), .hwdata(), .cacheable_or_kill_cache_m(1'b0), .cache_read_data_word_m(1'b0),
            .fetch_buffer(fetch_buffer), .p_adr(pcpf_node),
            .bus_rw(bus_rw), .hold(gated_hold_d_node),
            .bus_hold(bus_hold), .bus_committed(bus_committed_f_node));

      // Select the appropriate datapath value from the available inputs.
      mux2 #(32) un_cached_data_mux_u(.d0(i_cache_instr_f_node), .d1(shift_uncached_instr_node),
                                 .s(~cacheable_f), .generic_result(instr_raw_f[31:0]));
    end else begin : passthrough
      // Select the address associated with the active request.
      assign fetch_haddr = pcpf_node;
      wire [1:0] bus_rw;
      assign bus_rw = ~fetch_fault_f_node ? fetch_read_command_f_node : 0;
      assign fetch_hsize = 3'b010;

      // Convert non-cacheable fetch or data accesses into AHB transactions.
      ahb_direct_interface #(.DATA_PORT(1'b0)) ahb_direct_interface_i_u(.hclk(clk), .kill(kill_d), .hrese_tn(~reset), .hready(fetch_hready), .hresp(fetch_hresp),
        .hrdata(hrdata), .htrans(fetch_htrans), .hwrite(fetch_hwrite), .hwdata(),
        .hwstrb(), .bus_rw(bus_rw), .byte_mask(), .write_data(1'b0),
        .hold(gated_hold_d_node), .bus_hold(bus_hold), .bus_committed(bus_committed_f_node), .bus_error(fetch_bus_error_f_node), .fetch_buffer(fetch_buffer));

      assign cache_committed_f_node = 1'b0;
      // Select or format the instruction for the next pipeline stage.
      // Align and select the instruction word passed to the next pipeline stage.
      assign instr_raw_f = shift_uncached_instr_node;
      assign fetch_hburst = 3'b0;
      assign {i_cache_miss, i_cache_access, i_cache_hold_f} = 1'b0;
      assign {perf_i_cache_request_accept, perf_i_cache_miss_start} = 2'b0;
      assign cached_spill_ready_f = 1'b0;
    end

    
    // Choose the instruction value forwarded to the next pipeline stage.
    mux2 #(32) uncached_shift_instr_mux_u(fetch_buffer[31:0], {16'b0, fetch_buffer[31:16]}, pc_spill_f[1], shift_uncached_instr_node);
  end else begin : nobus 
    assign {fetch_haddr, fetch_hwrite, fetch_hsize, fetch_hburst, fetch_htrans,
            bus_hold, cache_committed_f_node, bus_committed_f_node, fetch_buffer, fetch_bus_error_f_node} = 1'b0;
    // Qualify pipeline backpressure with the current request or stage state.
    assign {i_cache_hold_f, i_cache_miss, i_cache_access} = 1'b0;
    assign {perf_i_cache_request_accept, perf_i_cache_miss_start} = 2'b0;
    assign cached_spill_ready_f = 1'b0;
    // Align and select the instruction word passed to the next pipeline stage.
    assign instr_raw_f = 1'b0;
  end

  assign fetch_cache_bus_hold_f = i_cache_hold_f | bus_hold;
  assign fetch_hold_f = fetch_cache_bus_hold_f | sel_spill_next_f;
  assign gated_hold_d_node = hold_d & ~sel_spill_next_f;

  // Pipeline the instruction word while honoring stage enable and clear.
  ffenl #(32) aligned_instr_raw_dff_u(clk, reset | kill_d, ~hold_d, post_spill_instr_raw_f, nop_node, instr_raw_d);

  
  // Select this hardware path from the active configuration.
  if(`CFG_ZICSR_SUPPORTED | `CFG_ZIFENCEI_SUPPORTED)
    // Select the PC source for the next fetch or recovery path.
    mux2 #(32) pcmux2_u(.d0(pc1_next_f), .d1(next_valid_pce), .s(csr_write_fence_m),.generic_result(pc2_next_f_node));
  else assign pc2_next_f_node = pc1_next_f;

  // Select the PC source for the next fetch or recovery path.
  mux3 #(32) pcmux3_u(pc2_next_f_node, epcm, trap_vector_m, {trap_m, ret_m}, unaligned_pc_next_f_node);
  localparam [31:0] reset_vector_xlen_node = `CFG_RESET_VECTOR;
  // Select the PC source for the next fetch or recovery path.
  mux2 #(32) pcresetmux_u({unaligned_pc_next_f_node[31:1], 1'b0}, reset_vector_xlen_node, reset, pc_next_f);
  // Hold the fetch address while the frontend is blocked.
  // Fetch PC changes only when the stage accepts an update or reset is active.
  // Register the associated stage PC using the configured Hold and reset behavior.
  ffen #(32) pcreg_u(clk, ~hold_f | reset, pc_next_f, pcf);

  
  // Select the next fetch address from sequential progression or control-flow redirection.
  assign pc_plus4_f = pcf[31:2] + 1; 

  // Select this hardware path from the active configuration.
  if (`CFG_ZCA_SUPPORTED) begin : pcadd
    reg [31:0] pc_plus2or4_comb_f_node;
    assign pc_plus2or4_f = pc_plus2or4_comb_f_node;
    
    
    // Compute combinational control and data selections.
    // Compute the combinational outputs from the current data and control inputs.
    always @*
      if (compressed_f) 
        if (pcf[1]) pc_plus2or4_comb_f_node = {pc_plus4_f, 2'b00};
        else        pc_plus2or4_comb_f_node = {pcf[31:2], 2'b10};
      else          pc_plus2or4_comb_f_node = {pc_plus4_f, pcf[1:0]}; 
  end else begin : pcadd
    // Select the next fetch address from sequential progression or control-flow redirection.
    assign pc_plus2or4_f = {pc_plus4_f, pcf[1:0]}; 
  end

  
  if (`CFG_BRANCH_PREDICTOR_ENABLE) begin : branch_predictor_gen
    // Provide predicted target and direction for fetch selection.
  // Predictor outputs guide speculative fetch and are checked against resolved flow.
    // Combine direction, target, and return predictions for the fetch PC.
    branch_predictor  branch_predictor_i_u(.clk(clk), .reset(reset),
                .FetchHold(hold_f), .DecodeHold(hold_d), .ExecuteHold(hold_e), .MemoryHold(hold_m), .WritebackHold(hold_w),
                .DecodeKill(kill_d), .ExecuteKill(kill_e), .MemoryKill(kill_m), .WritebackKill(kill_w), .instr_valid_d(instr_valid_d), .instr_valid_e(instr_valid_e),
                .branch_d(branch_d), .branch_e(branch_e), .jump_d(jump_d), .jump_e(jump_e),
                .instr_d(instr_d), .pc_next_f(pc_next_f), .pc_plus2or4_f(pc_plus2or4_f), .pc1_next_f(pc1_next_f), .pce(pce), .pcm(pcm), .pc_src_e(pc_src_e), .resolved_control_flow_address_e(resolved_control_flow_address_e), .effective_address_m(effective_address_m), .pcf(pcf), .next_valid_pce(next_valid_pce),
                .pcd(pcd), .link_address_e(link_address_e), .instruction_class_m(instruction_class_m), .prediction_wrong_e(prediction_wrong_e), .post_spill_instr_raw_f(post_spill_instr_raw_f), .prediction_wrong_m(prediction_wrong_m),
                .direction_prediction_wrong_m(direction_prediction_wrong_m), .target_prediction_wrong_m(target_prediction_wrong_m), .return_prediction_wrong_m(return_prediction_wrong_m), .instruction_class_wrong_m(instruction_class_wrong_m));

  end else begin : no_dynamic_prediction_gen
    // No GShare/PHT, BTB, or return-address stack is instantiated in this mode.
    // Fetch sequentially. On a resolved taken branch or jump, compare the
    // correct next PC with the instruction currently in decode. This is the
    // same PC recovery test used by branch_predictor in the enabled mode.
    wire [31:0] resolved_next_pce_node;
    wire [31:0] selected_next_address_node;
    wire branch_m_node, branch_w_node;
    wire jump_m_node, jump_w_node;
    wire call_d_node, call_e_node, call_m_node, call_w_node;
    wire return_d_node, return_e_node, return_m_node, return_w_node;

    assign resolved_next_pce_node = pc_src_e ? resolved_control_flow_address_e
                                             : link_address_e;
    assign selected_next_address_node = prediction_wrong_e ? resolved_next_pce_node
                                                            : pc_plus2or4_f;
    assign pc1_next_f = selected_next_address_node;
    assign prediction_wrong_e = instr_valid_e & instr_valid_d &
                                (resolved_next_pce_node != pcd);

    // Preserve the exact enable/kill behavior of the dynamic prediction path;
    // required by trap/fence redirection and performance monitoring.
    ffenrc #(1) sequential_redirect_m_reg_u(
      clk, reset, kill_m, ~hold_m, prediction_wrong_e, prediction_wrong_m);
    assign next_valid_pce = prediction_wrong_m ? pcf : pce;

    // Instruction classification is not dynamic prediction. Keep it so that
    // branch/CFI counters and CSR HPM event selection still work with BP off.
    // All BTB prediction inputs are tied low, and their prediction outputs
    // are unused; synthesis removes the unused class-error machinery.
    instruction_class class_without_predictor_u(
      .clk(clk), .reset(reset), .DecodeHold(hold_d), .ExecuteHold(hold_e),
      .MemoryHold(hold_m), .WritebackHold(hold_w),
      .DecodeKill(kill_d), .ExecuteKill(kill_e), .MemoryKill(kill_m),
      .post_spill_instr_raw_f(post_spill_instr_raw_f), .instr_d(instr_d),
      .branch_d(branch_d), .branch_e(branch_e), .jump_d(jump_d), .jump_e(jump_e),
      .btb_call_f(1'b0), .btb_return_f(1'b0),
      .btb_jump_f(1'b0), .btb_branch_f(1'b0),
      .branch_m(branch_m_node), .branch_w(branch_w_node),
      .jump_m(jump_m_node), .jump_w(jump_w_node),
      .call_d(call_d_node), .call_e(call_e_node),
      .call_m(call_m_node), .call_w(call_w_node),
      .return_d(return_d_node), .return_e(return_e_node),
      .return_m(return_m_node), .return_w(return_w_node),
      .predicted_call_f(), .predicted_return_f(),
      .predicted_jump_f(), .predicted_branch_f(),
      .instruction_class_wrong_m(), .return_class_wrong_d(),
      .predicted_return_d());
    assign instruction_class_m = {call_m_node, return_m_node,
                                  jump_m_node, branch_m_node};

    // No predictor-specific errors exist when BP is absent. Redirects (taken
    // branches/jumps) are still counted via prediction_wrong_m. Under the
    // sequential-fetch policy this represents the static not-taken misses.
    assign direction_prediction_wrong_m = 1'b0;
    assign target_prediction_wrong_m = 1'b0;
    assign return_prediction_wrong_m = 1'b0;
    assign instruction_class_wrong_m = 1'b0;
  end

  // Register the associated stage PC using the configured Hold and reset behavior.
  ffenrc #(32) pcd_reg_u(clk, reset, kill_d, ~hold_d, pcf, pcd);

  
  // Select this hardware path from the active configuration.
  if (`CFG_ZCA_SUPPORTED) begin : decomp_u
    wire illegal_comp_instr_d;
    // Expand compressed instructions into standard instruction encodings.
    compressed_decode  decomp_u(.instr_raw_d(instr_raw_d), .instr_d(instr_d), .illegal_comp_instr_d(illegal_comp_instr_d));
    // Align and select the instruction word passed to the next pipeline stage.
    assign illegal_integer_instr_d_node = illegal_base_instr_d | illegal_comp_instr_d; 
  end else begin : decomp_u
    assign instr_d = instr_raw_d;
    assign illegal_integer_instr_d_node = illegal_base_instr_d;
  end
  assign illegal_instr_d = illegal_integer_instr_d_node;

  
  // Align and select the instruction word passed to the next pipeline stage.
  assign instr_misaligned_fault_e_node = (resolved_control_flow_address_e[1] & ~`CFG_ZCA_SUPPORTED) & pc_src_e;
  // Pipeline the instruction word while honoring stage enable and clear.
  ffenrc #(1) instr_misaligned_reg_u(clk, reset, kill_m, ~hold_m, instr_misaligned_fault_e_node, instr_misaligned_fault_m);

  
  // Choose the instruction value forwarded to the next pipeline stage.
  mux2    #(32)     kill_instr_e_mux_u(instr_d, nop_node, kill_e, next_instr_d_node);
  // Pipeline the instruction word while honoring stage enable and clear.
  ffenr #(32)     instr_e_reg_u(clk, reset, ~hold_e, next_instr_d_node, instr_e_node);
  // The execute PC follows the corresponding decode-stage instruction.
  // Register the associated stage PC using the configured Hold and reset behavior.
  ffenr #(32) pce_reg_u(clk, reset, ~hold_e, pcd, pce);

  
  // Choose the instruction value forwarded to the next pipeline stage.
  mux2    #(32)     kill_instr_m_mux_u(instr_e_node, nop_node, kill_m, next_instr_e_node);
  // Pipeline the instruction word while honoring stage enable and clear.
  ffenr #(32)     instr_m_reg_u(clk, reset, ~hold_m, next_instr_e_node, instr_m);
  // Register the associated stage PC using the configured Hold and reset behavior.
  ffenr #(32) pcm_reg_u(clk, reset, ~hold_m, pce, pcm);

  
  // Select this hardware path from the active configuration.
  if (`CFG_ZCA_SUPPORTED) begin
    wire compressed_d_node;  
    // Register stage data under the supplied clock, reset, and enable controls.
    ffenrc #(1) compressed_d_reg_u(clk, reset, kill_d, ~hold_d, compressed_f, compressed_d_node);
    // Register stage data under the supplied clock, reset, and enable controls.
    ffenrc #(1) compressed_e_reg_u(clk, reset, kill_e, ~hold_e, compressed_d_node, compressed_e_node);
    // Select the address associated with the active request.
    assign link_address_e = pce + (compressed_e_node ? 'd2 : 'd4); 
  end else begin
    assign compressed_e_node = 1'b0;
    assign link_address_e = pce + 'd4;
  end

  
  // Select this hardware path from the active configuration.
  if (`CFG_ZICSR_SUPPORTED & `CFG_ZCA_SUPPORTED) begin
    wire compressed_m_node; 
    wire [15:0] instr_raw_e_node;
  wire [15:0] instr_raw_m_node;
    // Pipeline the instruction word while honoring stage enable and clear.
    ffenrc #(16) instr_raw_e_reg_u(clk, reset, kill_e, ~hold_e, instr_raw_d[15:0], instr_raw_e_node);
    // Pipeline the instruction word while honoring stage enable and clear.
    ffenrc #(16) instr_raw_m_reg_u(clk, reset, kill_m, ~hold_m, instr_raw_e_node, instr_raw_m_node);
    // Register stage data under the supplied clock, reset, and enable controls.
    ffenrc #(1)  compressed_m_reg_u(clk, reset, kill_m, ~hold_m, compressed_e_node, compressed_m_node);
    // Choose the instruction value forwarded to the next pipeline stage.
    mux2     #(32) instr_orig_mux_u(instr_m, {16'b0, instr_raw_m_node}, compressed_m_node, original_instr_m);
  end else
    // Align and select the instruction word passed to the next pipeline stage.
    assign original_instr_m = instr_m;

endmodule

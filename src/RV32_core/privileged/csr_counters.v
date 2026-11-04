// Implements machine-level cycle, instruction, and event counters.
// Handles counter reads, updates, and inhibit controls.


`include "config.vh"

module csr_counters     (
  input wire clk,  // Clock used for synchronous state updates.
  input wire reset,  // Resets the local state and pipeline registers.
  input wire hold_e,  // Holds execute-stage operands and control until accepted.
  input wire hold_m,  // Holds the memory-stage transaction and state.
  input wire hold_w,  // Backpressure condition preventing writeback advancement.
  input wire kill_m,  // Invalidates the instruction entering the memory stage.
  input wire instr_valid_not_flushed_m,  // Instruction word, decoded field, or validity qualifier.
  input wire load_hold_d,  // Prevents the corresponding pipeline stage from advancing.
  input wire store_hold_d,  // Prevents the corresponding pipeline stage from advancing.
  input wire csrm_write_m,  // Control and status register access or state.
  input wire csr_write_m,  // Control and status register access or state.
  input wire direction_prediction_wrong_m,  // Branch prediction mismatch used for recovery.
  input wire target_prediction_wrong_m,  // Branch prediction mismatch used for recovery.
  input wire return_prediction_wrong_m,  // Branch prediction mismatch used for recovery.
  input wire instruction_class_wrong_m,  // Instruction word, decoded field, or validity qualifier.
  input wire prediction_wrong_m,  // Branch prediction mismatch used for recovery.
  input wire [3:0] instruction_class_m,  // Instruction word, decoded field, or validity qualifier.
  input wire d_cache_miss,  // Cache miss indication for line refill processing.
  input wire d_cache_access,  // Cache-side data, address, or operation control.
  input wire i_cache_miss,  // Cache miss indication for line refill processing.
  input wire i_cache_access,  // Cache-side data, address, or operation control.
  input wire i_cache_hold_f,  // Backpressure caused by an unresolved cache operation.
  input wire d_cache_hold_m,  // Backpressure caused by an unresolved cache operation.
  input wire interrupt_m,  // Pending, enabled, or selected interrupt condition.
  input wire trap_m,  // Requests entry into a machine-mode exception or interrupt handler.
  input wire invalidate_i_cache_m,  // Cache-side data, address, or operation control.
  input wire div_busy_e,  // Indicates an outstanding iterative division.
  input wire [11:0] csr_adr_m,  // Control and status register access or state.
  input wire [31:0] csr_write_val_m,  // Control and status register access or state.
  input wire [31:0] mcountinhibit_regw,  // Provides mcountinhibit regw for this module.
  input wire [63:0] mtime_clint,  // 64-bit machine timer value from the local interrupt timer.
  output reg [31:0] csrc_read_val_m,  // Control and status register access or state.
  output reg illegal_csrc_access_m  // First ALU operand or operand selector.
);

  localparam mhpmcounterbase_node  = 12'hB00;
  localparam mtime            = 12'hB01;               
  localparam mhpmcounterhbase_node = 12'hB80;
  localparam mtimeh_node           = 12'hB81;               
  localparam mhpmeventbase_node    = 12'h323;
  localparam mhpmeventlast_node    = 12'h33F;
  
  localparam hpmeventtop_node      = `CFG_COUNTERS > 3 ? `CFG_COUNTERS - 1 : 3;
  localparam hpmcounterbase_node   = 12'hC00;
  localparam hpmcounterhbase_node  = 12'hC80;
  localparam time_node             = 12'hC01;
  localparam timeh_node            = 12'hC81;

  wire [4:0] counter_num_m_node;
  reg [31:0] hpmcounter_regw_node[`CFG_COUNTERS-1:0];
  reg [31:0] hpmcounterh_regw_node[`CFG_COUNTERS-1:0];
  wire [31:0] mhpmevent_regw_node[hpmeventtop_node:3];
  wire load_hold_e_node;
  wire load_hold_m_node;
  wire store_hold_e_node;
  wire store_hold_m_node;
  wire [`CFG_COUNTERS-1:0] write_hpmcounterm_node;
  wire [`CFG_COUNTERS-1:0] write_hpmcounterhm_node;
  wire [hpmeventtop_node:3] write_mhpmeventm_node;
  wire [31:0] counter_event_node; 
  wire [`CFG_COUNTERS-1:0] counter_inc_node;
  wire [63:0] hpmcounter_plus_m_node[`CFG_COUNTERS-1:0];
  wire [31:0] next_hpmcounterhm_node[`CFG_COUNTERS-1:0];
  wire [31:0] next_hpmcounterm_node[`CFG_COUNTERS-1:0];
  wire [31:0] next_mhpmeventm_node[hpmeventtop_node:3];

  genvar                   i_node;

  
  // Register stage data under the supplied clock, reset, and enable controls.
  ffenrc #(1) store_hold_e_reg_u(.clk(clk), .reset(reset), .clear(1'b0), .en(~hold_e), .d(store_hold_d), .q(store_hold_e_node));  
  // Register stage data under the supplied clock, reset, and enable controls.
  ffenrc #(1) store_hold_m_reg_u(.clk(clk), .reset(reset), .clear(kill_m), .en(~hold_m), .d(store_hold_e_node), .q(store_hold_m_node));

  // Register stage data under the supplied clock, reset, and enable controls.
  ffenrc #(1) load_hold_e_reg_u(.clk(clk), .reset(reset), .clear(1'b0), .en(~hold_e), .d(load_hold_d), .q(load_hold_e_node));  
  // Register stage data under the supplied clock, reset, and enable controls.
  ffenrc #(1) load_hold_m_reg_u(.clk(clk), .reset(reset), .clear(kill_m), .en(~hold_m), .d(load_hold_e_node), .q(load_hold_m_node));

  
  // Form the counter update value from the current event or state.
  assign counter_event_node[0]    = 1'b1;                                                      
  assign counter_event_node[1]    = 1'b0;                                                      
  assign counter_event_node[2]    = instr_valid_not_flushed_m;                                     
  // Select this hardware path from the active configuration.
  if (`CFG_COUNTERS > 3) begin : cevent                                                   
    
    
    assign counter_event_node[3]  = instruction_class_m[0] & instr_valid_not_flushed_m;                        
    assign counter_event_node[4]  = instruction_class_m[1] & ~instruction_class_m[2] & instr_valid_not_flushed_m;          
    assign counter_event_node[5]  = instruction_class_m[2] & instr_valid_not_flushed_m;                        
    assign counter_event_node[6]  = prediction_wrong_m & instr_valid_not_flushed_m;                          
    assign counter_event_node[7]  = direction_prediction_wrong_m & instr_valid_not_flushed_m;                       
    assign counter_event_node[8]  = target_prediction_wrong_m & instr_valid_not_flushed_m;                         
    assign counter_event_node[9]  = return_prediction_wrong_m & instr_valid_not_flushed_m;                   
    assign counter_event_node[10] = instruction_class_wrong_m & instr_valid_not_flushed_m;                      
    assign counter_event_node[11] = load_hold_m_node;                                                
    assign counter_event_node[12] = store_hold_m_node;                                               
    assign counter_event_node[13] = d_cache_access;                                              
    assign counter_event_node[14] = d_cache_miss;                                                
    assign counter_event_node[15] = d_cache_hold_m;                                              
    assign counter_event_node[16] = i_cache_access;                                              
    assign counter_event_node[17] = i_cache_miss;                                                
    assign counter_event_node[18] = i_cache_hold_f;                                              
    assign counter_event_node[19] = csr_write_m & instr_valid_not_flushed_m;                         
    assign counter_event_node[20] = invalidate_i_cache_m & instr_valid_not_flushed_m;                 
    assign counter_event_node[21] = 1'b0;                                                      
    assign counter_event_node[22] = trap_m & ~hold_w & interrupt_m;                              
    assign counter_event_node[23] = trap_m & ~hold_w & ~interrupt_m;                             
    assign counter_event_node[24] = div_busy_e;                                                   
    assign counter_event_node[31:25] = 1'b0; 
  end else begin : cevent
    // Form the counter update value from the current event or state.
    assign counter_event_node[31:3] = 1'b0;
  end

  
  // Apply the same combinational operation to each configured element.
  for (i_node = 0; i_node < `CFG_COUNTERS; i_node = i_node+1) begin : cntr
      assign write_hpmcounterm_node[i_node] = csrm_write_m & (csr_adr_m == mhpmcounterbase_node + i_node); // coverage tag: MTIME traps
      assign next_hpmcounterm_node[i_node][31:0] = write_hpmcounterm_node[i_node] ? csr_write_val_m : hpmcounter_plus_m_node[i_node][31:0];
      if (i_node < 3) assign counter_inc_node[i_node] = counter_event_node[i_node] & ~mcountinhibit_regw[i_node]; 
      else       assign counter_inc_node[i_node] = counter_event_node[i_node] & ~mcountinhibit_regw[i_node] & (mhpmevent_regw_node[i_node] != 0); 
      // Capture CSR or trap state on the clock edge.
      // Updates sequential state on the specified clock event.
      // Update sequential state on the active clock edge, respecting reset and enables.
      always @(posedge clk)
        if (reset) hpmcounter_regw_node[i_node][31:0] <= 1'b0;
        else       hpmcounter_regw_node[i_node][31:0] <= next_hpmcounterm_node[i_node];

      // Form the counter update value from the current event or state.
      assign hpmcounter_plus_m_node[i_node] = {hpmcounterh_regw_node[i_node], hpmcounter_regw_node[i_node]} + {63'b0, counter_inc_node[i_node]};
      assign write_hpmcounterhm_node[i_node] = csrm_write_m & (csr_adr_m == mhpmcounterhbase_node + i_node);
      assign next_hpmcounterhm_node[i_node] = write_hpmcounterhm_node[i_node] ? csr_write_val_m : hpmcounter_plus_m_node[i_node][63:32];
      // Updates sequential state on the specified clock event.
      // Clock the event_q state under the specified reset and enable conditions.
      always @(posedge clk)
          if (reset) hpmcounterh_regw_node[i_node] <= 1'b0;
          else       hpmcounterh_regw_node[i_node] <= next_hpmcounterhm_node[i_node];
  end

  
  // Select this hardware path from the active configuration.
  if (`CFG_COUNTERS > 3) begin : mhpmeventgen
    // Apply the same combinational operation to each configured element.
    for (i_node = 3; i_node < `CFG_COUNTERS; i_node = i_node+1) begin : mhpmevent
      reg [31:0] event_q_node;
      assign mhpmevent_regw_node[i_node] = event_q_node;
      assign write_mhpmeventm_node[i_node] = csrm_write_m & (csr_adr_m == mhpmeventbase_node + i_node - 3);
      assign next_mhpmeventm_node[i_node] = write_mhpmeventm_node[i_node] ? csr_write_val_m : mhpmevent_regw_node[i_node];
      // Updates sequential state on the specified clock event.
      // Clock the event_q, event_q state under the specified reset and enable conditions.
      always @(posedge clk)
        if (reset) event_q_node <= 1'b0;
        else       event_q_node <= next_mhpmeventm_node[i_node];
    end
  end else begin : mhpmeventgen 
    assign write_mhpmeventm_node = 1'b0;
    assign next_mhpmeventm_node[3] = 1'b0;
    assign mhpmevent_regw_node[3] = 1'b0;
  end

  
  // Form the counter update value from the current event or state.
  assign counter_num_m_node = csr_adr_m[4:0]; 
  // Compute combinational control and data selections.
  // Compute the combinational outputs from the current data and control inputs.
  always @* begin
    csrc_read_val_m = 1'b0; 
    illegal_csrc_access_m = 1'b0;
    if (csr_adr_m >= mhpmeventbase_node & csr_adr_m <= mhpmeventlast_node) begin
        if (csr_adr_m < mhpmeventbase_node+`CFG_COUNTERS-3) csrc_read_val_m = mhpmevent_regw_node[counter_num_m_node];
        else csrc_read_val_m =1'b0; 
      end
    else begin
        
        
        /* verilator lint_off WIDTH */
        begin 
          
          if      (csr_adr_m == time_node & ~csr_write_m & `CFG_ZICNTR_SUPPORTED)  csrc_read_val_m = mtime_clint[31:0];
          else if (csr_adr_m == timeh_node & ~csr_write_m & `CFG_ZICNTR_SUPPORTED) csrc_read_val_m = mtime_clint[63:32];
          else if (csr_adr_m >= mhpmcounterbase_node  & csr_adr_m < mhpmcounterbase_node+`CFG_COUNTERS & csr_adr_m != mtime)
                  csrc_read_val_m = hpmcounter_regw_node[counter_num_m_node];
          else if (csr_adr_m >= mhpmcounterbase_node+`CFG_COUNTERS & csr_adr_m < mhpmcounterbase_node+32)
                  csrc_read_val_m = 1'b0; 
          else if (csr_adr_m >= hpmcounterbase_node   & csr_adr_m < hpmcounterbase_node+3  & ~csr_write_m & `CFG_ZICNTR_SUPPORTED)    
                  csrc_read_val_m = hpmcounter_regw_node[counter_num_m_node];
          else if (csr_adr_m >= hpmcounterbase_node+3   & csr_adr_m < hpmcounterbase_node+`CFG_COUNTERS  & ~csr_write_m & `CFG_ZIHPM_SUPPORTED)    
                  csrc_read_val_m = hpmcounter_regw_node[counter_num_m_node];
          else if (csr_adr_m >= hpmcounterbase_node+`CFG_COUNTERS   & csr_adr_m < hpmcounterbase_node+32  & ~csr_write_m & `CFG_ZIHPM_SUPPORTED)    
                  csrc_read_val_m = 1'b0; 
          else if (csr_adr_m >= mhpmcounterhbase_node & csr_adr_m < mhpmcounterhbase_node+`CFG_COUNTERS & csr_adr_m != mtimeh_node)
                  csrc_read_val_m = hpmcounterh_regw_node[counter_num_m_node];
          else if (csr_adr_m >= mhpmcounterhbase_node+`CFG_COUNTERS & csr_adr_m < mhpmcounterhbase_node+32)
                  csrc_read_val_m = 1'b0; 
          else if (csr_adr_m >= hpmcounterhbase_node   & csr_adr_m < hpmcounterhbase_node+3  & ~csr_write_m & `CFG_ZICNTR_SUPPORTED)   
                  csrc_read_val_m = hpmcounterh_regw_node[counter_num_m_node];
          else if (csr_adr_m >= hpmcounterhbase_node+3 & csr_adr_m < hpmcounterhbase_node+`CFG_COUNTERS & ~csr_write_m & `CFG_ZIHPM_SUPPORTED)   
                  csrc_read_val_m = hpmcounterh_regw_node[counter_num_m_node];
          else if (csr_adr_m >= hpmcounterhbase_node+`CFG_COUNTERS & csr_adr_m < hpmcounterhbase_node+32 & ~csr_write_m & `CFG_ZIHPM_SUPPORTED)   
                  csrc_read_val_m = 1'b0;
          else    illegal_csrc_access_m = 1'b1; 
        end
        /* verilator lint_on WIDTH */
      end
  end
endmodule

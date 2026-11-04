// Checks physical memory access constraints for requested transactions.
// Reports attribute or access violations to the memory path.


`include "config.vh"

module pmachecker    (
  input wire [31:0] physical_address,  // Address operand or target address selection.
  input wire [1:0] size,  // Transfer size encoding used for byte-lane or access checks.
  input wire execute_access_f,  // Execute access used by the fetch-stage datapath or control.
  input wire write_access_m,  // Write access used by the memory-stage datapath or control.
  input wire read_access_m,  // Read access used by the memory-stage datapath or control.
  output wire cacheable,  // Cache-side data, address, or operation control.
  output wire idempotent,  // Provides idempotent for this module.
  output wire pma_instr_access_fault_f,  // Instruction word, decoded field, or validity qualifier.
  output wire pma_load_access_fault_m,  // Physical memory attribute or access permission result.
  output wire pma_store_amo_access_fault_m  // Physical memory attribute or access permission result.
);

  wire pma_access_fault_node;
  wire access_rw;
  wire access_rwxc;
  wire access_rx;
  wire [7:0] sel_regions;
  wire cacheable_region_node;
  wire idempotent_region_node;

  
  assign access_rw  = read_access_m | write_access_m;
  assign access_rwxc = read_access_m | write_access_m | execute_access_f;
  assign access_rx  = read_access_m | execute_access_f;

  
  // Generate one-hot region-select results for physical address ranges.
  adrdecs  adrdecs(physical_address, access_rw, access_rx, access_rwxc, size, sel_regions);

  
  assign pma_access_fault_node          = sel_regions[0] & access_rwxc;
  // Select or format the instruction for the next pipeline stage.
  assign pma_instr_access_fault_f    = execute_access_f & pma_access_fault_node;
  assign pma_load_access_fault_m     = read_access_m & ~write_access_m & pma_access_fault_node;
  assign pma_store_amo_access_fault_m = write_access_m & pma_access_fault_node;

  
  assign cacheable_region_node = (sel_regions[1] & `CFG_EXT_MEM_CACHEABLE) |
                                 sel_regions[2] | sel_regions[3];
  assign cacheable = cacheable_region_node;

  
  assign idempotent_region_node = sel_regions[1] | sel_regions[2] | sel_regions[3];
  assign idempotent = idempotent_region_node;
endmodule

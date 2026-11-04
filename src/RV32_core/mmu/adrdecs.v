// Combines physical address decoders for memory and device regions.
// Produces region-select and access-classification signals.


`include "config.vh"
  // verilator lint_off UNOPTFLAT

module adrdecs    (
  input wire [31:0] physical_address,  // Address operand or target address selection.
  input wire access_rw,  // Provides access rw for this module.
  input wire access_rx,  // Provides access rx for this module.
  input wire access_rwxc,  // Provides access rwxc for this module.
  input wire [1:0] size,  // Transfer size encoding used for byte-lane or access checks.
  output wire [7:0] sel_regions  // Provides sel regions for this module.
);

  localparam [3:0]       supported_size_node = 4'b0111;
  localparam [3:0]       supported_bus_size_node = 4'b0111;
  localparam [31:0] ext_mem_base_node = `CFG_EXT_MEM_BASE, EXT_MEM_RANGE = `CFG_EXT_MEM_RANGE;
  localparam [31:0] bootrom_base_node = `CFG_BOOTROM_BASE, BOOTROM_RANGE = `CFG_BOOTROM_RANGE;
  localparam [31:0] uncore_ram_base_node = `CFG_UNCORE_RAM_BASE;
  localparam [32:0] uncore_ram_end_node = {1'b0, uncore_ram_base_node} + {1'b0, `CFG_UNCORE_RAM_BYTES};
  localparam [31:0] apb_base_node = `CFG_APB_BASE, APB_RANGE = `CFG_APB_RANGE;
 
  // Decode an address against the configured memory region.
  adrdec extmemdec_u(physical_address, ext_mem_base_node, EXT_MEM_RANGE, |`CFG_EXT_MEM_SUPPORTED, access_rwxc, size, supported_size_node, sel_regions[1]);
  // Decode an address against the configured memory region.
  adrdec bootromdec_u(physical_address, bootrom_base_node, BOOTROM_RANGE, |`CFG_BOOTROM_SUPPORTED, access_rx, size, supported_size_node, sel_regions[2]);
  
  
  assign sel_regions[3] = `CFG_UNCORE_RAM_SUPPORTED & access_rwxc & supported_size_node[size] &
                         (physical_address >= uncore_ram_base_node) &
                         ({1'b0, physical_address} < uncore_ram_end_node);
  
  // Decode an address against the configured memory region.
  adrdec apbdec_u(physical_address, apb_base_node, APB_RANGE,
                  |`CFG_APB_SUPPORTED, access_rw, size,
                  supported_bus_size_node, sel_regions[4]);
  // Decode an address against the configured memory region.
  adrdec clintdec_u(physical_address, `CFG_CLINT_BASE, `CFG_CLINT_RANGE,
                    |`CFG_CLINT_SUPPORTED, access_rw, size,
                    supported_bus_size_node, sel_regions[5]);
  // Decode an address against the configured memory region.
  adrdec plicdec_u(physical_address, `CFG_PLIC_BASE, `CFG_PLIC_RANGE,
                   |`CFG_PLIC_SUPPORTED, access_rw, size,
                   supported_bus_size_node, sel_regions[6]);
  
  
  assign sel_regions[7] = access_rw & supported_bus_size_node[size] &
                               (((physical_address >= `CFG_GPIO_BASE) &&
                                 (physical_address <= (`CFG_GPIO_BASE + `CFG_GPIO_RANGE))) ||
                                ((physical_address >= `CFG_PERF_BASE) &&
                                 (physical_address <= (`CFG_PERF_BASE + `CFG_PERF_RANGE))) ||
                                ((physical_address >= 32'h2100_0000) &&
                                 (physical_address <= 32'h2100_FFFF)) ||
                                (physical_address >= 32'hC000_0000));
  assign sel_regions[0] = ~|(sel_regions[7:1]); 
endmodule

  // verilator lint_on UNOPTFLAT

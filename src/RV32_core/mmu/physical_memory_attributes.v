// Classifies physical addresses by memory and device attributes.
// Supplies access properties to memory and bus control.


`include "config.vh"

module physical_memory_attributes  #(
  parameter IMMU = 0
) (
  input wire [31:0] address,  // Address operand or target address selection.
  input wire [1:0] size,  // Transfer size encoding used for byte-lane or access checks.
  input wire execute_access_f,  // Execute access used by the fetch-stage datapath or control.
  input wire write_access_m,  // Write access used by the memory-stage datapath or control.
  input wire read_access_m,  // Read access used by the memory-stage datapath or control.
  output wire [31:0] physical_address,  // Address operand or target address selection.
  output wire cacheable,  // Cache-side data, address, or operation control.
  output wire idempotent,  // Provides idempotent for this module.
  output wire instr_access_fault_f,  // Instruction word, decoded field, or validity qualifier.
  output wire load_access_fault_m,  // Load access fault used by the memory-stage datapath or control.
  output wire store_amo_access_fault_m,  // Store amo access fault used by the memory-stage datapath or control.
  output wire load_misaligned_fault_m,  // Load misaligned fault used by the memory-stage datapath or control.
  output wire store_amo_misaligned_fault_m  // Store amo misaligned fault used by the memory-stage datapath or control.
);

  wire pma_instr_access_fault_f;
  wire pma_load_access_fault_m;
  wire pma_store_amo_access_fault_m;
  reg data_misaligned_m_node;
  wire read_no_amo_access_m_node;

  assign read_no_amo_access_m_node = read_access_m & ~write_access_m;

  // Generate memory-access fault indications from PMA checks.
  pmachecker pmachecker(
    .physical_address(physical_address), .size(size), .execute_access_f(execute_access_f), .write_access_m(write_access_m), .read_access_m(read_access_m),
    .cacheable(cacheable), .idempotent(idempotent),
    .pma_instr_access_fault_f(pma_instr_access_fault_f), .pma_load_access_fault_m(pma_load_access_fault_m), .pma_store_amo_access_fault_m(pma_store_amo_access_fault_m));

  // Select the address associated with the active request.
  assign physical_address = address;

  // Compute combinational control and data selections.
  // Compute the combinational next-state/output decisions from the current control state.
  always @*
    // Decode transfer size and address alignment for the active memory access.
    case (size)
      2'b00: data_misaligned_m_node = 1'b0;
      2'b01: data_misaligned_m_node = address[0];
      2'b10: data_misaligned_m_node = |address[1:0];
      2'b11: data_misaligned_m_node = |address[2:0];
    endcase

  assign load_misaligned_fault_m = data_misaligned_m_node & read_no_amo_access_m_node;
  assign store_amo_misaligned_fault_m = data_misaligned_m_node & write_access_m;

  // Select or format the instruction for the next pipeline stage.
  assign instr_access_fault_f = pma_instr_access_fault_f;
  assign load_access_fault_m = pma_load_access_fault_m;
  assign store_amo_access_fault_m = pma_store_amo_access_fault_m;
endmodule

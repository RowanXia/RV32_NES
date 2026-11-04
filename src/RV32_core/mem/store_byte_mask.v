// Generates byte enables for a store access.
// Combines transfer size with the low address bits.


module store_byte_mask #(parameter WORDLEN = 32, EXTEND = 0)(
  input wire [2:0] size,  // Transfer size encoding used for byte-lane or access checks.
  input wire [$clog2(WORDLEN/8)-1:0] adr,  // Address operand or decoded address field.
  output wire [WORDLEN/8-1:0] byte_mask,  // Active byte lanes for a memory write.
  output wire [WORDLEN/8-1:0] byte_mask_extended  // Active byte lanes for a memory write.
);

  // Optionally generate spillover byte enables for stores crossing a word boundary.
  if(EXTEND) begin
    wire [WORDLEN*2/8-1:0] extended_byte_mask_node;
    
    assign extended_byte_mask_node = (('d2**('d2**size))-'d1) << adr;
    // Shift the active-byte pattern into position using the low address bits.
    assign byte_mask = extended_byte_mask_node[WORDLEN/8-1:0];
    assign byte_mask_extended = extended_byte_mask_node[WORDLEN*2/8-1:WORDLEN/8];
  end else begin
    assign byte_mask = (('d2**('d2**size))-'d1) << adr;
    assign byte_mask_extended = 1'b0;
  end

                              
endmodule

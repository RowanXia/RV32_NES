// Decodes one configured physical address range.
// Indicates whether the current bus address selects the region.


module adrdec (
  input wire [31:0] physical_address,  // Address operand or target address selection.
  input wire [31:0] base,  // Base-address pattern of the decoded memory region.
  input wire [31:0] range,  // Address comparison mask defining the selected memory region.
  input wire supported,  // Enables this region when its target is implemented.
  input wire access_valid,  // Qualifies address decoding with the requested access type.
  input wire [1:0] size,  // Transfer size encoding used for byte-lane or access checks.
  input wire [3:0] size_mask,  // Indicates which transfer sizes are legal for this address region.
  output wire sel  // Asserted when the address, access, and transfer size match the region.
);

  wire match_node;            
  wire size_valid_node;        

  
  // Validate the requested transfer size against the region size mask.
  assign size_valid_node = size_mask[size];

  
  // Match the address against the base pattern and range mask.
  assign match_node = &((physical_address ~^ base) | range);

  
  // Select this address region only for enabled, legal accesses.
  assign sel = match_node & supported & access_valid & size_valid_node; // exclusion-tag: adrdecSel
endmodule

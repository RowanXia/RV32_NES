// Expands a binary input into a one-hot selection.
// Provides a reusable combinational decode primitive.


module decoder #(parameter BINARY_BITS = 3) (
  input wire [BINARY_BITS-1:0] binary,  // Binary index to decode into a one-hot output.
  output wire [(2**BINARY_BITS)-1:0] onehot  // One-hot selection corresponding to the binary input index.
);

  // Shift a single set bit by the binary index to form a one-hot select.
  assign onehot = 1 << binary;
endmodule

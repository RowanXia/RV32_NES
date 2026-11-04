// Implements the two-bit branch-direction state graph used by the design.
// 00/01 predict not taken; 10/11 predict taken.  The encoding follows the
// supplied Gray-code graph: taken drives 00->01->10 and 11->10, while not
// taken drives 10->11->00 and 01->00.


module sat_counter_2bit
  (output reg [1:0] new_state,
   input wire br_dir,  // Provides br dir for this module.
   input wire [1:0] old_state  // Provides old state for this module.
   );

  // Compute combinational control and data selections.
  // Compute the combinational next-state/output decisions from the current control state.
  always @* begin
    // Decode the current controller state and select the appropriate transition.
    case(old_state)
      2'b00: begin
 if(br_dir) new_state = 2'b01;
 else new_state = 2'b00;
      end
      2'b01: begin
 if(br_dir) new_state = 2'b10;
 else new_state = 2'b00;
      end
      2'b10: begin
 if(br_dir) new_state = 2'b10;
 else new_state = 2'b11;
      end
      2'b11: begin
 if(br_dir) new_state = 2'b10;
 else new_state = 2'b00;
      end
      default: new_state = 2'b00;
    endcase
  end

endmodule

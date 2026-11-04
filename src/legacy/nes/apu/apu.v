module APU(input clk, input ce, input reset,
           input [4:0] ADDR,  // APU Address Line
           input [7:0] DIN,   // Data to APU
           output [7:0] DOUT, // Data from APU
           input MW,          // Writes to APU
           input MR,          // Reads from APU
           input [4:0] audio_channels, // Enabled audio channels
           output reg [15:0] Sample,

           output DmaReq,      // 1 when DMC wants DMA
           input DmaAck,           // 1 when DMC byte is on DmcData. DmcDmaRequested should go low.
           output [15:0] DmaAddr,  // Address DMC wants to read
           input [7:0] DmaData,    // Input data to DMC from memory.

           output odd_or_even,
           output IRQ);       // IRQ asserted

// Which channels are enabled?
reg [3:0] Enabled;

// Output samples from the 4 channels
wire [3:0] Sq1Sample,Sq2Sample,TriSample,NoiSample;

// Output samples from the DMC channel
wire [6:0] DmcSample;
wire DmcIrq;
wire IsDmcActive;

// Generate internal memory write signals
wire ApuMW0 = MW && ADDR[4:2]==0; // SQ1
wire ApuMW1 = MW && ADDR[4:2]==1; // SQ2
wire ApuMW2 = MW && ADDR[4:2]==2; // TRI
wire ApuMW3 = MW && ADDR[4:2]==3; // NOI
wire ApuMW4 = MW && ADDR[4:2]>=4; // DMC
wire ApuMW5 = MW && ADDR[4:2]==5; // Control registers

wire Sq1NonZero, Sq2NonZero, TriNonZero, NoiNonZero;

// Common input to all channels
wire [7:0] LenCtr_In;
LenCtr_Lookup len(DIN[7:3], LenCtr_In);


// Frame sequencer registers
reg FrameSeqMode;
reg [15:0] Cycles;
reg ClkE, ClkL;
reg Wrote4017;
reg [1:0] IrqCtr;
reg InternalClock; // APU Differentiates between Even or Odd clocks
assign odd_or_even = InternalClock;


// Generate each channel
SquareChan   Sq1(clk, ce, reset, 1'b0, ADDR[1:0], DIN, ApuMW0, ClkL, ClkE, Enabled[0], LenCtr_In, Sq1Sample, Sq1NonZero);
SquareChan   Sq2(clk, ce, reset, 1'b1, ADDR[1:0], DIN, ApuMW1, ClkL, ClkE, Enabled[1], LenCtr_In, Sq2Sample, Sq2NonZero);
TriangleChan Tri(clk, ce, reset, ADDR[1:0], DIN, ApuMW2, ClkL, ClkE, Enabled[2], LenCtr_In, TriSample, TriNonZero);
NoiseChan    Noi(clk, ce, reset, ADDR[1:0], DIN, ApuMW3, ClkL, ClkE, Enabled[3], LenCtr_In, NoiSample, NoiNonZero);
DmcChan      Dmc(clk, ce, reset, odd_or_even, ADDR[2:0], DIN, ApuMW4, DmcSample, DmaReq, DmaAck, DmaAddr, DmaData, DmcIrq, IsDmcActive);

// Reading this register clears the frame interrupt flag (but not the DMC interrupt flag).
// If an interrupt flag was set at the same moment of the read, it will read back as 1 but it will not be cleared.
reg FrameInterrupt, DisableFrameInterrupt;


//mode 0: 4-step  effective rate (approx)
//---------------------------------------
//    - - - f      60 Hz
//    - l - l     120 Hz
//    e e e e     240 Hz


//mode 1: 5-step  effective rate (approx)
//---------------------------------------
//    - - - - -   (interrupt flag never set)
//    l - l - -    96 Hz
//    e e e e -   192 Hz

   
always @(posedge clk or posedge reset) if (reset) begin
  FrameSeqMode <= 0;
  DisableFrameInterrupt <= 0;
  FrameInterrupt <= 0;
  Enabled <= 0;
  InternalClock <= 0;
  Wrote4017 <= 0;
  ClkE <= 0;
  ClkL <= 0;
  Cycles <= 4; // This needs to be 5 for proper power up behavior
  IrqCtr <= 0;
end else if (ce) begin   
  FrameInterrupt <= IrqCtr[1] ? 1 : (ADDR == 5'h15 && MR || ApuMW5 && ADDR[1:0] == 3 && DIN[6]) ? 0 : FrameInterrupt;
  InternalClock <= !InternalClock;
  IrqCtr <= {IrqCtr[0], 1'b0};
  Cycles <= Cycles + 1;
  ClkE <= 0;
  ClkL <= 0;
  if (Cycles == 7457) begin
    ClkE <= 1;
  end else if (Cycles == 14913) begin
    ClkE <= 1;
    ClkL <= 1;
    ClkE <= 1;
    ClkL <= 1;
  end else if (Cycles == 22371) begin
    ClkE <= 1;
  end else if (Cycles == 29829) begin
    if (!FrameSeqMode) begin
      ClkE <= 1;
      ClkL <= 1;
      Cycles <= 0;
      IrqCtr <= 3;
      FrameInterrupt <= 1;
    end
  end else if (Cycles == 37281) begin
    ClkE <= 1;
    ClkL <= 1;
    Cycles <= 0;
  end
  
  // Handle one cycle delayed write to 4017.
  Wrote4017 <= 0;
  if (Wrote4017) begin
    if (FrameSeqMode) begin
      ClkE <= 1;
      ClkL <= 1;
    end
    Cycles <= 0;
  end
  
//  if (ClkE||ClkL) $write("%d: Clocking %s%s\n", Cycles, ClkE?"E":" ", ClkL?"L":" ");

  // Handle writes to control registers
  if (ApuMW5) begin
    case (ADDR[1:0])
    1: begin // Register $4015, ---D NT21
      Enabled <= DIN[3:0];
//      $write("$4015 = %X\n", DIN);
    end
    3: begin // Register $4017
      FrameSeqMode <= DIN[7]; // 1 = 5 frames cycle, 0 = 4 frames cycle
      DisableFrameInterrupt <= DIN[6];
     
      // If the internal clock is even, things happen
      // right away.
      if (!InternalClock) begin
        if (DIN[7]) begin
          ClkE <= 1;
          ClkL <= 1;
        end
        Cycles <= 0;
      end
      
      // Otherwise they get delayed one clock
      Wrote4017 <= InternalClock;
    end
    endcase
  end


end

// 音频采样率就是时钟频率
wire [15:0] sample_out;
ApuLookupTable lookup(clk, 
                      (audio_channels[0] ? {4'b0, Sq1Sample} : 8'b0) + 
                      (audio_channels[1] ? {4'b0, Sq2Sample} : 8'b0), 
                      (audio_channels[2] ? {4'b0, TriSample} + {3'b0, TriSample, 1'b0} : 8'b0) + 
                      (audio_channels[3] ? {3'b0, NoiSample, 1'b0} : 8'b0) +
                      (audio_channels[4] ? {1'b0, DmcSample} : 8'b0),
                      sample_out);
always @(posedge clk or posedge reset) begin
	if (reset) begin
		Sample <= 16'b0;
	end else if (ce) begin
		Sample <= sample_out;
	end
end

wire frame_irq = FrameInterrupt && !DisableFrameInterrupt;

// Generate bus output
assign DOUT = {DmcIrq, frame_irq, 1'b0, 
               IsDmcActive,
               NoiNonZero,
               TriNonZero,
               Sq2NonZero,
               Sq1NonZero};

assign IRQ = frame_irq || DmcIrq;

endmodule

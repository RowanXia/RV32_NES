// 采样通道
module DmcChan(input clk, input ce, input reset,
               input odd_or_even,
               input [2:0] Addr,
               input [7:0] DIN,
               input MW,
               output [6:0] Sample,
               output DmaReq,          // 1 when DMC wants DMA
               input DmaAck,           // 1 when DMC byte is on DmcData. DmcDmaRequested should go low.
               output [15:0] DmaAddr,  // Address DMC wants to read
               input [7:0] DmaData,    // Input data to DMC from memory.
               output Irq,
               output IsDmcActive);
  reg IrqEnable;
  reg IrqActive;
  reg Loop;                 // Looping enabled
  reg [3:0] Freq;           // Current value of frequency register
  reg [6:0] Dac = 0;        // Current value of DAC
  reg [7:0] SampleAddress;  // Base address of sample
  reg [7:0] SampleLen;      // Length of sample
  reg [7:0] ShiftReg;       // Shift register
  reg [8:0] Cycles;         // Down counter, is the period
  reg [14:0] Address;        // 15 bits current address, 0x8000-0xffff
  reg [11:0] BytesLeft;      // 12 bits bytes left counter 0 - 4081.
  reg [2:0] BitsUsed;        // Number of bits left in the SampleBuffer.
  reg [7:0] SampleBuffer;    // Next value to be loaded into shift reg
  reg HasSampleBuffer;       // Sample buffer is nonempty
  reg HasShiftReg;           // Shift reg is non empty
  reg [8:0] NewPeriod[0:15];
  reg DmcEnabled;
  reg [1:0] ActivationDelay;
  assign DmaAddr = {1'b1, Address};
  assign Sample = Dac;
  assign Irq = IrqActive;
  assign IsDmcActive = DmcEnabled;
  
  assign DmaReq = !HasSampleBuffer && DmcEnabled && !ActivationDelay[0];
    
  always @(*) begin
    NewPeriod[0] = 9'd428;
    NewPeriod[1] = 9'd380;
    NewPeriod[2] = 9'd340;
    NewPeriod[3] = 9'd320;
    NewPeriod[4] = 9'd286;
    NewPeriod[5] = 9'd254;
    NewPeriod[6] = 9'd226;
    NewPeriod[7] = 9'd214;
    NewPeriod[8] = 9'd190;
    NewPeriod[9] = 9'd160;
    NewPeriod[10] = 9'd42;
    NewPeriod[11] = 9'd28;
    NewPeriod[12] = 9'd06;
    NewPeriod[13] = 9'd4;
    NewPeriod[14] = 9'd2;
    NewPeriod[15] = 9'd4;
  end

  // Shift register initially loaded with 07
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      IrqEnable <= 0;
      IrqActive <= 0;
      Loop <= 0;
      Freq <= 0;
      Dac <= 0;
      SampleAddress <= 0;
      SampleLen <= 0;
      ShiftReg <= 8'hff;
      Cycles <= 439;
      Address <= 0;
      BytesLeft <= 0;
      BitsUsed <= 0;
      SampleBuffer <= 0;
      HasSampleBuffer <= 0;
      HasShiftReg <= 0;
      DmcEnabled <= 0;
      ActivationDelay <= 0;
    end else if (ce) begin
      if (ActivationDelay == 3 && !odd_or_even) ActivationDelay <= 1;
      if (ActivationDelay == 1) ActivationDelay <= 0;
      
      if (MW) begin
        case (Addr)
        0: begin  // $4010   il-- ffff   IRQ enable, loop, frequency index
            IrqEnable <= DIN[7];
            Loop <= DIN[6];
            Freq <= DIN[3:0];
            if (!DIN[7]) IrqActive <= 0;
          end
        1: begin  // $4011   -ddd dddd   DAC
            // This will get missed if the Dac <= far below runs, that is by design.
            Dac <= DIN[6:0];
          end
        2: begin  // $4012   aaaa aaaa   sample address
            SampleAddress <= DIN[7:0];
          end
        3: begin  // $4013   llll llll   sample length
            SampleLen <= DIN[7:0];
          end
        5: begin // $4015 write	---D NT21  Enable DMC (D)
            IrqActive <= 0;        // 写入寄存器会清除中断位
            DmcEnabled <= DIN[4];
            // If the DMC bit is set, the DMC sample will be restarted only if not already active.
            if (DIN[4] && !DmcEnabled) begin
              Address <= {1'b1, SampleAddress, 6'b000000};
              BytesLeft <= {SampleLen, 4'b0000};
              ActivationDelay <= 3;
            end
          end
        endcase
      end

      Cycles <= Cycles - 1;
      if (Cycles == 1) begin
        Cycles <= NewPeriod[Freq];
        if (HasShiftReg) begin
          if (ShiftReg[0]) begin
            Dac[6:1] <= (Dac[6:1] != 6'b111111) ? Dac[6:1] + 6'b000001 : Dac[6:1];
          end else begin
            Dac[6:1] <= (Dac[6:1] != 6'b000000) ? Dac[6:1] + 6'b111111 : Dac[6:1];
          end
        end
        ShiftReg <= {1'b0, ShiftReg[7:1]};
        BitsUsed <= BitsUsed + 1;
        if (BitsUsed == 7) begin
          HasShiftReg <= HasSampleBuffer;
          ShiftReg <= SampleBuffer;
          HasSampleBuffer <= 0;
        end
      end
      
      // Acknowledge DMA?
      if (DmaAck) begin
        Address <= Address + 1;
        BytesLeft <= BytesLeft - 1;
        HasSampleBuffer <= 1;
        SampleBuffer <= DmaData;
        if (BytesLeft == 0) begin
          Address <= {1'b1, SampleAddress, 6'b000000};
          BytesLeft <= {SampleLen, 4'b0000};
          DmcEnabled <= Loop;
          if (!Loop && IrqEnable)
            IrqActive <= 1;
        end
      end      
    end
  end
endmodule
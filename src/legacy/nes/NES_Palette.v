module NES_Palette(
    input [5:0] nes_color,
    output [23:0] COLOR
);

reg [23:0] palette[0:63];

initial begin
    palette[0] <= 24'h7c7c7c; palette[1] <= 24'h0000fc; palette[2] <= 24'h0000bc; palette[3] <= 24'h4428bc;
    palette[4] <= 24'h940084; palette[5] <= 24'ha80020; palette[6] <= 24'ha81000; palette[7] <= 24'h881400;
    palette[8] <= 24'h503000; palette[9] <= 24'h007800; palette[10] <= 24'h006800; palette[11] <= 24'h005800;
    palette[12] <= 24'h004058; palette[13] <= 24'h000000; palette[14] <= 24'h000000; palette[15] <= 24'h000000;

    palette[16] <= 24'hbcbcbc; palette[17] <= 24'h0078f8; palette[18] <= 24'h0058f8; palette[19] <= 24'h6844fc;
    palette[20] <= 24'hd800cc; palette[21] <= 24'he40058; palette[22] <= 24'hf83800; palette[23] <= 24'he45c10;
    palette[24] <= 24'hac7c00; palette[25] <= 24'h00b800; palette[26] <= 24'h00a800; palette[27] <= 24'h00a844;
    palette[28] <= 24'h008888; palette[29] <= 24'h000000; palette[30] <= 24'h000000; palette[31] <= 24'h000000;

    palette[32] <= 24'hf8f8f8; palette[33] <= 24'h3cbcfc; palette[34] <= 24'h6888fc; palette[35] <= 24'h9878f8;
    palette[36] <= 24'hf878f8; palette[37] <= 24'hf85898; palette[38] <= 24'hf87858; palette[39] <= 24'hfca044;
    palette[40] <= 24'hf8b800; palette[41] <= 24'hb8f818; palette[42] <= 24'h58d854; palette[43] <= 24'h58f898;
    palette[44] <= 24'h00e8d8; palette[45] <= 24'h787878; palette[46] <= 24'h000000; palette[47] <= 24'h000000;

    palette[48] <= 24'hfcfcfc; palette[49] <= 24'ha4e4fc; palette[50] <= 24'hb8b8f8; palette[51] <= 24'hd8b8f8;
    palette[52] <= 24'hf8b8f8; palette[53] <= 24'hf8a4c0; palette[54] <= 24'hf0d0b0; palette[55] <= 24'hfbdfa6;
    palette[56] <= 24'hf8d878; palette[57] <= 24'hd8f878; palette[58] <= 24'hb8f8b8; palette[59] <= 24'hb8f8d8;
    palette[60] <= 24'h00fcfc; palette[61] <= 24'hd8d8d8; palette[62] <= 24'h000000; palette[63] <= 24'h000000;
end

assign COLOR = palette[nes_color];

endmodule
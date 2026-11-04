module ApuLookupTable(
	input clk,
	input [7:0] in_a,
	input [7:0] in_b,
	output [15:0] out
);

reg [15:0] tmp_a, tmp_b;
  
function [15:0] lookup0;
	input [5:0] idx;
	case (idx)
		5'h00: lookup0 =     0;	5'h01: lookup0 =   760;	5'h02: lookup0 =  1503;	5'h03: lookup0 =  2228;
		5'h04: lookup0 =  2936;	5'h05: lookup0 =  3627;	5'h06: lookup0 =  4303;	5'h07: lookup0 =  4963;
		5'h08: lookup0 =  5609;	5'h09: lookup0 =  6240;	5'h0a: lookup0 =  6858;	5'h0b: lookup0 =  7462;
		5'h0c: lookup0 =  8053;	5'h0d: lookup0 =  8631;	5'h0e: lookup0 =  9198;	5'h0f: lookup0 =  9752;
		5'h10: lookup0 = 10296;	5'h11: lookup0 = 10828;	5'h12: lookup0 = 11349;	5'h13: lookup0 = 11860;
		5'h14: lookup0 = 12361;	5'h15: lookup0 = 12852;	5'h16: lookup0 = 13334;	5'h17: lookup0 = 13807;
		5'h18: lookup0 = 14270;	5'h19: lookup0 = 14725;	5'h1a: lookup0 = 15171;	5'h1b: lookup0 = 15609;
		5'h1c: lookup0 = 16039;	5'h1d: lookup0 = 16461;	5'h1e: lookup0 = 16876;	5'h1f: lookup0 = 16876;
		
		default: lookup0 = 16876;
	endcase
endfunction

function [15:0] lookup1;
	input [7:0] idx;
	case (idx)
		8'h00: lookup1 =     0;	8'h01: lookup1 =   439;	8'h02: lookup1 =   874;	8'h03: lookup1 =  1306;
		8'h04: lookup1 =  1735;	8'h05: lookup1 =  2160;	8'h06: lookup1 =  2581;	8'h07: lookup1 =  2999;
		8'h08: lookup1 =  3414;	8'h09: lookup1 =  3826;	8'h0a: lookup1 =  4234;	8'h0b: lookup1 =  4639;
		8'h0c: lookup1 =  5041;	8'h0d: lookup1 =  5440;	8'h0e: lookup1 =  5836;	8'h0f: lookup1 =  6229;
		8'h10: lookup1 =  6618;	8'h11: lookup1 =  7005;	8'h12: lookup1 =  7389;	8'h13: lookup1 =  7769;
		8'h14: lookup1 =  8147;	8'h15: lookup1 =  8522;	8'h16: lookup1 =  8895;	8'h17: lookup1 =  9264;
		8'h18: lookup1 =  9631;	8'h19: lookup1 =  9995;	8'h1a: lookup1 = 10356;	8'h1b: lookup1 = 10714;
		8'h1c: lookup1 = 11070;	8'h1d: lookup1 = 11423;	8'h1e: lookup1 = 11774;	8'h1f: lookup1 = 12122;
		8'h20: lookup1 = 12468;	8'h21: lookup1 = 12811;	8'h22: lookup1 = 13152;	8'h23: lookup1 = 13490;
		8'h24: lookup1 = 13825;	8'h25: lookup1 = 14159;	8'h26: lookup1 = 14490;	8'h27: lookup1 = 14818;
		8'h28: lookup1 = 15145;	8'h29: lookup1 = 15469;	8'h2a: lookup1 = 15791;	8'h2b: lookup1 = 16110;
		8'h2c: lookup1 = 16427;	8'h2d: lookup1 = 16742;	8'h2e: lookup1 = 17055;	8'h2f: lookup1 = 17366;
		8'h30: lookup1 = 17675;	8'h31: lookup1 = 17981;	8'h32: lookup1 = 18286;	8'h33: lookup1 = 18588;
		8'h34: lookup1 = 18888;	8'h35: lookup1 = 19187;	8'h36: lookup1 = 19483;	8'h37: lookup1 = 19777;
		8'h38: lookup1 = 20069;	8'h39: lookup1 = 20360;	8'h3a: lookup1 = 20648;	8'h3b: lookup1 = 20935;
		8'h3c: lookup1 = 21219;	8'h3d: lookup1 = 21502;	8'h3e: lookup1 = 21783;	8'h3f: lookup1 = 22062;
		8'h40: lookup1 = 22339;	8'h41: lookup1 = 22615;	8'h42: lookup1 = 22889;	8'h43: lookup1 = 23160;
		8'h44: lookup1 = 23431;	8'h45: lookup1 = 23699;	8'h46: lookup1 = 23966;	8'h47: lookup1 = 24231;
		8'h48: lookup1 = 24494;	8'h49: lookup1 = 24756;	8'h4a: lookup1 = 25016;	8'h4b: lookup1 = 25274;
		8'h4c: lookup1 = 25531;	8'h4d: lookup1 = 25786;	8'h4e: lookup1 = 26040;	8'h4f: lookup1 = 26292;
		8'h50: lookup1 = 26542;	8'h51: lookup1 = 26791;	8'h52: lookup1 = 27039;	8'h53: lookup1 = 27284;
		8'h54: lookup1 = 27529;	8'h55: lookup1 = 27772;	8'h56: lookup1 = 28013;	8'h57: lookup1 = 28253;
		8'h58: lookup1 = 28492;	8'h59: lookup1 = 28729;	8'h5a: lookup1 = 28964;	8'h5b: lookup1 = 29198;
		8'h5c: lookup1 = 29431;	8'h5d: lookup1 = 29663;	8'h5e: lookup1 = 29893;	8'h5f: lookup1 = 30121;
		8'h60: lookup1 = 30349;	8'h61: lookup1 = 30575;	8'h62: lookup1 = 30800;	8'h63: lookup1 = 31023;
		8'h64: lookup1 = 31245;	8'h65: lookup1 = 31466;	8'h66: lookup1 = 31685;	8'h67: lookup1 = 31904;
		8'h68: lookup1 = 32121;	8'h69: lookup1 = 32336;	8'h6a: lookup1 = 32551;	8'h6b: lookup1 = 32764;
		8'h6c: lookup1 = 32976;	8'h6d: lookup1 = 33187;	8'h6e: lookup1 = 33397;	8'h6f: lookup1 = 33605;
		8'h70: lookup1 = 33813;	8'h71: lookup1 = 34019;	8'h72: lookup1 = 34224;	8'h73: lookup1 = 34428;
		8'h74: lookup1 = 34630;	8'h75: lookup1 = 34832;	8'h76: lookup1 = 35032;	8'h77: lookup1 = 35232;
		8'h78: lookup1 = 35430;	8'h79: lookup1 = 35627;	8'h7a: lookup1 = 35823;	8'h7b: lookup1 = 36018;
		8'h7c: lookup1 = 36212;	8'h7d: lookup1 = 36405;	8'h7e: lookup1 = 36597;	8'h7f: lookup1 = 36788;
		8'h80: lookup1 = 36978;	8'h81: lookup1 = 37166;	8'h82: lookup1 = 37354;	8'h83: lookup1 = 37541;
		8'h84: lookup1 = 37727;	8'h85: lookup1 = 37912;	8'h86: lookup1 = 38095;	8'h87: lookup1 = 38278;
		8'h88: lookup1 = 38460;	8'h89: lookup1 = 38641;	8'h8a: lookup1 = 38821;	8'h8b: lookup1 = 39000;
		8'h8c: lookup1 = 39178;	8'h8d: lookup1 = 39355;	8'h8e: lookup1 = 39532;	8'h8f: lookup1 = 39707;
		8'h90: lookup1 = 39881;	8'h91: lookup1 = 40055;	8'h92: lookup1 = 40228;	8'h93: lookup1 = 40399;
		8'h94: lookup1 = 40570;	8'h95: lookup1 = 40740;	8'h96: lookup1 = 40909;	8'h97: lookup1 = 41078;
		8'h98: lookup1 = 41245;	8'h99: lookup1 = 41412;	8'h9a: lookup1 = 41577;	8'h9b: lookup1 = 41742;
		8'h9c: lookup1 = 41906;	8'h9d: lookup1 = 42070;	8'h9e: lookup1 = 42232;	8'h9f: lookup1 = 42394;
		8'ha0: lookup1 = 42555;	8'ha1: lookup1 = 42715;	8'ha2: lookup1 = 42874;	8'ha3: lookup1 = 43032;
		8'ha4: lookup1 = 43190;	8'ha5: lookup1 = 43347;	8'ha6: lookup1 = 43503;	8'ha7: lookup1 = 43659;
		8'ha8: lookup1 = 43813;	8'ha9: lookup1 = 43967;	8'haa: lookup1 = 44120;	8'hab: lookup1 = 44273;
		8'hac: lookup1 = 44424;	8'had: lookup1 = 44575;	8'hae: lookup1 = 44726;	8'haf: lookup1 = 44875;
		8'hb0: lookup1 = 45024;	8'hb1: lookup1 = 45172;	8'hb2: lookup1 = 45319;	8'hb3: lookup1 = 45466;
		8'hb4: lookup1 = 45612;	8'hb5: lookup1 = 45757;	8'hb6: lookup1 = 45902;	8'hb7: lookup1 = 46046;
		8'hb8: lookup1 = 46189;	8'hb9: lookup1 = 46332;	8'hba: lookup1 = 46474;	8'hbb: lookup1 = 46615;
		8'hbc: lookup1 = 46756;	8'hbd: lookup1 = 46895;	8'hbe: lookup1 = 47035;	8'hbf: lookup1 = 47173;
		8'hc0: lookup1 = 47312;	8'hc1: lookup1 = 47449;	8'hc2: lookup1 = 47586;	8'hc3: lookup1 = 47722;
		8'hc4: lookup1 = 47857;	8'hc5: lookup1 = 47992;	8'hc6: lookup1 = 48127;	8'hc7: lookup1 = 48260;
		8'hc8: lookup1 = 48393;	8'hc9: lookup1 = 48526;	8'hca: lookup1 = 48658;	

		default: lookup1 = 48658;
	endcase
endfunction

always @(posedge clk) begin
    tmp_a <= lookup0(in_a[4:0]);
    tmp_b <= lookup1(in_b);
end
assign out = tmp_a + tmp_b;


endmodule
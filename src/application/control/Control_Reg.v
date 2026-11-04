// Expose application mode, mapper, joypad and boot diagnostics through APB.
// Preserve the original PSEL-based writes at 0x00, 0x08 and 0x0c.
// Only 0x14 uses the full ACCESS handshake and byte-zero strobe.
// Button selection priority is btn1, btn2, then btn3; warm_boot is read-only.
module Control_Reg (
     
    input	wire			PCLK,		 
    input	wire			PRESETn,	 
    input	wire			PSEL,		 
	input	wire			PENABLE,
    input	wire	[31:0]	PADDR,		 
    input	wire	[31:0]	PWDATA,		 
	output	wire	[31:0]	PRDATA,		 
    input	wire			PWRITE,		 
    output	wire			PREADY,		 
	input	wire	[ 3:0]	PSTRB,
	output	wire			PSLVERR,
	
	input wire [15:0] serial_buttons,
	input wire warm_boot,
	input wire btn1,
	input wire btn2,
	input wire btn3,

	output wire [31:0]				status_flags /* synthesis syn_keep=1 */,
	output wire	[31:0]				nes_flags,
	output wire	[31:0]				joypad_buttons,
	output wire [7:0] diagnostic_led,
	output wire game_mode
);

wire valid_transfer;	 
wire read_access;   	 
wire write_access;  	 

assign valid_transfer = PSEL;

assign read_access  = valid_transfer & ~PWRITE;
assign write_access = valid_transfer & PWRITE;

assign PSLVERR = 1'b0;

reg switch_to_nes;
reg enable_hdmi_output;
reg [1:0] display_mult;
assign status_flags = {28'b0, display_mult, enable_hdmi_output, switch_to_nes};

always @(posedge PCLK or negedge PRESETn) begin
	if (!PRESETn) begin
		display_mult <= 2'b00;
	end else if (!btn1) begin
		display_mult <= 2'b00;
	end else if (!btn2) begin
		display_mult <= 2'b01;
	end else if (!btn3) begin
		display_mult <= 2'b10;
	end
end

reg [31:0] mapper_config_q;
assign nes_flags = mapper_config_q;

reg [31:0] nes_buttons_status;
assign joypad_buttons = nes_buttons_status;
reg [7:0] diagnostic_led_reg;
reg game_mode_reg;
assign diagnostic_led = diagnostic_led_reg;
assign game_mode = game_mode_reg;
wire boot_control_write = PSEL & PENABLE & PWRITE & PREADY &
                          (PADDR[9:0] == 10'h014) & PSTRB[0];

always @(posedge PCLK or negedge PRESETn) begin
	if (!PRESETn) begin
		switch_to_nes <= 1'b0;
		enable_hdmi_output <= 1'b0;
		 
		mapper_config_q <= {
			16'b0,
			1'b0,     
			1'b1,     
			3'h1,     
			3'h2,     
			8'b0     
		};
		nes_buttons_status <= 32'b0;
	end else if (write_access) begin
		case (PADDR[9:0])
			'h00: begin
				 
				{
					enable_hdmi_output,
					switch_to_nes
				} <= {
					PWDATA[1],
					PWDATA[0]
				};
			end
			'h04: begin

			end
			'h08: begin
				 
				mapper_config_q <= PWDATA;
			end
			
			'h0c: begin
				 
				nes_buttons_status <= PWDATA;
			end
			
			default: begin
			end
		endcase
	end
end

always @(posedge PCLK or negedge PRESETn) begin
	if (!PRESETn) begin
		diagnostic_led_reg <= 8'b0;
		game_mode_reg <= 1'b0;
	end else if (boot_control_write) begin
		diagnostic_led_reg <= PWDATA[7:0];
		game_mode_reg <= PWDATA[8];
	end
end

reg [31:0] prdata;
always @(posedge PCLK or negedge PRESETn) begin
	if (!PRESETn) begin
		prdata <= 32'b0;
	end else begin
		if (read_access) begin
            case (PADDR[9:0])
			'h00: begin
				 
				prdata <=
				{
					30'b0,
					enable_hdmi_output,
					switch_to_nes
				};
			end
			'h04: begin
				 
				prdata <= 32'b0;
			end
			'h08: begin
				 
				prdata <= mapper_config_q;
			end
			
			'h10: begin prdata <= {16'b0,serial_buttons}; end
			'h14: begin prdata <= {22'b0,warm_boot,game_mode_reg,diagnostic_led_reg}; end
			'h0c: begin
				 
				prdata <= nes_buttons_status;
			end
			
			default: begin
				prdata <= 32'b0;
			end
            endcase
        end
	end
end

assign PRDATA = prdata;

assign PREADY = 1'b1;

endmodule

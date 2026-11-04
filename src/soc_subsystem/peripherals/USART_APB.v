// Provide the board UART registers and received controller-byte pulses.
// Validate the start and stop bits at mid-bit sample points after RX synchronization.
// A newly received byte overrides simultaneous APB read clearing of rx_valid.
// Entering TX_START clears tx_start after any same-cycle APB write assignment.
module USART_APB #(
    parameter integer CLK_FREQ = 42_880_000,
    parameter integer BAUD_RATE = 115200
) (
     
    input  wire        PCLK,       
    input  wire        PRESETn,    
    input  wire        PSEL,       
    input  wire        PENABLE,    
    input  wire [31:0] PADDR,      
    input  wire        PWRITE,     
    input  wire [31:0] PWDATA,     
    output reg  [31:0] PRDATA,     
    output wire        PREADY,     
	input  wire	[3:0]  PSTRB,
	output wire		   PSLVERR,

    input  wire        RX,			 
    output wire        TX,			 
    output wire        TX_int,		 
    output wire [7:0]  controller_data,
    output wire        controller_valid,
    output wire        RX_int		 
);

assign PSLVERR = 1'b0;

localparam [1:0] REG_DATA  = 2'b00;   
localparam [1:0] REG_STATUS = 2'b01;  
localparam [1:0] REG_CTRL  = 2'b10;   

reg [7:0] tx_data_reg;       
reg [7:0] rx_data_reg;       
reg       tx_start;          
reg [3:0] tx_bit_count;      
reg [3:0] rx_bit_count;      
reg [9:0] tx_shift_reg;      
reg [7:0] rx_shift_reg;      
reg       tx_busy;           
reg       rx_valid;          
reg       rx_error;          

localparam BAUD_DIV = CLK_FREQ / BAUD_RATE;
localparam HALF_BAUD_DIV = BAUD_DIV / 2;

reg [11:0] tx_baud_counter;
reg        tx_baud_tick;

always @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
        tx_baud_counter <= 0;
        tx_baud_tick <= 0;
    end else begin
        if (tx_baud_counter >= BAUD_DIV - 1) begin
            tx_baud_counter <= 0;
            tx_baud_tick <= 1;
        end else begin
            tx_baud_counter <= tx_baud_counter + 1;
            tx_baud_tick <= 0;
        end
    end
end

wire apb_write = PSEL & PENABLE & PWRITE;
wire apb_read  = PSEL & PENABLE & ~PWRITE;
wire [1:0] reg_addr = PADDR[3:2];

wire status_tx_busy = tx_busy;
wire status_rx_valid = rx_valid;
wire status_rx_error = rx_error;

reg tx_int, rx_int;
assign controller_data = rx_data_reg;
assign controller_valid = rx_int & ~rx_error;
assign {TX_int, RX_int} = {tx_int, rx_int};

reg [1:0] tx_state;
localparam TX_IDLE = 2'b00;
localparam TX_START = 2'b01;
localparam TX_DATA = 2'b10;
localparam TX_STOP = 2'b11;

always @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
        tx_state <= TX_IDLE;
        tx_shift_reg <= 10'b1111111111;
        tx_bit_count <= 0;
        tx_busy <= 0;
		tx_int <= 1'b0;
    end else begin
        case (tx_state)
            TX_IDLE: begin
				tx_int <= 1'b0;
				
				if (tx_start) begin
					tx_busy <= 1'b1;
				end else begin
					tx_busy <= 1'b0;
				end
				
                if (tx_start & tx_baud_tick) begin
                    tx_state <= TX_START;
                    tx_shift_reg <= {1'b1, tx_data_reg, 1'b0};  
                    tx_bit_count <= 0;
                end else begin
                end
            end
            
            TX_START: begin
				 
                if (tx_baud_tick) begin
					tx_shift_reg <= {1'b1, tx_shift_reg[9:1]};  
                    tx_state <= TX_DATA;
                end
            end
            
            TX_DATA: begin
                if (tx_baud_tick) begin
                    if (tx_bit_count == 8) begin
                        tx_state <= TX_STOP;
                    end
                    tx_shift_reg <= {1'b1, tx_shift_reg[9:1]};  
                    tx_bit_count <= tx_bit_count + 1;
                end
            end
            
            TX_STOP: begin
                if (tx_baud_tick) begin
                    tx_state <= TX_IDLE;
                    tx_busy <= 0;
					tx_int <= 1'b1;		 
                end
            end
        endcase
    end
end

assign TX = tx_shift_reg[0];  

reg [1:0] rx_state;
localparam RX_IDLE = 2'b00;
localparam RX_START = 2'b01;
localparam RX_DATA = 2'b10;
localparam RX_STOP = 2'b11;

wire rx_sync1; reg rx_sync2;
GTP_DFF_P rx_meta_ff(.CLK(PCLK),.P(~PRESETn),.D(RX),.Q(rx_sync1));  

always @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin

        rx_sync2 <= 1;
    end else begin

        rx_sync2 <= rx_sync1;
    end
end

wire rx_sync = rx_sync2;  

reg [11:0] rx_baud_counter;
wire       rx_baud_tick;

always @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
        rx_baud_counter <= 0;
    end else begin
		if (rx_state == RX_START || rx_state == RX_DATA || rx_state == RX_STOP) begin
			 
			if (rx_baud_counter >= BAUD_DIV - 1) begin
				rx_baud_counter <= 'b0;
			end else begin
				rx_baud_counter <= rx_baud_counter + 1'b1;
			end
		end else begin
			rx_baud_counter <= 0;
		end
    end
end
 
assign rx_baud_tick = (rx_baud_counter == HALF_BAUD_DIV);

always @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
        rx_state <= RX_IDLE;
        rx_shift_reg <= 0;
        rx_bit_count <= 0;
        rx_data_reg <= 0;
        rx_valid <= 1'b0;
        rx_error <= 1'b0;
		rx_int <= 1'b0;
    end else begin
		if (apb_read && reg_addr == REG_DATA) begin
			rx_valid <= 0;  
		end
        case (rx_state)
            RX_IDLE: begin
				rx_int <= 1'b0;
                if (!rx_sync) begin  
                    rx_state <= RX_START;
                    rx_bit_count <= 0;
                    rx_error <= 0;
                end
            end
            
            RX_START: begin
                if (rx_baud_tick) begin
                     
                    if (!rx_sync) begin
                        rx_state <= RX_DATA;
                    end else begin
                        rx_state <= RX_IDLE;  
                    end
                end
            end
            
            RX_DATA: begin
                if (rx_baud_tick) begin
					rx_shift_reg <= {rx_sync, rx_shift_reg[7:1]};
                    if (rx_bit_count == 7) rx_state <= RX_STOP;
                    else rx_bit_count <= rx_bit_count + 1;
                end
            end
            
            RX_STOP: begin
                if (rx_baud_tick) begin
                     
                    if (rx_sync) begin
                        rx_data_reg <= rx_shift_reg[7:0];  
                        rx_valid <= 1;
                        rx_error <= 0;
                    end else begin
                        rx_error <= 1;  
                    end
					rx_int <= 1'b1;		 
                    rx_state <= RX_IDLE;
                end
            end
        endcase
    end
end

always @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
        tx_data_reg <= 8'b0;
        tx_start <= 1'b0;
    end else begin
        if (apb_write) begin
            case (reg_addr)
                REG_DATA: begin
                    if (!tx_busy) begin
                        tx_data_reg <= PWDATA[7:0];
                        tx_start <= 1'b1;
                    end
                end
                 
            endcase
        end
		 
		if (tx_state == TX_START) begin
			tx_start <= 1'b0;
		end
    end
end

always @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
        PRDATA <= 0;
    end else if (apb_read) begin
        case (reg_addr)
            REG_DATA: begin
                PRDATA <= {24'b0, rx_data_reg};
            end
            REG_STATUS: begin
                PRDATA <= {29'b0, status_rx_error, status_rx_valid, status_tx_busy};
            end
            REG_CTRL: begin
                PRDATA <= 0;  
            end
            default: begin
                PRDATA <= 0;
            end
        endcase
    end
end

reg pready;
always @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
		pready <= 1'b1;
	end else if (PSEL & !PWRITE & !PENABLE & pready) begin
		pready <= 1'b0;
	end else begin
		pready <= 1'b1;
	end
end
assign PREADY = pready;

endmodule

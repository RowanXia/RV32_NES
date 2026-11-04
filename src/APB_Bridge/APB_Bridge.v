// Modified for RV32 NES integration, 2026-11-01.
`timescale 1ns/1ps
// APB_Bridge.v -- RISC-V + NES, 2x6 AHB Matrix 的 S2 定制封装。
// 基于用户原 APB_Bridge.v 修改；两个 ARM CMSDK 模块保持逐字节不变。
// 2026-10-13
//
// CPU 地址视图：
//   0x1000_0000..0x1000_03FF -> PSEL0 -> Control_Reg
//   0x1000_0400..0x1000_07FF -> PSEL1 -> USART_APB
//   0x1006_0000..0x1006_00FF -> PSEL2 -> GPIO
//   0x0200_0000..0x0200_FFFF -> PSEL3 -> CLINT
//   0x0C00_0000..0x0FFF_FFFF -> PSEL4 -> PLIC
//   all other offsets          -> ERROR
// S2 外部地址由矩阵译码；本封装也检查完整基地址，防止低16位别名。
//
// 访问约定：只接受 4-byte 对齐的 32-bit 寄存器读写。
// 原 Control_Reg/USART_APB 没有使用 PSTRB 保护部分字节写；为保持这两个
// 外设不改动，本封装拒绝 byte/halfword/misaligned/oversize 访问。
// UART 仍是一字符8位，但其 MMIO 寄存器用 lw/sw 访问。
//
// 保留原16端口命名便于替换：端口2..15禁用，返回输入在内部硬接常量。
// 不是异步桥。PCLK=HCLK，PRESETn=HRESETn，PCLKEN=1。
// 本模块不生成时钟、不改变 USART 的波特率常量、不连接 Ethernet。
module APB_Bridge #(
    parameter AHB_ADDRWIDTH = 32,
    parameter APB_ADDRWIDTH = 32,
    parameter [31:0] APB_BASE_ADDR = 32'h1000_0000
)(
    input  wire                     HCLK,
    input  wire                     HRESETn,
    input  wire                     HSELS,
    input  wire [AHB_ADDRWIDTH-1:0]  HADDRS,
    input  wire [1:0]               HTRANS,
    input  wire [2:0]               HSIZES,
    input  wire                     HWRITES,
    // 必须连接矩阵的 HREADYMUX_APB，不要误接成一个独立常数或CPU全局HREADY。
    input  wire                     HREADYS,
    input  wire [31:0]              HWDATAS,
    input  wire [3:0]               HPROTS,
    output wire                     HREADYOUTS,
    output wire                     HRESPS,       // AHB-Lite: 1bit, OKAY/ERROR
    output wire [31:0]              HRDATAS,
    output wire                     PCLK,
    output wire                     PRESETn,
    output wire [APB_ADDRWIDTH-1:0]  PADDR,
    output wire                     PENABLE,
    output wire                     PWRITE,
    output wire [3:0]               PSTRB,
    output wire [2:0]               PPROT,
    output wire [31:0]              PWDATA,
    output wire                     APBACTIVE,
    output wire                     PSEL0,
    input  wire                     PREADY0,
    input  wire [31:0]              PRDATA0,
    input  wire                     PSLVERR0,
    output wire                     PSEL1,
    input  wire                     PREADY1,
    input  wire [31:0]              PRDATA1,
    input  wire                     PSLVERR1,
    output wire                     PSEL2,
    input  wire                     PREADY2,
    input  wire [31:0]              PRDATA2,
    input  wire                     PSLVERR2,
    output wire                     PSEL3,
    input  wire                     PREADY3,
    input  wire [31:0]              PRDATA3,
    input  wire                     PSLVERR3,
    output wire                     PSEL4,
    input  wire                     PREADY4,
    input  wire [31:0]              PRDATA4,
    input  wire                     PSLVERR4,
    output wire                     PSEL5,
    input  wire                     PREADY5,
    input  wire [31:0]              PRDATA5,
    input  wire                     PSLVERR5,
    output wire                     PSEL6,
    input  wire                     PREADY6,
    input  wire [31:0]              PRDATA6,
    input  wire                     PSLVERR6,
    output wire                     PSEL7,
    input  wire                     PREADY7,
    input  wire [31:0]              PRDATA7,
    input  wire                     PSLVERR7,
    output wire                     PSEL8,
    input  wire                     PREADY8,
    input  wire [31:0]              PRDATA8,
    input  wire                     PSLVERR8,
    output wire                     PSEL9,
    input  wire                     PREADY9,
    input  wire [31:0]              PRDATA9,
    input  wire                     PSLVERR9,
    output wire                     PSEL10,
    input  wire                     PREADY10,
    input  wire [31:0]              PRDATA10,
    input  wire                     PSLVERR10,
    output wire                     PSEL11,
    input  wire                     PREADY11,
    input  wire [31:0]              PRDATA11,
    input  wire                     PSLVERR11,
    output wire                     PSEL12,
    input  wire                     PREADY12,
    input  wire [31:0]              PRDATA12,
    input  wire                     PSLVERR12,
    output wire                     PSEL13,
    input  wire                     PREADY13,
    input  wire [31:0]              PRDATA13,
    input  wire                     PSLVERR13,
    output wire                     PSEL14,
    input  wire                     PREADY14,
    input  wire [31:0]              PRDATA14,
    input  wire                     PSLVERR14,
    output wire                     PSEL15,
    input  wire                     PREADY15,
    input  wire [31:0]              PRDATA15,
    input  wire                     PSLVERR15
);
    assign PCLK    = HCLK;
    assign PRESETn = HRESETn;

    wire        bridge_psel;
    wire        bridge_pready;
    wire        bridge_pslverr;
    wire [31:0] bridge_prdata;
    wire        mux_pready;
    wire        mux_pslverr;
    wire [31:0] mux_prdata;

    // HSIZE和原始地址低2位必须在AHB地址阶段被接受时记录。
    // CMSDK稍后输出的PADDR已把低2位置零；不能用它判断原始未对齐访问。
    wire ahb_accept = HSELS & HTRANS[1] & HREADYS;
    reg  word_access_q;
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn)
            word_access_q <= 1'b0;
        else if (ahb_accept)
            word_access_q <= (HSIZES == 3'b010) && (HADDRS[1:0] == 2'b00);
    end

    // 保留师兄的非额外寄存配置及CMSDK地址/数据阶段状态机。
    // 未选中外设、非法尺寸等错误也交给该状态机生成标准两周期AHB ERROR。
    cmsdk_ahb_to_apb #(
        .ADDRWIDTH      (AHB_ADDRWIDTH),
        .REGISTER_RDATA (0),
        .REGISTER_WDATA (0)
    ) ahb_to_apb (
        .HCLK      (HCLK),
        .HRESETn   (HRESETn),
        .PCLKEN    (1'b1),
        .HSEL      (HSELS),
        .HADDR     (HADDRS),
        .HTRANS    (HTRANS),
        .HSIZE     (HSIZES),
        .HPROT     (HPROTS),
        .HWRITE    (HWRITES),
        .HREADY    (HREADYS),
        .HWDATA    (HWDATAS),
        .HREADYOUT (HREADYOUTS),
        .HRDATA    (HRDATAS),
        .HRESP     (HRESPS),
        .PADDR     (PADDR),
        .PENABLE   (PENABLE),
        .PWRITE    (PWRITE),
        .PSTRB     (PSTRB),
        .PPROT     (PPROT),
        .PWDATA    (PWDATA),
        .PSEL      (bridge_psel),
        .APBACTIVE (APBACTIVE),
        .PRDATA    (bridge_prdata),
        .PREADY    (bridge_pready),
        .PSLVERR   (bridge_pslverr)
    );

    // 这里的PADDR来自CMSDK的地址寄存器，不使用正在流水变化的HADDRS。
    // 不减基址：保留完整PADDR；Control_Reg用[9:0]，USART_APB用[3:2]。
    wire ctrl_hit      = (PADDR >= 32'h1000_0000) && (PADDR <= 32'h1000_03FF);
    wire usart_hit     = (PADDR >= 32'h1000_0400) && (PADDR <= 32'h1000_07FF);
    wire gpio_hit      = (PADDR >= 32'h1006_0000) && (PADDR <= 32'h1006_00FF);
    wire clint_hit     = (PADDR >= 32'h0200_0000) && (PADDR <= 32'h0200_FFFF);
    wire plic_hit      = (PADDR >= 32'h0C00_0000) && (PADDR <= 32'h0FFF_FFFF);
    wire target_valid  = word_access_q &&
                         (ctrl_hit || usart_hit || gpio_hit || clint_hit || plic_hit);
    wire mux_psel      = HRESETn && bridge_psel && target_valid;
    reg [3:0] DECODE4BIT;

    always @(*) begin
        DECODE4BIT = 4'd15;             // 默认未命中，端口15禁用
        if (ctrl_hit)
            DECODE4BIT = 4'd0;
        else if (usart_hit)
            DECODE4BIT = 4'd1;
        else if (gpio_hit)
            DECODE4BIT = 4'd2;
        else if (clint_hit)
            DECODE4BIT = 4'd3;
        else if (plic_hit)
            DECODE4BIT = 4'd4;
    end

    // CMSDK MUX的“禁用端口”本身返回零值OKAY，不会自动生成ERROR。
    // 因此本封装显式补默认错误响应，而不是把未映射地址当成实际PSEL15。
    // 响应由bridge_psel/已锁存地址限定，不能在等待期间跟随下一条AHB地址。
    wire decode_error = bridge_psel && !target_valid;
    assign bridge_pready  = decode_error ? 1'b1 : mux_pready;
    assign bridge_pslverr = decode_error ? PENABLE : mux_pslverr;
    assign bridge_prdata  = decode_error ? 32'b0 : mux_prdata;

    cmsdk_apb_slave_mux #(
        .PORT0_ENABLE (1),
        .PORT1_ENABLE (1),
        .PORT2_ENABLE (1),
        .PORT3_ENABLE (1),
        .PORT4_ENABLE (1),
        .PORT5_ENABLE (0),
        .PORT6_ENABLE (0),
        .PORT7_ENABLE (0),
        .PORT8_ENABLE (0),
        .PORT9_ENABLE (0),
        .PORT10_ENABLE (0),
        .PORT11_ENABLE (0),
        .PORT12_ENABLE (0),
        .PORT13_ENABLE (0),
        .PORT14_ENABLE (0),
        .PORT15_ENABLE (0)
    ) apb_slave_mux (
        .DECODE4BIT (DECODE4BIT),
        .PSEL       (mux_psel),
        .PREADY     (mux_pready),
        .PSLVERR    (mux_pslverr),
        .PRDATA     (mux_prdata),
        .PSEL0     (PSEL0),
        .PREADY0   (PREADY0),
        .PRDATA0   (PRDATA0),
        .PSLVERR0  (PSLVERR0),
        .PSEL1     (PSEL1),
        .PREADY1   (PREADY1),
        .PRDATA1   (PRDATA1),
        .PSLVERR1  (PSLVERR1),
        .PSEL2     (PSEL2),
        .PREADY2   (PREADY2),
        .PRDATA2   (PRDATA2),
        .PSLVERR2  (PSLVERR2),
        .PSEL3     (PSEL3),
        .PREADY3   (PREADY3),
        .PRDATA3   (PRDATA3),
        .PSLVERR3  (PSLVERR3),
        .PSEL4     (PSEL4),
        .PREADY4   (PREADY4),
        .PRDATA4   (PRDATA4),
        .PSLVERR4  (PSLVERR4),
        .PSEL5     (PSEL5),
        .PREADY5   (1'b1),
        .PRDATA5   (32'b0),
        .PSLVERR5  (1'b0),
        .PSEL6     (PSEL6),
        .PREADY6   (1'b1),
        .PRDATA6   (32'b0),
        .PSLVERR6  (1'b0),
        .PSEL7     (PSEL7),
        .PREADY7   (1'b1),
        .PRDATA7   (32'b0),
        .PSLVERR7  (1'b0),
        .PSEL8     (PSEL8),
        .PREADY8   (1'b1),
        .PRDATA8   (32'b0),
        .PSLVERR8  (1'b0),
        .PSEL9     (PSEL9),
        .PREADY9   (1'b1),
        .PRDATA9   (32'b0),
        .PSLVERR9  (1'b0),
        .PSEL10    (PSEL10),
        .PREADY10  (1'b1),
        .PRDATA10  (32'b0),
        .PSLVERR10 (1'b0),
        .PSEL11    (PSEL11),
        .PREADY11  (1'b1),
        .PRDATA11  (32'b0),
        .PSLVERR11 (1'b0),
        .PSEL12    (PSEL12),
        .PREADY12  (1'b1),
        .PRDATA12  (32'b0),
        .PSLVERR12 (1'b0),
        .PSEL13    (PSEL13),
        .PREADY13  (1'b1),
        .PRDATA13  (32'b0),
        .PSLVERR13 (1'b0),
        .PSEL14    (PSEL14),
        .PREADY14  (1'b1),
        .PRDATA14  (32'b0),
        .PSLVERR14 (1'b0),
        .PSEL15    (PSEL15),
        .PREADY15  (1'b1),
        .PRDATA15  (32'b0),
        .PSLVERR15 (1'b0)
    );

    // 参数只保留与原顶层的接口兼容性。本定制版本服务32-bit SoC。
    // synthesis translate_off
    initial begin
        if (AHB_ADDRWIDTH != 32 || APB_ADDRWIDTH != 32) begin
            $display("ERROR: APB_Bridge requires 32-bit AHB/PADDR ports.");
            $finish;
        end
        if (APB_BASE_ADDR[15:0] != 16'b0) begin
            $display("ERROR: APB_BASE_ADDR must be 64KiB aligned.");
            $finish;
        end
    end
    // synthesis translate_on
endmodule

`timescale 1ns / 1ps

module HDMI_IN_DDR3_gauss_filter_top (
    // ==========================================
    // 1. 系统时钟与复位
    // ==========================================
    input  wire        clk_p,           // 125MHz 差分时钟输入
    input  wire        clk_n,
    input  wire        rst_n,           // 系统复位 (如按键)

    // ==========================================
    // 2. PCIe 物理接口 (对接 RK3568, 484封装)
    // ==========================================
    input  wire        pcie_refclk_p,   // PCIe 100MHz 参考时钟
    input  wire        pcie_refclk_n,
    input  wire        pcie_rx_p,       // PCIe 差分接收
    input  wire        pcie_rx_n,
    output wire        pcie_tx_p,       // PCIe 差分发送
    output wire        pcie_tx_n,
    input  wire        pcie_perst_n,    // RK3568发来的复位信号

    // ==========================================
    // 3. DDR3 内存接口
    // ==========================================
    output wire        mem_rst_n,
    output wire        mem_ck,
    output wire        mem_ck_n,
    output wire        mem_cke,
    output wire        mem_cs_n,
    output wire        mem_ras_n,
    output wire        mem_cas_n,
    output wire        mem_we_n,
    output wire        mem_odt,
    output wire [14:0] mem_a,
    output wire [2:0]  mem_ba,
    inout  wire [3:0]  mem_dqs,
    inout  wire [3:0]  mem_dqs_n,
    inout  wire [31:0] mem_dq,
    output wire [3:0]  mem_dm,

    // ==========================================
    // 4. 视频输入物理接口 (来自采集芯片/Sensor)
    // ==========================================
    input  wire        pixclk_in,
    input  wire        vs_in,
    input  wire        hs_in,
    input  wire        de_in,
    input  wire [7:0]  r_in,
    input  wire [7:0]  g_in,
    input  wire [7:0]  b_in
);

    // ==========================================
    // 内部信号声明 (极其重要，防止未定义报错)
    // ==========================================
    wire pix_clk;
    assign pix_clk = pixclk_in; // 统一视频时钟

    // 图像处理后的最终输出信号 (对接给 PCIe)
    wire [7:0] r_out;
    wire [7:0] g_out;
    wire [7:0] b_out;
    wire       de_out;
    wire       vs_out;
    wire       hs_out;

    // =========================================================
    // 【模块插入区】：你的 PLL、DDR3、高斯滤波 例化代码未来放在这里
    // =========================================================

    // 注意：为了保证你能先通过编译测试，我在这里写了“直通逻辑”，
    // 假装输入的视频数据已经处理完毕，直接发给输出线。
    // 等你这版代码编译通过后，你再把这几行 assign 删掉，
    // 替换成你真实的 module 例化（比如 gauss_filter 模块）。
    
    assign r_out  = r_in;
    assign g_out  = g_in;
    assign b_out  = b_in;
    assign de_out = de_in;
    assign vs_out = vs_in;
    assign hs_out = hs_in;

    // =========================================================
    // 终极对接：PCIe DMA 视频流推送引擎 (128-bit AXI-Stream)
    // =========================================================
    
    // --- PCIe 内部逻辑连线 ---
    wire        pcie_user_clk;     
    wire        pcie_user_rst_n;   
    wire        pcie_link_up;      
    wire        pcie_tready;       

    // 1. 提取场同步下降沿 (生成 tlast 信号，告诉RK3568一帧传完了)
    reg vs_out_d1;
    always @(posedge pix_clk) begin
        vs_out_d1 <= vs_out;
    end
    wire frame_end_pulse = (~vs_out) & vs_out_d1; 

    // 2. 数据拼接逻辑：将 24-bit 的 RGB 像素拼接成 128-bit 总线数据
    wire [127:0] pcie_data_bus;
    assign pcie_data_bus = {104'd0, r_out, g_out, b_out}; 

    // 3. 例化纯血 PCIe IP 核心
    pcie u_pcie_top (
        .p_refck_n           (pcie_refclk_n),     
        .p_refck_p           (pcie_refclk_p),
        .p_rx_n              (pcie_rx_n),         
        .p_rx_p              (pcie_rx_p),
        .p_tx_n              (pcie_tx_n),         
        .p_tx_p              (pcie_tx_p),
        .p_perst_n           (pcie_perst_n),      

        .p_user_clk          (pcie_user_clk),     
        .p_user_reset_n      (pcie_user_rst_n),   
        .p_link_up           (pcie_link_up),      

        .axis_master_tdata    (pcie_data_bus),     
        .axis_master_tvalid   (de_out),            
        .axis_master_tready   (pcie_tready),       
        .axis_master_tlast    (frame_end_pulse),   
        .axis_master_tuser    (1'b0),              
        .axis_master_tkeep    (16'hFFFF),          

        .axis_slave0_tdata    (),
        .axis_slave0_tvalid   (1'b0),
        .axis_slave0_tready   (),
        .axis_slave0_tlast    (1'b0),
        .axis_slave0_tuser    (),
        .axis_slave0_tkeep    (16'h0000)
    );

endmodule
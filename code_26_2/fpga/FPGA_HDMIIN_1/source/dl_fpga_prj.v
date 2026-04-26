`timescale 1ns / 1ps
//===============================================================================
// 模块声明：顶层FPGA工程模块 (HDMI -> DDR3 -> PCIe 纯净版)
//===============================================================================
module dl_fpga_prj #(
   parameter MEM_ROW_WIDTH        = 15         ,    // DDR3行地址宽度
   parameter MEM_COLUMN_WIDTH     = 10         ,    // DDR3列地址宽度
   parameter MEM_BANK_WIDTH       = 3          ,    // DDR3 Bank地址宽度
   parameter MEM_DQ_WIDTH         = 16         ,    // DDR3数据位宽
   parameter MEM_DQS_WIDTH        = 2               // DDR3 DQS信号数量
)(
    //===========================================================================
    // 系统时钟和复位信号
    //===========================================================================
    input                                sys_clk                      ,    // 系统参考时钟（40MHz）
    input                                sys_rst_n                    ,    // 系统复位信号（低有效）

    //===========================================================================
    // DDR3物理接口信号
    //===========================================================================
    output                               ddr3_cs_n                    ,    
    output                               ddr3_rst_n                   ,    
    output                               ddr3_ck                      ,    
    output                               ddr3_ck_n                    ,    
    output                               ddr3_cke                     ,    
    output                               ddr3_ras_n                   ,    
    output                               ddr3_cas_n                   ,    
    output                               ddr3_we_n                    ,    
    output                               ddr3_odt                     ,    
    output      [MEM_ROW_WIDTH-1:0]      ddr3_a                       ,    
    output      [MEM_BANK_WIDTH-1:0]     ddr3_ba                      ,    
    inout       [MEM_DQ_WIDTH/8-1:0]     ddr3_dqs                     ,    
    inout       [MEM_DQ_WIDTH/8-1:0]     ddr3_dqs_n                   ,    
    inout       [MEM_DQ_WIDTH-1:0]       ddr3_dq                      ,    
    output      [MEM_DQ_WIDTH/8-1:0]     ddr3_dm                      ,    

    //===========================================================================
    // HDMI 输入信号 (MS7200)
    //===========================================================================
    input                                hdmi_pix_clk                  ,
    input                                hdmi_vs                       ,
    input                                hdmi_hs                       ,
    input                                hdmi_de                       ,
    input       [7:0]                    hdmi_r                        ,
    input       [7:0]                    hdmi_g                        ,
    input       [7:0]                    hdmi_b                        ,
    inout                                hdmi_rx_scl                   ,
    inout                                hdmi_rx_sda                   ,
    
    //===========================================================================
    // PCIe物理接口信号
    //===========================================================================
    input					             pcie_refclk_p                ,    // PCIe参考时钟正
	input					             pcie_refclk_n                ,    // PCIe参考时钟负
	input					             pcie_perst_n                 ,    // PCIe插槽复位信号
	input		[1:0]		             pcie_rxn                     ,    
	input		[1:0]		             pcie_rxp                     ,    
	output wire	[1:0]		             pcie_txn                     ,    
	output wire	[1:0]		             pcie_txp                          
);

//===============================================================================
// HDMI 信号处理与 I2C 配置
//===============================================================================
wire hdmi_rx_init_done;
wire hdmi_video_rst_n;
wire [15:0] hdmi_rgb565;
assign hdmi_rgb565      = {hdmi_r[7:3], hdmi_g[7:2], hdmi_b[7:3]};

localparam [19:0] HDMI_IIC_STARTUP_CYCLES = 20'd1_000_000;
reg [19:0] hdmi_iic_startup_cnt;
reg        hdmi_iic_rstn;

always @(posedge clk_10m or negedge lock) begin
    if (!lock) begin
        hdmi_iic_startup_cnt <= 20'd0;
        hdmi_iic_rstn        <= 1'b0;
    end else if (hdmi_iic_startup_cnt == HDMI_IIC_STARTUP_CYCLES) begin
        hdmi_iic_startup_cnt <= hdmi_iic_startup_cnt;
        hdmi_iic_rstn        <= 1'b1;
    end else begin
        hdmi_iic_startup_cnt <= hdmi_iic_startup_cnt + 20'd1;
        hdmi_iic_rstn        <= 1'b0;
    end
end

reg [2:0] ddr_init_done_hdmi_sync;
reg [2:0] hdmi_rx_init_done_hdmi_sync;

always @(posedge hdmi_pix_clk or negedge hdmi_iic_rstn) begin
    if (!hdmi_iic_rstn) begin
        ddr_init_done_hdmi_sync     <= 3'd0;
        hdmi_rx_init_done_hdmi_sync <= 3'd0;
    end else begin
        ddr_init_done_hdmi_sync     <= {ddr_init_done_hdmi_sync[1:0], ddr_init_done};
        hdmi_rx_init_done_hdmi_sync <= {hdmi_rx_init_done_hdmi_sync[1:0], hdmi_rx_init_done};
    end
end

assign hdmi_video_rst_n = ddr_init_done_hdmi_sync[2] && hdmi_rx_init_done_hdmi_sync[2];

wire hdmi_iic_trig, hdmi_iic_wr, hdmi_iic_busy, hdmi_iic_byte_over;
wire [15:0] hdmi_iic_addr;
wire [7:0]  hdmi_iic_wdata, hdmi_iic_rdata, hdmi_iic_device_id;
wire hdmi_sda_in, hdmi_sda_out, hdmi_sda_oe;

assign hdmi_rx_sda = hdmi_sda_oe ? hdmi_sda_out : 1'bz;
assign hdmi_sda_in = hdmi_rx_sda;

ms7200_ctl u_hdmi_rx_ms7200_ctl (
    .clk        (clk_10m),
    .rstn       (hdmi_iic_rstn),
    .init_over  (hdmi_rx_init_done),
    .device_id  (hdmi_iic_device_id),
    .iic_trig   (hdmi_iic_trig),
    .w_r        (hdmi_iic_wr),
    .addr       (hdmi_iic_addr),
    .data_in    (hdmi_iic_wdata),
    .busy       (hdmi_iic_busy),
    .data_out   (hdmi_iic_rdata),
    .byte_over  (hdmi_iic_byte_over)
);

iic_dri #(
    .CLK_FRE    (27'd10_000_000),
    .IIC_FREQ   (20'd400_000),
    .T_WR       (10'd1),
    .ADDR_BYTE  (2'd2),
    .LEN_WIDTH  (8'd3),
    .DATA_BYTE  (2'd1)
) u_hdmi_rx_iic_dri (
    .clk        (clk_10m),
    .rstn       (hdmi_iic_rstn),
    .pluse      (hdmi_iic_trig),
    .device_id  (hdmi_iic_device_id),
    .w_r        (hdmi_iic_wr),
    .byte_len   (4'd1),
    .addr       (hdmi_iic_addr),
    .data_in    (hdmi_iic_wdata),
    .busy       (hdmi_iic_busy),
    .byte_over  (hdmi_iic_byte_over),
    .data_out   (hdmi_iic_rdata),
    .scl        (hdmi_rx_scl),
    .sda_in     (hdmi_sda_in),
    .sda_out    (hdmi_sda_out),
    .sda_out_en (hdmi_sda_oe)
);

//===============================================================================
// 内部参数与网络定义
//===============================================================================
parameter CTRL_ADDR_WIDTH = MEM_ROW_WIDTH + MEM_BANK_WIDTH + MEM_COLUMN_WIDTH;  

wire ddrphy_cpd_lock, ddr_init_done, pll_lock, core_clk;
wire [CTRL_ADDR_WIDTH-1:0] axi_awaddr, axi_araddr;
wire [3:0] axi_awuser_id, axi_awlen, axi_aruser_id, axi_arlen, axi_wusero_id, axi_rid;
wire axi_awuser_ap, axi_awready, axi_awvalid, axi_wready, axi_wusero_last;
wire axi_aruser_ap, axi_arready, axi_arvalid, axi_rvalid, axi_rlast;
wire [MEM_DQ_WIDTH*8-1:0] axi_wdata, axi_rdata;
wire [MEM_DQ_WIDTH*8/8-1:0] axi_wstrb;

wire lock, clk_10m, clk_25m, clk_50m;
wire pclk_div2, pclk, ref_clk, core_rst_n;
wire smlh_link_up, rdlh_link_up;

//===============================================================================
// PLL时钟管理
//===============================================================================
pll dl_pll_inst (
  .clkout0(clk_10m),    
  .clkout1(clk_25m),    
  .clkout2(clk_50m),    
  .lock(lock),          
  .clkin1(sys_clk)      
);

//===============================================================================
// HDMI 图像格式化模块 (通道0)
//===============================================================================
wire        ch0_write_data_valid;
wire [15:0] ch0_write_data;

img_data_stream_reducer dl_ch0_image_reshape(
    .clk                    (hdmi_pix_clk               ),
    .rst_n                  (hdmi_video_rst_n           ),
    .img_vs                 (hdmi_vs                    ),
    .img_data_valid         (hdmi_de                    ),
    .img_data               (hdmi_rgb565                ),
    .img_data_valid_out     (ch0_write_data_valid       ),   
    .img_data_out           (ch0_write_data             )    
);

//===============================================================================
// PCIe AXI Stream 接口和 DMA
//===============================================================================
wire        axis_master_tvalid, axis_master_tready, axis_master_tlast;
wire [127:0] axis_master_tdata;
wire [3:0]   axis_master_tkeep;
wire [7:0]   axis_master_tuser;
wire        axis_slave0_tready, axis_slave0_tvalid, axis_slave0_tlast, axis_slave0_tuser;
wire [127:0] axis_slave0_tdata;
wire        axis_slave1_tready, axis_slave1_tvalid, axis_slave1_tlast, axis_slave1_tuser;
wire [127:0] axis_slave1_tdata;
wire        axis_slave2_tready, axis_slave2_tvalid, axis_slave2_tlast, axis_slave2_tuser;
wire [127:0] axis_slave2_tdata;

wire dma_write_req;
wire [11:0] dma_write_addr;
wire [127:0] dma_write_data;

reg [2:0] ddr_init_done_pclk_sync;
wire      ch0_rframe_rst_n;

always @(posedge pclk_div2 or negedge core_rst_n) begin
    if (!core_rst_n) begin
        ddr_init_done_pclk_sync <= 3'd0;
    end else begin
        ddr_init_done_pclk_sync <= {ddr_init_done_pclk_sync[1:0], ddr_init_done};
    end
end

assign ch0_rframe_rst_n = core_rst_n && ddr_init_done_pclk_sync[2];

// ===============================================================================
// 🚀 修复版：PCIe DMA 帧同步逻辑 (原生场同步信号触发)
// ===============================================================================
reg          ch0_read_frame_req;
wire         ch0_read_req_ack, ch0_read_data_en, ch0_line_full_flag;
wire [127:0] ch0_read_data;

reg ch0_read_req_ack_d1, ch0_read_req_ack_d2;
wire ch0_read_req_ack_pclk = ch0_read_req_ack_d2;

always @(posedge pclk_div2) begin
    if (!core_rst_n) begin
        ch0_read_req_ack_d1 <= 1'b0;
        ch0_read_req_ack_d2 <= 1'b0;
    end else begin
        ch0_read_req_ack_d1 <= ch0_read_req_ack;
        ch0_read_req_ack_d2 <= ch0_read_req_ack_d1;
    end
end

// 1. 将 hdmi_vs 信号跨时钟域同步到 PCIe 时钟域 (pclk_div2)，并消除亚稳态
reg hdmi_vs_d1, hdmi_vs_d2, hdmi_vs_d3;
always @(posedge pclk_div2) begin
    if (!core_rst_n) begin
        hdmi_vs_d1 <= 1'b0;
        hdmi_vs_d2 <= 1'b0;
        hdmi_vs_d3 <= 1'b0;
    end else begin
        hdmi_vs_d1 <= hdmi_vs;
        hdmi_vs_d2 <= hdmi_vs_d1;
        hdmi_vs_d3 <= hdmi_vs_d2;
    end
end

// 2. 检测 hdmi_vs 的下降沿（代表一帧图像从 HDMI 接收完毕，已存入 DDR3）
wire frame_done_pulse = (~hdmi_vs_d2) & hdmi_vs_d3;

// 3. 使用真实的帧结束脉冲来触发 DMA 读取
always @(posedge pclk_div2) begin
    if (!core_rst_n) begin
        ch0_read_frame_req <= 1'b0;
    end else if (frame_done_pulse) begin
        // 真正的“发令枪”！一帧存满，立刻通知 PCIe 抽水！
        ch0_read_frame_req <= 1'b1; 
    end else if (ch0_read_req_ack_pclk) begin
        ch0_read_frame_req <= 1'b0;
    end
end
//===============================================================================
// PCIe 图像选择模块 (只用通道0)
//===============================================================================
pcie_image_channel_selector dl_pcie_img_select_inst(
    .clk                         (pclk_div2),     
    .rst_n                       (core_rst_n),     
    .dma_sim_vs                  (ch0_read_frame_req),     
    .line_full_flag              (ch0_line_full_flag), 

    .ch0_data_req                (ch0_read_data_en),     
    .ch0_data                    (ch0_read_data),     
    
    // 空闲通道 1,2,3 安全接地处理
    .ch1_data_req                (),     
    .ch1_data                    (128'd0),     
    .ch2_data_req                (),     
    .ch2_data                    (128'd0),     
    .ch3_data_req                (),     
    .ch3_data                    (128'd0),     

    .dma_wr_data_req             (dma_write_req),     
    .dma_wr_data                 (dma_write_data)      
);

//===============================================================================
// DDR3 AXI 控制器
//===============================================================================
mem_axi_burst_ctrl_core dl_axi_ctrl_inst (
	  .ARESETN                     (ddr_init_done),
	  .ACLK                        (core_clk),
	  .M_AXI_AWID                  (axi_awuser_id),
	  .M_AXI_AWADDR                (axi_awaddr),
	  .M_AXI_AWLEN                 (axi_awlen),
      .M_AXI_AWUSER                (axi_awuser_ap),
	  .M_AXI_AWVALID               (axi_awvalid),
	  .M_AXI_AWREADY               (axi_awready),
	  .M_AXI_WDATA                 (axi_wdata),
	  .M_AXI_WSTRB                 (axi_wstrb),
	  .M_AXI_WREADY                (axi_wready),
      .M_AXI_BVALID                (1'b1),
	  .M_AXI_ARID                  (axi_aruser_id),
	  .M_AXI_ARADDR                (axi_araddr),
	  .M_AXI_ARLEN                 (axi_arlen),
      .M_AXI_ARUSER                (axi_aruser_ap),
	  .M_AXI_ARVALID               (axi_arvalid),
	  .M_AXI_ARREADY               (axi_arready),
	  .M_AXI_RID                   (axi_rid),
	  .M_AXI_RDATA                 (axi_rdata),
	  .M_AXI_RLAST                 (axi_rlast),
	  .M_AXI_RVALID                (axi_rvalid),

      .key                         ({1'b1,3'b111,4'b0000}),

      // 通道0 (HDMI专用)   
      .ch0_wframe_pclk             (hdmi_pix_clk),
      .ch0_wframe_rst_n            (hdmi_video_rst_n),
      .ch0_wframe_vsync            (hdmi_vs),
      .ch0_wframe_data_valid       (ch0_write_data_valid),         
      .ch0_wframe_data             (ch0_write_data),
      .ch0_rframe_pclk             (pclk_div2),   
    .ch0_rframe_rst_n            (ch0_rframe_rst_n),
      .ch0_rframe_vsync            (ch0_read_frame_req),
      .ch0_rframe_req              (ch0_read_frame_req),
      .ch0_rframe_req_ack          (ch0_read_req_ack),
      .ch0_rframe_data_en          (ch0_read_data_en),
      .ch0_rframe_data             (ch0_read_data),      
      .ch0_read_line_full          (ch0_line_full_flag),

      // 通道1,2,3 安全屏蔽
      .ch1_wframe_pclk             (1'b0),
      .ch1_wframe_rst_n            (1'b0),
      .ch1_wframe_vsync            (1'b0),
      .ch1_wframe_data_valid       (1'b0),          
      .ch1_wframe_data             (16'd0),      
      .ch1_rframe_pclk             (1'b0),   
      .ch1_rframe_rst_n            (1'b0), 
      .ch1_rframe_vsync            (1'b0),
      .ch1_rframe_req              (1'b0),

      .ch2_wframe_pclk             (1'b0),
      .ch2_wframe_rst_n            (1'b0),
      .ch2_wframe_vsync            (1'b0),
      .ch2_wframe_data_valid       (1'b0),
      .ch2_wframe_data             (16'd0),
      .ch2_rframe_pclk             (1'b0),   
      .ch2_rframe_rst_n            (1'b0), 
      .ch2_rframe_vsync            (1'b0),
      .ch2_rframe_req              (1'b0),

      .ch3_wframe_pclk             (1'b0),  
      .ch3_wframe_rst_n            (1'b0),
      .ch3_wframe_vsync            (1'b0),
      .ch3_wframe_data_valid       (1'b0),
      .ch3_wframe_data             (16'd0),
      .ch3_rframe_pclk             (1'b0),   
      .ch3_rframe_rst_n            (1'b0), 
      .ch3_rframe_vsync            (1'b0),
      .ch3_rframe_req              (1'b0)
);

//===============================================================================
// DDR3内存控制器 IP核
//===============================================================================
ddr3 #(
    .MEM_ROW_WIDTH              (MEM_ROW_WIDTH),
    .MEM_COLUMN_WIDTH           (MEM_COLUMN_WIDTH),
    .MEM_BANK_WIDTH             (MEM_BANK_WIDTH),
    .MEM_DQ_WIDTH               (MEM_DQ_WIDTH),
    .MEM_DM_WIDTH               (MEM_DQS_WIDTH),
    .MEM_DQS_WIDTH              (MEM_DQS_WIDTH),
    .CTRL_ADDR_WIDTH            (CTRL_ADDR_WIDTH)
  ) dl_I_ips_ddr_top(
    .ref_clk                    (sys_clk),    
    .resetn                     (sys_rst_n),    
    .core_clk                   (core_clk),
    .pll_lock                   (pll_lock),
    .ddrphy_cpd_lock            (ddrphy_cpd_lock),
    .ddr_init_done              (ddr_init_done),

    .axi_awaddr                 (axi_awaddr),
    .axi_awuser_ap              (axi_awuser_ap),
    .axi_awuser_id              (axi_awuser_id),
    .axi_awlen                  (axi_awlen),
    .axi_awready                (axi_awready),
    .axi_awvalid                (axi_awvalid),
    .axi_wdata                  (axi_wdata),
    .axi_wstrb                  (axi_wstrb),
    .axi_wready                 (axi_wready),
    .axi_wusero_id              (axi_wusero_id),
    .axi_wusero_last            (axi_wusero_last),

    .axi_araddr                 (axi_araddr),
    .axi_aruser_ap              (axi_aruser_ap),
    .axi_aruser_id              (axi_aruser_id),
    .axi_arlen                  (axi_arlen),
    .axi_arready                (axi_arready),
    .axi_arvalid                (axi_arvalid),
    .axi_rdata                  (axi_rdata),
    .axi_rid                    (axi_rid),
    .axi_rlast                  (axi_rlast),
    .axi_rvalid                 (axi_rvalid),

    .apb_clk                    (1'b0),    
    .apb_rst_n                  (1'b0),    
    .apb_sel                    (1'b0),    
    .apb_enable                 (1'b0),    
    .apb_addr                   (8'd0),    
    .apb_write                  (1'b0),    
    .apb_wdata                  (16'd0),    

    .mem_cs_n                   (ddr3_cs_n),
    .mem_rst_n                  (ddr3_rst_n),
    .mem_ck                     (ddr3_ck),
    .mem_ck_n                   (ddr3_ck_n),
    .mem_cke                    (ddr3_cke),
    .mem_ras_n                  (ddr3_ras_n),
    .mem_cas_n                  (ddr3_cas_n),
    .mem_we_n                   (ddr3_we_n),
    .mem_odt                    (ddr3_odt),
    .mem_a                      (ddr3_a),
    .mem_ba                     (ddr3_ba),
    .mem_dqs                    (ddr3_dqs),
    .mem_dqs_n                  (ddr3_dqs_n),
    .mem_dq                     (ddr3_dq),
    .mem_dm                     (ddr3_dm),

    .dbg_gate_start             (1'b0),    
    .dbg_cpd_start              (1'b0),    
    .dbg_ddrphy_rst_n           (1'b1),    
    .dbg_gpll_scan_rst          (1'b0),    
    .samp_position_dyn_adj      (1'b0),    
    .init_samp_position_even    (16'd0),    
    .init_samp_position_odd     (16'd0),    
    .wrcal_position_dyn_adj     (1'b0),    
    .init_wrcal_position        (16'd0),    
    .force_read_clk_ctrl        (1'b0),    
    .init_slip_step             (8'd0),    
    .init_read_clk_ctrl         (6'd0),    
    .debug_cpd_offset_adj       (1'b0),    
    .debug_cpd_offset_dir       (1'b0),    
    .debug_cpd_offset           (10'd0),    
    .ck_dly_en                  (1'b0),    
    .init_ck_dly_step           (8'd0)     
  );

//===============================================================================
// PCIe 物理层、DMA及寄存器逻辑
//===============================================================================
wire sync_perst_n;

hsst_rst_cross_sync_v1_0 #(.RST_CNTR_VALUE(16'hC000))
dl_u_refclk_perstn_debounce(
    .clk                (ref_clk),
    .rstn_in            (pcie_perst_n),
    .rstn_out           (sync_perst_n)
);

hsst_rst_sync_v1_0 dl_u_ref_core_rstn_sync (
    .clk                (ref_clk),
    .rst_n              (core_rst_n),
    .sig_async          (1'b1),
    .sig_synced         () // ref_core_rst_n
);

hsst_rst_sync_v1_0 dl_u_pclk_core_rstn_sync (
    .clk                (pclk),
    .rst_n              (core_rst_n),
    .sig_async          (1'b1),
    .sig_synced         () // s_pclk_rstn
);

wire [7:0] cfg_pbus_num;
wire [4:0] cfg_pbus_dev_num;
wire [2:0] cfg_max_rd_req_size, cfg_max_payload_size;
wire cfg_rcb;

pcie_dma_core #(
	.DEVICE_TYPE			(3'b000),
	.AXIS_SLAVE_NUM			(3)
) dl_u_ips2l_pcie_dma (
	.clk					(pclk_div2),			         
	.rst_n					(core_rst_n),                    
	.i_cfg_pbus_num			(cfg_pbus_num),				
	.i_cfg_pbus_dev_num		(cfg_pbus_dev_num),			
	.i_cfg_max_rd_req_size	(cfg_max_rd_req_size),		
	.i_cfg_max_payload_size	(cfg_max_payload_size),		
	.i_axis_master_tvld		(axis_master_tvalid),	
	.o_axis_master_trdy		(axis_master_tready),	
	.i_axis_master_tdata	(axis_master_tdata),	
	.i_axis_master_tkeep	(axis_master_tkeep),	
	.i_axis_master_tlast	(axis_master_tlast),	
	.i_axis_master_tuser	(axis_master_tuser),	

	.i_axis_slave0_trdy		(axis_slave0_tready),		
	.o_axis_slave0_tvld		(axis_slave0_tvalid),	
	.o_axis_slave0_tdata	(axis_slave0_tdata),	
	.o_axis_slave0_tlast	(axis_slave0_tlast),	
	.o_axis_slave0_tuser	(axis_slave0_tuser),	

    .i_axis_slave1_trdy		(axis_slave1_tready),
    .o_axis_slave1_tvld		(axis_slave1_tvalid),
    .o_axis_slave1_tdata	(axis_slave1_tdata),
    .o_axis_slave1_tlast	(axis_slave1_tlast),
    .o_axis_slave1_tuser	(axis_slave1_tuser),

    .i_axis_slave2_trdy		(axis_slave2_tready),
    .o_axis_slave2_tvld		(axis_slave2_tvalid),
    .o_axis_slave2_tdata	(axis_slave2_tdata),
    .o_axis_slave2_tlast	(axis_slave2_tlast),
    .o_axis_slave2_tuser	(axis_slave2_tuser),

	.i_cfg_ido_req_en		(1'b0),			
	.i_cfg_ido_cpl_en		(1'b0),			
	.i_xadm_ph_cdts			(8'b0),				
	.i_xadm_pd_cdts			(12'b0),				
	.i_xadm_nph_cdts		(8'b0),			
	.i_xadm_npd_cdts		(12'b0),			
	.i_xadm_cplh_cdts		(8'b0),			
	.i_xadm_cpld_cdts		(12'b0),			

	.i_apb_psel				(1'b0),				
	.i_apb_paddr			(9'd0),				
	.i_apb_pwdata			(32'd0),					
	.i_apb_pstrb			(4'd0),					
	.i_apb_pwrite			(1'b0),						
	.i_apb_penable			(1'b0),						

    .o_dma_write_data_req   (dma_write_req),
    .o_dma_write_addr       (dma_write_addr),
    .i_dma_write_data       (dma_write_data)
);

pcie_test dl_u_ips2l_pcie_wrap (
	.button_rst_n				(1'b1),	
	.power_up_rst_n				(1'b1),			
	.perst_n					(sync_perst_n),
	.pclk						(pclk),					
	.pclk_div2					(pclk_div2),			
	.ref_clk					(ref_clk),				
	.ref_clk_n					(pcie_refclk_n),			
	.ref_clk_p					(pcie_refclk_p),			
	.core_rst_n					(core_rst_n),			
	.p_sel						(1'b0),			
	.p_strb						(4'd0),			
	.p_addr						(16'd0),			
	.p_wdata					(32'd0),			
	.p_ce						(1'b0),			
	.p_we						(1'b0),			
	.rxn						(pcie_rxn),					
	.rxp						(pcie_rxp),					
	.txn						(pcie_txn),					
	.txp						(pcie_txp),					
	.pcs_nearend_loop			({4{1'b0}}),			
	.pma_nearend_ploop			({4{1'b0}}),			
	.pma_nearend_sloop			({4{1'b0}}),			
	.axis_master_tvalid			(axis_master_tvalid),	
	.axis_master_tready			(axis_master_tready),	
	.axis_master_tdata			(axis_master_tdata),	
	.axis_master_tkeep			(axis_master_tkeep),	
	.axis_master_tlast			(axis_master_tlast),	
	.axis_master_tuser			(axis_master_tuser),	
	.axis_slave0_tready			(axis_slave0_tready),	
	.axis_slave0_tvalid			(axis_slave0_tvalid),	
	.axis_slave0_tdata			(axis_slave0_tdata),	
	.axis_slave0_tlast			(axis_slave0_tlast),	
	.axis_slave0_tuser			(axis_slave0_tuser),	
    .axis_slave1_tready			(axis_slave1_tready),
    .axis_slave1_tvalid			(axis_slave1_tvalid),
    .axis_slave1_tdata			(axis_slave1_tdata),
    .axis_slave1_tlast			(axis_slave1_tlast),
    .axis_slave1_tuser			(axis_slave1_tuser),
    .axis_slave2_tready			(axis_slave2_tready),
    .axis_slave2_tvalid			(axis_slave2_tvalid),
    .axis_slave2_tdata			(axis_slave2_tdata),
    .axis_slave2_tlast			(axis_slave2_tlast),
    .axis_slave2_tuser			(axis_slave2_tuser),
	.cfg_max_rd_req_size		(cfg_max_rd_req_size),	
	.cfg_max_payload_size		(cfg_max_payload_size),	
	.cfg_rcb					(cfg_rcb),				
	.cfg_pbus_num				(cfg_pbus_num),			
	.cfg_pbus_dev_num			(cfg_pbus_dev_num),		
	.diag_ctrl_bus				(2'b0),					
	.app_ras_des_sd_hold_ltssm	(1'b0),					
	.app_ras_des_tba_ctrl		(2'b0),					
	.dyn_debug_info_sel			(4'b0),					
	.smlh_link_up				(smlh_link_up),			
	.rdlh_link_up				(rdlh_link_up)			
);

endmodule
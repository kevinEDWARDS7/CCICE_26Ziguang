//FPGA我只用小眼睛队一体板FPGA工程
`timescale 1ns / 1ps
//===============================================================================
// 模块声明：顶层FPGA工程模块
//===============================================================================
module dl_fpga_prj #(
   //===========================================================================
   // DDR3内存参数配置
   //===========================================================================
   parameter MEM_ROW_WIDTH        = 15         ,    // DDR3行地址宽度（15bit = 32K行）
   parameter MEM_COLUMN_WIDTH     = 10         ,    // DDR3列地址宽度（10bit = 1K列）
   parameter MEM_BANK_WIDTH       = 3          ,    // DDR3 Bank地址宽度（3bit = 8个Bank）
   parameter MEM_DQ_WIDTH          = 16         ,    // DDR3数据位宽（16bit数据总线）
   parameter MEM_DQS_WIDTH         = 2              // DDR3 DQS信号数量（2个，对应8bit字节使能）

)(
    //===========================================================================
    // 系统时钟和复位信号
    //===========================================================================
    input                                sys_clk                      ,    // 系统参考时钟（40MHz），用于PLL输入
    input                                sys_rst_n                    ,    // 系统复位信号（低有效），来自板级复位源

    //=====================.======================================================
    // DDR3物理接口信号（直接连接到DDR3颗粒）
    //===========================================================================
    output                               ddr3_cs_n                    ,    // 片选信号（低有效）
    output                               ddr3_rst_n                   ,    // DDR3复位信号（低有效）
    output                               ddr3_ck                      ,    // DDR3时钟信号（差分正）
    output                               ddr3_ck_n                    ,    // DDR3时钟信号（差分负）
    output                               ddr3_cke                     ,    // 时钟使能信号（高有效）
    output                               ddr3_ras_n                   ,    // 行地址选通（低有效）
    output                               ddr3_cas_n                   ,    // 列地址选通（低有效）
    output                               ddr3_we_n                    ,    // 写使能信号（低有效）
    output                               ddr3_odt                     ,    // 片上终端电阻控制
    output      [MEM_ROW_WIDTH-1:0]      ddr3_a                       ,    // 地址总线（行/列地址复用）
    output      [MEM_BANK_WIDTH-1:0]     ddr3_ba                      ,    // Bank地址总线
    inout       [MEM_DQ_WIDTH/8-1:0]     ddr3_dqs                     ,    // 数据选通信号（差分正，输入输出）
    inout       [MEM_DQ_WIDTH/8-1:0]     ddr3_dqs_n                   ,    // 数据选通信号（差分负，输入输出）
    inout       [MEM_DQ_WIDTH-1:0]       ddr3_dq                      ,    // 数据总线（16bit，输入输出）
    output      [MEM_DQ_WIDTH/8-1:0]     ddr3_dm                      ,    // 数据掩码信号（写使能控制）


    //===========================================================================
    // HSST光纤信号
    //===========================================================================
    //    input                                i_free_clk                    ,
    //    input                                i_pll_rst_0                   ,
    //    input                                i_wtchdg_clr_0                ,
    output  [1:0]                        o_wtchdg_st_0                 ,
    output                               o_pll_done_0                  ,
    output                               o_txlane_done_2               ,
    output                               o_rxlane_done_2               ,
    //    input                                i_p_refckn_0                  ,
    //    input                                i_p_refckp_0                  ,
    output                               o_p_pll_lock_0                ,
    output                               o_p_rx_sigdet_sta_2           ,
    output                               o_p_lx_cdr_align_2            ,
    input                                i_p_l2rxn                     ,
    input                                i_p_l2rxp                     ,
    output                               o_p_l2txn                     ,
    output                               o_p_l2txp                     ,
    output  [2:0]                        o_rxstatus_2                  ,
    output  [3:0]                        o_rdisper_2                   ,
    output  [3:0]                        o_rdecer_2                    , 
    //    input                                src_rst                       ,
    //    input                                chk_rst                       ,
    output                               tx_disable                    ,
    output  [3:0]                        o_pl_err,
    output  [1:0]                        cam_init_done                 ,

    // 40PIN HDMI input daughter card, MS7200 RGB888 parallel output.
    input                                hdmi_pix_clk                  ,
    input                                hdmi_vs                       ,
    input                                hdmi_hs                       ,
    input                                hdmi_de                       ,
    input       [7:0]                    hdmi_r                        ,
    input       [7:0]                    hdmi_g                        ,
    input       [7:0]                    hdmi_b                        ,
    output                               hdmi_rx_init_done             ,
    inout                                hdmi_rx_scl                   ,
    inout                                hdmi_rx_sda                   ,
    
    //===========================================================================
    // 摄像头1接口信号（OV5640）
    //===========================================================================
    inout                                cam1_scl                      ,    // I2C时钟线（用于配置摄像头寄存器）
    inout                                cam1_sda                      ,    // I2C数据线（双向，用于配置摄像头寄存器）
    input                                cam1_vsync                    ,    // 场同步信号（垂直同步，每帧开始时拉高）
    input                                cam1_href                     ,    // 行有效信号（水平参考，数据有效指示）
    input                                cam1_pclk                     ,    // 像素时钟（摄像头输出像素数据的同步时钟）
    input   [7:0]                        cam1_data                     ,    // 像素数据总线（8bit，在pclk上升沿采样）
    output                               cam1_reset_n                  ,    // 摄像头复位信号（低有效，用于硬件复位摄像头）
    
    //===========================================================================
    // 摄像头2接口信号（OV5640）
    //===========================================================================
    inout                                cam2_scl                      ,    // I2C时钟线
    inout                                cam2_sda                      ,    // I2C数据线
    input                                cam2_vsync                    ,    // 场同步信号
    input                                cam2_href                     ,    // 行有效信号
    input                                cam2_pclk                     ,    // 像素时钟
    input   [7:0]                        cam2_data                     ,    // 像素数据总线（8bit）
    output                               cam2_reset_n                  ,// 摄像头复位信号（低有效）

    //===========================================================================
    // 摄像头fmc接口信号（OV5640）
    //===========================================================================
    inout                                cam_fmc_scl                      ,    // I2C时钟线
    inout                                cam_fmc_sda                      ,    // I2C数据线
    input                                cam_fmc_vsync                    ,    // 场同步信号
    input                                cam_fmc_href                     ,    // 行有效信号
    input                                cam_fmc_pclk                     ,    // 像素时钟
    input   [7:0]                        cam_fmc_data                     ,    // 像素数据总线（8bit）
    output                               cam_fmc_reset_n                  ,// 摄像头复位信号（低有效）    
 //===========================================================================
    // PCIe物理接口信号（差分信号，2个Lane）
    //===========================================================================
    input					             pcie_refclk_p                ,    // PCIe参考时钟（差分正，100MHz）
	input					             pcie_refclk_n                ,    // PCIe参考时钟（差分负）
	input					             pcie_perst_n                 ,    // PCIe复位信号（低有效，来自PCIe插槽）
	input		[1:0]		             pcie_rxn                     ,    // PCIe接收数据（差分负，Lane[1:0]）
	input		[1:0]		             pcie_rxp                     ,    // PCIe接收数据（差分正，Lane[1:0]）
	output wire	[1:0]		             pcie_txn                      ,    // PCIe发送数据（差分负，Lane[1:0]）
	output wire	[1:0]		             pcie_txp                          // PCIe发送数据（差分正，Lane[1:0]）
   
);

//tx_disable接收，拉高
assign tx_disable = 1'b1;

assign hdmi_rgb565      = {hdmi_r[7:3], hdmi_g[7:2], hdmi_b[7:3]};
assign hdmi_video_rst_n = lock && ddr_init_done && hdmi_rx_init_done;
assign hdmi_rx_sda      = hdmi_sda_oe ? hdmi_sda_out : 1'bz;
assign hdmi_sda_in      = hdmi_rx_sda;

ms7200_ctl u_hdmi_rx_ms7200_ctl (
    .clk        (clk_10m),
    .rstn       (lock),
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
    .rstn       (lock),
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
// 内部参数定义
//===============================================================================
parameter CTRL_ADDR_WIDTH = MEM_ROW_WIDTH + MEM_BANK_WIDTH + MEM_COLUMN_WIDTH;  // 控制器地址总宽度（28bit）
parameter TH_1S = 27'd33000000;                                                  // 1秒计数值（33MHz时钟下）
parameter REM_DQS_WIDTH = 9 - MEM_DQS_WIDTH;                                    // 剩余DQS宽度（用于计算）


                                  //===============================================================================
                                  // LED指示
                                  //===============================================================================
reg heart_beat_led             ;  // 心跳LED
reg pclk_led                   ;  // PCIe时钟LED
reg ref_led                    ;  // 参考时钟LED

//===============================================================================
// DDR3控制相关信号
//===============================================================================
wire                        ddrphy_cpd_lock            ;    // DDR PHY校准锁定信号（相位校准完成）
wire                        ddr_init_done              ;    // DDR初始化完成标志（高有效，表示DDR可用）
wire                        pll_lock                   ;    // DDR PLL锁定信号（时钟稳定）
wire                        core_clk                   ;    // DDR核心工作时钟（来自DDR控制器）

//===============================================================================
// AXI4写通道信号（用于向DDR写入数据）
//===============================================================================
wire [CTRL_ADDR_WIDTH-1:0]  axi_awaddr                 ;    // 写地址（28bit，包含行、列、Bank地址）
wire                        axi_awuser_ap              ;    // 写地址用户信号：地址保护
wire [3:0]                  axi_awuser_id              ;    // 写地址用户ID（4bit，用于标识不同的写事务）
wire [3:0]                  axi_awlen                  ;    // 写突发长度（4bit，最大16个数据）
wire                        axi_awready                ;    // 写地址就绪（DDR控制器准备好接收地址）
wire                        axi_awvalid                ;    // 写地址有效（地址总线上的地址有效）
wire [MEM_DQ_WIDTH*8-1:0]   axi_wdata                  ;    // 写数据（128bit宽，16*8=128）
wire [MEM_DQ_WIDTH*8/8-1:0] axi_wstrb                  ;    // 写数据选通（16bit，每位对应一个字节）
wire                        axi_wready                 ;    // 写数据就绪（DDR控制器准备好接收数据）
wire [3:0]                  axi_wusero_id              ;    // 写数据用户ID（用于匹配地址和数据）
wire                        axi_wusero_last            ;    // 写数据最后一个（突发传输的最后一个数据）

//===============================================================================
// AXI4读通道信号（用于从DDR读取数据）
//===============================================================================
wire [CTRL_ADDR_WIDTH-1:0]  axi_araddr                 ;    // 读地址（28bit）
wire                        axi_aruser_ap              ;    // 读地址用户信号：地址保护
wire [3:0]                  axi_aruser_id              ;    // 读地址用户ID（4bit）
wire [3:0]                  axi_arlen                  ;    // 读突发长度（4bit）
wire                        axi_arready                ;    // 读地址就绪
wire                        axi_arvalid                ;    // 读地址有效
wire [MEM_DQ_WIDTH*8-1:0]   axi_rdata  /* synthesis syn_keep = 1 */;    // 读数据（128bit，综合工具保持此信号）
wire                        axi_rvalid /* synthesis syn_keep = 1 */;    // 读数据有效（数据总线上的数据有效）
wire [3:0]                  axi_rid                    ;    // 读数据ID（用于匹配读请求和读数据）
wire                        axi_rlast                  ;    // 读数据最后一个（突发传输的最后一个数据）

                                                          //===============================================================================
                                                          // 系统控制信号
                                                          //===============================================================================
wire resetn                     ;                         // 系统复位信号（高有效，未使用）
reg  [26:0]                 cnt                        ;  // 计数器（27bit，用于心跳LED计时）
wire [7:0]                  err_cnt                    ;  // 错误计数器（8bit，未使用）
wire free_clk_g                 ;                         // 自由时钟门控（未使用）

//cmos
// 系统复位延时计数器
reg  [15:0]                 rstn_1ms                   ;
// 摄像头通用信号
wire                        cam_fmc_scl                   ;//cmos i2c clock
wire                        cam_fmc_sda                   ;//cmos i2c data
wire                        cam_fmc_vsync                 ;//cmos vsync
wire                        cam_fmc_href                  ;//cmos hsync refrence,data valid
wire                        cam_fmc_pclk                  ;//cmos pxiel clock
wire   [7:0]                cam_fmc_data                  ;//cmos data
wire                        cam_fmc_reset                 ;//cmos reset
// 摄像头初始化使能信号
wire                        cam_init_enable                 ;
// 摄像头1相关信号：8bit转16bit后的数据
wire[15:0]                  cam1_data_16bit             ;
wire                        cam1_href_16bit           ;
reg [7:0]                   cam1_data_d0                ;
reg                         cam1_href_d0             ;
reg                         cam1_vsync_d0             ;
wire                        cam1_pclk_16bit           ;
// 摄像头2相关信号：8bit转16bit后的数据
wire[15:0]                  cam2_data_16bit              ;
wire                        cam2_href_16bit          ;
reg [7:0]                   cam2_data_d0                ;
reg                         cam2_href_d0              ;
reg                         cam2_vsync_d0             ;
wire                        cam2_pclk_16bit          ;
//转16bit数据fmc
wire[15:0]                  cam_fmc_data_16bit   ;
wire                        cam_fmc_href_16bit   ;
reg [7:0]                   cam_fmc_data_d0      ;
reg                         cam_fmc_href_d0      ;
reg                         cam_fmc_vsync_d0     ;
wire                        cam_fmc_pclk_16bit   ;
wire[15:0]                  o_rgb565                   ;
wire                        pclk_in_test               ;    
wire                        vs_in_test                 ;
wire                        de_in_test                 ;
wire[15:0]                  i_rgb565                   ;
wire                        pclk_in_test_2             ;    
wire                        vs_in_test_2               ;
wire                        de_in_test_2               ;
wire[15:0]                  i_rgb565_2                 ;
//fmc数据
wire[15:0]                  fmc_rgb565;
wire                        fmc_pclk;
wire                        fmc_vs;
wire                        fmc_de;
wire [15:0]                 hdmi_rgb565;
wire                        hdmi_video_rst_n;
wire                        hdmi_iic_trig;
wire                        hdmi_iic_wr;
wire [15:0]                 hdmi_iic_addr;
wire [7:0]                  hdmi_iic_wdata;
wire [7:0]                  hdmi_iic_rdata;
wire [7:0]                  hdmi_iic_device_id;
wire                        hdmi_iic_busy;
wire                        hdmi_iic_byte_over;
wire                        hdmi_sda_in;
wire                        hdmi_sda_out;
wire                        hdmi_sda_oe;

//===============================================================================
// PLL输出时钟信号
//===============================================================================
wire                        lock                       ;    // PLL锁定信号（高有效表示所有时钟输出稳定）
wire                        clk_10m                    ;    // 10MHz时钟（用于慢速外设）
wire                        clk_25m                    ;    // 25MHz时钟（用于摄像头配置模块）
wire                        clk_50m                    ;    // 50MHz时钟（系统主时钟，用于摄像头初始化和控制）

//===============================================================================
// PCIe配置参数定义
//===============================================================================
localparam DEVICE_TYPE = 3'b000;			    // PCIe设备类型：3'b000=端点设备, 3'b001=根端口, 3'b100=其他
localparam AXIS_SLAVE_NUM = 3;				    // AXI-Stream从设备数量：支持3个独立的流通道

//reg             ref_led;

//===============================================================================
// PCIe测试单元模式信号
//===============================================================================
wire			pcie_cfg_ctrl_en;			    // PCIe配置控制使能
wire			axis_master_tready_cfg;		    // 配置模式下的AXI-Stream主设备就绪
wire			cfg_axis_slave0_tvalid;		    // 配置模式下的AXI-Stream从设备有效
wire	[127:0]	cfg_axis_slave0_tdata;		    // 配置模式下的AXI-Stream数据
wire			cfg_axis_slave0_tlast;		    // 配置模式下的AXI-Stream最后数据标志
wire			cfg_axis_slave0_tuser;		    // 配置模式下的AXI-Stream用户信号

//===============================================================================
// AXI-Stream多路复用相关信号
//===============================================================================
wire			axis_master_tready_mem;		    // 内存模式的AXI-Stream主设备就绪信号
wire			axis_master_tvalid_mem;		    // 内存模式的AXI-Stream主设备有效信号
wire	[127:0]	axis_master_tdata_mem;		    // 内存模式的AXI-Stream数据（128bit）
wire	[3:0]	axis_master_tkeep_mem;		    // 内存模式的AXI-Stream数据有效字节（4bit）
wire			axis_master_tlast_mem;		    // 内存模式的AXI-Stream最后数据标志
wire	[7:0]	axis_master_tuser_mem;		    // 内存模式的AXI-Stream用户信号（8bit）

//===============================================================================
// DMA相关信号
//===============================================================================
wire			cross_4kb_boundary;			    // 跨4KB边界标志（PCIe DMA传输限制检测）
wire			dma_axis_slave0_tvalid;		    // DMA的AXI-Stream从设备0有效信号
wire	[127:0]	dma_axis_slave0_tdata;		    // DMA的AXI-Stream从设备0数据（128bit）
wire			dma_axis_slave0_tlast;		    // DMA的AXI-Stream从设备0最后数据标志
wire			dma_axis_slave0_tuser;		    // DMA的AXI-Stream从设备0用户信号

//===============================================================================
// 复位消抖和同步信号（跨时钟域复位同步）
//===============================================================================
wire			sync_button_rst_n; 			    // 同步后的按钮复位信号（低有效）
wire			ref_core_rst_n;			        // 同步到参考时钟域的核心复位信号
wire            sync_perst_n;			        // 同步后的PCIe复位信号（低有效）
wire			s_pclk_rstn;			        // 同步到pclk时钟域的核心复位信号

//===============================================================================
// PCIe内部时钟和复位信号
//===============================================================================
wire			pclk_div2/*synthesis PAP_MARK_DEBUG="1"*/;  	// PCIe用户时钟分频（x2时125MHz，x1时62.5MHz）
wire			pclk/*synthesis PAP_MARK_DEBUG="1"*/;		    // PCIe用户时钟（x2时125MHz，x1时62.5MHz，可调试）
wire			ref_clk; 				        // PCIe参考时钟（来自PHY，100MHz）
wire			core_rst_n;				        // PCIe核心复位信号（高有效，同步到多个时钟域）

//===============================================================================
// AXI-Stream主设备接口信号（PCIe IP核输出，用于向PCIe发送数据）
//===============================================================================
wire			axis_master_tvalid;            // 主设备数据有效信号
wire			axis_master_tready;            // 主设备数据就绪信号
wire	[127:0]	axis_master_tdata;             // 主设备数据（128bit，PCIe数据包）
wire	[3:0]	axis_master_tkeep;             // 主设备数据有效字节（4bit，每位对应32bit）
wire			axis_master_tlast;             // 主设备最后数据标志（表示PCIe包的结束）
wire	[7:0]	axis_master_tuser;             // 主设备用户信号（8bit，包含PCIe TLP头信息）

//===============================================================================
// AXI4-Stream从设备接口信号（PCIe IP核输入，用于从PCIe接收数据）
//===============================================================================
// 从设备0接口（DMA数据通道）
wire			axis_slave0_tready;            // 从设备0就绪信号（表示可以接收数据）
wire			axis_slave0_tvalid;            // 从设备0有效信号（表示数据有效）
wire	[127:0]	axis_slave0_tdata;             // 从设备0数据（128bit）
wire			axis_slave0_tlast;             // 从设备0最后数据标志
wire			axis_slave0_tuser;             // 从设备0用户信号

// 从设备1接口
wire			axis_slave1_tready;            // 从设备1就绪信号
wire			axis_slave1_tvalid;            // 从设备1有效信号
wire	[127:0]	axis_slave1_tdata;             // 从设备1数据（128bit）
wire			axis_slave1_tlast;             // 从设备1最后数据标志
wire			axis_slave1_tuser;             // 从设备1用户信号

// 从设备2接口
wire			axis_slave2_tready;            // 从设备2就绪信号
wire			axis_slave2_tvalid;            // 从设备2有效信号
wire	[127:0]	axis_slave2_tdata;             // 从设备2数据（128bit）
wire			axis_slave2_tlast;             // 从设备2最后数据标志
wire			axis_slave2_tuser;             // 从设备2用户信号

//===============================================================================
// PCIe配置寄存器信号（来自PCIe配置空间）
//===============================================================================
wire	[7:0]	cfg_pbus_num;			        // PCIe总线号（8bit，标识PCIe总线）
wire	[4:0]	cfg_pbus_dev_num; 		        // PCIe设备号（5bit，标识设备）
wire	[2:0]	cfg_max_rd_req_size;	        // 最大读请求大小（3bit，128/256/512/1024/2048/4096字节）
wire	[2:0]	cfg_max_payload_size;	        // 最大负载大小（3bit，128/256/512/1024/2048/4096字节）
wire			cfg_rcb;				        // 读完成边界（Read Completion Boundary，128或64字节对齐）

//===============================================================================
// PCIe流控和信用管理信号
//===============================================================================
wire			cfg_ido_req_en;			        // IDO请求使能（当前禁用）
wire			cfg_ido_cpl_en;			        // IDO完成使能（当前禁用）
wire	[7:0]	xadm_ph_cdts;			        // 发布头信用计数器（未使用）
wire	[11:0]	xadm_pd_cdts;			        // 发布数据信用计数器（未使用）
wire	[7:0]	xadm_nph_cdts;			        // 非发布头信用计数器（未使用）
wire	[11:0]	xadm_npd_cdts;			        // 非发布数据信用计数器（未使用）
wire	[7:0]	xadm_cplh_cdts;			        // 完成头信用计数器（未使用）
wire	[11:0]	xadm_cpld_cdts;			        // 完成数据信用计数器（未使用）

//===============================================================================
// PCIe链路状态信号
//===============================================================================
wire	[4:0]	smlh_ltssm_state/*synthesis PAP_MARK_DEBUG="1"*/;   // 链路训练和状态状态机状态（5bit，可调试）

//===============================================================================
// LED控制相关信号和计数器
//===============================================================================
reg		[22:0]	ref_led_cnt;		        // 参考时钟LED计数器（23bit，用于控制LED闪烁频率）
reg		[26:0]	pclk_led_cnt;		        // PCIe时钟LED计数器（27bit）
wire			smlh_link_up; 		        // 软件链路状态：链路已建立（高有效）
wire			rdlh_link_up; 	    // 硬件链路状态：链路已建立（高有效，可调试）

//===============================================================================
// UART到APB接口信号（用于通过UART配置PCIe寄存器，32bit位宽）
//===============================================================================
wire			uart_p_sel;			        // UART APB选择信号（片选）
wire	[3:0]	uart_p_strb;		        // UART APB字节选通（4bit，每位对应一个字节）
wire	[15:0]	uart_p_addr;		        // UART APB地址（16bit地址空间）
wire	[31:0]	uart_p_wdata;		        // UART APB写数据（32bit）
wire			uart_p_ce;			        // UART APB时钟使能
wire			uart_p_we;			        // UART APB写使能
wire			uart_p_rdy;			        // UART APB就绪信号
wire	[31:0]	uart_p_rdata;		        // UART APB读数据（32bit）

//===============================================================================
// 内部APB总线信号（连接到APB多路复用器）
//===============================================================================
wire	[3:0]	p_strb; 			        // APB字节选通（4bit）
wire	[15:0]	p_addr; 			        // APB地址（16bit）
wire	[31:0]	p_wdata; 			        // APB写数据（32bit）
wire			p_ce; 				        // APB时钟使能
wire			p_we; 				        // APB写使能

//===============================================================================
// APB多路复用器选择和响应信号
//===============================================================================
// APB地址空间分配：
//   0~5: HSSTLP（高速串行链路测试）
//   6: 保留
//   7: PCIe寄存器空间
//   8: 配置寄存器空间
//   9: DMA控制器寄存器空间（基地址0x8000）
wire			p_sel_pcie;			        // PCIe寄存器空间选择
wire			p_sel_cfg;			        // 配置寄存器空间选择
wire			p_sel_dma;			        // DMA寄存器空间选择

wire	[31:0]	p_rdata_pcie;		        // PCIe寄存器空间读数据
wire	[31:0]	p_rdata_cfg;		        // 配置寄存器空间读数据
wire	[31:0]	p_rdata_dma;		        // DMA寄存器空间读数据

wire			p_rdy_pcie;			        // PCIe寄存器空间就绪
wire			p_rdy_cfg;			        // 配置寄存器空间就绪
wire			p_rdy_dma;			        // DMA寄存器空间就绪			

//===============================================================================
// PCIe流控和信用管理信号固定赋值
//===============================================================================
assign cfg_ido_req_en	=	1'b0;	    // IDO请求功能禁用
assign cfg_ido_cpl_en	=	1'b0;	    // IDO完成功能禁用
assign xadm_ph_cdts		=	8'b0;	    // 发布头信用计数器清零
assign xadm_pd_cdts		=	12'b0;	    // 发布数据信用计数器清零
assign xadm_nph_cdts	=	8'b0;	    // 非发布头信用计数器清零
assign xadm_npd_cdts	=	12'b0;	    // 非发布数据信用计数器清零
assign xadm_cplh_cdts	=	8'b0;	    // 完成头信用计数器清零
assign xadm_cpld_cdts	=	12'b0;	    // 完成数据信用计数器清零	





//===============================================================================
// AXI总线接口信号定义：用于DDR3数据读写
//===============================================================================
// 通道0（摄像头1通道1）：图像数据写入和读取
wire          ch0_write_data_valid      ;       // 写入数据有效信号
wire [15:0]   ch0_write_data            ;      // 写入数据（16bit）
reg           ch0_read_frame_req;               // 读帧请求信号
wire          ch0_read_req_ack;                 // 读请求应答信号
wire          ch0_read_data_en;                 // 读数据使能信号
wire  [127:0] ch0_read_data;                    // 读数据（128bit，AXI总线宽度）
wire          ch0_read_data_valid;              // 读数据有效信号

// 通道1（摄像头1通道2）：图像数据写入和读取
wire          ch1_write_data_valid      ;       
wire [15:0]   ch1_write_data            ;       
reg           ch1_read_frame_req;               
wire          ch1_read_req_ack;                 
wire          ch1_read_data_en;                 
wire  [127:0] ch1_read_data;                    
wire          ch1_read_data_valid;              

// 通道2（摄像头2通道1）：图像数据写入和读取
wire          ch2_write_data_valid      ;       
wire [15:0]   ch2_write_data            ;       
reg           ch2_read_frame_req;               
wire          ch2_read_req_ack;                 
wire          ch2_read_data_en;                 
wire  [127:0] ch2_read_data;                    
wire          ch2_read_data_valid;              

// 通道3（摄像头2通道2）：图像数据写入和读取
wire          ch3_write_data_valid      ;       
wire [15:0]   ch3_write_data            ;       
reg           ch3_read_frame_req;               
wire          ch3_read_req_ack;                 
wire          ch3_read_data_en;                 
wire  [127:0] ch3_read_data;                    
wire          ch3_read_data_valid;              

//===============================================================================
// PCIe DMA接口信号定义
//===============================================================================
// DMA控制器基地址：0x8000
wire            dma_write_req;                   // DMA写数据请求信号
wire [11:0]     dma_write_addr;                 // DMA写地址（12bit，最大4KB）
wire [127:0]    dma_write_data;                  // DMA写数据（128bit，AXI-Stream宽度）

// 摄像头2像素时钟缓冲（未使用，保留）
wire            cam2_pclk_bufg;

// 摄像头1数据同步寄存器（两级同步，用于跨时钟域）
reg             cam1_vsync_d1;
reg             cam1_vsync_d2;
reg             cam1_href_d1;
reg             cam1_href_d2;
reg   [7:0]     cam1_data_d1;
reg   [7:0]     cam1_data_d2;

// 摄像头2数据同步寄存器（两级同步，用于跨时钟域）
reg             cam2_vsync_d1;
reg             cam2_vsync_d2;
reg             cam2_href_d1;
reg             cam2_href_d2;
reg   [7:0]     cam2_data_d1;
reg   [7:0]     cam2_data_d2;

//fmc同步
reg             cam_fmc_vsync_d1;
reg             cam_fmc_vsync_d2;
reg             cam_fmc_href_d1;
reg             cam_fmc_href_d2;
reg   [7:0]     cam_fmc_data_d1;
reg   [7:0]     cam_fmc_data_d2;


// 行缓冲区满标志：用于指示各通道的行缓冲区是否已满
wire            ch0_line_full_flag;            // 通道0行缓冲满标志
wire            ch1_line_full_flag;            // 通道1行缓冲满标志
wire            ch2_line_full_flag;            // 通道2行缓冲满标志
wire            ch3_line_full_flag;            // 通道3行缓冲满标志
wire [11:0]     debug_read_line_index;
wire [11:0]     debug_read_beat_index;
wire [31:0]     debug_dma_req_line_count;
wire [31:0]     debug_dma_req_beat_count;
wire [31:0]     debug_dma_underflow_count;
wire [31:0]     debug_dma_zero_output_count;
wire            debug_read_frame_active;
reg  [31:0]     hdmi_pix_clk_alive             /*synthesis PAP_MARK_DEBUG="1"*/;
reg  [31:0]     hdmi_vs_counter                /*synthesis PAP_MARK_DEBUG="1"*/;
reg  [31:0]     hdmi_hs_counter                /*synthesis PAP_MARK_DEBUG="1"*/;
reg  [31:0]     hdmi_de_pixel_counter          /*synthesis PAP_MARK_DEBUG="1"*/;
reg  [31:0]     hdmi_frame_count               /*synthesis PAP_MARK_DEBUG="1"*/;
reg             hdmi_vs_d0;
reg             hdmi_vs_d1;
reg             hdmi_hs_d0;
reg             hdmi_hs_d1;

// 摄像头1数据同步：两级寄存器同步，消除亚稳态
always @(posedge cam1_pclk)begin
    cam1_vsync_d1 <= cam1_vsync;
    cam1_vsync_d2 <= cam1_vsync_d1;
    cam1_href_d1 <= cam1_href;
    cam1_href_d2  <= cam1_href_d1;
    cam1_data_d1 <= cam1_data;
    cam1_data_d2 <= cam1_data_d1;
end

// 摄像头2数据同步：两级寄存器同步，消除亚稳态
always @(posedge cam2_pclk)begin
    cam2_vsync_d1 <= cam2_vsync;
    cam2_vsync_d2 <= cam2_vsync_d1;
    cam2_href_d1 <= cam2_href;
    cam2_href_d2  <= cam2_href_d1;
    cam2_data_d1 <= cam2_data;
    cam2_data_d2 <= cam2_data_d1;
end

// 摄像头fmc数据同步：两级寄存器同步，消除亚稳态
always @(posedge cam_fmc_pclk)begin
    cam_fmc_vsync_d1 <= cam_fmc_vsync;
    cam_fmc_vsync_d2 <= cam_fmc_vsync_d1;
    cam_fmc_href_d1 <= cam_fmc_href;
    cam_fmc_href_d2  <= cam_fmc_href_d1;
    cam_fmc_data_d1 <= cam_fmc_data;
    cam_fmc_data_d2 <= cam_fmc_data_d1;
end

//*==============================================================================
// PLL时钟管理模块：将系统时钟分频/倍频为多个时钟域
//*==============================================================================
pll dl_pll_inst (
  .clkout0(clk_10m),    // 输出：10MHz时钟（用于慢速外设）
  .clkout1(clk_25m),    // 输出：25MHz时钟（用于摄像头配置）
  .clkout2(clk_50m),    // 输出：50MHz时钟（用于系统主时钟）
  .lock(lock),          // 输出：PLL锁定信号（高有效表示时钟稳定）
  .clkin1(sys_clk)       // 输入：系统参考时钟（40MHz）
);

// GTP_CLKBUFR U_CLKBUFR ( 
// .CLKOUT     (cmos2_pclk_bufg), 
// .CLKIN      (cmos2_pclk)
// ); 

//*==============================================================================
// 摄像头初始化和配置模块
//*==============================================================================
// OV5640寄存器配置使能：上电延时后使能摄像头初始化
sys_pwseq_delay_circuit	dl_power_on_delay_inst(
    .clk_50M                 (clk_50m        ),              // 输入：50MHz时钟
    .reset_n                 (ddr_init_done  ),              // 输入：复位信号（DDR初始化完成后有效）
    .camera1_rstn            (cam1_reset_n    ),              // 输出：摄像头1复位信号（低有效）
    .camera2_rstn            (cam2_reset_n    ),              // 输出：摄像头2复位信号（低有效）
    .camerafmc_rstn          (cam_fmc_reset_n),
    .camera_pwnd             (               ),               // 输出：摄像头电源控制（未使用）
    .initial_en              (cam_init_enable     )           // 输出：初始化使能信号
);
// 摄像头1寄存器配置模块：通过I2C配置OV5640寄存器
sensor_reg_cfg_mgr	dl_coms1_reg_config(
    .clk_25M                 (clk_50m            ),          // 输入：时钟（实际使用50MHz）
    .camera_rstn             (cam1_reset_n        ),          // 输入：摄像头复位信号
    .initial_en              (cam_init_enable         ),      // 输入：初始化使能		
    .i2c_sclk                (cam1_scl          ),//output
    .i2c_sdat                (cam1_sda          ),//inout
    .reg_conf_done           (cam_init_done[0]  ),//output config_finished
    .reg_index               (                   ),//output reg [8:0]
    .clock_20k               (                   ) //output reg
);

// 摄像头2寄存器配置模块
sensor_reg_cfg_mgr	dl_coms2_reg_config(
    .clk_25M                 (clk_50m            ),//input
    .camera_rstn             (cam2_reset_n        ),//input
    .initial_en              (cam_init_enable         ),//input		
    .i2c_sclk                (cam2_scl          ),//output
    .i2c_sdat                (cam2_sda          ),//inout
    .reg_conf_done           (cam_init_done[1]  ),//output config_finished
    .reg_index               (                   ),//output reg [8:0]
    .clock_20k               (                   ) //output reg
);

wire cam_init_fmc; //fmc摄像头模块

// 摄像头fmc寄存器配置模块
sensor_reg_cfg_mgr	dl_comsfmc_reg_config(
    .clk_25M                 (clk_50m            ),//input
    .camera_rstn             (cam_fmc_reset_n        ),//input
    .initial_en              (cam_init_enable         ),//input		
    .i2c_sclk                (cam_fmc_scl          ),//output
    .i2c_sdat                (cam_fmc_sda          ),//inout
    .reg_conf_done           (cam_init_fmc       ),//output config_finished
    .reg_index               (                   ),//output reg [8:0]
    .clock_20k               (                   ) //output reg
);


//===============================================================================
// 摄像头数据格式转换：8bit转16bit
//===============================================================================
// 摄像头1：将同步后的8bit数据送入格式转换模块
always@(posedge cam1_pclk)
    begin
        cam1_data_d0        <= cam1_data_d2    ;  // 延迟一拍，对齐时序
        cam1_href_d0     <= cam1_href_d2    ;     // 行有效信号延迟
        cam1_vsync_d0    <= cam1_vsync_d2   ;      // 场同步信号延迟
    end

// 摄像头1：8bit转16bit格式转换模块
cmos_pixel_width_adapter dl_cmos1_8_16bit(
.pclk           (cam1_pclk       ),          // 输入：像素时钟
.rst_n          (cam_init_done[0]),          // 输入：复位信号（摄像头初始化完成后有效）
.pdata_i        (cam1_data_d0       ),       // 输入：8bit像素数据
.de_i           (cam1_href_d0    ),          // 输入：数据有效信号
.vs_i           (cam1_vsync_d0    ),         // 输入：场同步信号

.pixel_clk      (cam1_pclk_16bit ),          // 输出：16bit模式下的像素时钟
.pdata_o        (cam1_data_16bit    ),       // 输出：16bit像素数据
.de_o           (cam1_href_16bit )           // 输出：16bit模式下的数据有效信号
);

// 摄像头2：将同步后的8bit数据送入格式转换模块
always@(posedge cam2_pclk)
    begin
        cam2_data_d0        <= cam2_data_d2    ;  // 延迟一拍，对齐时序
        cam2_href_d0     <= cam2_href_d2    ;     // 行有效信号延迟
        cam2_vsync_d0    <= cam2_vsync_d2   ;      // 场同步信号延迟
    end

// 摄像头2：8bit转16bit格式转换模块
cmos_pixel_width_adapter dl_cmos2_8_16bit(
.pclk           (cam2_pclk       ),          // 输入：像素时钟
.rst_n          (cam_init_done[1]),          // 输入：复位信号（摄像头初始化完成后有效）
.pdata_i        (cam2_data_d0       ),       // 输入：8bit像素数据
.de_i           (cam2_href_d0    ),          // 输入：数据有效信号
.vs_i           (cam2_vsync_d0    ),         // 输入：场同步信号

.pixel_clk      (cam2_pclk_16bit ),          // 输出：16bit模式下的像素时钟
.pdata_o        (cam2_data_16bit    ),       // 输出：16bit像素数据
.de_o           (cam2_href_16bit )           // 输出：16bit模式下的数据有效信号
);

// 摄像头fmc：将同步后的8bit数据送入格式转换模块
always@(posedge cam_fmc_pclk)
    begin
        cam_fmc_data_d0        <= cam_fmc_data_d2    ;  // 延迟一拍，对齐时序
        cam_fmc_href_d0     <= cam_fmc_href_d2    ;     // 行有效信号延迟
        cam_fmc_vsync_d0    <= cam_fmc_vsync_d2   ;      // 场同步信号延迟
    end

// 摄像头2：8bit转16bit格式转换模块
cmos_pixel_width_adapter dl_cmosfmc_8_16bit(
.pclk           (cam_fmc_pclk       ),          // 输入：像素时钟
.rst_n          (cam_init_fmc),          // 输入：复位信号（摄像头初始化完成后有效）
.pdata_i        (cam_fmc_data_d0       ),       // 输入：8bit像素数据
.de_i           (cam_fmc_href_d0    ),          // 输入：数据有效信号
.vs_i           (cam_fmc_vsync_d0    ),         // 输入：场同步信号

.pixel_clk      (cam_fmc_pclk_16bit ),          // 输出：16bit模式下的像素时钟
.pdata_o        (cam_fmc_data_16bit    ),       // 输出：16bit像素数据
.de_o           (cam_fmc_href_16bit )           // 输出：16bit模式下的数据有效信号
);


//===============================================================================
// 视频数据选择和RGB格式转换
//===============================================================================
// 通道1视频数据选择：使用摄像头1的数据
assign     pclk_in_test    =    hdmi_pix_clk       ;
assign     vs_in_test      =    hdmi_vs            ;
assign     de_in_test      =    hdmi_de            ;
assign     i_rgb565        =    hdmi_rgb565        ;

// 通道2视频数据选择：使用摄像头2的数据
assign     pclk_in_test_2  =    hdmi_pix_clk       ;
assign     vs_in_test_2    =    hdmi_vs            ;
assign     de_in_test_2    =    hdmi_de            ;
assign     i_rgb565_2      =    hdmi_rgb565        ;

assign     fmc_pclk   = hdmi_pix_clk;
assign     fmc_vs     = hdmi_vs;
assign     fmc_de     = hdmi_de;
assign     fmc_rgb565 = hdmi_rgb565;


wire [15: 0] channel_0_data;
wire         channel_0_vs;
wire         channel_0_de;
wire         channel_0_hs;
image_filter u_image_fliter_0
(
    .clk(sys_clk),
    .reset_n(1'b1),

    .in_hsync(pclk_in_test),
    .in_vsync(vs_in_test),
    .in_de(de_in_test),              
    .in_data(i_rgb565),

    .out_hsync(channel_0_hs),
    .out_vsync(channel_0_vs),
    .out_de(channel_0_de),
    .out_data(channel_0_data)
);

wire [15: 0] channel_1_data;
wire         channel_1_vs;
wire         channel_1_de;
wire         channel_1_hs;
image_filter u_image_fliter_1
(
    .clk(sys_clk),
    .reset_n(1'b1),

    .in_hsync(pclk_in_test),
    .in_vsync(vs_in_test),
    .in_de(de_in_test),              
    .in_data(i_rgb565),

    .out_hsync(channel_1_hs),
    .out_vsync(channel_1_vs),
    .out_de(channel_1_de),
    .out_data(channel_1_data)
);

wire [15: 0] channel_2_data;
wire         channel_2_vs;
wire         channel_2_de;
wire         channel_2_hs;
image_filter u_image_fliter_2
(
    .clk(sys_clk),
    .reset_n(1'b1),

    .in_hsync(pclk_in_test),
    .in_vsync(vs_in_test),
    .in_de(de_in_test),              
    .in_data(i_rgb565),

    .out_hsync(channel_2_hs),
    .out_vsync(channel_2_vs),
    .out_de(channel_2_de),
    .out_data(channel_2_data)
);

wire [15: 0] channel_3_data;
wire         channel_3_vs;
wire         channel_3_de;
wire         channel_3_hs;
image_filter u_image_fliter_3
(
    .clk(sys_clk),
    .reset_n(1'b1),

    .in_hsync(pclk_in_test),
    .in_vsync(vs_in_test),
    .in_de(de_in_test),              
    .in_data(i_rgb565),

    .out_hsync(channel_3_hs),
    .out_vsync(channel_3_vs),
    .out_de(channel_3_de),
    .out_data(channel_3_data)
);


always@(posedge core_clk or negedge ddr_init_done)
begin
   if (!ddr_init_done)
      cnt <= 27'd0;              // DDR未初始化完成，计数器清零
   else if ( cnt >= TH_1S )      // 计数到1秒（33,000,000个时钟周期）
      cnt <= 27'd0;               // 计数器清零
   else
      cnt <= cnt + 27'd1;        // 计数器递增
end

// 心跳LED控制：每秒翻转一次LED状态
always @(posedge core_clk or negedge ddr_init_done)
begin
   if (!ddr_init_done)
      heart_beat_led <= 1'd1;     // DDR未初始化完成，LED保持高电平
   else if ( cnt >= TH_1S )       // 每1秒翻转一次
      heart_beat_led <= ~heart_beat_led;
end

//添加光纤HSST的例化模块及信号声明
wire tx_clk;
wire rx_clk;
wire i_p_pcs_word_align_en_2 = 1'b1;
wire [ 3:0] i_tdispsel_2 = 4'b0;
wire [ 3:0] i_tdispctrl_2 = 4'b0;
wire [ 2:0] o_rxstatus_2;
wire [ 3:0] o_rdisper_2;
wire [31:0] tx_data;
wire [ 3:0] tx_kchar; 
wire [31:0] rx_data;
wire [ 3:0] rx_kchar; 

hsst_tran_video U_INST (
    .i_free_clk                    (sys_clk                    ), // input          
    .i_wtchdg_clr_0                (i_wtchdg_clr_0                ), // input          
    .o_wtchdg_st_0                 (o_wtchdg_st_0                 ), // output [1:0]   
    .o_pll_done_0                  (o_pll_done_0                  ), // output         
    .o_txlane_done_2               (o_txlane_done_2               ), // output         
    .o_rxlane_done_2               (o_rxlane_done_2               ), // output         
    .i_p_refckn_0                  (pcie_refclk_n                  ), // input          
    .i_p_refckp_0                  (pcie_refclk_p                  ), // input          
    .o_p_clk2core_tx_2             (tx_clk                        ), // output         
    .i_p_tx2_clk_fr_core           (tx_clk                        ), // input   o_p_clk2core_tx_0       
    .o_p_clk2core_rx_2             (rx_clk                        ), // output         
    .i_p_rx2_clk_fr_core           (rx_clk                        ), // input          
    .o_p_pll_lock_0                (o_p_pll_lock_0                ), // output         
    .o_p_rx_sigdet_sta_2           (o_p_rx_sigdet_sta_2           ), // output         
    .o_p_lx_cdr_align_2            (o_p_lx_cdr_align_2            ), // output         
    .i_p_pcs_word_align_en_2       (i_p_pcs_word_align_en_2       ), // input          
    .i_p_l2rxn                     (i_p_l2rxn                     ), // input          
    .i_p_l2rxp                     (i_p_l2rxp                     ), // input          
    .o_p_l2txn                     (o_p_l2txn                     ), // output         
    .o_p_l2txp                     (o_p_l2txp                     ), // output         
    .i_txd_2                       (tx_data                       ), // input  [31:0]  
    .i_tdispsel_2                  (i_tdispsel_2                  ), // input  [3:0]   
    .i_tdispctrl_2                 (i_tdispctrl_2                 ), // input  [3:0]   
    .i_txk_2                       (tx_kchar                      ), // input  [3:0]   
    .o_rxstatus_2                  (o_rxstatus_2[2:0]             ), // output [2:0]   
    .o_rxd_2                       (rx_data                       ), // output [31:0]  
    .o_rdisper_2                   (o_rdisper_2[3:0]              ), // output [3:0]   
    .o_rdecer_2                    (o_rdecer_2[3:0]               ), // output [3:0]   
    .o_rxk_2                       (rx_kchar                      ), // output [3:0]   
    .i_pll_rst_0                   (~rstn_out                   )  // input  
);

//接纳第四个输入源,从光纤中解包数据
reg  [15:0] rstn_1ms;
always @(posedge clk_10m)
begin
	if(!lock)
	    rstn_1ms <= 16'd0;
	else
	begin
		if(rstn_1ms == 16'h2710)
		    rstn_1ms <= rstn_1ms;
		else
		    rstn_1ms <= rstn_1ms + 1'b1;
	end
end

assign rstn_out = (rstn_1ms == 16'h2710);
//32位数据对齐模块
wire[31:0] rx_data_align /* synthesis PAP_MARK_DEBUG="true" */;
wire[ 3:0] rx_ctrl_align /* synthesis PAP_MARK_DEBUG="true" */;
word_align u_word_align
(
    .rst                        (~rstn_out               ),
    .rx_clk                     (rx_clk                  ),
    .gt_rx_data                 (rx_data                 ),
    .gt_rx_ctrl                 (rx_kchar                ),
    .rx_data_align              (rx_data_align           ),
    .rx_ctrl_align              (rx_ctrl_align           )
);

//GTP视频数据解析模块
wire vs_wr;
wire de_wr;
wire[15:0] vout_data_r;

video_packet_rec u_video_packet_rec
(
	.rst                        (~rstn_out               ),
	.rx_clk                     (rx_clk                  ),
	.gt_rx_data                 (rx_data_align           ),
	.gt_rx_ctrl                 (rx_ctrl_align           ),
	.vout_width                 (16'd1280                ),
	
	.vs                         (vs_wr                   ),
	.de                         (de_wr                   ),
	.vout_data                  (vout_data_r             )
);

//===============================================================================
// DDR3内存控制器IP核例化：提供高速数据缓存功能
//===============================================================================
// 参数说明：
//   MEM_ROW_WIDTH      : 行地址宽度（15bit，支持32K行）
//   MEM_COLUMN_WIDTH   : 列地址宽度（10bit，支持1K列）
//   MEM_BANK_WIDTH     : Bank地址宽度（3bit，支持8个Bank）
//   MEM_DQ_WIDTH       : 数据位宽（16bit）
//   MEM_DM_WIDTH       : 数据掩码宽度（等于DQS数量）
//   MEM_DQS_WIDTH      : DQS信号数量（2个，对应2个字节）
//   CTRL_ADDR_WIDTH    : 控制器地址总宽度（28bit，包含行、列、Bank）
ddr3 #(
    .MEM_ROW_WIDTH              (MEM_ROW_WIDTH                ),
    .MEM_COLUMN_WIDTH           (MEM_COLUMN_WIDTH             ),
    .MEM_BANK_WIDTH             (MEM_BANK_WIDTH               ),
    .MEM_DQ_WIDTH               (MEM_DQ_WIDTH                 ),
    .MEM_DM_WIDTH               (MEM_DQS_WIDTH                ),
    .MEM_DQS_WIDTH              (MEM_DQS_WIDTH                ),
    .CTRL_ADDR_WIDTH            (CTRL_ADDR_WIDTH              )
  )dl_I_ips_ddr_top(
    // 时钟和复位接口
    .ref_clk                    (sys_clk                     ),    // 输入：参考时钟（40MHz系统时钟）
    .resetn                     (sys_rst_n                  ),    // 输入：复位信号（低有效）
    .core_clk                   (core_clk                     ),
    .pll_lock                   (pll_lock                     ),
    .phy_pll_lock               (phy_pll_lock                 ),
    .gpll_lock                  (gpll_lock                    ),
    .rst_gpll_lock              (rst_gpll_lock                ),
    .ddrphy_cpd_lock            (ddrphy_cpd_lock              ),
    .ddr_init_done              (ddr_init_done                ),

    .axi_awaddr                 (axi_awaddr                   ),
    .axi_awuser_ap              (axi_awuser_ap                ),
    .axi_awuser_id              (axi_awuser_id                ),
    .axi_awlen                  (axi_awlen                    ),
    .axi_awready                (axi_awready                  ),
    .axi_awvalid                (axi_awvalid                  ),

    .axi_wdata                  (axi_wdata                    ),
    .axi_wstrb                  (axi_wstrb                    ),
    .axi_wready                 (axi_wready                   ),
    .axi_wusero_id              (axi_wusero_id                ),
    .axi_wusero_last            (axi_wusero_last              ),

    .axi_araddr                 (axi_araddr                   ),
    .axi_aruser_ap              (axi_aruser_ap                ),
    .axi_aruser_id              (axi_aruser_id                ),
    .axi_arlen                  (axi_arlen                    ),
    .axi_arready                (axi_arready                  ),
    .axi_arvalid                (axi_arvalid                  ),

    .axi_rdata                  (axi_rdata                    ),
    .axi_rid                    (axi_rid                      ),
    .axi_rlast                  (axi_rlast                    ),
    .axi_rvalid                 (axi_rvalid                   ),

    // APB配置接口
    .apb_clk                    (1'b0                         ),    // APB时钟（禁用）
    .apb_rst_n                  (1'b0                         ),    // APB复位（禁用）
    .apb_sel                    (1'b0                         ),    // APB选择（禁用）
    .apb_enable                 (1'b0                         ),    // APB使能（禁用）
    .apb_addr                   (8'd0                         ),    // APB地址（固定为0）
    .apb_write                  (1'b0                         ),    // APB写使能（禁用）
    .apb_ready                  (                             ),    // APB就绪（未连接）
    .apb_wdata                  (16'd0                        ),    // APB写数据（固定为0）
    .apb_rdata                  (                             ),    // APB读数据（未连接）


    .mem_cs_n                   (ddr3_cs_n                     ),

    .mem_rst_n                  (ddr3_rst_n                    ),
    .mem_ck                     (ddr3_ck                       ),
    .mem_ck_n                   (ddr3_ck_n                     ),
    .mem_cke                    (ddr3_cke                      ),
    .mem_ras_n                  (ddr3_ras_n                    ),
    .mem_cas_n                  (ddr3_cas_n                    ),
    .mem_we_n                   (ddr3_we_n                     ),
    .mem_odt                    (ddr3_odt                      ),
    .mem_a                      (ddr3_a                        ),
    .mem_ba                     (ddr3_ba                       ),
    .mem_dqs                    (ddr3_dqs                      ),
    .mem_dqs_n                  (ddr3_dqs_n                    ),
    .mem_dq                     (ddr3_dq                       ),
    .mem_dm                     (ddr3_dm                       ),

    //===========================================================================
    // DDR3调试和校准接口（当前未使用，使用默认值）
    //===========================================================================
    // 调试控制信号
    .dbg_gate_start             (1'b0                         ),    // 调试门控启动（禁用）
    .dbg_cpd_start              (1'b0                         ),    // 调试CPD启动（禁用）
    .dbg_ddrphy_rst_n           (1'b1                         ),    // 调试DDR PHY复位（保持使能）
    .dbg_gpll_scan_rst          (1'b0                         ),    // 调试GPLL扫描复位（禁用）

    // 采样位置校准（用于调整数据采样窗口）
    .samp_position_dyn_adj      (1'b0                         ),    // 动态采样位置调整（禁用）
    .init_samp_position_even    (16'd0                        ),    // 初始偶数采样位置（使用默认值）
    .init_samp_position_odd     (16'd0                        ),    // 初始奇数采样位置（使用默认值）

    // 写校准位置（用于调整写时序）
    .wrcal_position_dyn_adj     (1'b0                         ),    // 动态写校准位置调整（禁用）
    .init_wrcal_position        (16'd0                        ),    // 初始写校准位置（使用默认值）

    // 读时钟控制（用于调整读时钟相位）
    .force_read_clk_ctrl        (1'b0                         ),    // 强制读时钟控制（禁用）
    .init_slip_step             (8'd0                         ),    // 初始滑移步数（使用默认值）
    .init_read_clk_ctrl         (6'd0                         ),    // 初始读时钟控制（使用默认值）

    // 调试输出信号（未连接，可用于调试时监控）
    .debug_calib_ctrl           (                             ),    // 调试校准控制状态（未连接）
    .dbg_dll_upd_state          (                             ),    // 调试DLL更新状态（未连接）
    .dbg_slice_status           (                             ),    // 调试Slice状态（未连接）
    .dbg_slice_state            (                             ),    // 调试Slice状态机（未连接）
    .debug_data                 (                             ),    // 调试数据输出（未连接）
    .debug_gpll_dps_phase       (                             ),    // 调试GPLL DPS相位（未连接）

    // 调试状态输出
    .dbg_rst_dps_state          (                             ),    // 调试复位DPS状态（未连接）
    .dbg_tran_err_rst_cnt       (                             ),    // 调试传输错误复位计数（未连接）
    .dbg_ddrphy_init_fail       (                             ),    // 调试DDR PHY初始化失败标志（未连接）

    // CPD（Clock Phase Detector）调试接口
    .debug_cpd_offset_adj       (1'b0                         ),    // 调试CPD偏移调整（禁用）
    .debug_cpd_offset_dir       (1'b0                         ),    // 调试CPD偏移方向（禁用）
    .debug_cpd_offset           (10'd0                        ),    // 调试CPD偏移值（固定为0）
    .debug_dps_cnt_dir0         (                             ),    // 调试DPS计数方向0（未连接）
    .debug_dps_cnt_dir1         (                             ),    // 调试DPS计数方向1（未连接）

    // 时钟延迟控制（用于调整时钟树延迟）
    .ck_dly_en                  (1'b0                         ),    // 时钟延迟使能（禁用）
    .init_ck_dly_step           (8'd0                         ),    // 初始时钟延迟步数（使用默认值）
    .ck_dly_set_bin             (                             ),    // 时钟延迟设置二进制值（未连接）

    // 校准和状态监控
    .align_error                (                             ),    // 对齐错误标志（未连接，可用于错误检测）
    .debug_rst_state            (                             ),    // 调试复位状态（未连接）
    .debug_cpd_state            (                             )     // 调试CPD状态（未连接）

  );


//*==============================================================================
// 图像整形模块：将图像数据格式化为适合DDR写入的格式
//*==============================================================================
always @(posedge hdmi_pix_clk) begin
    if (!hdmi_video_rst_n) begin
        hdmi_pix_clk_alive <= 32'd0;
        hdmi_vs_counter <= 32'd0;
        hdmi_hs_counter <= 32'd0;
        hdmi_de_pixel_counter <= 32'd0;
        hdmi_frame_count <= 32'd0;
        hdmi_vs_d0 <= 1'b0;
        hdmi_vs_d1 <= 1'b0;
        hdmi_hs_d0 <= 1'b0;
        hdmi_hs_d1 <= 1'b0;
    end
    else begin
        hdmi_pix_clk_alive <= hdmi_pix_clk_alive + 32'd1;
        hdmi_vs_d0 <= hdmi_vs;
        hdmi_vs_d1 <= hdmi_vs_d0;
        hdmi_hs_d0 <= hdmi_hs;
        hdmi_hs_d1 <= hdmi_hs_d0;

        if (hdmi_vs_d0 && !hdmi_vs_d1) begin
            hdmi_vs_counter <= hdmi_vs_counter + 32'd1;
            hdmi_frame_count <= hdmi_frame_count + 32'd1;
            hdmi_de_pixel_counter <= 32'd0;
        end
        else if (hdmi_de) begin
            hdmi_de_pixel_counter <= hdmi_de_pixel_counter + 32'd1;
        end

        if (hdmi_hs_d0 && !hdmi_hs_d1) begin
            hdmi_hs_counter <= hdmi_hs_counter + 32'd1;
        end
    end
end

// 通道0图像整形：处理摄像头1的RGB565数据，输出16bit格式化的图像数据
//vs同步
//reg    sfpin_vs_d0;
//reg    sfpin_vs_d1;
//
//always@(posedge rx_clk or negedge rstn_out)    begin
//    if(!rstn_out)
//    begin
//        sfpin_vs_d0    <=    1'd0;
//        sfpin_vs_d1    <=    1'd0;
//    end
//    else
//    begin
//        sfpin_vs_d0    <=    vs_wr;
//        sfpin_vs_d1    <=    sfpin_vs_d0;
//    end
//end
//
//
//wire             sfpin_scale_de;
//wire  [15:0]     sfpin_scale_data;
//video_scale_process#(
//    .PIX_DATA_WIDTH       ( 16 )
//)u_video_scale_process_sfpin(
//    .video_clk            ( rx_clk            ),
//    .rst_n                ( rstn_out          ),
//    .frame_sync_n         ( ~sfpin_vs_d1      ),
//    .video_data_in        ( vout_data_r       ), 
//    .video_data_valid     ( de_wr             ),
//    .video_data_out       ( ch0_write_data  ),
//    .video_data_out_valid ( ch0_write_data_valid    ),
//    .video_ready          ( 1'b1              ),
//    .video_width_in       ( 1280              ),
//    .video_height_in      ( 720               ),
//    .video_width_out      ( 640               ),
//    .video_height_out     ( 360               )
//);

img_data_stream_reducer dl_ch0_image_reshape(
    .clk                    (hdmi_pix_clk               ),
    .rst_n                  (hdmi_video_rst_n           ),

    .img_vs                 (hdmi_vs                    ),
    .img_data_valid         (hdmi_de                    ),
    .img_data               (hdmi_rgb565                ),
   
    .img_data_valid_out     (ch0_write_data_valid       ),   // 输出：格式化后的数据有效信号
    .img_data_out           (ch0_write_data             )    // 输出：格式化后的16bit图像数据
);

// 通道1图像整形：与通道0使用相同输入源（摄像头1），用于多通道处理
img_data_stream_reducer dl_ch1_image_reshape(
    .clk                    (pclk_in_test               ),   // 输入：像素时钟（摄像头1）
    .rst_n                  (hdmi_video_rst_n           ),

    .img_vs                 (vs_in_test                 ),   // 输入：场同步信号
    .img_data_valid         (de_in_test                 ),   // 输入：数据有效信号
    .img_data               (i_rgb565                   ),   // 输入：RGB565格式图像数据
   
    .img_data_valid_out     (ch1_write_data_valid      ),   // 输出：格式化后的数据有效信号
    .img_data_out           (ch1_write_data            )    // 输出：格式化后的16bit图像数据
);

// 通道2图像整形：处理摄像头2的RGB565数据，输出16bit格式化的图像数据
img_data_stream_reducer dl_ch2_image_reshape(
    .clk                    (pclk_in_test_2             ),   // 输入：像素时钟（摄像头2）
    .rst_n                  (hdmi_video_rst_n           ),

    .img_vs                 (vs_in_test_2               ),   // 输入：场同步信号（摄像头2）
    .img_data_valid         (de_in_test_2               ),   // 输入：数据有效信号（摄像头2）
    .img_data               (i_rgb565_2                 ),   // 输入：RGB565格式图像数据（摄像头2）
   
    .img_data_valid_out     (ch2_write_data_valid      ),   // 输出：格式化后的数据有效信号
    .img_data_out           (ch2_write_data            )    // 输出：格式化后的16bit图像数据
);

// 通道3图像整形：fmc数据源
img_data_stream_reducer dl_ch3_image_reshape(
    .clk                    (fmc_pclk                   ),   // 输入：像素时钟（摄像头2）
    .rst_n                  (hdmi_video_rst_n           ),

    .img_vs                 (fmc_vs                     ),   // 输入：场同步信号（摄像头2）
    .img_data_valid         (fmc_de                     ),   // 输入：数据有效信号（摄像头2）
    .img_data               (fmc_rgb565                 ),   // 输入：RGB565格式图像数据（摄像头2）
   
    .img_data_valid_out     (ch3_write_data_valid      ),   // 输出：格式化后的数据有效信号
    .img_data_out           (ch3_write_data            )    // 输出：格式化后的16bit图像数据
);


// PCIe图像选择模块：从4个通道中选择数据并通过PCIe DMA传输
pcie_image_channel_selector dl_pcie_img_select_inst(
    .clk                         (pclk_div2                                 ),     // 输入：PCIe时钟域（125MHz）
    .rst_n                       (core_rst_n                                ),     // 输入：核心复位信号
    
    // DMA触发信号
    .dma_sim_vs                  (ch0_read_frame_req                            ),     // 输入：模拟场同步（帧读请求）
    .line_full_flag              (ch0_line_full_flag                            ),     // 输入：单路HDMI IN通道0行缓冲满标志

    // 通道数据接口：从DDR读取的128bit宽数据
    .ch0_data_req                (ch0_read_data_en                        ),     // 输入：通道0数据请求使能
    .ch0_data                    (ch0_read_data                           ),     // 输入：通道0数据（128bit）
    .ch1_data_req                (ch1_read_data_en                        ),     // 输入：通道1数据请求使能
    .ch1_data                    (ch1_read_data                           ),     // 输入：通道1数据（128bit）
    .ch2_data_req                (ch2_read_data_en                        ),     // 输入：通道2数据请求使能
    .ch2_data                    (ch2_read_data                           ),     // 输入：通道2数据（128bit）
    .ch3_data_req                (ch3_read_data_en                        ),     // 输入：通道3数据请求使能
    .ch3_data                    (ch3_read_data                           ),     // 输入：通道3数据（128bit）

    // DMA写接口：输出到PCIe DMA控制器
    .dma_wr_data_req             (dma_write_req                      ),     // 输出：DMA写数据请求
    .dma_wr_data                 (dma_write_data                          ),     // 输出：DMA写数据（128bit）
    .debug_read_line_index       (debug_read_line_index                   ),
    .debug_read_beat_index       (debug_read_beat_index                   ),
    .debug_dma_req_line_count    (debug_dma_req_line_count                ),
    .debug_dma_req_beat_count    (debug_dma_req_beat_count                ),
    .debug_dma_underflow_count   (debug_dma_underflow_count               ),
    .debug_dma_zero_output_count (debug_dma_zero_output_count             ),
    .debug_read_frame_active     (debug_read_frame_active                 )
);
//*==============================================================================
// AXI控制器例化：管理DDR3的读写操作，支持4个通道的图像数据缓存
//*==============================================================================
mem_axi_burst_ctrl_core dl_axi_ctrl_inst
(
	  .ARESETN                     (ddr_init_done                             ),
	  .ACLK                        (core_clk                                  ),
	  .M_AXI_AWID                  (axi_awuser_id                             ),
	  .M_AXI_AWADDR                (axi_awaddr                                ),
	  .M_AXI_AWLEN                 (axi_awlen                                 ),
	  .M_AXI_AWSIZE                (                                          ),
	  .M_AXI_AWBURST               (                                          ),
	  .M_AXI_AWLOCK                (                                          ),
	  .M_AXI_AWCACHE               (                                          ),
	  .M_AXI_AWPROT                (                                          ),
	  .M_AXI_AWQOS                 (                                          ),
	  .M_AXI_AWUSER                (                                          ),
	  .M_AXI_AWVALID               (axi_awvalid                               ),
	  .M_AXI_AWREADY               (axi_awready                               ),
	  .M_AXI_WDATA                 (axi_wdata                                 ),
	  .M_AXI_WSTRB                 (axi_wstrb                                 ),
	  .M_AXI_WLAST                 (                                          ),
	  .M_AXI_WUSER                 (                                          ),
	  .M_AXI_WVALID                (                                          ),
	  .M_AXI_WREADY                (axi_wready                                ),
	  .M_AXI_BID                   (0                                         ),
	  .M_AXI_BRESP                 (0                                         ),
	  .M_AXI_BUSER                 (0                                         ),
      .M_AXI_BVALID                (1'b1                                      ),

	  .M_AXI_BREADY                (                                          ),
	  .M_AXI_ARID                  (axi_aruser_id                             ),
	  .M_AXI_ARADDR                (axi_araddr                                ),
	  .M_AXI_ARLEN                 (axi_arlen                                 ),
	  .M_AXI_ARSIZE                (                                          ),
	  .M_AXI_ARBURST               (                                          ),
	  .M_AXI_ARLOCK                (                                          ),
	  .M_AXI_ARCACHE               (                                          ),
	  .M_AXI_ARPROT                (                                          ),
	  .M_AXI_ARQOS                 (                                          ),
	  .M_AXI_ARUSER                (                                          ),
	  .M_AXI_ARVALID               (axi_arvalid                               ),
	  .M_AXI_ARREADY               (axi_arready                               ),
	  .M_AXI_RID                   (axi_rid                                   ),
	  .M_AXI_RDATA                 (axi_rdata                                 ),
	  .M_AXI_RRESP                 (0                                         ),
	  .M_AXI_RLAST                 (axi_rlast                                 ),
	  .M_AXI_RUSER                 (0                                         ),
	  .M_AXI_RVALID                (axi_rvalid                                ),
	  .M_AXI_RREADY                (                                          ),  

      // key
      .key                         ({1'b1,3'b111,4'b0000}                     ),

      // 通道0   
      .ch0_wframe_pclk             (hdmi_pix_clk                              ),
      .ch0_wframe_rst_n            (hdmi_video_rst_n                          ),
      .ch0_wframe_vsync            (hdmi_vs                                   ),
      .ch0_wframe_data_valid       (ch0_write_data_valid                     ),         
      .ch0_wframe_data             (ch0_write_data                           ),

      .ch0_rframe_pclk             (pclk_div2                                 ),   
      .ch0_rframe_rst_n            (ddr_init_done                             ), 
      .ch0_rframe_vsync            (ch0_read_frame_req                            ),
      .ch0_rframe_req              (ch0_read_frame_req                            ),
      .ch0_rframe_req_ack          (ch0_read_req_ack                        ),
      .ch0_rframe_data_en          (ch0_read_data_en                        ),
      .ch0_rframe_data             (ch0_read_data                           ),      
      .ch0_rframe_data_valid       (                                          ),
      .ch0_read_line_full          (ch0_line_full_flag                          ),

        // 通道1
      .ch1_wframe_pclk             (pclk_in_test                              ),
      .ch1_wframe_rst_n            (hdmi_video_rst_n                          ),
      .ch1_wframe_vsync            (vs_in_test                                ),
      .ch1_wframe_data_valid       (ch1_write_data_valid                     ),          
      .ch1_wframe_data             (ch1_write_data                           ),      

      .ch1_rframe_pclk             (pclk_div2                                 ),   
      .ch1_rframe_rst_n            (ddr_init_done                             ), 
      .ch1_rframe_vsync            (1'b0                                      ),
      .ch1_rframe_req              (1'b0                                      ),
      .ch1_rframe_req_ack          (                                          ),
      .ch1_rframe_data_en          (ch1_read_data_en                        ),
      .ch1_rframe_data             (ch1_read_data                           ),      
      .ch1_rframe_data_valid       (                                          ),
      .ch1_read_line_full          (ch1_line_full_flag                          ),

        // 通道2
      .ch2_wframe_pclk             (pclk_in_test_2                            ),
      .ch2_wframe_rst_n            (hdmi_video_rst_n                          ),
      .ch2_wframe_vsync            (vs_in_test_2                              ),
      .ch2_wframe_data_valid       (ch2_write_data_valid                     ),
      .ch2_wframe_data             (ch2_write_data                           ),

      .ch2_rframe_pclk             (pclk_div2                                 ),   
      .ch2_rframe_rst_n            (ddr_init_done                             ), 
      .ch2_rframe_vsync            (1'b0                                      ),
      .ch2_rframe_req              (1'b0                                      ),
      .ch2_rframe_req_ack          (                                          ),
      .ch2_rframe_data_en          (ch2_read_data_en                        ),
      .ch2_rframe_data             (ch2_read_data                           ),      
      .ch2_rframe_data_valid       (                                          ),
      .ch2_read_line_full          (ch2_line_full_flag                          ),

      // 通道3
      .ch3_wframe_pclk             (fmc_pclk                                 ),  
      .ch3_wframe_rst_n            (hdmi_video_rst_n                          ),
      .ch3_wframe_vsync            (fmc_vs                                   ),
      .ch3_wframe_data_valid       (ch3_write_data_valid                     ),
      .ch3_wframe_data             (ch3_write_data                           ),

      .ch3_rframe_pclk             (pclk_div2                                 ),   
      .ch3_rframe_rst_n            (ddr_init_done                             ), 
      .ch3_rframe_vsync            (1'b0                                      ),
      .ch3_rframe_req              (1'b0                                      ),
      .ch3_rframe_req_ack          (                                          ),
      .ch3_rframe_data_en          (ch3_read_data_en                        ),
      .ch3_rframe_data             (ch3_read_data                           ),      
      .ch3_rframe_data_valid       (                                          ),
      .ch3_read_line_full          (ch3_line_full_flag                          )
);


//*==============================================================================
// PCIe接口模块：实现PCIe数据通信和DMA传输功能
//*==============================================================================
// 复位消抖和同步：消除复位信号的毛刺并同步到不同时钟域
hsst_rst_cross_sync_v1_0 #(
    `ifdef IPS2L_PCIE_SPEEDUP_SIM
    .RST_CNTR_VALUE     (16'h10             )
    `else
    .RST_CNTR_VALUE     (16'hC000           )
    `endif
)
dl_u_refclk_buttonrstn_debounce(
    .clk                (ref_clk            ),
    .rstn_in            (sys_rst_n        ),
    .rstn_out           (sync_button_rst_n  )
);

hsst_rst_cross_sync_v1_0 #(
    `ifdef IPS2L_PCIE_SPEEDUP_SIM
    .RST_CNTR_VALUE     (16'h10             )
    `else
    .RST_CNTR_VALUE     (16'hC000           )
    `endif
)
dl_u_refclk_perstn_debounce(
    .clk                (ref_clk            ),
    .rstn_in            (pcie_perst_n            ),
    .rstn_out           (sync_perst_n       )
);

hsst_rst_sync_v1_0  dl_u_ref_core_rstn_sync    (
    .clk                (ref_clk            ),
    .rst_n              (core_rst_n         ),
    .sig_async          (1'b1               ),
    .sig_synced         (ref_core_rst_n     )
);

hsst_rst_sync_v1_0  dl_u_pclk_core_rstn_sync   (
    .clk                (pclk               ),
    .rst_n              (core_rst_n         ),
    .sig_async          (1'b1               ),
    .sig_synced         (s_pclk_rstn        )
);

//===============================================================================
// PCIe参考时钟LED控制：在PCIe链路建立后闪烁，指示参考时钟运行状态
//===============================================================================
always @(posedge ref_clk or negedge sync_perst_n) begin
	if (!sync_perst_n) begin
		// PCIe复位期间：计数器清零，LED保持高电平
		ref_led_cnt <= 23'd0;
		ref_led <= 1'b1;
	end else if (smlh_link_up & rdlh_link_up) begin
		// PCIe链路已建立：计数器递增，当计数器全1时翻转LED
		ref_led_cnt <= ref_led_cnt + 23'd1;
		if(&ref_led_cnt)  // 如果计数器所有位都为1（约8.3M次计数），翻转LED
			ref_led <= ~ref_led;
	end
end

//===============================================================================
// PCIe用户时钟LED控制：在PCIe链路建立后闪烁，指示用户时钟运行状态
//===============================================================================
always @(posedge pclk or negedge s_pclk_rstn) begin
	if (!s_pclk_rstn) begin
		// PCIe复位期间：计数器清零，LED保持高电平
		pclk_led_cnt <= 27'd0;
		pclk_led <= 1'b1;
	end else if (smlh_link_up & rdlh_link_up) begin
		// PCIe链路已建立：计数器递增，当计数器全1时翻转LED
		pclk_led_cnt <= pclk_led_cnt + 27'd1;
		if(&pclk_led_cnt)  // 如果计数器所有位都为1（约134M次计数），翻转LED
			pclk_led <= ~pclk_led;
	end
end


//===============================================================================
// PCIe DMA控制器模块：实现PCIe DMA数据传输功能
//===============================================================================
// DMA控制器基地址：0x8000（通过APB接口访问）
// 功能：从DDR3读取图像数据，通过PCIe传输到上位机
pcie_dma_core #(
	.DEVICE_TYPE			(DEVICE_TYPE),                  // PCIe设备类型
	.AXIS_SLAVE_NUM			(AXIS_SLAVE_NUM)                 // AXI-Stream从设备数量（3个）
) dl_u_ips2l_pcie_dma (
	// 时钟和复位
	.clk					(pclk_div2),			         // 输入：PCIe时钟域（125MHz或62.5MHz）
	.rst_n					(core_rst_n),                    // 输入：核心复位信号（高有效）				

	// Num
	.i_cfg_pbus_num			(cfg_pbus_num),				
	.i_cfg_pbus_dev_num		(cfg_pbus_dev_num),			
	.i_cfg_max_rd_req_size	(cfg_max_rd_req_size),		
	.i_cfg_max_payload_size	(cfg_max_payload_size),		

	// AXI4-Stream master interface
	.i_axis_master_tvld		(axis_master_tvalid_mem),	
	.o_axis_master_trdy		(axis_master_tready_mem),	
	.i_axis_master_tdata	(axis_master_tdata_mem),	
	.i_axis_master_tkeep	(axis_master_tkeep_mem),	
														
	.i_axis_master_tlast	(axis_master_tlast_mem),	
	.i_axis_master_tuser	(axis_master_tuser_mem),	

	// AXI4-Stream slave0 interface
	.i_axis_slave0_trdy		(axis_slave0_tready),		
	.o_axis_slave0_tvld		(dma_axis_slave0_tvalid),	
	.o_axis_slave0_tdata	(dma_axis_slave0_tdata),	
	.o_axis_slave0_tlast	(dma_axis_slave0_tlast),	
	.o_axis_slave0_tuser	(dma_axis_slave0_tuser),	

	// AXI4-Stream slave1 interface
	.i_axis_slave1_trdy		(axis_slave1_tready),		
	.o_axis_slave1_tvld		(axis_slave1_tvalid),		
	.o_axis_slave1_tdata	(axis_slave1_tdata),		
	.o_axis_slave1_tlast	(axis_slave1_tlast),		
	.o_axis_slave1_tuser	(axis_slave1_tuser),		

	// AXI4-Stream slave2 interface
	.i_axis_slave2_trdy		(axis_slave2_tready),		
	.o_axis_slave2_tvld		(axis_slave2_tvalid),		
	.o_axis_slave2_tdata	(axis_slave2_tdata),		
	.o_axis_slave2_tlast	(axis_slave2_tlast),		
	.o_axis_slave2_tuser	(axis_slave2_tuser),		

	// From pcie
	.i_cfg_ido_req_en		(cfg_ido_req_en),			
	.i_cfg_ido_cpl_en		(cfg_ido_cpl_en),			
	.i_xadm_ph_cdts			(xadm_ph_cdts),				
	.i_xadm_pd_cdts			(xadm_pd_cdts),				
	.i_xadm_nph_cdts		(xadm_nph_cdts),			
	.i_xadm_npd_cdts		(xadm_npd_cdts),			
	.i_xadm_cplh_cdts		(xadm_cplh_cdts),			
	.i_xadm_cpld_cdts		(xadm_cpld_cdts),			

	// APB interface
	.i_apb_psel				(p_sel_dma),				
	.i_apb_paddr			(p_addr[8:0]),				
	.i_apb_pwdata			(p_wdata),					
	.i_apb_pstrb			(p_strb),					
	.i_apb_pwrite			(p_we),						
	.i_apb_penable			(p_ce),						
	.o_apb_prdy				(p_rdy_dma),				
	.o_apb_prdata			(p_rdata_dma),				
	.o_cross_4kb_boundary	(cross_4kb_boundary),		//4k边界
    //**********************************************************************
    // dma write interface
    .o_dma_write_data_req   (dma_write_req  ),
    .o_dma_write_addr       (dma_write_addr      ),
    .i_dma_write_data       (dma_write_data      )
);



//===============================================================================
// APB配置接口固定赋值（当前未使用配置寄存器）
//===============================================================================
assign p_rdy_cfg               = 1'b0;                         // 配置寄存器就绪信号（固定为未就绪）
assign p_rdata_cfg             = 32'b0;                        // 配置寄存器读数据（固定为0）

//===============================================================================
// AXI-Stream信号连接：将DMA输出连接到PCIe IP核的从设备接口
//===============================================================================
assign axis_slave0_tvalid      = dma_axis_slave0_tvalid;       // 从设备0有效信号：来自DMA控制器
assign axis_slave0_tlast       = dma_axis_slave0_tlast;        // 从设备0最后数据：来自DMA控制器
assign axis_slave0_tuser       = dma_axis_slave0_tuser;        // 从设备0用户信号：来自DMA控制器
assign axis_slave0_tdata       = dma_axis_slave0_tdata;        // 从设备0数据：来自DMA控制器

//===============================================================================
// AXI-Stream信号连接：将PCIe IP核的主设备接口连接到DMA控制器
//===============================================================================
assign axis_master_tvalid_mem  = axis_master_tvalid;            // 主设备有效信号：连接到DMA控制器
assign axis_master_tdata_mem   = axis_master_tdata;             // 主设备数据：连接到DMA控制器
assign axis_master_tkeep_mem   = axis_master_tkeep;            // 主设备数据有效字节：连接到DMA控制器
assign axis_master_tlast_mem   = axis_master_tlast;             // 主设备最后数据：连接到DMA控制器
assign axis_master_tuser_mem   = axis_master_tuser;             // 主设备用户信号：连接到DMA控制器

// 主设备就绪信号：从DMA控制器反馈到PCIe IP核
assign axis_master_tready      = axis_master_tready_mem;



// PCIe IP TOP : HSSTLP : 0x0000~6000 PCIe BASE ADDR : 0x7000
pcie_test dl_u_ips2l_pcie_wrap (
	.button_rst_n				(1'b1),	
	.power_up_rst_n				(1'b1),			
	.perst_n					(1'b1),			

	// The clock and reset signals
	.pclk						(pclk),					
	.pclk_div2					(pclk_div2),			
	.ref_clk					(ref_clk),				
	.ref_clk_n					(pcie_refclk_n),			
	.ref_clk_p					(pcie_refclk_p),			
	.core_rst_n					(core_rst_n),			

	// APB interface to DBI config
	.p_sel						(p_sel_pcie),			
	.p_strb						(uart_p_strb),			
	.p_addr						(uart_p_addr),			
	.p_wdata					(uart_p_wdata),			
	.p_ce						(uart_p_ce),			
	.p_we						(uart_p_we),			
	.p_rdy						(p_rdy_pcie),			
	.p_rdata					(p_rdata_pcie),			

	// PHY diff signals
	.rxn						(pcie_rxn),					
	.rxp						(pcie_rxp),					
	.txn						(pcie_txn),					
	.txp						(pcie_txp),					
	.pcs_nearend_loop			({4{1'b0}}),			
	.pma_nearend_ploop			({4{1'b0}}),			
	.pma_nearend_sloop			({4{1'b0}}),			

	// AXI4-Stream master interface
	.axis_master_tvalid			(axis_master_tvalid),	
	.axis_master_tready			(axis_master_tready),	
	.axis_master_tdata			(axis_master_tdata),	
	.axis_master_tkeep			(axis_master_tkeep),	
														
	.axis_master_tlast			(axis_master_tlast),	
	.axis_master_tuser			(axis_master_tuser),	

	// AXI4-Stream slave 0 interface
	.axis_slave0_tready			(axis_slave0_tready),	
	.axis_slave0_tvalid			(axis_slave0_tvalid),	
	.axis_slave0_tdata			(axis_slave0_tdata),	
	.axis_slave0_tlast			(axis_slave0_tlast),	
	.axis_slave0_tuser			(axis_slave0_tuser),	

	// AXI4-Stream slave 1 interface
	.axis_slave1_tready			(axis_slave1_tready),	
	.axis_slave1_tvalid			(axis_slave1_tvalid),	
	.axis_slave1_tdata			(axis_slave1_tdata),	
	.axis_slave1_tlast			(axis_slave1_tlast),	
	.axis_slave1_tuser			(axis_slave1_tuser),	

	// AXI4-Stream slave 2 interface
	.axis_slave2_tready			(axis_slave2_tready),	
	.axis_slave2_tvalid			(axis_slave2_tvalid),	
	.axis_slave2_tdata			(axis_slave2_tdata),	
	.axis_slave2_tlast			(axis_slave2_tlast),	
	.axis_slave2_tuser			(axis_slave2_tuser),	

	.pm_xtlh_block_tlp			(),						

	.cfg_send_cor_err_mux		(),						
	.cfg_send_nf_err_mux		(),						
	.cfg_send_f_err_mux			(),						
	.cfg_sys_err_rc				(),						
	.cfg_aer_rc_err_mux			(),						

	// The radm timeout
	.radm_cpl_timeout			(),						

	// Configuration signals
	.cfg_max_rd_req_size		(cfg_max_rd_req_size),	
	.cfg_bus_master_en			(),						
	.cfg_max_payload_size		(cfg_max_payload_size),	
	.cfg_ext_tag_en				(),						
	.cfg_rcb					(cfg_rcb),				
	.cfg_mem_space_en			(),						
	.cfg_pm_no_soft_rst			(),						
	.cfg_crs_sw_vis_en			(),						
	.cfg_no_snoop_en			(),						
	.cfg_relax_order_en			(),						
	.cfg_tph_req_en				(),						
	.cfg_pf_tph_st_mode			(),						
	.rbar_ctrl_update			(),						
	.cfg_atomic_req_en			(),						

	.cfg_pbus_num				(cfg_pbus_num),			
	.cfg_pbus_dev_num			(cfg_pbus_dev_num),		

	// Debug signals
	.radm_idle					(),						
	.radm_q_not_empty			(),						
	.radm_qoverflow				(),						
	.diag_ctrl_bus				(2'b0),					
	.cfg_link_auto_bw_mux		(),						
	.cfg_bw_mgt_mux				(),						
	.cfg_pme_mux				(),						
	.app_ras_des_sd_hold_ltssm	(1'b0),					
	.app_ras_des_tba_ctrl		(2'b0),					

	.dyn_debug_info_sel			(4'b0),					
	.debug_info_mux				(),

	// System signal
	.smlh_link_up				(smlh_link_up),			//link状态
	.rdlh_link_up				(rdlh_link_up),			//link状态
	.smlh_ltssm_state			(smlh_ltssm_state)
);



//===============================================================================
// HDMI frame-ready to DDR read-frame request control
//===============================================================================
reg         hdmi_vs_pclk_meta;
reg         hdmi_vs_pclk_d0;
reg         hdmi_vs_pclk_d1;
reg         frame_ready                     /*synthesis PAP_MARK_DEBUG="1"*/;
reg         read_frame_active               /*synthesis PAP_MARK_DEBUG="1"*/;
reg [11:0]  read_line_index                 /*synthesis PAP_MARK_DEBUG="1"*/;
reg [11:0]  read_beat_index                 /*synthesis PAP_MARK_DEBUG="1"*/;
reg [31:0]  ddr_write_frame_count           /*synthesis PAP_MARK_DEBUG="1"*/;
reg [31:0]  ddr_read_frame_count            /*synthesis PAP_MARK_DEBUG="1"*/;

always @(posedge pclk_div2) begin
    if (!core_rst_n) begin
        hdmi_vs_pclk_meta <= 1'b0;
        hdmi_vs_pclk_d0 <= 1'b0;
        hdmi_vs_pclk_d1 <= 1'b0;
    end
    else begin
        hdmi_vs_pclk_meta <= hdmi_vs;
        hdmi_vs_pclk_d0 <= hdmi_vs_pclk_meta;
        hdmi_vs_pclk_d1 <= hdmi_vs_pclk_d0;
    end
end

always @(posedge pclk_div2) begin
    if (!core_rst_n) begin
        frame_ready <= 1'b0;
        ddr_write_frame_count <= 32'd0;
    end
    else if (hdmi_vs_pclk_d0 && !hdmi_vs_pclk_d1) begin
        frame_ready <= 1'b1;
        ddr_write_frame_count <= ddr_write_frame_count + 32'd1;
    end
    else if (ch0_read_frame_req) begin
        frame_ready <= 1'b0;
    end
end

always @(posedge pclk_div2) begin
    if (!core_rst_n) begin
        read_line_index <= 12'd0;
        read_beat_index <= 12'd0;
        read_frame_active <= 1'b0;
        ddr_read_frame_count <= 32'd0;
    end
    else if (ch0_read_frame_req) begin
        read_line_index <= 12'd0;
        read_beat_index <= 12'd0;
        read_frame_active <= 1'b1;
        ddr_read_frame_count <= ddr_read_frame_count + 32'd1;
    end
    else if (dma_write_req) begin
        if (read_beat_index == 12'd79) begin
            read_beat_index <= 12'd0;
            if (read_line_index == 12'd359) begin
                read_line_index <= 12'd0;
                read_frame_active <= 1'b0;
            end
            else begin
                read_line_index <= read_line_index + 12'd1;
            end
        end
        else begin
            read_beat_index <= read_beat_index + 12'd1;
        end
    end
end

always @(posedge pclk_div2) begin
    if (!core_rst_n) begin
        ch0_read_frame_req <= 1'b0;
    end
    else if (ch0_read_req_ack) begin
        ch0_read_frame_req <= 1'b0;
    end
    else if (frame_ready && !read_frame_active && !ch0_read_frame_req) begin
        ch0_read_frame_req <= 1'b1;
    end
end

endmodule

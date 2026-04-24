`timescale 1ns / 1ps
`define UD #1
`define HDMI

module hdmi_ddr_ov5640_top#(
	parameter MEM_ROW_ADDR_WIDTH   = 15         ,
	parameter MEM_COL_ADDR_WIDTH   = 10         ,
	parameter MEM_BADDR_WIDTH      = 3          ,
	parameter MEM_DQ_WIDTH         =  32        ,
	parameter MEM_DM_WIDTH         =  MEM_DQ_WIDTH/8,
	parameter MEM_DQS_WIDTH        =  MEM_DQ_WIDTH/8
)(
	input                                sys_clk              ,//50Mhz
//OV5647
    output  [1:0]                        cmos_init_done       ,//OV5640寄存器初始化完成
    //coms1	
    inout                                cmos1_scl            ,//cmos1 i2c 
    inout                                cmos1_sda            ,//cmos1 i2c 
    input                                cmos1_vsync          ,//cmos1 vsync
    input                                cmos1_href           ,//cmos1 hsync refrence,data valid
    input                                cmos1_pclk           ,//cmos1 pxiel clock
    input   [7:0]                        cmos1_data           ,//cmos1 data
    output                               cmos1_reset          ,//cmos1 reset
    //coms2
    inout                                cmos2_scl            ,//cmos2 i2c 
    inout                                cmos2_sda            ,//cmos2 i2c 
    input                                cmos2_vsync          ,//cmos2 vsync
    input                                cmos2_href           ,//cmos2 hsync refrence,data valid
    input                                cmos2_pclk           ,//cmos2 pxiel clock
    input   [7:0]                        cmos2_data           ,//cmos2 data
    output                               cmos2_reset          ,//cmos2 reset
//DDR
    output                               mem_rst_n                 ,
    output                               mem_ck                    ,
    output                               mem_ck_n                  ,
    output                               mem_cke                   ,
    output                               mem_cs_n                  ,
    output                               mem_ras_n                 ,
    output                               mem_cas_n                 ,
    output                               mem_we_n                  ,
    output                               mem_odt                   ,
    output      [MEM_ROW_ADDR_WIDTH-1:0] mem_a                     ,
    output      [MEM_BADDR_WIDTH-1:0]    mem_ba                    ,
    inout       [MEM_DQ_WIDTH/8-1:0]     mem_dqs                   ,
    inout       [MEM_DQ_WIDTH/8-1:0]     mem_dqs_n                 ,
    inout       [MEM_DQ_WIDTH-1:0]       mem_dq                    ,
    output      [MEM_DQ_WIDTH/8-1:0]     mem_dm                    ,
    output reg                           heart_beat_led            ,
    output                               ddr_init_done             ,
//MS72xx       
    output                               rstn_out1                 ,
    output                               rstn_out2                 ,
    output                               rstn_out3                 ,
                                         
    output                               iic_rx_scl,
    inout                                iic_rx_sda,
    output                               iic_scl                   ,//hdmi_in
    inout                                iic_sda                   ,//hdmi_in
    output                               hdmi_int_led              ,//HDMI_OUT初始化完成
//HDMI_OUT,接视频板的out
    output                               pix_clk                   ,//pixclk                           
    output     reg                       vs_out                    , 
    output     reg                       hs_out                    , 
    output     reg                       de_out                    ,
    output     reg[7:0]                  r_out                     , 
    output     reg[7:0]                  g_out                     , 
    output     reg[7:0]                  b_out                     ,
//HDMI_IN1,接视频板的in1
    input                                pixclk_in                 ,                            
    input                                vs_in                     , 
    input                                hs_in                     , 
    input                                de_in                     ,
    input     [7:0]                      r_in                      , 
    input     [7:0]                      g_in                      , 
    input     [7:0]                      b_in                      ,
//HDMI_IN2,接视频板的in2
    input                                pixclk_in2                ,
    input                                vs_in2                    ,
    input                                hs_in2                    ,
    input                                de_in2                    ,
    input     [7:0]                      r_in2                     ,
    input     [7:0]                      g_in2                     ,
    input     [7:0]                      b_in2                     ,
//HDMI_IN3,接视频板的in3
    input                                pixclk_in3                ,
    input                                vs_in3                    ,
    input                                hs_in3                    ,
    input                                de_in3                    ,
    input     [7:0]                      r_in3                     ,
    input     [7:0]                      g_in3                     ,
    input     [7:0]                      b_in3                     ,
//hsst	
	input                                i_p_refckn_0              ,
	input                                i_p_refckp_0              ,
	input                                i_p_l2rxn                 ,
	input                                i_p_l2rxp                 ,
	input                                i_p_l3rxn                 ,
	input                                i_p_l3rxp                 ,
	output                               o_p_l2txn                 ,
	output                               o_p_l2txp                 ,
	output                               o_p_l3txn                 ,
	output                               o_p_l3txp                 ,
	output wire                          SFP_TX_DISABLE0           ,
	output wire                          SFP_TX_DISABLE1     	    

);
/////////////////////////////////////////////////////////////////////////////////////
// ENABLE_DDR
    parameter CTRL_ADDR_WIDTH = MEM_ROW_ADDR_WIDTH + MEM_BADDR_WIDTH + MEM_COL_ADDR_WIDTH;//28
    parameter TH_1S = 27'd33000000;
/////////////////////////////////////////////////////////////////////////////////////
    reg  [15:0]                 rstn_1ms            ;
    wire                        cmos_scl            ;//cmos i2c clock
    wire                        cmos_sda            ;//cmos i2c data
    wire                        cmos_vsync          ;//cmos vsync
    wire                        cmos_href           ;//cmos hsync refrence,data valid
    wire                        cmos_pclk           ;//cmos pxiel clock
    wire   [7:0]                cmos_data           ;//cmos data
    wire                        cmos_reset          ;//cmos reset
    wire                        initial_en          ;
    wire[15:0]                  cmos1_d_16bit       ;
    wire                        cmos1_href_16bit    ;
    reg [7:0]                   cmos1_d_d0          ;
    reg                         cmos1_href_d0       ;
    reg                         cmos1_vsync_d0      ;
    wire                        cmos1_pclk_16bit    ;
    wire[15:0]                  cmos2_d_16bit       /*synthesis PAP_MARK_DEBUG="1"*/;
    wire                        cmos2_href_16bit    /*synthesis PAP_MARK_DEBUG="1"*/;
    reg [7:0]                   cmos2_d_d0          /*synthesis PAP_MARK_DEBUG="1"*/;
    reg                         cmos2_href_d0       /*synthesis PAP_MARK_DEBUG="1"*/;
    reg                         cmos2_vsync_d0      /*synthesis PAP_MARK_DEBUG="1"*/;
    wire                        cmos2_pclk_16bit    /*synthesis PAP_MARK_DEBUG="1"*/;
    wire[15:0]                  o_rgb565            ;
    wire                        pclk_in_test        ;    
    wire                        vs_in_test          ;
    wire                        de_in_test          ;
    wire[15:0]                  i_rgb565            ;
    wire                        de_re               ;
//AXI parameter
    parameter MEM_DATA_BITS          = 256;             //external memory user interface data width
    parameter ADDR_BITS              = 25;             //external memory user interface address width
    parameter BUSRT_BITS             = 10;             //external memory user interface burst width
    wire                            wr_burst_data_req;
    wire                            wr_burst_finish;
    wire                            rd_burst_finish;
    wire                            rd_burst_req;
    wire                            wr_burst_req;
    wire[BUSRT_BITS - 1:0]          rd_burst_len;
    wire[BUSRT_BITS - 1:0]          wr_burst_len;
    wire[ADDR_BITS - 1:0]           rd_burst_addr;
    wire[ADDR_BITS - 1:0]           wr_burst_addr;
    wire                            rd_burst_data_valid;
    wire[MEM_DATA_BITS - 1 : 0]     rd_burst_data;
    wire[MEM_DATA_BITS - 1 : 0]     wr_burst_data;
//axi bus   
    wire [3:0]                      s00_axi_awid;
    wire [63:0]                     s00_axi_awaddr;
    wire [7:0]                      s00_axi_awlen;    // burst length: 0-255
    wire [2:0]                      s00_axi_awsize;   // burst size: fixed 2'b011
    wire [1:0]                      s00_axi_awburst;  // burst type: fixed 2'b01(incremental burst)
    wire                            s00_axi_awlock;   // lock: fixed 2'b00
    wire [3:0]                      s00_axi_awcache;  // cache: fiex 2'b0011
    wire [2:0]                      s00_axi_awprot;   // protect: fixed 2'b000
    wire [3:0]                      s00_axi_awqos;    // qos: fixed 2'b0000
    wire [0:0]                      s00_axi_awuser;   // user: fixed 32'd0
    wire                            s00_axi_awvalid;
    wire                            s00_axi_awready;
    // master write data
    wire [MEM_DATA_BITS - 1 : 0]    s00_axi_wdata/*synthesis PAP_MARK_DEBUG = "ture"*/;
    wire [MEM_DATA_BITS/8 - 1:0]    s00_axi_wstrb;
    wire                            s00_axi_wlast;
    wire [0:0]                      s00_axi_wuser;
    wire                            s00_axi_wvalid;
    wire                            s00_axi_wready;
    // master write response
    wire [3:0]                      s00_axi_bid;
    wire [1:0]                      s00_axi_bresp;
    wire [0:0]                      s00_axi_buser;
    wire                            s00_axi_bvalid;
    wire                            s00_axi_bready;
    // master read address
    wire [3:0]                      s00_axi_arid;
    wire [63:0]                     s00_axi_araddr;
    wire [7:0]                      s00_axi_arlen;
    wire [2:0]                      s00_axi_arsize;
    wire [1:0]                      s00_axi_arburst;
    wire [1:0]                      s00_axi_arlock;
    wire [3:0]                      s00_axi_arcache;
    wire [2:0]                      s00_axi_arprot;
    wire [3:0]                      s00_axi_arqos;
    wire [0:0]                      s00_axi_aruser;
    wire                            s00_axi_arvalid;
    wire                            s00_axi_arready;
    // master read data
    wire [3:0]                      s00_axi_rid;
    wire [MEM_DATA_BITS - 1 : 0]    s00_axi_rdata/*synthesis PAP_MARK_DEBUG = "ture"*/;
    wire [1:0]                      s00_axi_rresp;
    wire                            s00_axi_rlast;
    wire [0:0]                      s00_axi_ruser;
    wire                            s00_axi_rvalid;
    wire                            s00_axi_rready;

//channel 0
    wire                            ch0_wr_burst_data_req;
    wire                            ch0_wr_burst_finish;
    wire                            ch0_rd_burst_finish;
    wire                            ch0_rd_burst_req;
    wire                            ch0_wr_burst_req;
    wire[BUSRT_BITS - 1:0]          ch0_rd_burst_len;
    wire[BUSRT_BITS - 1:0]          ch0_wr_burst_len;
    wire[ADDR_BITS - 1:0]           ch0_rd_burst_addr;
    wire[ADDR_BITS - 1:0]           ch0_wr_burst_addr;
    wire                            ch0_rd_burst_data_valid;
    wire[MEM_DATA_BITS - 1 : 0]     ch0_rd_burst_data;
    wire[MEM_DATA_BITS - 1 : 0]     ch0_wr_burst_data;    
    wire                            ch0_read_req;
    wire                            ch0_read_req_ack;
    wire                            ch0_read_en;
    wire[15:0]                      ch0_read_data;
    wire                            ch0_write_en;
    wire[15:0]                      ch0_write_data;
    wire                            ch0_write_req;
    wire                            ch0_write_req_ack;
    wire[1:0]                       ch0_write_addr_index;
    wire[1:0]                       ch0_read_addr_index;

//channel 1
    wire                            ch1_wr_burst_data_req;
    wire                            ch1_wr_burst_finish;
    wire                            ch1_rd_burst_finish;
    wire                            ch1_rd_burst_req;
    wire                            ch1_wr_burst_req;
    wire[BUSRT_BITS - 1:0]          ch1_rd_burst_len;
    wire[BUSRT_BITS - 1:0]          ch1_wr_burst_len;
    wire[ADDR_BITS - 1:0]           ch1_rd_burst_addr;
    wire[ADDR_BITS - 1:0]           ch1_wr_burst_addr;
    wire                            ch1_rd_burst_data_valid;
    wire[MEM_DATA_BITS - 1 : 0]     ch1_rd_burst_data;
    wire[MEM_DATA_BITS - 1 : 0]     ch1_wr_burst_data;    
    wire                            ch1_read_req;
    wire                            ch1_read_req_ack;
    wire                            ch1_read_en;
    wire[15:0]                      ch1_read_data;
    wire                            ch1_write_en;
    wire[15:0]                      ch1_write_data;
    wire                            ch1_write_req;
    wire                            ch1_write_req_ack;
    wire[1:0]                       ch1_write_addr_index;
    wire[1:0]                       ch1_read_addr_index;

//channel 2
    wire                            ch2_wr_burst_data_req;
    wire                            ch2_wr_burst_finish;
    wire                            ch2_rd_burst_finish;
    wire                            ch2_rd_burst_req;
    wire                            ch2_wr_burst_req;
    wire[BUSRT_BITS - 1:0]          ch2_rd_burst_len;
    wire[BUSRT_BITS - 1:0]          ch2_wr_burst_len;
    wire[ADDR_BITS - 1:0]           ch2_rd_burst_addr;
    wire[ADDR_BITS - 1:0]           ch2_wr_burst_addr;
    wire                            ch2_rd_burst_data_valid;
    wire[MEM_DATA_BITS - 1 : 0]     ch2_rd_burst_data;
    wire[MEM_DATA_BITS - 1 : 0]     ch2_wr_burst_data;    
    wire                            ch2_read_req;
    wire                            ch2_read_req_ack;
    wire                            ch2_read_en;
    wire[15:0]                      ch2_read_data;
    wire                            ch2_write_en;
    wire[15:0]                      ch2_write_data;
    wire                            ch2_write_req;
    wire                            ch2_write_req_ack;
    wire[1:0]                       ch2_write_addr_index;
    wire[1:0]                       ch2_read_addr_index;  

//channel 3
    wire                            ch3_wr_burst_data_req;
    wire                            ch3_wr_burst_finish;
    wire                            ch3_rd_burst_finish;
    wire                            ch3_rd_burst_req;
    wire                            ch3_wr_burst_req;
    wire[BUSRT_BITS - 1:0]          ch3_rd_burst_len;
    wire[BUSRT_BITS - 1:0]          ch3_wr_burst_len;
    wire[ADDR_BITS - 1:0]           ch3_rd_burst_addr;
    wire[ADDR_BITS - 1:0]           ch3_wr_burst_addr;
    wire                            ch3_rd_burst_data_valid;
    wire[MEM_DATA_BITS - 1 : 0]     ch3_rd_burst_data;
    wire[MEM_DATA_BITS - 1 : 0]     ch3_wr_burst_data;    
    wire                            ch3_read_req;
    wire                            ch3_read_req_ack;
    wire                            ch3_read_en;
    wire[15:0]                      ch3_read_data;
    wire                            ch3_write_en;
    wire[15:0]                      ch3_write_data;
    wire                            ch3_write_req;
    wire                            ch3_write_req_ack;
    wire[1:0]                       ch3_write_addr_index;
    wire[1:0]                       ch3_read_addr_index;  

    wire                            read_req;
    wire                            read_req_ack;
    wire                            read_en/*synthesis PAP_MARK_DEBUG = "ture"*/;
    wire[15:0]                      read_data/*synthesis PAP_MARK_DEBUG = "ture"*/;
    wire                            write_en/*synthesis PAP_MARK_DEBUG = "ture"*/;
    wire[15:0]                      write_data /*synthesis PAP_MARK_DEBUG = "ture"*/;
    wire                            write_req;
    wire                            write_req_ack;
    wire[1:0]                       write_addr_index;
    wire[1:0]                       read_addr_index;

/************************************************************
hsst参数定义
************************************************************/	
wire          i_wtchdg_clr_0 ;
assign        i_wtchdg_clr_0=1'b0;

assign         SFP_TX_DISABLE0       = 1'b0 ;
assign         SFP_TX_DISABLE1       = 1'b0 ;


wire tx0_clk;
wire gt0_txfsmresetdone;
wire gt1_txfsmresetdone;
wire gt2_txfsmresetdone;
wire gt3_txfsmresetdone;
wire[31:0] tx0_data;
wire[3:0] tx0_kchar;
wire tx1_clk;
wire[31:0] tx1_data;
wire[3:0] tx1_kchar; 
wire tx2_clk;
wire[31:0] tx2_data;
wire[3:0] tx2_kchar;
wire tx3_clk;
wire[31:0] tx3_data;
wire[3:0] tx3_kchar;
  
wire rx0_clk;
wire[31:0] rx0_data;
wire[3:0] rx0_kchar;
wire rx1_clk;
wire[31:0] rx1_data ;
wire[3:0] rx1_kchar ;
wire rx2_clk;
wire[31:0] rx2_data ;
wire[3:0] rx2_kchar ;
wire rx3_clk;
wire[31:0] rx3_data;
wire[3:0] rx3_kchar;

reg[31:0] gt_tx_data ;
reg[3:0] gt_tx_ctrl ;

wire[31:0] gt_tx_data0 ;
wire[3:0] gt_tx_ctrl0 ;
wire[31:0] gt_tx_data1 ;
wire[3:0] gt_tx_ctrl1 ;

wire rx_clk;
wire tx_clk;
wire[31:0] rx_data   ;
wire[3:0] rx_kchar   ;

assign tx_clk = tx2_clk;
assign rx_clk = rx3_clk;
assign rx_data = rx2_data;
assign rx_kchar = rx2_kchar;
assign tx0_data = gt_tx_data;
assign tx0_kchar = gt_tx_ctrl;
assign tx1_data = gt_tx_data;
assign tx1_kchar = gt_tx_ctrl;
assign tx2_data = gt_tx_data;
assign tx2_kchar = gt_tx_ctrl;
assign tx3_data = gt_tx_data;
assign tx3_kchar = gt_tx_ctrl;
/////////////////////////////////////////////////////////////////////////////////////
//PLL
    pll u_pll (
        .clkin1   (  sys_clk    ),//50MHz
        .clkout0  (  pix_clk    ),//37.125M 720P30
        .clkout1  (  cfg_clk    ),//10MHz
        .clkout2  (  clk_25M    ),//25M
        .pll_lock (  locked     )
    );

    wire init_over;
    wire init_over_2;
//HDMI配置 IN3和OUT
    ms72xx_ctl ms72xx_ctl_inst1(
        .clk(cfg_clk),              // input
        .rst_n(1'b1),          // input
        .init_over(init_over),  // output
        .iic_scl(iic_scl),      // output
        .iic_sda(iic_sda)       // inout
    );
//HDMI配置 IN1和IN2
    ms7200_double_crtl ms7200_double_crtl_inst(
        .clk(cfg_clk),              // input
        .rst_n(1'b1),          // input
        .init_over(init_over_2),  // output
        .iic_scl(iic_rx_scl),      // output
        .iic_sda(iic_rx_sda)       // inout
    );   


assign rstn_out1 = 1'b1;
assign rstn_out2 = 1'b1;
assign rstn_out3 = 1'b1;
 
    
    always @(posedge cfg_clk)
    begin
    	if(!locked)
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

//配置CMOS///////////////////////////////////////////////////////////////////////////////////
//OV5640 register configure enable    
    power_on_delay	power_on_delay_inst(
    	.clk_50M                 (sys_clk        ),//input
    	.reset_n                 (1'b1           ),//input	
    	.camera1_rstn            (cmos1_reset    ),//output
    	.camera2_rstn            (cmos2_reset    ),//output	
    	.camera_pwnd             (               ),//output
    	.initial_en              (initial_en     ) //output		
    );
//CMOS1 Camera 
    reg_config	coms1_reg_config(
    	.clk_25M                 (clk_25M            ),//input
    	.camera_rstn             (cmos1_reset        ),//input
    	.initial_en              (initial_en         ),//input		
    	.i2c_sclk                (cmos1_scl          ),//output
    	.i2c_sdat                (cmos1_sda          ),//inout
    	.reg_conf_done           (cmos_init_done[0]  ),//output config_finished
    	.reg_index               (                   ),//output reg [8:0]
    	.clock_20k               (                   ) //output reg
    );

//CMOS2 Camera 
    reg_config	coms2_reg_config(
    	.clk_25M                 (clk_25M            ),//input
    	.camera_rstn             (cmos2_reset        ),//input
    	.initial_en              (initial_en         ),//input		
    	.i2c_sclk                (cmos2_scl          ),//output
    	.i2c_sdat                (cmos2_sda          ),//inout
    	.reg_conf_done           (cmos_init_done[1]  ),//output config_finished
    	.reg_index               (                   ),//output reg [8:0]
    	.clock_20k               (                   ) //output reg
    );
//CMOS 8bit转16bit///////////////////////////////////////////////////////////////////////////////////
//CMOS1
    always@(posedge cmos1_pclk)
        begin
            cmos1_d_d0        <= cmos1_data    ;
            cmos1_href_d0     <= cmos1_href    ;
            cmos1_vsync_d0    <= cmos1_vsync   ;
        end

    cmos_8_16bit cmos1_8_16bit(
    	.pclk           (cmos1_pclk       ),//input
    	.rst_n          (cmos_init_done[0]),//input
    	.pdata_i        (cmos1_d_d0       ),//input[7:0]
    	.de_i           (cmos1_href_d0    ),//input
    	.vs_i           (cmos1_vsync_d0    ),//input
    	
    	.pixel_clk      (cmos1_pclk_16bit ),//output
    	.pdata_o        (cmos1_d_16bit    ),//output[15:0]
    	.de_o           (cmos1_href_16bit ) //output
    );
//CMOS2
    always@(posedge cmos2_pclk)
        begin
            cmos2_d_d0        <= cmos2_data    ;
            cmos2_href_d0     <= cmos2_href    ;
            cmos2_vsync_d0    <= cmos2_vsync   ;
        end

    cmos_8_16bit cmos2_8_16bit(
    	.pclk           (cmos2_pclk       ),//input
    	.rst_n          (cmos_init_done[1]),//input
    	.pdata_i        (cmos2_d_d0       ),//input[7:0]
    	.de_i           (cmos2_href_d0    ),//input
    	.vs_i           (cmos2_vsync_d0    ),//input
    	
    	.pixel_clk      (cmos2_pclk_16bit ),//output
    	.pdata_o        (cmos2_d_16bit    ),//output[15:0]
    	.de_o           (cmos2_href_16bit ) //output
    );
//输入视频源选择//////////////////////////////////////////////////////////////////////////////////////////
`ifdef CMOS_1
assign     pclk_in_test    =    cmos1_pclk_16bit    ;
assign     vs_in_test      =    cmos1_vsync_d0      ;
assign     de_in_test      =    cmos1_href_16bit    ;
assign     i_rgb565        =    {cmos1_d_16bit[4:0],cmos1_d_16bit[10:5],cmos1_d_16bit[15:11]};//{r,g,b}
`elsif CMOS_2
assign     pclk_in_test    =    cmos2_pclk_16bit    ;
assign     vs_in_test      =    cmos2_vsync_d0      ;
assign     de_in_test      =    cmos2_href_16bit    ;
assign     i_rgb565        =    {cmos2_d_16bit[4:0],cmos2_d_16bit[10:5],cmos2_d_16bit[15:11]};//{r,g,b}
`elsif HDMI
assign     pclk_in_test    =    pixclk_in    ;
assign     vs_in_test      =    vs_in      ;
assign     de_in_test      =    de_in    ;
assign     i_rgb565        =    {r_in[7:3], g_in[7:2], b_in[7:3]};//{r,g,b}
`elsif FULL_WHITE
assign     pclk_in_test    =    pixclk_in    ;
assign     vs_in_test      =    vs_in      ;
assign     de_in_test      =    de_in    ;
assign     i_rgb565        =    16'hffff;//{r,g,b}
`endif


//HDMI线性插值进行缩小
reg    hdmi_vs_in_d0;
reg    hdmi_vs_in_d1;

always@(posedge pixclk_in or negedge rstn_out)    begin
    if(!rstn_out)
    begin
        hdmi_vs_in_d0    <=    1'd0;
        hdmi_vs_in_d1    <=    1'd0;
    end
    else
    begin
        hdmi_vs_in_d0    <=    vs_in;
        hdmi_vs_in_d1    <=    hdmi_vs_in_d0;
    end
end


wire              hdmi_1_scale_de;
wire    [23:0]    hdmi_1_scale_data;
video_scale_process#(
    .PIX_DATA_WIDTH       ( 24 )
)u_video_scale_process_0_hdmi_in(
    .video_clk            ( pixclk_in          ),
    .rst_n                ( rstn_out1             ),
    .frame_sync_n         ( ~hdmi_vs_in_d1       ),
    .video_data_in        ( {r_in,g_in,b_in}        ),
    .video_data_valid     ( de_in     ),
    .video_data_out       ( hdmi_1_scale_data       ),
    .video_data_out_valid ( hdmi_1_scale_de ),
    .video_ready          ( 1'b1          ),
    .video_width_in       ( 1280       ),
    .video_height_in      ( 720      ),
    .video_width_out      ( 640      ),
    .video_height_out     ( 360     )
);
//接纳第二个输入源
//vs同步
reg    cmos1_vs_d0;
reg    cmos1_vs_d1;

always@(posedge pixclk_in or negedge rstn_out)    begin
    if(!rstn_out)
    begin
        cmos1_vs_d0    <=    1'd0;
        cmos1_vs_d1    <=    1'd0;
    end
    else
    begin
        cmos1_vs_d0    <=    cmos1_vsync_d0;
        cmos1_vs_d1    <=    cmos1_vs_d0;
    end
end


wire             cmos1_scale_de;
wire  [23:0]     cmos1_scale_data;
video_scale_process#(
    .PIX_DATA_WIDTH       ( 24 )
)u_video_scale_process_1_cmos1(
    .video_clk            ( cmos1_pclk_16bit          ),
    .rst_n                ( cmos_init_done[0]          ),
    .frame_sync_n         ( ~cmos1_vs_d1       ),
    .video_data_in        ( {cmos1_d_16bit[4:0],3'b0,cmos1_d_16bit[10:5],2'b0,cmos1_d_16bit[15:11],3'b0}        ),
    .video_data_valid     ( cmos1_href_16bit     ),
    .video_data_out       ( cmos1_scale_data       ),
    .video_data_out_valid ( cmos1_scale_de ),
    .video_ready          ( 1'b1          ),
    .video_width_in       ( 1280       ),
    .video_height_in      ( 720      ),
    .video_width_out      ( 640      ),
    .video_height_out     ( 360     )
);
//接纳第三个输入源
//vs同步
reg    cmos2_vs_d0;
reg    cmos2_vs_d1;

always@(posedge pixclk_in or negedge rstn_out)    begin
    if(!rstn_out)
    begin
        cmos2_vs_d0    <=    1'd0;
        cmos2_vs_d1    <=    1'd0;
    end
    else
    begin
        cmos2_vs_d0    <=    cmos2_vsync_d0;
        cmos2_vs_d1    <=    cmos2_vs_d0;
    end
end


wire             cmos2_scale_de;
wire  [23:0]     cmos2_scale_data;
video_scale_process#(
    .PIX_DATA_WIDTH       ( 24 )
)u_video_scale_process_2_cmos2(
    .video_clk            ( cmos2_pclk_16bit          ),
    .rst_n                ( cmos_init_done[1]          ),
    .frame_sync_n         ( ~cmos2_vs_d1       ),
    .video_data_in        ( {cmos2_d_16bit[4:0],3'b0,cmos2_d_16bit[10:5],2'b0,cmos2_d_16bit[15:11],3'b0}        ),
    .video_data_valid     ( cmos2_href_16bit     ),
    .video_data_out       ( cmos2_scale_data       ),
    .video_data_out_valid ( cmos2_scale_de ),
    .video_ready          ( 1'b1          ),
    .video_width_in       ( 1280       ),
    .video_height_in      ( 720      ),
    .video_width_out      ( 640      ),
    .video_height_out     ( 360     )
);
//接纳第四个输入源
//vs同步
reg    hdmi2_vs_d0;
reg    hdmi2_vs_d1;

always@(posedge pixclk_in or negedge rstn_out)    begin
    if(!rstn_out)
    begin
        hdmi2_vs_d0    <=    1'd0;
        hdmi2_vs_d1    <=    1'd0;
    end
    else
    begin
        hdmi2_vs_d0    <=    vs_in2; 
        hdmi2_vs_d1    <=    hdmi2_vs_d0;
    end
end


wire             hdmi2_scale_de;
wire  [23:0]     hdmi2_scale_data;
video_scale_process#(
    .PIX_DATA_WIDTH       ( 24 )
)u_video_scale_process_3_hdmi2(
    .video_clk            ( pixclk_in2          ),
    .rst_n                ( rstn_out1          ),
    .frame_sync_n         ( ~hdmi2_vs_d1       ),
    .video_data_in        ( {r_in2,g_in2,b_in2}        ), 
    .video_data_valid     ( de_in2     ),
    .video_data_out       ( hdmi2_scale_data       ),
    .video_data_out_valid ( hdmi2_scale_de ),
    .video_ready          ( 1'b1          ),
    .video_width_in       ( 1280       ),
    .video_height_in      ( 720      ),
    .video_width_out      ( 640      ),
    .video_height_out     ( 360     )
);


//通道0，HDMI，发送写DDR模块
cmos_write_req_gen cmos_write_req_gen_m0_hdmi_in(
	.rst                        (~rstn_out1                ),
	.pclk                       (pixclk_in             ),
	.cmos_vsync                 (vs_in               ),
	.write_req                  (ch0_write_req            ),
	.write_addr_index           (ch0_write_addr_index     ),
	.read_addr_index            (ch0_read_addr_index      ),
	.write_req_ack              (ch0_write_req_ack        )
);

//channel 1 发送请求
cmos_write_req_gen cmos_write_req_gen_m1_cmos1(
	.rst                        (~cmos_init_done[0]                ),
	.pclk                       (cmos1_pclk_16bit             ),
	.cmos_vsync                 (cmos1_vsync_d0               ),
	.write_req                  (ch1_write_req            ),
	.write_addr_index           (ch1_write_addr_index     ),
	.read_addr_index            (ch1_read_addr_index      ),
	.write_req_ack              (ch1_write_req_ack        )
);

//channel 2 发送请求
cmos_write_req_gen cmos_write_req_gen_m2_cmos2(
	.rst                        (~cmos_init_done[1]                ),
	.pclk                       (cmos2_pclk_16bit             ),
	.cmos_vsync                 (cmos2_vsync_d0               ),
	.write_req                  (ch2_write_req            ),
	.write_addr_index           (ch2_write_addr_index     ),
	.read_addr_index            (ch2_read_addr_index      ),
	.write_req_ack              (ch2_write_req_ack        )
);

//channel 3 发送请求
cmos_write_req_gen cmos_write_req_gen_m3_hdmi2(
	.rst                        (~rstn_out1                 ),
	.pclk                       (pixclk_in2             ),
	.cmos_vsync                 (vs_in2               ),
	.write_req                  (ch3_write_req            ),
	.write_addr_index           (ch3_write_addr_index     ),
	.read_addr_index            (ch3_read_addr_index      ),
	.write_req_ack              (ch3_write_req_ack        )
);                                 


wire    ch0_clk; //通道0的
wire    ch1_clk; //通道1的
wire    ch2_clk; //通道2的
wire    ch3_clk; //通道3的

//通道0 
assign ch0_write_data = {hdmi_1_scale_data[23:19],hdmi_1_scale_data[15:10],hdmi_1_scale_data[7:3]};
assign ch0_write_en   = hdmi_1_scale_de;
assign ch0_clk        = pixclk_in;

//通道1
assign ch1_write_data = {cmos1_scale_data[23:19],cmos1_scale_data[15:10],cmos1_scale_data[7:3]};
assign ch1_write_en   = cmos1_scale_de;
assign ch1_clk        = cmos1_pclk_16bit;

//通道2
assign ch2_write_data = {cmos2_scale_data[23:19],cmos2_scale_data[15:10],cmos2_scale_data[7:3]};
assign ch2_write_en   = cmos2_scale_de;
assign ch2_clk        = cmos2_pclk_16bit;

//通道3
assign ch3_write_data = {hdmi2_scale_data[23:19],hdmi2_scale_data[15:10],hdmi2_scale_data[7:3]};
assign ch3_write_en   = hdmi2_scale_de;
assign ch3_clk        = pixclk_in2;

//通道0向AXI发送读写请求的模块
frame_read_write
#
(
	.MEM_DATA_BITS              (256                      ),
	.READ_DATA_BITS             (16                       ),
	.WRITE_DATA_BITS            (16                       ),
	.ADDR_BITS                  (25                       ),
	.BUSRT_BITS                 (10                       ),
	.BURST_SIZE                 (16                       ) //?
)
frame_read_write_m0_hdmi_in
(
	.rst                        (~ddr_init_done           ),
	.mem_clk                    (core_clk                 ),
	.rd_burst_req               (ch0_rd_burst_req             ),
	.rd_burst_len               (ch0_rd_burst_len             ),
	.rd_burst_addr              (ch0_rd_burst_addr            ),
	.rd_burst_data_valid        (ch0_rd_burst_data_valid      ),
	.rd_burst_data              (ch0_rd_burst_data            ),
	.rd_burst_finish            (ch0_rd_burst_finish          ),
	.read_clk                   (pix_clk                  ),
	.read_req                   (ch0_read_req            ),
	.read_req_ack               (ch0_read_req_ack         ),
	.read_finish                (                         ),
	.read_addr_0                (25'd0                    ), //The first frame address is 0
	.read_addr_1                (25'd921600               ), //The second frame address is 24'd2073600 ,large enough address space for one frame of video
	.read_addr_2                (25'd1843200              ),
	.read_addr_3                (25'd2764800              ),
	.read_addr_index            (ch0_read_addr_index      ),
	.read_len                   (25'd57600                ),//frame size 
	.read_en                    (ch0_read_en              ),
	.read_data                  (ch0_read_data            ),

	.wr_burst_req               (ch0_wr_burst_req             ),
	.wr_burst_len               (ch0_wr_burst_len             ),
	.wr_burst_addr              (ch0_wr_burst_addr            ),
	.wr_burst_data_req          (ch0_wr_burst_data_req        ),
	.wr_burst_data              (ch0_wr_burst_data            ),
	.wr_burst_finish            (ch0_wr_burst_finish          ),
	.write_clk                  (ch0_clk                     ),
	.write_req                  (ch0_write_req            ),
	.write_req_ack              (ch0_write_req_ack        ),
	.write_finish               (                         ),
	.write_addr_0               (25'd0                    ),
	.write_addr_1               (25'd921600               ),
	.write_addr_2               (25'd1843200              ),
	.write_addr_3               (25'd2764800              ),
	.write_addr_index           (ch0_write_addr_index     ),
	.write_len                  (25'd57600                ), //frame size  
	.write_en                   (ch0_write_en             ),
	.write_data                 (ch0_write_data           )
);

//channel 1向DDR3发请求的模块
frame_read_write
#
(
	.MEM_DATA_BITS              (256                      ),
	.READ_DATA_BITS             (16                       ),
	.WRITE_DATA_BITS            (16                       ),
	.ADDR_BITS                  (25                       ),
	.BUSRT_BITS                 (10                       ),
	.BURST_SIZE                 (16                       ) //?
)
frame_read_write_m1_cmos1
(
	.rst                        (~ddr_init_done           ),
	.mem_clk                    (core_clk                 ),
	.rd_burst_req               (ch1_rd_burst_req             ),
	.rd_burst_len               (ch1_rd_burst_len             ),
	.rd_burst_addr              (ch1_rd_burst_addr            ),
	.rd_burst_data_valid        (ch1_rd_burst_data_valid      ),
	.rd_burst_data              (ch1_rd_burst_data            ),
	.rd_burst_finish            (ch1_rd_burst_finish          ),
	.read_clk                   (pix_clk                  ),
	.read_req                   (ch1_read_req            ),
	.read_req_ack               (ch1_read_req_ack         ),
	.read_finish                (                         ),
	.read_addr_0                (25'd3686400              ), //The first frame address is 0
	.read_addr_1                (25'd4608000              ), //The second frame address is 24'd2073600 ,large enough address space for one frame of video
	.read_addr_2                (25'd5529600              ),
	.read_addr_3                (25'd6451200              ),
	.read_addr_index            (ch1_read_addr_index      ),
	.read_len                   (25'd57600                ),//frame size 
	.read_en                    (ch1_read_en              ),
	.read_data                  (ch1_read_data            ),

	.wr_burst_req               (ch1_wr_burst_req             ),
	.wr_burst_len               (ch1_wr_burst_len             ),
	.wr_burst_addr              (ch1_wr_burst_addr            ),
	.wr_burst_data_req          (ch1_wr_burst_data_req        ),
	.wr_burst_data              (ch1_wr_burst_data            ),
	.wr_burst_finish            (ch1_wr_burst_finish          ),
	.write_clk                  (ch1_clk                     ),
	.write_req                  (ch1_write_req            ),
	.write_req_ack              (ch1_write_req_ack        ),
	.write_finish               (                         ),
	.write_addr_0               (25'd3686400              ),
	.write_addr_1               (25'd4608000              ),
	.write_addr_2               (25'd5529600              ),
	.write_addr_3               (25'd6451200              ),
	.write_addr_index           (ch1_write_addr_index     ),
	.write_len                  (25'd57600                ), //frame size  
	.write_en                   (ch1_write_en             ),
	.write_data                 (ch1_write_data           )
);

//channel 2向DDR3发请求的模块
frame_read_write
#
(
	.MEM_DATA_BITS              (256                      ),
	.READ_DATA_BITS             (16                       ),
	.WRITE_DATA_BITS            (16                       ),
	.ADDR_BITS                  (25                       ),
	.BUSRT_BITS                 (10                       ),
	.BURST_SIZE                 (16                       ) //?
)
frame_read_write_m2_cmos2
(
	.rst                        (~ddr_init_done           ),
	.mem_clk                    (core_clk                 ),
	.rd_burst_req               (ch2_rd_burst_req             ),
	.rd_burst_len               (ch2_rd_burst_len             ),
	.rd_burst_addr              (ch2_rd_burst_addr            ),
	.rd_burst_data_valid        (ch2_rd_burst_data_valid      ),
	.rd_burst_data              (ch2_rd_burst_data            ),
	.rd_burst_finish            (ch2_rd_burst_finish          ),
	.read_clk                   (pix_clk                  ),
	.read_req                   (ch2_read_req            ),
	.read_req_ack               (ch2_read_req_ack         ),
	.read_finish                (                         ),
	.read_addr_0                (25'd7372800              ), //The first frame address is 0
	.read_addr_1                (25'd8294400              ), //The second frame address is 24'd2073600 ,large enough address space for one frame of video
	.read_addr_2                (25'd9216000              ),
	.read_addr_3                (25'd10137600             ),
	.read_addr_index            (ch2_read_addr_index      ),
	.read_len                   (25'd57600                ),//frame size 
	.read_en                    (ch2_read_en              ),
	.read_data                  (ch2_read_data            ),

	.wr_burst_req               (ch2_wr_burst_req             ),
	.wr_burst_len               (ch2_wr_burst_len             ),
	.wr_burst_addr              (ch2_wr_burst_addr            ),
	.wr_burst_data_req          (ch2_wr_burst_data_req        ),
	.wr_burst_data              (ch2_wr_burst_data            ),
	.wr_burst_finish            (ch2_wr_burst_finish          ),
	.write_clk                  (ch2_clk                     ),
	.write_req                  (ch2_write_req            ),
	.write_req_ack              (ch2_write_req_ack        ),
	.write_finish               (                         ),
	.write_addr_0               (25'd7372800              ),
	.write_addr_1               (25'd8294400              ),
	.write_addr_2               (25'd9216000              ),
	.write_addr_3               (25'd10137600             ),
	.write_addr_index           (ch2_write_addr_index     ),
	.write_len                  (25'd57600                ), //frame size  
	.write_en                   (ch2_write_en             ),
	.write_data                 (ch2_write_data           )
);

//channel 3向DDR3发请求的模块
frame_read_write
#
(
	.MEM_DATA_BITS              (256                      ),
	.READ_DATA_BITS             (16                       ),
	.WRITE_DATA_BITS            (16                       ),
	.ADDR_BITS                  (25                       ),
	.BUSRT_BITS                 (10                       ),
	.BURST_SIZE                 (16                       ) //?
)
frame_read_write_m3_hdmi2
(
	.rst                        (~ddr_init_done           ),
	.mem_clk                    (core_clk                 ),
	.rd_burst_req               (ch3_rd_burst_req             ),
	.rd_burst_len               (ch3_rd_burst_len             ),
	.rd_burst_addr              (ch3_rd_burst_addr            ),
	.rd_burst_data_valid        (ch3_rd_burst_data_valid      ),
	.rd_burst_data              (ch3_rd_burst_data            ),
	.rd_burst_finish            (ch3_rd_burst_finish          ),
	.read_clk                   (pix_clk                  ),
	.read_req                   (ch3_read_req            ),
	.read_req_ack               (ch3_read_req_ack         ),
	.read_finish                (                         ),
	.read_addr_0                (25'd11059200             ), //The first frame address is 0
	.read_addr_1                (25'd11980800             ), //The second frame address is 24'd2073600 ,large enough address space for one frame of video
	.read_addr_2                (25'd12902400             ),
	.read_addr_3                (25'd13824000             ),
	.read_addr_index            (ch3_read_addr_index      ),
	.read_len                   (25'd57600                ),//frame size 
	.read_en                    (ch3_read_en              ),
	.read_data                  (ch3_read_data            ),

	.wr_burst_req               (ch3_wr_burst_req             ),
	.wr_burst_len               (ch3_wr_burst_len             ),
	.wr_burst_addr              (ch3_wr_burst_addr            ),
	.wr_burst_data_req          (ch3_wr_burst_data_req        ),
	.wr_burst_data              (ch3_wr_burst_data            ),
	.wr_burst_finish            (ch3_wr_burst_finish          ),
	.write_clk                  (ch3_clk                     ),
	.write_req                  (ch3_write_req            ),
	.write_req_ack              (ch3_write_req_ack        ),
	.write_finish               (                         ),
	.write_addr_0               (25'd11059200             ),
	.write_addr_1               (25'd11980800             ),
	.write_addr_2               (25'd12902400             ),
	.write_addr_3               (25'd13824000             ),
	.write_addr_index           (ch3_write_addr_index     ),
	.write_len                  (25'd57600                ), //frame size  
	.write_en                   (ch3_write_en             ),
	.write_data                 (ch3_write_data           )
);


/************************************************************
视频输出选择通道
************************************************************/
always@(posedge pix_clk) begin

    r_out<={v3_data[15:11],3'b0   };
    g_out<={v3_data[10:5],2'b0    };
    b_out<={v3_data[4:0],3'b0     }; 
    vs_out<=v3_vs;
    hs_out<=v3_hs;
    de_out<=v3_de;
end


//下面的模块是发送读请求的模块
wire    [11:0]    x_act;
wire    [11:0]    y_act;

sync_vg sync_vg
(                            
    .clk            (  pix_clk              ),//input       a'a'da            clk,                                 
    .rstn           (  rstn_out            ),//input                   rstn,                            
    .vs_out         (  vs_o                 ),//output reg              vs_out,                                                                                                                                      
    .hs_out         (  hs_o                 ),//output reg              hs_out,            
    .de_out         (                       ),//output reg              de_out, 
    .x_act        	(x_act					),
    .y_act        	(y_act					),
    .de_re          (  de_re                )    
); 




//产生色彩叠加
wire [7:0]    color_bar_r;
wire [7:0]    color_bar_g;
wire [7:0]    color_bar_b;
wire [15:0]   v0_data      ;
wire          v0_hs        ;
wire          v0_vs        ;
wire          v0_de        ;
wire [15:0]   v1_data      ;
wire          v1_hs        ;
wire          v1_vs        ;
wire          v1_de        ;
wire [15:0]   v2_data      ;
wire          v2_vs;
wire          v2_hs;
wire          v2_de;
wire [15:0]   v3_data      ;
wire          v3_vs;
wire          v3_hs;
wire          v3_de;
color_bar color_bar_m0(
	.clk                        (pix_clk                ),
	.rst                        (~rstn_out               ),
	.hs                         (color_bar_hs             ),
	.vs                         (color_bar_vs             ),
	.de                         (color_bar_de             ),
	.rgb_r                      (color_bar_r              ),
	.rgb_g                      (color_bar_g              ),
	.rgb_b                      (color_bar_b              )
);
//读写偏移请求
//generate a frame read data request
video_rect_read_data video_rect_read_data_m0_hdmi_in
(
	.video_clk                  (pix_clk                ),
	.rst                        (~rstn_out1               ),
	.video_left_offset          (12'd0                    ),
	.video_top_offset           (12'd0                    ),
	.video_width                (12'd640                 ),
	.video_height	            (12'd360                  ),
	.read_req                   (ch0_read_req             ),
	.read_req_ack               (ch0_read_req_ack         ),
	.read_en                    (ch0_read_en              ),
	.read_data                  (ch0_read_data            ),
	.timing_hs                  (color_bar_hs             ),
	.timing_vs                  (color_bar_vs             ),
	.timing_de                  (color_bar_de             ),
	.timing_data 	            (),
	.hs                         (v0_hs                    ),
	.vs                         (v0_vs                    ),
	.de                         (v0_de                    ),
	.vout_data                  (v0_data                  )
);
      
video_rect_read_data video_rect_read_data_m1_cmos1
(
	.video_clk                  (pix_clk                ),
	.rst                        (~rstn_out1               ),
	.video_left_offset          (12'd640                    ),
	.video_top_offset           (12'd0                    ),
	.video_width                (12'd640                 ),
	.video_height	            (12'd360                  ),
	.read_req                   (ch1_read_req             ),
	.read_req_ack               (ch1_read_req_ack         ),
	.read_en                    (ch1_read_en              ),
	.read_data                  (ch1_read_data            ),
	.timing_hs                  (v0_hs             ),
	.timing_vs                  (v0_vs             ),
	.timing_de                  (v0_de             ),
	.timing_data 	            (v0_data),
	.hs                         (v1_hs                    ),
	.vs                         (v1_vs                    ),
	.de                         (v1_de                    ),
	.vout_data                  (v1_data                  )
);

video_rect_read_data video_rect_read_data_m2_cmos2
(
	.video_clk                  (pix_clk                ),
	.rst                        (~rstn_out1               ),
	.video_left_offset          (12'd0                    ),
	.video_top_offset           (12'd360                    ),
	.video_width                (12'd640                 ),
	.video_height	            (12'd360                  ),
	.read_req                   (ch2_read_req             ),
	.read_req_ack               (ch2_read_req_ack         ),
	.read_en                    (ch2_read_en              ),
	.read_data                  (ch2_read_data            ),
	.timing_hs                  (v1_hs             ),
	.timing_vs                  (v1_vs             ),
	.timing_de                  (v1_de             ),
	.timing_data 	            (v1_data),
	.hs                         (v2_hs                    ),
	.vs                         (v2_vs                    ),
	.de                         (v2_de                    ),
	.vout_data                  (v2_data                  )
);

video_rect_read_data video_rect_read_data_m3_sfpin
(
	.video_clk                  (pix_clk                ),
	.rst                        (~rstn_out1               ),
	.video_left_offset          (12'd640                    ),
	.video_top_offset           (12'd360                    ),
	.video_width                (12'd640                 ),
	.video_height	            (12'd360                  ),
	.read_req                   (ch3_read_req             ),
	.read_req_ack               (ch3_read_req_ack         ),
	.read_en                    (ch3_read_en              ),
	.read_data                  (ch3_read_data            ),
	.timing_hs                  (v2_hs             ),
	.timing_vs                  (v2_vs             ),
	.timing_de                  (v2_de             ),
	.timing_data 	            (v2_data),
	.hs                         (v3_hs                    ),
	.vs                         (v3_vs                    ),
	.de                         (v3_de                    ),
	.vout_data                  (v3_data                  )
);


////////////////////////////////////////////////////////////////////////////////////////////
//ddr    
DDR3_50H u_DDR3_50H (
       .ref_clk                   (sys_clk            ),
       .resetn                    (rstn_out           ),// input
       .ddr_init_done             (ddr_init_done      ),// output
       .ddrphy_clkin              (core_clk           ),// output
       .pll_lock                  (pll_lock           ),// output
       //写地址通道
       .axi_awaddr                (s00_axi_awaddr         ),// input [27:0]
       .axi_awuser_ap             (1'b0               ),// input
       .axi_awuser_id             (s00_axi_awid      ),// input [3:0]
       .axi_awlen                 (s00_axi_awlen          ),// input [3:0]
       .axi_awready               (s00_axi_awready        ),// output
       .axi_awvalid               (s00_axi_awvalid        ),// input
       //写通道
       .axi_wdata                 (s00_axi_wdata          ),
       .axi_wstrb                 (s00_axi_wstrb          ),// input [31:0]
       .axi_wready                (s00_axi_wready         ),// output
       .axi_wusero_id             (                   ),// output [3:0]
       .axi_wusero_last           (axi_wusero_last    ),// output
       //读地址通道
       .axi_araddr                (s00_axi_araddr         ),// input [27:0]
       .axi_aruser_ap             (1'b0               ),// input
       .axi_aruser_id             (s00_axi_arid      ),// input [3:0]
       .axi_arlen                 (s00_axi_arlen          ),// input [3:0]
       .axi_arready               (s00_axi_arready        ),// output
       .axi_arvalid               (s00_axi_arvalid        ),// input
       //读通道
       .axi_rdata                 (s00_axi_rdata          ),// output [255:0]
       .axi_rid                   (s00_axi_rid            ),// output [3:0]
       .axi_rlast                 (s00_axi_rlast          ),// output
       .axi_rvalid                (s00_axi_rvalid         ),// output
       
       .apb_clk                   (1'b0               ),// input
       .apb_rst_n                 (1'b1               ),// input
       .apb_sel                   (1'b0               ),// input
       .apb_enable                (1'b0               ),// input
       .apb_addr                  (8'b0               ),// input [7:0]
       .apb_write                 (1'b0               ),// input
       .apb_ready                 (                   ), // output
       .apb_wdata                 (16'b0              ),// input [15:0]
       .apb_rdata                 (                   ),// output [15:0]
       .apb_int                   (                   ),// output
       
       .mem_rst_n                 (mem_rst_n          ),// output
       .mem_ck                    (mem_ck             ),// output
       .mem_ck_n                  (mem_ck_n           ),// output
       .mem_cke                   (mem_cke            ),// output
       .mem_cs_n                  (mem_cs_n           ),// output
       .mem_ras_n                 (mem_ras_n          ),// output
       .mem_cas_n                 (mem_cas_n          ),// output
       .mem_we_n                  (mem_we_n           ),// output
       .mem_odt                   (mem_odt            ),// output
       .mem_a                     (mem_a              ),// output [14:0]
       .mem_ba                    (mem_ba             ),// output [2:0]
       .mem_dqs                   (mem_dqs            ),// inout [3:0]
       .mem_dqs_n                 (mem_dqs_n          ),// inout [3:0]
       .mem_dq                    (mem_dq             ),// inout [31:0]
       .mem_dm                    (mem_dm             ),// output [3:0]
       //debug
       .debug_data                (                   ),// output [135:0]
       .debug_slice_state         (                   ),// output [51:0]
       .debug_calib_ctrl          (                   ),// output [21:0]
       .ck_dly_set_bin            (                   ),// output [7:0]
       .force_ck_dly_en           (1'b0               ),// input
       .force_ck_dly_set_bin      (8'h05              ),// input [7:0]
       .dll_step                  (                   ),// output [7:0]
       .dll_lock                  (                   ),// output
       .init_read_clk_ctrl        (2'b0               ),// input [1:0]
       .init_slip_step            (4'b0               ),// input [3:0]
       .force_read_clk_ctrl       (1'b0               ),// input
       .ddrphy_gate_update_en     (1'b0               ),// input
       .update_com_val_err_flag   (                   ),// output [3:0]
       .rd_fake_stop              (1'b0               ) // input
);



//AXI模块
assign s00_axi_bvalid =1'b1; 
aq_axi_master_256	u_aq_axi_master
(
	  .ARESETN                     (ddr_init_done                             ),
	  .ACLK                        (core_clk                                  ),
	  .M_AXI_AWID                  (s00_axi_awid                              ),
	  .M_AXI_AWADDR                (s00_axi_awaddr                            ),
	  .M_AXI_AWLEN                 (s00_axi_awlen                             ),
	  .M_AXI_AWSIZE                (s00_axi_awsize                            ),
	  .M_AXI_AWBURST               (s00_axi_awburst                           ),
	  .M_AXI_AWLOCK                (s00_axi_awlock                            ),
	  .M_AXI_AWCACHE               (s00_axi_awcache                           ),
	  .M_AXI_AWPROT                (s00_axi_awprot                            ),
	  .M_AXI_AWQOS                 (s00_axi_awqos                             ),
	  .M_AXI_AWUSER                (s00_axi_awuser                            ),
	  .M_AXI_AWVALID               (s00_axi_awvalid                           ),
	  .M_AXI_AWREADY               (s00_axi_awready                           ),
	  .M_AXI_WDATA                 (s00_axi_wdata                             ),
	  .M_AXI_WSTRB                 (s00_axi_wstrb                             ),
	  .M_AXI_WLAST                 (s00_axi_wlast                             ),
	  .M_AXI_WUSER                 (s00_axi_wuser                             ),
	  .M_AXI_WVALID                (s00_axi_wvalid                            ),
	  .M_AXI_WREADY                (s00_axi_wready                            ),
	  .M_AXI_BID                   (s00_axi_bid                               ),
	  .M_AXI_BRESP                 (s00_axi_bresp                             ),
	  .M_AXI_BUSER                 (s00_axi_buser                             ),
      .M_AXI_BVALID                (s00_axi_bvalid                            ),

	  .M_AXI_BREADY                (s00_axi_bready                            ),
	  .M_AXI_ARID                  (s00_axi_arid                              ),
	  .M_AXI_ARADDR                (s00_axi_araddr                            ),
	  .M_AXI_ARLEN                 (s00_axi_arlen                             ),
	  .M_AXI_ARSIZE                (s00_axi_arsize                            ),
	  .M_AXI_ARBURST               (s00_axi_arburst                           ),
	  .M_AXI_ARLOCK                (s00_axi_arlock                            ),
	  .M_AXI_ARCACHE               (s00_axi_arcache                           ),
	  .M_AXI_ARPROT                (s00_axi_arprot                            ),
	  .M_AXI_ARQOS                 (s00_axi_arqos                             ),
	  .M_AXI_ARUSER                (s00_axi_aruser                            ),
	  .M_AXI_ARVALID               (s00_axi_arvalid                           ),
	  .M_AXI_ARREADY               (s00_axi_arready                           ),
	  .M_AXI_RID                   (s00_axi_rid                               ),
	  .M_AXI_RDATA                 (s00_axi_rdata                             ),
	  .M_AXI_RRESP                 (s00_axi_rresp                             ),
	  .M_AXI_RLAST                 (s00_axi_rlast                             ),
	  .M_AXI_RUSER                 (s00_axi_ruser                             ),
	  .M_AXI_RVALID                (s00_axi_rvalid                            ),
	  .M_AXI_RREADY                (s00_axi_rready                            ),
	  .MASTER_RST                  (1'b0                                      ),
	  .WR_START                    (wr_burst_req                              ),
	  .WR_ADRS                     ({wr_burst_addr,5'd0}                      ),
	  .WR_LEN                      ({wr_burst_len, 5'd0}                      ),
	  .WR_READY                    (                                          ),
	  .WR_FIFO_RE                  (wr_burst_data_req                         ),
	  .WR_FIFO_EMPTY               (1'b0                                      ),
	  .WR_FIFO_AEMPTY              (1'b0                                      ),
	  .WR_FIFO_DATA                (wr_burst_data                             ),
	  .WR_DONE                     (wr_burst_finish                           ),
	  .RD_START                    (rd_burst_req                              ),
	  .RD_ADRS                     ({rd_burst_addr,5'd0}                      ),
	  .RD_LEN                      ({rd_burst_len, 5'd0}                       ),
	  .RD_READY                    (                                          ),
	  .RD_FIFO_WE                  (rd_burst_data_valid                       ),
	  .RD_FIFO_FULL                (1'b0                                      ),
	  .RD_FIFO_AFULL               (1'b0                                      ),
	  .RD_FIFO_DATA                (rd_burst_data                             ),
	  .RD_DONE                     (rd_burst_finish                           ),
	  .DEBUG                       (                                          )
);



//读写仲裁模块
//读仲裁
mem_read_arbi 
#(
	.MEM_DATA_BITS               (MEM_DATA_BITS),
	.ADDR_BITS                   (ADDR_BITS    ),
	.BUSRT_BITS                  (BUSRT_BITS   )
)
mem_read_arbi_m0
(
	.rst_n                        (ddr_init_done),
	.mem_clk                      (core_clk),
	.ch0_rd_burst_req             (ch0_rd_burst_req),
	.ch0_rd_burst_len             (ch0_rd_burst_len),
	.ch0_rd_burst_addr            (ch0_rd_burst_addr),
	.ch0_rd_burst_data_valid      (ch0_rd_burst_data_valid),
	.ch0_rd_burst_data            (ch0_rd_burst_data),
	.ch0_rd_burst_finish          (ch0_rd_burst_finish),
	
 	.ch1_rd_burst_req             (ch1_rd_burst_req),
 	.ch1_rd_burst_len             (ch1_rd_burst_len),
 	.ch1_rd_burst_addr            (ch1_rd_burst_addr),
 	.ch1_rd_burst_data_valid      (ch1_rd_burst_data_valid),
 	.ch1_rd_burst_data            (ch1_rd_burst_data),
 	.ch1_rd_burst_finish          (ch1_rd_burst_finish),

    .ch2_rd_burst_req             (ch2_rd_burst_req),
 	.ch2_rd_burst_len             (ch2_rd_burst_len),
 	.ch2_rd_burst_addr            (ch2_rd_burst_addr),
 	.ch2_rd_burst_data_valid      (ch2_rd_burst_data_valid),
 	.ch2_rd_burst_data            (ch2_rd_burst_data),
 	.ch2_rd_burst_finish          (ch2_rd_burst_finish),

    .ch3_rd_burst_req             (ch3_rd_burst_req),
 	.ch3_rd_burst_len             (ch3_rd_burst_len),
 	.ch3_rd_burst_addr            (ch3_rd_burst_addr),
 	.ch3_rd_burst_data_valid      (ch3_rd_burst_data_valid),
 	.ch3_rd_burst_data            (ch3_rd_burst_data),
 	.ch3_rd_burst_finish          (ch3_rd_burst_finish),

	.rd_burst_req                 (rd_burst_req),
	.rd_burst_len                 (rd_burst_len),
	.rd_burst_addr                (rd_burst_addr),
	.rd_burst_data_valid          (rd_burst_data_valid),
	.rd_burst_data                (rd_burst_data),
	.rd_burst_finish              (rd_burst_finish)	
);
//写仲裁
mem_write_arbi
#(
	.MEM_DATA_BITS               (MEM_DATA_BITS),
	.ADDR_BITS                   (ADDR_BITS    ),
	.BUSRT_BITS                  (BUSRT_BITS   )
)
mem_write_arbi_m0(
	.rst_n                       (ddr_init_done),
	.mem_clk                     (core_clk),
	
	.ch0_wr_burst_req            (ch0_wr_burst_req),
	.ch0_wr_burst_len            (ch0_wr_burst_len),
	.ch0_wr_burst_addr           (ch0_wr_burst_addr),
	.ch0_wr_burst_data_req       (ch0_wr_burst_data_req),
	.ch0_wr_burst_data           (ch0_wr_burst_data),
	.ch0_wr_burst_finish         (ch0_wr_burst_finish),
	
	.ch1_wr_burst_req            (ch1_wr_burst_req),
	.ch1_wr_burst_len            (ch1_wr_burst_len),
	.ch1_wr_burst_addr           (ch1_wr_burst_addr),
	.ch1_wr_burst_data_req       (ch1_wr_burst_data_req),
	.ch1_wr_burst_data           (ch1_wr_burst_data),
	.ch1_wr_burst_finish         (ch1_wr_burst_finish),

	.ch2_wr_burst_req            (ch2_wr_burst_req),
	.ch2_wr_burst_len            (ch2_wr_burst_len),
	.ch2_wr_burst_addr           (ch2_wr_burst_addr),
	.ch2_wr_burst_data_req       (ch2_wr_burst_data_req),
	.ch2_wr_burst_data           (ch2_wr_burst_data),
	.ch2_wr_burst_finish         (ch2_wr_burst_finish),

	.ch3_wr_burst_req            (ch3_wr_burst_req),
	.ch3_wr_burst_len            (ch3_wr_burst_len),
	.ch3_wr_burst_addr           (ch3_wr_burst_addr),
	.ch3_wr_burst_data_req       (ch3_wr_burst_data_req),
	.ch3_wr_burst_data           (ch3_wr_burst_data),
	.ch3_wr_burst_finish         (ch3_wr_burst_finish),
	

	.wr_burst_req(wr_burst_req),
	.wr_burst_len(wr_burst_len),
	.wr_burst_addr(wr_burst_addr),
	.wr_burst_data_req(wr_burst_data_req),
	.wr_burst_data(wr_burst_data),
	.wr_burst_finish(wr_burst_finish)	
);

reg [26:0] cnt;

//心跳信号
     always@(posedge core_clk) begin
        if (!ddr_init_done)
            cnt <= 27'd0;
        else if ( cnt >= TH_1S )
            cnt <= 27'd0;
        else
            cnt <= cnt + 27'd1;
     end

     always @(posedge core_clk)
        begin
        if (!ddr_init_done)
            heart_beat_led <= 1'd1;
        else if ( cnt >= TH_1S )
            heart_beat_led <= ~heart_beat_led;
    end
                 
/************************************************************
HSST数据处理 将4路拼接好的数据进行打包sfp输出
************************************************************/
wire       sfp_out_vs;
wire       sfp_out_hs;
wire       sfp_out_de;
wire [4:0] sfp_out_r;
wire [5:0] sfp_out_g;
wire [4:0] sfp_out_b;
assign sfp_out_r  = v3_data[15:11];
assign sfp_out_g  = v3_data[10: 5];
assign sfp_out_b  = v3_data[ 4: 0];
assign sfp_out_vs = v3_vs;
assign sfp_out_hs = v3_hs;
assign sfp_out_de = v3_de;

always@(posedge tx_clk)
begin
    gt_tx_data  <= gt_tx_data0;
    gt_tx_ctrl  <= gt_tx_ctrl0;           
end

//HSST 数据打包
video_packet_send video_packet_send_m0
(
	.rst                        (~rstn_out                   ),
	.tx_clk                     (tx_clk                      ),
	
	.pclk                       (pix_clk                    ),
	.vs                         (sfp_out_vs                 ),
	.de                         (sfp_out_de                 ),
	.vin_data                   ({sfp_out_r,sfp_out_g,sfp_out_b}),
	.vin_width                  (16'd1280                     ),
	
	.gt_tx_data                 (gt_tx_data0                 ),
	.gt_tx_ctrl                 (gt_tx_ctrl0                 )
);

/************************************************************
hsst模块例化
************************************************************/
//sfp2发送，sfp3接收
hsst_core u_hsst_core (
  .i_free_clk          (sys_clk),               // input
  .i_pll_rst_0         (~rstn_out),            // input
  .i_wtchdg_clr_0      (i_wtchdg_clr_0),        // input
  .o_wtchdg_st_0       (o_wtchdg_st_0),         // output [1:0]
  .o_txlane_done_2     (o_txlane_done_2),       // output
  .o_rxlane_done_3     (o_rxlane_done_3),       // output
  .i_p_refckn_0        (i_p_refckn_0),          // input
  .i_p_refckp_0        (i_p_refckp_0),          // input
  .o_p_clk2core_tx_2   (tx2_clk),         		// output
  .i_p_tx2_clk_fr_core (tx2_clk),      			// input
  .i_p_tx3_clk_fr_core (tx2_clk),      			// input
  .o_p_clk2core_rx_2   (rx3_clk),          		// output
  .i_p_rx2_clk_fr_core (rx3_clk),      			// input
  .i_p_rx3_clk_fr_core (rx3_clk),      			// input
  .i_p_l2rxn           (i_p_l2rxn),        // input
  .i_p_l2rxp           (i_p_l2rxp),        // input
  .i_p_l3rxn           (i_p_l3rxn),        // input
  .i_p_l3rxp           (i_p_l3rxp),        // input
  .o_p_l2txn           (o_p_l2txn),        // output
  .o_p_l2txp           (o_p_l2txp),        // output
  .o_p_l3txn           (o_p_l3txn),        // output
  .o_p_l3txp           (o_p_l3txp),        // output

  .i_txd_2             (tx2_data),         // input [31:0]
  .i_tdispsel_2        (4'b0),             // input [3:0]
  .i_tdispctrl_2       (4'b0),             // input [3:0]
  .i_txk_2             (tx2_kchar),        // input [3:0]

  .i_txd_3             (tx3_data),         // input [31:0]
  .i_tdispsel_3        (4'b0),             // input [3:0]
  .i_tdispctrl_3       (4'b0),             // input [3:0]
  .i_txk_3             (tx3_kchar),        // input [3:0]

  .o_rxd_2             (rx2_data),         // output [31:0]
  .o_rxk_2             (rx2_kchar),        // output [3:0]

  .o_rxd_3             (rx3_data),         // output [31:0]
  .o_rxk_3             (rx3_kchar)         // output [3:0]
);
endmodule

//FPGA鎴戝彧鐢ㄥ皬鐪肩潧闃熶竴浣撴澘FPGA宸ョ▼
`timescale 1ns / 1ps
//===============================================================================
// 妯″潡澹版槑锛氶《灞侳PGA宸ョ▼妯″潡
//===============================================================================
module dl_fpga_prj #(
   //===========================================================================
   // DDR3鍐呭瓨鍙傛暟閰嶇疆
   //===========================================================================
   parameter MEM_ROW_WIDTH        = 15         ,    // DDR3琛屽湴鍧€瀹藉害锛?5bit = 32K琛岋級
   parameter MEM_COLUMN_WIDTH     = 10         ,    // DDR3鍒楀湴鍧€瀹藉害锛?0bit = 1K鍒楋級
   parameter MEM_BANK_WIDTH       = 3          ,    // DDR3 Bank鍦板潃瀹藉害锛?bit = 8涓狟ank锛?   parameter MEM_DQ_WIDTH          = 16         ,    // DDR3鏁版嵁浣嶅锛?6bit鏁版嵁鎬荤嚎锛?   parameter MEM_DQS_WIDTH         = 2              // DDR3 DQS淇″彿鏁伴噺锛?涓紝瀵瑰簲8bit瀛楄妭浣胯兘锛?
)(
    //===========================================================================
    // 绯荤粺鏃堕挓鍜屽浣嶄俊鍙?    //===========================================================================
    input                                sys_clk                      ,    // 绯荤粺鍙傝€冩椂閽燂紙40MHz锛夛紝鐢ㄤ簬PLL杈撳叆
    input                                sys_rst_n                    ,    // 绯荤粺澶嶄綅淇″彿锛堜綆鏈夋晥锛夛紝鏉ヨ嚜鏉跨骇澶嶄綅婧?
    //=====================.======================================================
    // DDR3鐗╃悊鎺ュ彛淇″彿锛堢洿鎺ヨ繛鎺ュ埌DDR3棰楃矑锛?    //===========================================================================
    output                               ddr3_cs_n                    ,    // 鐗囬€変俊鍙凤紙浣庢湁鏁堬級
    output                               ddr3_rst_n                   ,    // DDR3澶嶄綅淇″彿锛堜綆鏈夋晥锛?    output                               ddr3_ck                      ,    // DDR3鏃堕挓淇″彿锛堝樊鍒嗘锛?    output                               ddr3_ck_n                    ,    // DDR3鏃堕挓淇″彿锛堝樊鍒嗚礋锛?    output                               ddr3_cke                     ,    // 鏃堕挓浣胯兘淇″彿锛堥珮鏈夋晥锛?    output                               ddr3_ras_n                   ,    // 琛屽湴鍧€閫夐€氾紙浣庢湁鏁堬級
    output                               ddr3_cas_n                   ,    // 鍒楀湴鍧€閫夐€氾紙浣庢湁鏁堬級
    output                               ddr3_we_n                    ,    // 鍐欎娇鑳戒俊鍙凤紙浣庢湁鏁堬級
    output                               ddr3_odt                     ,    // 鐗囦笂缁堢鐢甸樆鎺у埗
    output      [MEM_ROW_WIDTH-1:0]      ddr3_a                       ,    // 鍦板潃鎬荤嚎锛堣/鍒楀湴鍧€澶嶇敤锛?    output      [MEM_BANK_WIDTH-1:0]     ddr3_ba                      ,    // Bank鍦板潃鎬荤嚎
    inout       [MEM_DQ_WIDTH/8-1:0]     ddr3_dqs                     ,    // 鏁版嵁閫夐€氫俊鍙凤紙宸垎姝ｏ紝杈撳叆杈撳嚭锛?    inout       [MEM_DQ_WIDTH/8-1:0]     ddr3_dqs_n                   ,    // 鏁版嵁閫夐€氫俊鍙凤紙宸垎璐燂紝杈撳叆杈撳嚭锛?    inout       [MEM_DQ_WIDTH-1:0]       ddr3_dq                      ,    // 鏁版嵁鎬荤嚎锛?6bit锛岃緭鍏ヨ緭鍑猴級
    output      [MEM_DQ_WIDTH/8-1:0]     ddr3_dm                      ,    // 鏁版嵁鎺╃爜淇″彿锛堝啓浣胯兘鎺у埗锛?

    //===========================================================================
    // HSST鍏夌氦淇″彿
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
    // PCIe鐗╃悊鎺ュ彛淇″彿锛堝樊鍒嗕俊鍙凤紝2涓狶ane锛?    //===========================================================================
    input					             pcie_refclk_p                ,    // PCIe鍙傝€冩椂閽燂紙宸垎姝ｏ紝100MHz锛?	input					             pcie_refclk_n                ,    // PCIe鍙傝€冩椂閽燂紙宸垎璐燂級
	input					             pcie_perst_n                 ,    // PCIe澶嶄綅淇″彿锛堜綆鏈夋晥锛屾潵鑷狿CIe鎻掓Ы锛?	input		[1:0]		             pcie_rxn                     ,    // PCIe鎺ユ敹鏁版嵁锛堝樊鍒嗚礋锛孡ane[1:0]锛?	input		[1:0]		             pcie_rxp                     ,    // PCIe鎺ユ敹鏁版嵁锛堝樊鍒嗘锛孡ane[1:0]锛?	output wire	[1:0]		             pcie_txn                      ,    // PCIe鍙戦€佹暟鎹紙宸垎璐燂紝Lane[1:0]锛?	output wire	[1:0]		             pcie_txp                          // PCIe鍙戦€佹暟鎹紙宸垎姝ｏ紝Lane[1:0]锛?   
);

//tx_disable鎺ユ敹锛屾媺楂?assign tx_disable = 1'b1;

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
// 鍐呴儴鍙傛暟瀹氫箟
//===============================================================================
parameter CTRL_ADDR_WIDTH = MEM_ROW_WIDTH + MEM_BANK_WIDTH + MEM_COLUMN_WIDTH;  // 鎺у埗鍣ㄥ湴鍧€鎬诲搴︼紙28bit锛?parameter TH_1S = 27'd33000000;                                                  // 1绉掕鏁板€硷紙33MHz鏃堕挓涓嬶級
parameter REM_DQS_WIDTH = 9 - MEM_DQS_WIDTH;                                    // 鍓╀綑DQS瀹藉害锛堢敤浜庤绠楋級


                                  //===============================================================================
                                  // LED鎸囩ず
                                  //===============================================================================
reg heart_beat_led             ;  // 蹇冭烦LED
reg pclk_led                   ;  // PCIe鏃堕挓LED
reg ref_led                    ;  // 鍙傝€冩椂閽烲ED

//===============================================================================
// DDR3鎺у埗鐩稿叧淇″彿
//===============================================================================
wire                        ddrphy_cpd_lock            ;    // DDR PHY鏍″噯閿佸畾淇″彿锛堢浉浣嶆牎鍑嗗畬鎴愶級
wire                        ddr_init_done              ;    // DDR鍒濆鍖栧畬鎴愭爣蹇楋紙楂樻湁鏁堬紝琛ㄧずDDR鍙敤锛?wire                        pll_lock                   ;    // DDR PLL閿佸畾淇″彿锛堟椂閽熺ǔ瀹氾級
wire                        core_clk                   ;    // DDR鏍稿績宸ヤ綔鏃堕挓锛堟潵鑷狣DR鎺у埗鍣級

//===============================================================================
// AXI4鍐欓€氶亾淇″彿锛堢敤浜庡悜DDR鍐欏叆鏁版嵁锛?//===============================================================================
wire [CTRL_ADDR_WIDTH-1:0]  axi_awaddr                 ;    // 鍐欏湴鍧€锛?8bit锛屽寘鍚銆佸垪銆丅ank鍦板潃锛?wire                        axi_awuser_ap              ;    // 鍐欏湴鍧€鐢ㄦ埛淇″彿锛氬湴鍧€淇濇姢
wire [3:0]                  axi_awuser_id              ;    // 鍐欏湴鍧€鐢ㄦ埛ID锛?bit锛岀敤浜庢爣璇嗕笉鍚岀殑鍐欎簨鍔★級
wire [3:0]                  axi_awlen                  ;    // 鍐欑獊鍙戦暱搴︼紙4bit锛屾渶澶?6涓暟鎹級
wire                        axi_awready                ;    // 鍐欏湴鍧€灏辩华锛圖DR鎺у埗鍣ㄥ噯澶囧ソ鎺ユ敹鍦板潃锛?wire                        axi_awvalid                ;    // 鍐欏湴鍧€鏈夋晥锛堝湴鍧€鎬荤嚎涓婄殑鍦板潃鏈夋晥锛?wire [MEM_DQ_WIDTH*8-1:0]   axi_wdata                  ;    // 鍐欐暟鎹紙128bit瀹斤紝16*8=128锛?wire [MEM_DQ_WIDTH*8/8-1:0] axi_wstrb                  ;    // 鍐欐暟鎹€夐€氾紙16bit锛屾瘡浣嶅搴斾竴涓瓧鑺傦級
wire                        axi_wready                 ;    // 鍐欐暟鎹氨缁紙DDR鎺у埗鍣ㄥ噯澶囧ソ鎺ユ敹鏁版嵁锛?wire [3:0]                  axi_wusero_id              ;    // 鍐欐暟鎹敤鎴稩D锛堢敤浜庡尮閰嶅湴鍧€鍜屾暟鎹級
wire                        axi_wusero_last            ;    // 鍐欐暟鎹渶鍚庝竴涓紙绐佸彂浼犺緭鐨勬渶鍚庝竴涓暟鎹級

//===============================================================================
// AXI4璇婚€氶亾淇″彿锛堢敤浜庝粠DDR璇诲彇鏁版嵁锛?//===============================================================================
wire [CTRL_ADDR_WIDTH-1:0]  axi_araddr                 ;    // 璇诲湴鍧€锛?8bit锛?wire                        axi_aruser_ap              ;    // 璇诲湴鍧€鐢ㄦ埛淇″彿锛氬湴鍧€淇濇姢
wire [3:0]                  axi_aruser_id              ;    // 璇诲湴鍧€鐢ㄦ埛ID锛?bit锛?wire [3:0]                  axi_arlen                  ;    // 璇荤獊鍙戦暱搴︼紙4bit锛?wire                        axi_arready                ;    // 璇诲湴鍧€灏辩华
wire                        axi_arvalid                ;    // 璇诲湴鍧€鏈夋晥
wire [MEM_DQ_WIDTH*8-1:0]   axi_rdata  /* synthesis syn_keep = 1 */;    // 璇绘暟鎹紙128bit锛岀患鍚堝伐鍏蜂繚鎸佹淇″彿锛?wire                        axi_rvalid /* synthesis syn_keep = 1 */;    // 璇绘暟鎹湁鏁堬紙鏁版嵁鎬荤嚎涓婄殑鏁版嵁鏈夋晥锛?wire [3:0]                  axi_rid                    ;    // 璇绘暟鎹甀D锛堢敤浜庡尮閰嶈璇锋眰鍜岃鏁版嵁锛?wire                        axi_rlast                  ;    // 璇绘暟鎹渶鍚庝竴涓紙绐佸彂浼犺緭鐨勬渶鍚庝竴涓暟鎹級

                                                          //===============================================================================
                                                          // 绯荤粺鎺у埗淇″彿
                                                          //===============================================================================
wire resetn                     ;                         // 绯荤粺澶嶄綅淇″彿锛堥珮鏈夋晥锛屾湭浣跨敤锛?reg  [26:0]                 cnt                        ;  // 璁℃暟鍣紙27bit锛岀敤浜庡績璺矻ED璁℃椂锛?wire [7:0]                  err_cnt                    ;  // 閿欒璁℃暟鍣紙8bit锛屾湭浣跨敤锛?wire free_clk_g                 ;                         // 鑷敱鏃堕挓闂ㄦ帶锛堟湭浣跨敤锛?
wire                        cam1_scl;
wire                        cam1_sda;
wire                        cam1_vsync = 1'b0;
wire                        cam1_href  = 1'b0;
wire                        cam1_pclk  = 1'b0;
wire [7:0]                  cam1_data  = 8'd0;
wire                        cam1_reset_n;
wire                        cam2_scl;
wire                        cam2_sda;
wire                        cam2_vsync = 1'b0;
wire                        cam2_href  = 1'b0;
wire                        cam2_pclk  = 1'b0;
wire [7:0]                  cam2_data  = 8'd0;
wire                        cam2_reset_n;
wire                        cam_fmc_reset_n;
//cmos
// 绯荤粺澶嶄綅寤舵椂璁℃暟鍣?reg  [15:0]                 rstn_1ms                   ;
// 鎽勫儚澶撮€氱敤淇″彿
wire                        cam_fmc_scl                   ;//cmos i2c clock
wire                        cam_fmc_sda                   ;//cmos i2c data
wire                        cam_fmc_vsync                 ;//cmos vsync
wire                        cam_fmc_href                  ;//cmos hsync refrence,data valid
wire                        cam_fmc_pclk                  ;//cmos pxiel clock
wire   [7:0]                cam_fmc_data                  ;//cmos data
wire                        cam_fmc_reset                 ;//cmos reset
// 鎽勫儚澶村垵濮嬪寲浣胯兘淇″彿
wire                        cam_init_enable                 ;
// 鎽勫儚澶?鐩稿叧淇″彿锛?bit杞?6bit鍚庣殑鏁版嵁
wire[15:0]                  cam1_data_16bit             ;
wire                        cam1_href_16bit           ;
reg [7:0]                   cam1_data_d0                ;
reg                         cam1_href_d0             ;
reg                         cam1_vsync_d0             ;
wire                        cam1_pclk_16bit           ;
// 鎽勫儚澶?鐩稿叧淇″彿锛?bit杞?6bit鍚庣殑鏁版嵁
wire[15:0]                  cam2_data_16bit              ;
wire                        cam2_href_16bit          ;
reg [7:0]                   cam2_data_d0                ;
reg                         cam2_href_d0              ;
reg                         cam2_vsync_d0             ;
wire                        cam2_pclk_16bit          ;
//杞?6bit鏁版嵁fmc
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
//fmc鏁版嵁
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
// PLL杈撳嚭鏃堕挓淇″彿
//===============================================================================
wire                        lock                       ;    // PLL閿佸畾淇″彿锛堥珮鏈夋晥琛ㄧず鎵€鏈夋椂閽熻緭鍑虹ǔ瀹氾級
wire                        clk_10m                    ;    // 10MHz鏃堕挓锛堢敤浜庢參閫熷璁撅級
wire                        clk_25m                    ;    // 25MHz鏃堕挓锛堢敤浜庢憚鍍忓ご閰嶇疆妯″潡锛?wire                        clk_50m                    ;    // 50MHz鏃堕挓锛堢郴缁熶富鏃堕挓锛岀敤浜庢憚鍍忓ご鍒濆鍖栧拰鎺у埗锛?
//===============================================================================
// PCIe閰嶇疆鍙傛暟瀹氫箟
//===============================================================================
localparam DEVICE_TYPE = 3'b000;			    // PCIe璁惧绫诲瀷锛?'b000=绔偣璁惧, 3'b001=鏍圭鍙? 3'b100=鍏朵粬
localparam AXIS_SLAVE_NUM = 3;				    // AXI-Stream浠庤澶囨暟閲忥細鏀寔3涓嫭绔嬬殑娴侀€氶亾

//reg             ref_led;

//===============================================================================
// PCIe娴嬭瘯鍗曞厓妯″紡淇″彿
//===============================================================================
wire			pcie_cfg_ctrl_en;			    // PCIe閰嶇疆鎺у埗浣胯兘
wire			axis_master_tready_cfg;		    // 閰嶇疆妯″紡涓嬬殑AXI-Stream涓昏澶囧氨缁?wire			cfg_axis_slave0_tvalid;		    // 閰嶇疆妯″紡涓嬬殑AXI-Stream浠庤澶囨湁鏁?wire	[127:0]	cfg_axis_slave0_tdata;		    // 閰嶇疆妯″紡涓嬬殑AXI-Stream鏁版嵁
wire			cfg_axis_slave0_tlast;		    // 閰嶇疆妯″紡涓嬬殑AXI-Stream鏈€鍚庢暟鎹爣蹇?wire			cfg_axis_slave0_tuser;		    // 閰嶇疆妯″紡涓嬬殑AXI-Stream鐢ㄦ埛淇″彿

//===============================================================================
// AXI-Stream澶氳矾澶嶇敤鐩稿叧淇″彿
//===============================================================================
wire			axis_master_tready_mem;		    // 鍐呭瓨妯″紡鐨凙XI-Stream涓昏澶囧氨缁俊鍙?wire			axis_master_tvalid_mem;		    // 鍐呭瓨妯″紡鐨凙XI-Stream涓昏澶囨湁鏁堜俊鍙?wire	[127:0]	axis_master_tdata_mem;		    // 鍐呭瓨妯″紡鐨凙XI-Stream鏁版嵁锛?28bit锛?wire	[3:0]	axis_master_tkeep_mem;		    // 鍐呭瓨妯″紡鐨凙XI-Stream鏁版嵁鏈夋晥瀛楄妭锛?bit锛?wire			axis_master_tlast_mem;		    // 鍐呭瓨妯″紡鐨凙XI-Stream鏈€鍚庢暟鎹爣蹇?wire	[7:0]	axis_master_tuser_mem;		    // 鍐呭瓨妯″紡鐨凙XI-Stream鐢ㄦ埛淇″彿锛?bit锛?
//===============================================================================
// DMA鐩稿叧淇″彿
//===============================================================================
wire			cross_4kb_boundary;			    // 璺?KB杈圭晫鏍囧織锛圥CIe DMA浼犺緭闄愬埗妫€娴嬶級
wire			dma_axis_slave0_tvalid;		    // DMA鐨凙XI-Stream浠庤澶?鏈夋晥淇″彿
wire	[127:0]	dma_axis_slave0_tdata;		    // DMA鐨凙XI-Stream浠庤澶?鏁版嵁锛?28bit锛?wire			dma_axis_slave0_tlast;		    // DMA鐨凙XI-Stream浠庤澶?鏈€鍚庢暟鎹爣蹇?wire			dma_axis_slave0_tuser;		    // DMA鐨凙XI-Stream浠庤澶?鐢ㄦ埛淇″彿

//===============================================================================
// 澶嶄綅娑堟姈鍜屽悓姝ヤ俊鍙凤紙璺ㄦ椂閽熷煙澶嶄綅鍚屾锛?//===============================================================================
wire			sync_button_rst_n; 			    // 鍚屾鍚庣殑鎸夐挳澶嶄綅淇″彿锛堜綆鏈夋晥锛?wire			ref_core_rst_n;			        // 鍚屾鍒板弬鑰冩椂閽熷煙鐨勬牳蹇冨浣嶄俊鍙?wire            sync_perst_n;			        // 鍚屾鍚庣殑PCIe澶嶄綅淇″彿锛堜綆鏈夋晥锛?wire			s_pclk_rstn;			        // 鍚屾鍒皃clk鏃堕挓鍩熺殑鏍稿績澶嶄綅淇″彿

//===============================================================================
// PCIe鍐呴儴鏃堕挓鍜屽浣嶄俊鍙?//===============================================================================
wire			pclk_div2/*synthesis PAP_MARK_DEBUG="1"*/;  	// PCIe鐢ㄦ埛鏃堕挓鍒嗛锛坸2鏃?25MHz锛寈1鏃?2.5MHz锛?wire			pclk/*synthesis PAP_MARK_DEBUG="1"*/;		    // PCIe鐢ㄦ埛鏃堕挓锛坸2鏃?25MHz锛寈1鏃?2.5MHz锛屽彲璋冭瘯锛?wire			ref_clk; 				        // PCIe鍙傝€冩椂閽燂紙鏉ヨ嚜PHY锛?00MHz锛?wire			core_rst_n;				        // PCIe鏍稿績澶嶄綅淇″彿锛堥珮鏈夋晥锛屽悓姝ュ埌澶氫釜鏃堕挓鍩燂級

//===============================================================================
// AXI-Stream涓昏澶囨帴鍙ｄ俊鍙凤紙PCIe IP鏍歌緭鍑猴紝鐢ㄤ簬鍚慞CIe鍙戦€佹暟鎹級
//===============================================================================
wire			axis_master_tvalid;            // 涓昏澶囨暟鎹湁鏁堜俊鍙?wire			axis_master_tready;            // 涓昏澶囨暟鎹氨缁俊鍙?wire	[127:0]	axis_master_tdata;             // 涓昏澶囨暟鎹紙128bit锛孭CIe鏁版嵁鍖咃級
wire	[3:0]	axis_master_tkeep;             // 涓昏澶囨暟鎹湁鏁堝瓧鑺傦紙4bit锛屾瘡浣嶅搴?2bit锛?wire			axis_master_tlast;             // 涓昏澶囨渶鍚庢暟鎹爣蹇楋紙琛ㄧずPCIe鍖呯殑缁撴潫锛?wire	[7:0]	axis_master_tuser;             // 涓昏澶囩敤鎴蜂俊鍙凤紙8bit锛屽寘鍚玃CIe TLP澶翠俊鎭級

//===============================================================================
// AXI4-Stream浠庤澶囨帴鍙ｄ俊鍙凤紙PCIe IP鏍歌緭鍏ワ紝鐢ㄤ簬浠嶱CIe鎺ユ敹鏁版嵁锛?//===============================================================================
// 浠庤澶?鎺ュ彛锛圖MA鏁版嵁閫氶亾锛?wire			axis_slave0_tready;            // 浠庤澶?灏辩华淇″彿锛堣〃绀哄彲浠ユ帴鏀舵暟鎹級
wire			axis_slave0_tvalid;            // 浠庤澶?鏈夋晥淇″彿锛堣〃绀烘暟鎹湁鏁堬級
wire	[127:0]	axis_slave0_tdata;             // 浠庤澶?鏁版嵁锛?28bit锛?wire			axis_slave0_tlast;             // 浠庤澶?鏈€鍚庢暟鎹爣蹇?wire			axis_slave0_tuser;             // 浠庤澶?鐢ㄦ埛淇″彿

// 浠庤澶?鎺ュ彛
wire			axis_slave1_tready;            // 浠庤澶?灏辩华淇″彿
wire			axis_slave1_tvalid;            // 浠庤澶?鏈夋晥淇″彿
wire	[127:0]	axis_slave1_tdata;             // 浠庤澶?鏁版嵁锛?28bit锛?wire			axis_slave1_tlast;             // 浠庤澶?鏈€鍚庢暟鎹爣蹇?wire			axis_slave1_tuser;             // 浠庤澶?鐢ㄦ埛淇″彿

// 浠庤澶?鎺ュ彛
wire			axis_slave2_tready;            // 浠庤澶?灏辩华淇″彿
wire			axis_slave2_tvalid;            // 浠庤澶?鏈夋晥淇″彿
wire	[127:0]	axis_slave2_tdata;             // 浠庤澶?鏁版嵁锛?28bit锛?wire			axis_slave2_tlast;             // 浠庤澶?鏈€鍚庢暟鎹爣蹇?wire			axis_slave2_tuser;             // 浠庤澶?鐢ㄦ埛淇″彿

//===============================================================================
// PCIe閰嶇疆瀵勫瓨鍣ㄤ俊鍙凤紙鏉ヨ嚜PCIe閰嶇疆绌洪棿锛?//===============================================================================
wire	[7:0]	cfg_pbus_num;			        // PCIe鎬荤嚎鍙凤紙8bit锛屾爣璇哖CIe鎬荤嚎锛?wire	[4:0]	cfg_pbus_dev_num; 		        // PCIe璁惧鍙凤紙5bit锛屾爣璇嗚澶囷級
wire	[2:0]	cfg_max_rd_req_size;	        // 鏈€澶ц璇锋眰澶у皬锛?bit锛?28/256/512/1024/2048/4096瀛楄妭锛?wire	[2:0]	cfg_max_payload_size;	        // 鏈€澶ц礋杞藉ぇ灏忥紙3bit锛?28/256/512/1024/2048/4096瀛楄妭锛?wire			cfg_rcb;				        // 璇诲畬鎴愯竟鐣岋紙Read Completion Boundary锛?28鎴?4瀛楄妭瀵归綈锛?
//===============================================================================
// PCIe娴佹帶鍜屼俊鐢ㄧ鐞嗕俊鍙?//===============================================================================
wire			cfg_ido_req_en;			        // IDO璇锋眰浣胯兘锛堝綋鍓嶇鐢級
wire			cfg_ido_cpl_en;			        // IDO瀹屾垚浣胯兘锛堝綋鍓嶇鐢級
wire	[7:0]	xadm_ph_cdts;			        // 鍙戝竷澶翠俊鐢ㄨ鏁板櫒锛堟湭浣跨敤锛?wire	[11:0]	xadm_pd_cdts;			        // 鍙戝竷鏁版嵁淇＄敤璁℃暟鍣紙鏈娇鐢級
wire	[7:0]	xadm_nph_cdts;			        // 闈炲彂甯冨ご淇＄敤璁℃暟鍣紙鏈娇鐢級
wire	[11:0]	xadm_npd_cdts;			        // 闈炲彂甯冩暟鎹俊鐢ㄨ鏁板櫒锛堟湭浣跨敤锛?wire	[7:0]	xadm_cplh_cdts;			        // 瀹屾垚澶翠俊鐢ㄨ鏁板櫒锛堟湭浣跨敤锛?wire	[11:0]	xadm_cpld_cdts;			        // 瀹屾垚鏁版嵁淇＄敤璁℃暟鍣紙鏈娇鐢級

//===============================================================================
// PCIe閾捐矾鐘舵€佷俊鍙?//===============================================================================
wire	[4:0]	smlh_ltssm_state/*synthesis PAP_MARK_DEBUG="1"*/;   // 閾捐矾璁粌鍜岀姸鎬佺姸鎬佹満鐘舵€侊紙5bit锛屽彲璋冭瘯锛?
//===============================================================================
// LED鎺у埗鐩稿叧淇″彿鍜岃鏁板櫒
//===============================================================================
reg		[22:0]	ref_led_cnt;		        // 鍙傝€冩椂閽烲ED璁℃暟鍣紙23bit锛岀敤浜庢帶鍒禠ED闂儊棰戠巼锛?reg		[26:0]	pclk_led_cnt;		        // PCIe鏃堕挓LED璁℃暟鍣紙27bit锛?wire			smlh_link_up; 		        // 杞欢閾捐矾鐘舵€侊細閾捐矾宸插缓绔嬶紙楂樻湁鏁堬級
wire			rdlh_link_up; 	    // 纭欢閾捐矾鐘舵€侊細閾捐矾宸插缓绔嬶紙楂樻湁鏁堬紝鍙皟璇曪級

//===============================================================================
// UART鍒癆PB鎺ュ彛淇″彿锛堢敤浜庨€氳繃UART閰嶇疆PCIe瀵勫瓨鍣紝32bit浣嶅锛?//===============================================================================
wire			uart_p_sel;			        // UART APB閫夋嫨淇″彿锛堢墖閫夛級
wire	[3:0]	uart_p_strb;		        // UART APB瀛楄妭閫夐€氾紙4bit锛屾瘡浣嶅搴斾竴涓瓧鑺傦級
wire	[15:0]	uart_p_addr;		        // UART APB鍦板潃锛?6bit鍦板潃绌洪棿锛?wire	[31:0]	uart_p_wdata;		        // UART APB鍐欐暟鎹紙32bit锛?wire			uart_p_ce;			        // UART APB鏃堕挓浣胯兘
wire			uart_p_we;			        // UART APB鍐欎娇鑳?wire			uart_p_rdy;			        // UART APB灏辩华淇″彿
wire	[31:0]	uart_p_rdata;		        // UART APB璇绘暟鎹紙32bit锛?
//===============================================================================
// 鍐呴儴APB鎬荤嚎淇″彿锛堣繛鎺ュ埌APB澶氳矾澶嶇敤鍣級
//===============================================================================
wire	[3:0]	p_strb; 			        // APB瀛楄妭閫夐€氾紙4bit锛?wire	[15:0]	p_addr; 			        // APB鍦板潃锛?6bit锛?wire	[31:0]	p_wdata; 			        // APB鍐欐暟鎹紙32bit锛?wire			p_ce; 				        // APB鏃堕挓浣胯兘
wire			p_we; 				        // APB鍐欎娇鑳?
//===============================================================================
// APB澶氳矾澶嶇敤鍣ㄩ€夋嫨鍜屽搷搴斾俊鍙?//===============================================================================
// APB鍦板潃绌洪棿鍒嗛厤锛?//   0~5: HSSTLP锛堥珮閫熶覆琛岄摼璺祴璇曪級
//   6: 淇濈暀
//   7: PCIe瀵勫瓨鍣ㄧ┖闂?//   8: 閰嶇疆瀵勫瓨鍣ㄧ┖闂?//   9: DMA鎺у埗鍣ㄥ瘎瀛樺櫒绌洪棿锛堝熀鍦板潃0x8000锛?wire			p_sel_pcie;			        // PCIe瀵勫瓨鍣ㄧ┖闂撮€夋嫨
wire			p_sel_cfg;			        // 閰嶇疆瀵勫瓨鍣ㄧ┖闂撮€夋嫨
wire			p_sel_dma;			        // DMA瀵勫瓨鍣ㄧ┖闂撮€夋嫨

wire	[31:0]	p_rdata_pcie;		        // PCIe瀵勫瓨鍣ㄧ┖闂磋鏁版嵁
wire	[31:0]	p_rdata_cfg;		        // 閰嶇疆瀵勫瓨鍣ㄧ┖闂磋鏁版嵁
wire	[31:0]	p_rdata_dma;		        // DMA瀵勫瓨鍣ㄧ┖闂磋鏁版嵁

wire			p_rdy_pcie;			        // PCIe瀵勫瓨鍣ㄧ┖闂村氨缁?wire			p_rdy_cfg;			        // 閰嶇疆瀵勫瓨鍣ㄧ┖闂村氨缁?wire			p_rdy_dma;			        // DMA瀵勫瓨鍣ㄧ┖闂村氨缁?		

//===============================================================================
// PCIe娴佹帶鍜屼俊鐢ㄧ鐞嗕俊鍙峰浐瀹氳祴鍊?//===============================================================================
assign cfg_ido_req_en	=	1'b0;	    // IDO璇锋眰鍔熻兘绂佺敤
assign cfg_ido_cpl_en	=	1'b0;	    // IDO瀹屾垚鍔熻兘绂佺敤
assign xadm_ph_cdts		=	8'b0;	    // 鍙戝竷澶翠俊鐢ㄨ鏁板櫒娓呴浂
assign xadm_pd_cdts		=	12'b0;	    // 鍙戝竷鏁版嵁淇＄敤璁℃暟鍣ㄦ竻闆?assign xadm_nph_cdts	=	8'b0;	    // 闈炲彂甯冨ご淇＄敤璁℃暟鍣ㄦ竻闆?assign xadm_npd_cdts	=	12'b0;	    // 闈炲彂甯冩暟鎹俊鐢ㄨ鏁板櫒娓呴浂
assign xadm_cplh_cdts	=	8'b0;	    // 瀹屾垚澶翠俊鐢ㄨ鏁板櫒娓呴浂
assign xadm_cpld_cdts	=	12'b0;	    // 瀹屾垚鏁版嵁淇＄敤璁℃暟鍣ㄦ竻闆?





//===============================================================================
// AXI鎬荤嚎鎺ュ彛淇″彿瀹氫箟锛氱敤浜嶥DR3鏁版嵁璇诲啓
//===============================================================================
// 閫氶亾0锛堟憚鍍忓ご1閫氶亾1锛夛細鍥惧儚鏁版嵁鍐欏叆鍜岃鍙?wire          ch0_write_data_valid      ;       // 鍐欏叆鏁版嵁鏈夋晥淇″彿
wire [15:0]   ch0_write_data            ;      // 鍐欏叆鏁版嵁锛?6bit锛?reg           ch0_read_frame_req;               // 璇诲抚璇锋眰淇″彿
wire          ch0_read_req_ack;                 // 璇昏姹傚簲绛斾俊鍙?wire          ch0_read_data_en;                 // 璇绘暟鎹娇鑳戒俊鍙?wire  [127:0] ch0_read_data;                    // 璇绘暟鎹紙128bit锛孉XI鎬荤嚎瀹藉害锛?wire          ch0_read_data_valid;              // 璇绘暟鎹湁鏁堜俊鍙?
// 閫氶亾1锛堟憚鍍忓ご1閫氶亾2锛夛細鍥惧儚鏁版嵁鍐欏叆鍜岃鍙?wire          ch1_write_data_valid      ;       
wire [15:0]   ch1_write_data            ;       
reg           ch1_read_frame_req;               
wire          ch1_read_req_ack;                 
wire          ch1_read_data_en;                 
wire  [127:0] ch1_read_data;                    
wire          ch1_read_data_valid;              

// 閫氶亾2锛堟憚鍍忓ご2閫氶亾1锛夛細鍥惧儚鏁版嵁鍐欏叆鍜岃鍙?wire          ch2_write_data_valid      ;       
wire [15:0]   ch2_write_data            ;       
reg           ch2_read_frame_req;               
wire          ch2_read_req_ack;                 
wire          ch2_read_data_en;                 
wire  [127:0] ch2_read_data;                    
wire          ch2_read_data_valid;              

// 閫氶亾3锛堟憚鍍忓ご2閫氶亾2锛夛細鍥惧儚鏁版嵁鍐欏叆鍜岃鍙?wire          ch3_write_data_valid      ;       
wire [15:0]   ch3_write_data            ;       
reg           ch3_read_frame_req;               
wire          ch3_read_req_ack;                 
wire          ch3_read_data_en;                 
wire  [127:0] ch3_read_data;                    
wire          ch3_read_data_valid;              

//===============================================================================
// PCIe DMA鎺ュ彛淇″彿瀹氫箟
//===============================================================================
// DMA鎺у埗鍣ㄥ熀鍦板潃锛?x8000
wire            dma_write_req;                   // DMA鍐欐暟鎹姹備俊鍙?wire [11:0]     dma_write_addr;                 // DMA鍐欏湴鍧€锛?2bit锛屾渶澶?KB锛?wire [127:0]    dma_write_data;                  // DMA鍐欐暟鎹紙128bit锛孉XI-Stream瀹藉害锛?
// 鎽勫儚澶?鍍忕礌鏃堕挓缂撳啿锛堟湭浣跨敤锛屼繚鐣欙級
wire            cam2_pclk_bufg;

// 鎽勫儚澶?鏁版嵁鍚屾瀵勫瓨鍣紙涓ょ骇鍚屾锛岀敤浜庤法鏃堕挓鍩燂級
reg             cam1_vsync_d1;
reg             cam1_vsync_d2;
reg             cam1_href_d1;
reg             cam1_href_d2;
reg   [7:0]     cam1_data_d1;
reg   [7:0]     cam1_data_d2;

// 鎽勫儚澶?鏁版嵁鍚屾瀵勫瓨鍣紙涓ょ骇鍚屾锛岀敤浜庤法鏃堕挓鍩燂級
reg             cam2_vsync_d1;
reg             cam2_vsync_d2;
reg             cam2_href_d1;
reg             cam2_href_d2;
reg   [7:0]     cam2_data_d1;
reg   [7:0]     cam2_data_d2;

//fmc鍚屾
reg             cam_fmc_vsync_d1;
reg             cam_fmc_vsync_d2;
reg             cam_fmc_href_d1;
reg             cam_fmc_href_d2;
reg   [7:0]     cam_fmc_data_d1;
reg   [7:0]     cam_fmc_data_d2;


// 琛岀紦鍐插尯婊℃爣蹇楋細鐢ㄤ簬鎸囩ず鍚勯€氶亾鐨勮缂撳啿鍖烘槸鍚﹀凡婊?wire            ch0_line_full_flag;            // 閫氶亾0琛岀紦鍐叉弧鏍囧織
wire            ch1_line_full_flag;            // 閫氶亾1琛岀紦鍐叉弧鏍囧織
wire            ch2_line_full_flag;            // 閫氶亾2琛岀紦鍐叉弧鏍囧織
wire            ch3_line_full_flag;            // 閫氶亾3琛岀紦鍐叉弧鏍囧織

// 鎽勫儚澶?鏁版嵁鍚屾锛氫袱绾у瘎瀛樺櫒鍚屾锛屾秷闄や簹绋虫€?always @(posedge cam1_pclk)begin
    cam1_vsync_d1 <= cam1_vsync;
    cam1_vsync_d2 <= cam1_vsync_d1;
    cam1_href_d1 <= cam1_href;
    cam1_href_d2  <= cam1_href_d1;
    cam1_data_d1 <= cam1_data;
    cam1_data_d2 <= cam1_data_d1;
end

// 鎽勫儚澶?鏁版嵁鍚屾锛氫袱绾у瘎瀛樺櫒鍚屾锛屾秷闄や簹绋虫€?always @(posedge cam2_pclk)begin
    cam2_vsync_d1 <= cam2_vsync;
    cam2_vsync_d2 <= cam2_vsync_d1;
    cam2_href_d1 <= cam2_href;
    cam2_href_d2  <= cam2_href_d1;
    cam2_data_d1 <= cam2_data;
    cam2_data_d2 <= cam2_data_d1;
end

// 鎽勫儚澶磃mc鏁版嵁鍚屾锛氫袱绾у瘎瀛樺櫒鍚屾锛屾秷闄や簹绋虫€?always @(posedge cam_fmc_pclk)begin
    cam_fmc_vsync_d1 <= cam_fmc_vsync;
    cam_fmc_vsync_d2 <= cam_fmc_vsync_d1;
    cam_fmc_href_d1 <= cam_fmc_href;
    cam_fmc_href_d2  <= cam_fmc_href_d1;
    cam_fmc_data_d1 <= cam_fmc_data;
    cam_fmc_data_d2 <= cam_fmc_data_d1;
end

//*==============================================================================
// PLL鏃堕挓绠＄悊妯″潡锛氬皢绯荤粺鏃堕挓鍒嗛/鍊嶉涓哄涓椂閽熷煙
//*==============================================================================
pll dl_pll_inst (
  .clkout0(clk_10m),    // 杈撳嚭锛?0MHz鏃堕挓锛堢敤浜庢參閫熷璁撅級
  .clkout1(clk_25m),    // 杈撳嚭锛?5MHz鏃堕挓锛堢敤浜庢憚鍍忓ご閰嶇疆锛?  .clkout2(clk_50m),    // 杈撳嚭锛?0MHz鏃堕挓锛堢敤浜庣郴缁熶富鏃堕挓锛?  .lock(lock),          // 杈撳嚭锛歅LL閿佸畾淇″彿锛堥珮鏈夋晥琛ㄧず鏃堕挓绋冲畾锛?  .clkin1(sys_clk)       // 杈撳叆锛氱郴缁熷弬鑰冩椂閽燂紙40MHz锛?);

// GTP_CLKBUFR U_CLKBUFR ( 
// .CLKOUT     (cmos2_pclk_bufg), 
// .CLKIN      (cmos2_pclk)
// ); 

//*==============================================================================
// 鎽勫儚澶村垵濮嬪寲鍜岄厤缃ā鍧?//*==============================================================================
// OV5640瀵勫瓨鍣ㄩ厤缃娇鑳斤細涓婄數寤舵椂鍚庝娇鑳芥憚鍍忓ご鍒濆鍖?sys_pwseq_delay_circuit	dl_power_on_delay_inst(
    .clk_50M                 (clk_50m        ),              // 杈撳叆锛?0MHz鏃堕挓
    .reset_n                 (ddr_init_done  ),              // 杈撳叆锛氬浣嶄俊鍙凤紙DDR鍒濆鍖栧畬鎴愬悗鏈夋晥锛?    .camera1_rstn            (cam1_reset_n    ),              // 杈撳嚭锛氭憚鍍忓ご1澶嶄綅淇″彿锛堜綆鏈夋晥锛?    .camera2_rstn            (cam2_reset_n    ),              // 杈撳嚭锛氭憚鍍忓ご2澶嶄綅淇″彿锛堜綆鏈夋晥锛?    .camerafmc_rstn          (cam_fmc_reset_n),
    .camera_pwnd             (               ),               // 杈撳嚭锛氭憚鍍忓ご鐢垫簮鎺у埗锛堟湭浣跨敤锛?    .initial_en              (cam_init_enable     )           // 杈撳嚭锛氬垵濮嬪寲浣胯兘淇″彿
);
// 鎽勫儚澶?瀵勫瓨鍣ㄩ厤缃ā鍧楋細閫氳繃I2C閰嶇疆OV5640瀵勫瓨鍣?sensor_reg_cfg_mgr	dl_coms1_reg_config(
    .clk_25M                 (clk_50m            ),          // 杈撳叆锛氭椂閽燂紙瀹為檯浣跨敤50MHz锛?    .camera_rstn             (cam1_reset_n        ),          // 杈撳叆锛氭憚鍍忓ご澶嶄綅淇″彿
    .initial_en              (cam_init_enable         ),      // 杈撳叆锛氬垵濮嬪寲浣胯兘		
    .i2c_sclk                (cam1_scl          ),//output
    .i2c_sdat                (cam1_sda          ),//inout
    .reg_conf_done           (cam_init_done[0]  ),//output config_finished
    .reg_index               (                   ),//output reg [8:0]
    .clock_20k               (                   ) //output reg
);

// 鎽勫儚澶?瀵勫瓨鍣ㄩ厤缃ā鍧?sensor_reg_cfg_mgr	dl_coms2_reg_config(
    .clk_25M                 (clk_50m            ),//input
    .camera_rstn             (cam2_reset_n        ),//input
    .initial_en              (cam_init_enable         ),//input		
    .i2c_sclk                (cam2_scl          ),//output
    .i2c_sdat                (cam2_sda          ),//inout
    .reg_conf_done           (cam_init_done[1]  ),//output config_finished
    .reg_index               (                   ),//output reg [8:0]
    .clock_20k               (                   ) //output reg
);

wire cam_init_fmc; //fmc鎽勫儚澶存ā鍧?
// 鎽勫儚澶磃mc瀵勫瓨鍣ㄩ厤缃ā鍧?sensor_reg_cfg_mgr	dl_comsfmc_reg_config(
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
// 鎽勫儚澶存暟鎹牸寮忚浆鎹細8bit杞?6bit
//===============================================================================
// 鎽勫儚澶?锛氬皢鍚屾鍚庣殑8bit鏁版嵁閫佸叆鏍煎紡杞崲妯″潡
always@(posedge cam1_pclk)
    begin
        cam1_data_d0        <= cam1_data_d2    ;  // 寤惰繜涓€鎷嶏紝瀵归綈鏃跺簭
        cam1_href_d0     <= cam1_href_d2    ;     // 琛屾湁鏁堜俊鍙峰欢杩?        cam1_vsync_d0    <= cam1_vsync_d2   ;      // 鍦哄悓姝ヤ俊鍙峰欢杩?    end

// 鎽勫儚澶?锛?bit杞?6bit鏍煎紡杞崲妯″潡
cmos_pixel_width_adapter dl_cmos1_8_16bit(
.pclk           (cam1_pclk       ),          // 杈撳叆锛氬儚绱犳椂閽?.rst_n          (cam_init_done[0]),          // 杈撳叆锛氬浣嶄俊鍙凤紙鎽勫儚澶村垵濮嬪寲瀹屾垚鍚庢湁鏁堬級
.pdata_i        (cam1_data_d0       ),       // 杈撳叆锛?bit鍍忕礌鏁版嵁
.de_i           (cam1_href_d0    ),          // 杈撳叆锛氭暟鎹湁鏁堜俊鍙?.vs_i           (cam1_vsync_d0    ),         // 杈撳叆锛氬満鍚屾淇″彿

.pixel_clk      (cam1_pclk_16bit ),          // 杈撳嚭锛?6bit妯″紡涓嬬殑鍍忕礌鏃堕挓
.pdata_o        (cam1_data_16bit    ),       // 杈撳嚭锛?6bit鍍忕礌鏁版嵁
.de_o           (cam1_href_16bit )           // 杈撳嚭锛?6bit妯″紡涓嬬殑鏁版嵁鏈夋晥淇″彿
);

// 鎽勫儚澶?锛氬皢鍚屾鍚庣殑8bit鏁版嵁閫佸叆鏍煎紡杞崲妯″潡
always@(posedge cam2_pclk)
    begin
        cam2_data_d0        <= cam2_data_d2    ;  // 寤惰繜涓€鎷嶏紝瀵归綈鏃跺簭
        cam2_href_d0     <= cam2_href_d2    ;     // 琛屾湁鏁堜俊鍙峰欢杩?        cam2_vsync_d0    <= cam2_vsync_d2   ;      // 鍦哄悓姝ヤ俊鍙峰欢杩?    end

// 鎽勫儚澶?锛?bit杞?6bit鏍煎紡杞崲妯″潡
cmos_pixel_width_adapter dl_cmos2_8_16bit(
.pclk           (cam2_pclk       ),          // 杈撳叆锛氬儚绱犳椂閽?.rst_n          (cam_init_done[1]),          // 杈撳叆锛氬浣嶄俊鍙凤紙鎽勫儚澶村垵濮嬪寲瀹屾垚鍚庢湁鏁堬級
.pdata_i        (cam2_data_d0       ),       // 杈撳叆锛?bit鍍忕礌鏁版嵁
.de_i           (cam2_href_d0    ),          // 杈撳叆锛氭暟鎹湁鏁堜俊鍙?.vs_i           (cam2_vsync_d0    ),         // 杈撳叆锛氬満鍚屾淇″彿

.pixel_clk      (cam2_pclk_16bit ),          // 杈撳嚭锛?6bit妯″紡涓嬬殑鍍忕礌鏃堕挓
.pdata_o        (cam2_data_16bit    ),       // 杈撳嚭锛?6bit鍍忕礌鏁版嵁
.de_o           (cam2_href_16bit )           // 杈撳嚭锛?6bit妯″紡涓嬬殑鏁版嵁鏈夋晥淇″彿
);

// 鎽勫儚澶磃mc锛氬皢鍚屾鍚庣殑8bit鏁版嵁閫佸叆鏍煎紡杞崲妯″潡
always@(posedge cam_fmc_pclk)
    begin
        cam_fmc_data_d0        <= cam_fmc_data_d2    ;  // 寤惰繜涓€鎷嶏紝瀵归綈鏃跺簭
        cam_fmc_href_d0     <= cam_fmc_href_d2    ;     // 琛屾湁鏁堜俊鍙峰欢杩?        cam_fmc_vsync_d0    <= cam_fmc_vsync_d2   ;      // 鍦哄悓姝ヤ俊鍙峰欢杩?    end

// 鎽勫儚澶?锛?bit杞?6bit鏍煎紡杞崲妯″潡
cmos_pixel_width_adapter dl_cmosfmc_8_16bit(
.pclk           (cam_fmc_pclk       ),          // 杈撳叆锛氬儚绱犳椂閽?.rst_n          (cam_init_fmc),          // 杈撳叆锛氬浣嶄俊鍙凤紙鎽勫儚澶村垵濮嬪寲瀹屾垚鍚庢湁鏁堬級
.pdata_i        (cam_fmc_data_d0       ),       // 杈撳叆锛?bit鍍忕礌鏁版嵁
.de_i           (cam_fmc_href_d0    ),          // 杈撳叆锛氭暟鎹湁鏁堜俊鍙?.vs_i           (cam_fmc_vsync_d0    ),         // 杈撳叆锛氬満鍚屾淇″彿

.pixel_clk      (cam_fmc_pclk_16bit ),          // 杈撳嚭锛?6bit妯″紡涓嬬殑鍍忕礌鏃堕挓
.pdata_o        (cam_fmc_data_16bit    ),       // 杈撳嚭锛?6bit鍍忕礌鏁版嵁
.de_o           (cam_fmc_href_16bit )           // 杈撳嚭锛?6bit妯″紡涓嬬殑鏁版嵁鏈夋晥淇″彿
);


//===============================================================================
// 瑙嗛鏁版嵁閫夋嫨鍜孯GB鏍煎紡杞崲
//===============================================================================
// 閫氶亾1瑙嗛鏁版嵁閫夋嫨锛氫娇鐢ㄦ憚鍍忓ご1鐨勬暟鎹?assign     pclk_in_test    =    hdmi_pix_clk       ;
assign     vs_in_test      =    hdmi_vs            ;
assign     de_in_test      =    hdmi_de            ;
assign     i_rgb565        =    hdmi_rgb565        ;

// 閫氶亾2瑙嗛鏁版嵁閫夋嫨锛氫娇鐢ㄦ憚鍍忓ご2鐨勬暟鎹?assign     pclk_in_test_2  =    hdmi_pix_clk       ;
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
      cnt <= 27'd0;              // DDR鏈垵濮嬪寲瀹屾垚锛岃鏁板櫒娓呴浂
   else if ( cnt >= TH_1S )      // 璁℃暟鍒?绉掞紙33,000,000涓椂閽熷懆鏈燂級
      cnt <= 27'd0;               // 璁℃暟鍣ㄦ竻闆?   else
      cnt <= cnt + 27'd1;        // 璁℃暟鍣ㄩ€掑
end

// 蹇冭烦LED鎺у埗锛氭瘡绉掔炕杞竴娆ED鐘舵€?always @(posedge core_clk or negedge ddr_init_done)
begin
   if (!ddr_init_done)
      heart_beat_led <= 1'd1;     // DDR鏈垵濮嬪寲瀹屾垚锛孡ED淇濇寔楂樼數骞?   else if ( cnt >= TH_1S )       // 姣?绉掔炕杞竴娆?      heart_beat_led <= ~heart_beat_led;
end

//娣诲姞鍏夌氦HSST鐨勪緥鍖栨ā鍧楀強淇″彿澹版槑
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

//鎺ョ撼绗洓涓緭鍏ユ簮,浠庡厜绾や腑瑙ｅ寘鏁版嵁
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
//32浣嶆暟鎹榻愭ā鍧?wire[31:0] rx_data_align /* synthesis PAP_MARK_DEBUG="true" */;
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

//GTP瑙嗛鏁版嵁瑙ｆ瀽妯″潡
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
// DDR3鍐呭瓨鎺у埗鍣↖P鏍镐緥鍖栵細鎻愪緵楂橀€熸暟鎹紦瀛樺姛鑳?//===============================================================================
// 鍙傛暟璇存槑锛?//   MEM_ROW_WIDTH      : 琛屽湴鍧€瀹藉害锛?5bit锛屾敮鎸?2K琛岋級
//   MEM_COLUMN_WIDTH   : 鍒楀湴鍧€瀹藉害锛?0bit锛屾敮鎸?K鍒楋級
//   MEM_BANK_WIDTH     : Bank鍦板潃瀹藉害锛?bit锛屾敮鎸?涓狟ank锛?//   MEM_DQ_WIDTH       : 鏁版嵁浣嶅锛?6bit锛?//   MEM_DM_WIDTH       : 鏁版嵁鎺╃爜瀹藉害锛堢瓑浜嶥QS鏁伴噺锛?//   MEM_DQS_WIDTH      : DQS淇″彿鏁伴噺锛?涓紝瀵瑰簲2涓瓧鑺傦級
//   CTRL_ADDR_WIDTH    : 鎺у埗鍣ㄥ湴鍧€鎬诲搴︼紙28bit锛屽寘鍚銆佸垪銆丅ank锛?ddr3 #(
    .MEM_ROW_WIDTH              (MEM_ROW_WIDTH                ),
    .MEM_COLUMN_WIDTH           (MEM_COLUMN_WIDTH             ),
    .MEM_BANK_WIDTH             (MEM_BANK_WIDTH               ),
    .MEM_DQ_WIDTH               (MEM_DQ_WIDTH                 ),
    .MEM_DM_WIDTH               (MEM_DQS_WIDTH                ),
    .MEM_DQS_WIDTH              (MEM_DQS_WIDTH                ),
    .CTRL_ADDR_WIDTH            (CTRL_ADDR_WIDTH              )
  )dl_I_ips_ddr_top(
    // 鏃堕挓鍜屽浣嶆帴鍙?    .ref_clk                    (sys_clk                     ),    // 杈撳叆锛氬弬鑰冩椂閽燂紙40MHz绯荤粺鏃堕挓锛?    .resetn                     (sys_rst_n                  ),    // 杈撳叆锛氬浣嶄俊鍙凤紙浣庢湁鏁堬級
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

    // APB閰嶇疆鎺ュ彛
    .apb_clk                    (1'b0                         ),    // APB鏃堕挓锛堢鐢級
    .apb_rst_n                  (1'b0                         ),    // APB澶嶄綅锛堢鐢級
    .apb_sel                    (1'b0                         ),    // APB閫夋嫨锛堢鐢級
    .apb_enable                 (1'b0                         ),    // APB浣胯兘锛堢鐢級
    .apb_addr                   (8'd0                         ),    // APB鍦板潃锛堝浐瀹氫负0锛?    .apb_write                  (1'b0                         ),    // APB鍐欎娇鑳斤紙绂佺敤锛?    .apb_ready                  (                             ),    // APB灏辩华锛堟湭杩炴帴锛?    .apb_wdata                  (16'd0                        ),    // APB鍐欐暟鎹紙鍥哄畾涓?锛?    .apb_rdata                  (                             ),    // APB璇绘暟鎹紙鏈繛鎺ワ級


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
    // DDR3璋冭瘯鍜屾牎鍑嗘帴鍙ｏ紙褰撳墠鏈娇鐢紝浣跨敤榛樿鍊硷級
    //===========================================================================
    // 璋冭瘯鎺у埗淇″彿
    .dbg_gate_start             (1'b0                         ),    // 璋冭瘯闂ㄦ帶鍚姩锛堢鐢級
    .dbg_cpd_start              (1'b0                         ),    // 璋冭瘯CPD鍚姩锛堢鐢級
    .dbg_ddrphy_rst_n           (1'b1                         ),    // 璋冭瘯DDR PHY澶嶄綅锛堜繚鎸佷娇鑳斤級
    .dbg_gpll_scan_rst          (1'b0                         ),    // 璋冭瘯GPLL鎵弿澶嶄綅锛堢鐢級

    // 閲囨牱浣嶇疆鏍″噯锛堢敤浜庤皟鏁存暟鎹噰鏍风獥鍙ｏ級
    .samp_position_dyn_adj      (1'b0                         ),    // 鍔ㄦ€侀噰鏍蜂綅缃皟鏁达紙绂佺敤锛?    .init_samp_position_even    (16'd0                        ),    // 鍒濆鍋舵暟閲囨牱浣嶇疆锛堜娇鐢ㄩ粯璁ゅ€硷級
    .init_samp_position_odd     (16'd0                        ),    // 鍒濆濂囨暟閲囨牱浣嶇疆锛堜娇鐢ㄩ粯璁ゅ€硷級

    // 鍐欐牎鍑嗕綅缃紙鐢ㄤ簬璋冩暣鍐欐椂搴忥級
    .wrcal_position_dyn_adj     (1'b0                         ),    // 鍔ㄦ€佸啓鏍″噯浣嶇疆璋冩暣锛堢鐢級
    .init_wrcal_position        (16'd0                        ),    // 鍒濆鍐欐牎鍑嗕綅缃紙浣跨敤榛樿鍊硷級

    // 璇绘椂閽熸帶鍒讹紙鐢ㄤ簬璋冩暣璇绘椂閽熺浉浣嶏級
    .force_read_clk_ctrl        (1'b0                         ),    // 寮哄埗璇绘椂閽熸帶鍒讹紙绂佺敤锛?    .init_slip_step             (8'd0                         ),    // 鍒濆婊戠Щ姝ユ暟锛堜娇鐢ㄩ粯璁ゅ€硷級
    .init_read_clk_ctrl         (6'd0                         ),    // 鍒濆璇绘椂閽熸帶鍒讹紙浣跨敤榛樿鍊硷級

    // 璋冭瘯杈撳嚭淇″彿锛堟湭杩炴帴锛屽彲鐢ㄤ簬璋冭瘯鏃剁洃鎺э級
    .debug_calib_ctrl           (                             ),    // 璋冭瘯鏍″噯鎺у埗鐘舵€侊紙鏈繛鎺ワ級
    .dbg_dll_upd_state          (                             ),    // 璋冭瘯DLL鏇存柊鐘舵€侊紙鏈繛鎺ワ級
    .dbg_slice_status           (                             ),    // 璋冭瘯Slice鐘舵€侊紙鏈繛鎺ワ級
    .dbg_slice_state            (                             ),    // 璋冭瘯Slice鐘舵€佹満锛堟湭杩炴帴锛?    .debug_data                 (                             ),    // 璋冭瘯鏁版嵁杈撳嚭锛堟湭杩炴帴锛?    .debug_gpll_dps_phase       (                             ),    // 璋冭瘯GPLL DPS鐩镐綅锛堟湭杩炴帴锛?
    // 璋冭瘯鐘舵€佽緭鍑?    .dbg_rst_dps_state          (                             ),    // 璋冭瘯澶嶄綅DPS鐘舵€侊紙鏈繛鎺ワ級
    .dbg_tran_err_rst_cnt       (                             ),    // 璋冭瘯浼犺緭閿欒澶嶄綅璁℃暟锛堟湭杩炴帴锛?    .dbg_ddrphy_init_fail       (                             ),    // 璋冭瘯DDR PHY鍒濆鍖栧け璐ユ爣蹇楋紙鏈繛鎺ワ級

    // CPD锛圕lock Phase Detector锛夎皟璇曟帴鍙?    .debug_cpd_offset_adj       (1'b0                         ),    // 璋冭瘯CPD鍋忕Щ璋冩暣锛堢鐢級
    .debug_cpd_offset_dir       (1'b0                         ),    // 璋冭瘯CPD鍋忕Щ鏂瑰悜锛堢鐢級
    .debug_cpd_offset           (10'd0                        ),    // 璋冭瘯CPD鍋忕Щ鍊硷紙鍥哄畾涓?锛?    .debug_dps_cnt_dir0         (                             ),    // 璋冭瘯DPS璁℃暟鏂瑰悜0锛堟湭杩炴帴锛?    .debug_dps_cnt_dir1         (                             ),    // 璋冭瘯DPS璁℃暟鏂瑰悜1锛堟湭杩炴帴锛?
    // 鏃堕挓寤惰繜鎺у埗锛堢敤浜庤皟鏁存椂閽熸爲寤惰繜锛?    .ck_dly_en                  (1'b0                         ),    // 鏃堕挓寤惰繜浣胯兘锛堢鐢級
    .init_ck_dly_step           (8'd0                         ),    // 鍒濆鏃堕挓寤惰繜姝ユ暟锛堜娇鐢ㄩ粯璁ゅ€硷級
    .ck_dly_set_bin             (                             ),    // 鏃堕挓寤惰繜璁剧疆浜岃繘鍒跺€硷紙鏈繛鎺ワ級

    // 鏍″噯鍜岀姸鎬佺洃鎺?    .align_error                (                             ),    // 瀵归綈閿欒鏍囧織锛堟湭杩炴帴锛屽彲鐢ㄤ簬閿欒妫€娴嬶級
    .debug_rst_state            (                             ),    // 璋冭瘯澶嶄綅鐘舵€侊紙鏈繛鎺ワ級
    .debug_cpd_state            (                             )     // 璋冭瘯CPD鐘舵€侊紙鏈繛鎺ワ級

  );


//*==============================================================================
// 鍥惧儚鏁村舰妯″潡锛氬皢鍥惧儚鏁版嵁鏍煎紡鍖栦负閫傚悎DDR鍐欏叆鐨勬牸寮?//*==============================================================================
// 閫氶亾0鍥惧儚鏁村舰锛氬鐞嗘憚鍍忓ご1鐨凴GB565鏁版嵁锛岃緭鍑?6bit鏍煎紡鍖栫殑鍥惧儚鏁版嵁
//vs鍚屾
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
   
    .img_data_valid_out     (ch0_write_data_valid       ),   // 杈撳嚭锛氭牸寮忓寲鍚庣殑鏁版嵁鏈夋晥淇″彿
    .img_data_out           (ch0_write_data             )    // 杈撳嚭锛氭牸寮忓寲鍚庣殑16bit鍥惧儚鏁版嵁
);

// 閫氶亾1鍥惧儚鏁村舰锛氫笌閫氶亾0浣跨敤鐩稿悓杈撳叆婧愶紙鎽勫儚澶?锛夛紝鐢ㄤ簬澶氶€氶亾澶勭悊
img_data_stream_reducer dl_ch1_image_reshape(
    .clk                    (pclk_in_test               ),   // 杈撳叆锛氬儚绱犳椂閽燂紙鎽勫儚澶?锛?    .rst_n                  (hdmi_video_rst_n           ),

    .img_vs                 (vs_in_test                 ),   // 杈撳叆锛氬満鍚屾淇″彿
    .img_data_valid         (de_in_test                 ),   // 杈撳叆锛氭暟鎹湁鏁堜俊鍙?    .img_data               (i_rgb565                   ),   // 杈撳叆锛歊GB565鏍煎紡鍥惧儚鏁版嵁
   
    .img_data_valid_out     (ch1_write_data_valid      ),   // 杈撳嚭锛氭牸寮忓寲鍚庣殑鏁版嵁鏈夋晥淇″彿
    .img_data_out           (ch1_write_data            )    // 杈撳嚭锛氭牸寮忓寲鍚庣殑16bit鍥惧儚鏁版嵁
);

// 閫氶亾2鍥惧儚鏁村舰锛氬鐞嗘憚鍍忓ご2鐨凴GB565鏁版嵁锛岃緭鍑?6bit鏍煎紡鍖栫殑鍥惧儚鏁版嵁
img_data_stream_reducer dl_ch2_image_reshape(
    .clk                    (pclk_in_test_2             ),   // 杈撳叆锛氬儚绱犳椂閽燂紙鎽勫儚澶?锛?    .rst_n                  (hdmi_video_rst_n           ),

    .img_vs                 (vs_in_test_2               ),   // 杈撳叆锛氬満鍚屾淇″彿锛堟憚鍍忓ご2锛?    .img_data_valid         (de_in_test_2               ),   // 杈撳叆锛氭暟鎹湁鏁堜俊鍙凤紙鎽勫儚澶?锛?    .img_data               (i_rgb565_2                 ),   // 杈撳叆锛歊GB565鏍煎紡鍥惧儚鏁版嵁锛堟憚鍍忓ご2锛?   
    .img_data_valid_out     (ch2_write_data_valid      ),   // 杈撳嚭锛氭牸寮忓寲鍚庣殑鏁版嵁鏈夋晥淇″彿
    .img_data_out           (ch2_write_data            )    // 杈撳嚭锛氭牸寮忓寲鍚庣殑16bit鍥惧儚鏁版嵁
);

// 閫氶亾3鍥惧儚鏁村舰锛歠mc鏁版嵁婧?img_data_stream_reducer dl_ch3_image_reshape(
    .clk                    (fmc_pclk                   ),   // 杈撳叆锛氬儚绱犳椂閽燂紙鎽勫儚澶?锛?    .rst_n                  (hdmi_video_rst_n           ),

    .img_vs                 (fmc_vs                     ),   // 杈撳叆锛氬満鍚屾淇″彿锛堟憚鍍忓ご2锛?    .img_data_valid         (fmc_de                     ),   // 杈撳叆锛氭暟鎹湁鏁堜俊鍙凤紙鎽勫儚澶?锛?    .img_data               (fmc_rgb565                 ),   // 杈撳叆锛歊GB565鏍煎紡鍥惧儚鏁版嵁锛堟憚鍍忓ご2锛?   
    .img_data_valid_out     (ch3_write_data_valid      ),   // 杈撳嚭锛氭牸寮忓寲鍚庣殑鏁版嵁鏈夋晥淇″彿
    .img_data_out           (ch3_write_data            )    // 杈撳嚭锛氭牸寮忓寲鍚庣殑16bit鍥惧儚鏁版嵁
);


// PCIe鍥惧儚閫夋嫨妯″潡锛氫粠4涓€氶亾涓€夋嫨鏁版嵁骞堕€氳繃PCIe DMA浼犺緭
pcie_image_channel_selector dl_pcie_img_select_inst(
    .clk                         (pclk_div2                                 ),     // 杈撳叆锛歅CIe鏃堕挓鍩燂紙125MHz锛?    .rst_n                       (core_rst_n                                ),     // 杈撳叆锛氭牳蹇冨浣嶄俊鍙?    
    // DMA瑙﹀彂淇″彿
    .dma_sim_vs                  (ch0_read_frame_req                            ),     // 杈撳叆锛氭ā鎷熷満鍚屾锛堝抚璇昏姹傦級
    .line_full_flag              (ch0_line_full_flag && ch1_line_full_flag && ch2_line_full_flag && ch3_line_full_flag ),     // 杈撳叆锛氭墍鏈夐€氶亾琛岀紦鍐叉弧鏍囧織

    // 閫氶亾鏁版嵁鎺ュ彛锛氫粠DDR璇诲彇鐨?28bit瀹芥暟鎹?    .ch0_data_req                (ch0_read_data_en                        ),     // 杈撳叆锛氶€氶亾0鏁版嵁璇锋眰浣胯兘
    .ch0_data                    (ch0_read_data                           ),     // 杈撳叆锛氶€氶亾0鏁版嵁锛?28bit锛?    .ch1_data_req                (ch1_read_data_en                        ),     // 杈撳叆锛氶€氶亾1鏁版嵁璇锋眰浣胯兘
    .ch1_data                    (ch1_read_data                           ),     // 杈撳叆锛氶€氶亾1鏁版嵁锛?28bit锛?    .ch2_data_req                (ch2_read_data_en                        ),     // 杈撳叆锛氶€氶亾2鏁版嵁璇锋眰浣胯兘
    .ch2_data                    (ch2_read_data                           ),     // 杈撳叆锛氶€氶亾2鏁版嵁锛?28bit锛?    .ch3_data_req                (ch3_read_data_en                        ),     // 杈撳叆锛氶€氶亾3鏁版嵁璇锋眰浣胯兘
    .ch3_data                    (ch3_read_data                           ),     // 杈撳叆锛氶€氶亾3鏁版嵁锛?28bit锛?
    // DMA鍐欐帴鍙ｏ細杈撳嚭鍒癙CIe DMA鎺у埗鍣?    .dma_wr_data_req             (dma_write_req                      ),     // 杈撳嚭锛欴MA鍐欐暟鎹姹?    .dma_wr_data                 (dma_write_data                          )      // 杈撳嚭锛欴MA鍐欐暟鎹紙128bit锛?);
//*==============================================================================
// AXI鎺у埗鍣ㄤ緥鍖栵細绠＄悊DDR3鐨勮鍐欐搷浣滐紝鏀寔4涓€氶亾鐨勫浘鍍忔暟鎹紦瀛?//*==============================================================================
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

      // 閫氶亾0   
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

        // 閫氶亾1
      .ch1_wframe_pclk             (pclk_in_test                              ),
      .ch1_wframe_rst_n            (hdmi_video_rst_n                          ),
      .ch1_wframe_vsync            (vs_in_test                                ),
      .ch1_wframe_data_valid       (ch1_write_data_valid                     ),          
      .ch1_wframe_data             (ch1_write_data                           ),      

      .ch1_rframe_pclk             (pclk_div2                                 ),   
      .ch1_rframe_rst_n            (ddr_init_done                             ), 
      .ch1_rframe_vsync            (ch0_read_frame_req                            ),
      .ch1_rframe_req              (ch0_read_frame_req                            ),
      .ch1_rframe_req_ack          (                                          ),
      .ch1_rframe_data_en          (ch1_read_data_en                        ),
      .ch1_rframe_data             (ch1_read_data                           ),      
      .ch1_rframe_data_valid       (                                          ),
      .ch1_read_line_full          (ch1_line_full_flag                          ),

        // 閫氶亾2
      .ch2_wframe_pclk             (pclk_in_test_2                            ),
      .ch2_wframe_rst_n            (hdmi_video_rst_n                          ),
      .ch2_wframe_vsync            (vs_in_test_2                              ),
      .ch2_wframe_data_valid       (ch2_write_data_valid                     ),
      .ch2_wframe_data             (ch2_write_data                           ),

      .ch2_rframe_pclk             (pclk_div2                                 ),   
      .ch2_rframe_rst_n            (ddr_init_done                             ), 
      .ch2_rframe_vsync            (ch0_read_frame_req                            ),
      .ch2_rframe_req              (ch0_read_frame_req                            ),
      .ch2_rframe_req_ack          (                                          ),
      .ch2_rframe_data_en          (ch2_read_data_en                        ),
      .ch2_rframe_data             (ch2_read_data                           ),      
      .ch2_rframe_data_valid       (                                          ),
      .ch2_read_line_full          (ch2_line_full_flag                          ),

      // 閫氶亾3
      .ch3_wframe_pclk             (fmc_pclk                                 ),  
      .ch3_wframe_rst_n            (hdmi_video_rst_n                          ),
      .ch3_wframe_vsync            (fmc_vs                                   ),
      .ch3_wframe_data_valid       (ch3_write_data_valid                     ),
      .ch3_wframe_data             (ch3_write_data                           ),

      .ch3_rframe_pclk             (pclk_div2                                 ),   
      .ch3_rframe_rst_n            (ddr_init_done                             ), 
      .ch3_rframe_vsync            (ch0_read_frame_req                            ),
      .ch3_rframe_req              (ch0_read_frame_req                            ),
      .ch3_rframe_req_ack          (                                          ),
      .ch3_rframe_data_en          (ch3_read_data_en                        ),
      .ch3_rframe_data             (ch3_read_data                           ),      
      .ch3_rframe_data_valid       (                                          ),
      .ch3_read_line_full          (ch3_line_full_flag                          )
);


//*==============================================================================
// PCIe鎺ュ彛妯″潡锛氬疄鐜癙CIe鏁版嵁閫氫俊鍜孌MA浼犺緭鍔熻兘
//*==============================================================================
// 澶嶄綅娑堟姈鍜屽悓姝ワ細娑堥櫎澶嶄綅淇″彿鐨勬瘺鍒哄苟鍚屾鍒颁笉鍚屾椂閽熷煙
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
// PCIe鍙傝€冩椂閽烲ED鎺у埗锛氬湪PCIe閾捐矾寤虹珛鍚庨棯鐑侊紝鎸囩ず鍙傝€冩椂閽熻繍琛岀姸鎬?//===============================================================================
always @(posedge ref_clk or negedge sync_perst_n) begin
	if (!sync_perst_n) begin
		// PCIe澶嶄綅鏈熼棿锛氳鏁板櫒娓呴浂锛孡ED淇濇寔楂樼數骞?		ref_led_cnt <= 23'd0;
		ref_led <= 1'b1;
	end else if (smlh_link_up & rdlh_link_up) begin
		// PCIe閾捐矾宸插缓绔嬶細璁℃暟鍣ㄩ€掑锛屽綋璁℃暟鍣ㄥ叏1鏃剁炕杞琇ED
		ref_led_cnt <= ref_led_cnt + 23'd1;
		if(&ref_led_cnt)  // 濡傛灉璁℃暟鍣ㄦ墍鏈変綅閮戒负1锛堢害8.3M娆¤鏁帮級锛岀炕杞琇ED
			ref_led <= ~ref_led;
	end
end

//===============================================================================
// PCIe鐢ㄦ埛鏃堕挓LED鎺у埗锛氬湪PCIe閾捐矾寤虹珛鍚庨棯鐑侊紝鎸囩ず鐢ㄦ埛鏃堕挓杩愯鐘舵€?//===============================================================================
always @(posedge pclk or negedge s_pclk_rstn) begin
	if (!s_pclk_rstn) begin
		// PCIe澶嶄綅鏈熼棿锛氳鏁板櫒娓呴浂锛孡ED淇濇寔楂樼數骞?		pclk_led_cnt <= 27'd0;
		pclk_led <= 1'b1;
	end else if (smlh_link_up & rdlh_link_up) begin
		// PCIe閾捐矾宸插缓绔嬶細璁℃暟鍣ㄩ€掑锛屽綋璁℃暟鍣ㄥ叏1鏃剁炕杞琇ED
		pclk_led_cnt <= pclk_led_cnt + 27'd1;
		if(&pclk_led_cnt)  // 濡傛灉璁℃暟鍣ㄦ墍鏈変綅閮戒负1锛堢害134M娆¤鏁帮級锛岀炕杞琇ED
			pclk_led <= ~pclk_led;
	end
end


//===============================================================================
// PCIe DMA鎺у埗鍣ㄦā鍧楋細瀹炵幇PCIe DMA鏁版嵁浼犺緭鍔熻兘
//===============================================================================
// DMA鎺у埗鍣ㄥ熀鍦板潃锛?x8000锛堥€氳繃APB鎺ュ彛璁块棶锛?// 鍔熻兘锛氫粠DDR3璇诲彇鍥惧儚鏁版嵁锛岄€氳繃PCIe浼犺緭鍒颁笂浣嶆満
pcie_dma_core #(
	.DEVICE_TYPE			(DEVICE_TYPE),                  // PCIe璁惧绫诲瀷
	.AXIS_SLAVE_NUM			(AXIS_SLAVE_NUM)                 // AXI-Stream浠庤澶囨暟閲忥紙3涓級
) dl_u_ips2l_pcie_dma (
	// 鏃堕挓鍜屽浣?	.clk					(pclk_div2),			         // 杈撳叆锛歅CIe鏃堕挓鍩燂紙125MHz鎴?2.5MHz锛?	.rst_n					(core_rst_n),                    // 杈撳叆锛氭牳蹇冨浣嶄俊鍙凤紙楂樻湁鏁堬級				

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
	.o_cross_4kb_boundary	(cross_4kb_boundary),		//4k杈圭晫
    //**********************************************************************
    // dma write interface
    .o_dma_write_data_req   (dma_write_req  ),
    .o_dma_write_addr       (dma_write_addr      ),
    .i_dma_write_data       (dma_write_data      )
);



//===============================================================================
// APB閰嶇疆鎺ュ彛鍥哄畾璧嬪€硷紙褰撳墠鏈娇鐢ㄩ厤缃瘎瀛樺櫒锛?//===============================================================================
assign p_rdy_cfg               = 1'b0;                         // 閰嶇疆瀵勫瓨鍣ㄥ氨缁俊鍙凤紙鍥哄畾涓烘湭灏辩华锛?assign p_rdata_cfg             = 32'b0;                        // 閰嶇疆瀵勫瓨鍣ㄨ鏁版嵁锛堝浐瀹氫负0锛?
//===============================================================================
// AXI-Stream淇″彿杩炴帴锛氬皢DMA杈撳嚭杩炴帴鍒癙CIe IP鏍哥殑浠庤澶囨帴鍙?//===============================================================================
assign axis_slave0_tvalid      = dma_axis_slave0_tvalid;       // 浠庤澶?鏈夋晥淇″彿锛氭潵鑷狣MA鎺у埗鍣?assign axis_slave0_tlast       = dma_axis_slave0_tlast;        // 浠庤澶?鏈€鍚庢暟鎹細鏉ヨ嚜DMA鎺у埗鍣?assign axis_slave0_tuser       = dma_axis_slave0_tuser;        // 浠庤澶?鐢ㄦ埛淇″彿锛氭潵鑷狣MA鎺у埗鍣?assign axis_slave0_tdata       = dma_axis_slave0_tdata;        // 浠庤澶?鏁版嵁锛氭潵鑷狣MA鎺у埗鍣?
//===============================================================================
// AXI-Stream淇″彿杩炴帴锛氬皢PCIe IP鏍哥殑涓昏澶囨帴鍙ｈ繛鎺ュ埌DMA鎺у埗鍣?//===============================================================================
assign axis_master_tvalid_mem  = axis_master_tvalid;            // 涓昏澶囨湁鏁堜俊鍙凤細杩炴帴鍒癉MA鎺у埗鍣?assign axis_master_tdata_mem   = axis_master_tdata;             // 涓昏澶囨暟鎹細杩炴帴鍒癉MA鎺у埗鍣?assign axis_master_tkeep_mem   = axis_master_tkeep;            // 涓昏澶囨暟鎹湁鏁堝瓧鑺傦細杩炴帴鍒癉MA鎺у埗鍣?assign axis_master_tlast_mem   = axis_master_tlast;             // 涓昏澶囨渶鍚庢暟鎹細杩炴帴鍒癉MA鎺у埗鍣?assign axis_master_tuser_mem   = axis_master_tuser;             // 涓昏澶囩敤鎴蜂俊鍙凤細杩炴帴鍒癉MA鎺у埗鍣?
// 涓昏澶囧氨缁俊鍙凤細浠嶥MA鎺у埗鍣ㄥ弽棣堝埌PCIe IP鏍?assign axis_master_tready      = axis_master_tready_mem;



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
	.smlh_link_up				(smlh_link_up),			//link鐘舵€?	.rdlh_link_up				(rdlh_link_up),			//link鐘舵€?	.smlh_ltssm_state			(smlh_ltssm_state)
);



//===============================================================================
// DMA鍐欏湴鍧€寤惰繜鍜屽抚璇锋眰鎺у埗閫昏緫
//===============================================================================
// DMA鍐欏湴鍧€寤惰繜瀵勫瓨鍣細鐢ㄤ簬妫€娴嬪湴鍧€鍥炵粫锛堜竴甯у啓鍏ュ畬鎴愶級
reg  [11:0]  dma_write_addr_dly1;              // 寤惰繜涓€鎷?reg  [11:0]  dma_write_addr_dly2;              // 寤惰繜涓ゆ媿
// DMA鍐欏抚璁℃暟鍣細鐢ㄤ簬璁℃暟鍐欏叆鐨勫抚鏁帮紝姣忓畬鎴愪竴甯э紙720琛岋級鍙戦€佷竴娆¤璇锋眰
reg  [11:0]  dma_frame_write_cnt;              // 璁℃暟dma鍐欏叆鐨勫抚鏁帮紙720琛?甯э級

// DMA鍐欏湴鍧€寤惰繜锛氱敤浜庢娴嬪湴鍧€浠?x9f鍒?xa0鐨勮烦鍙橈紙琛ㄧず涓€甯у啓鍏ュ畬鎴愶級
always @(posedge pclk_div2) begin
    if (!core_rst_n) begin
        dma_write_addr_dly1 <= 12'd0;
        dma_write_addr_dly2 <= 12'd0;
    end else begin
        dma_write_addr_dly1 <= dma_write_addr;
        dma_write_addr_dly2 <= dma_write_addr_dly1;
    end
end

// DMA甯у啓鍏ヨ鏁板櫒锛氭娴嬪埌鍦板潃鍥炵粫鏃讹紙0x9f -> 0xa0锛夎鏁板姞1锛屽畬鎴?20甯у悗娓呴浂
always @(posedge pclk_div2) begin
    if (!core_rst_n) begin
        dma_frame_write_cnt <= 12'd0;
    end else if (dma_write_addr_dly1 == 12'ha0 && dma_write_addr_dly2 == 12'h9f) begin
        // 妫€娴嬪埌鍦板潃浠?x9f璺冲彉鍒?xa0锛岃〃绀哄畬鎴愪竴甯у啓鍏?        dma_frame_write_cnt <= dma_frame_write_cnt + 1'b1;
    end
    else if (dma_frame_write_cnt == 12'd720)begin
        // 瀹屾垚720甯у啓鍏ュ悗娓呴浂
        dma_frame_write_cnt <= 12'd0;
    end
    else begin
        dma_frame_write_cnt <= dma_frame_write_cnt;
    end
end

// 閫氶亾0璇诲抚璇锋眰鎺у埗锛氬畬鎴?20甯у啓鍏ュ悗锛屽彂閫佽甯ц姹?always @(posedge pclk_div2) begin
    if (!core_rst_n) begin
        ch0_read_frame_req <=1'b0;
    end else if (dma_frame_write_cnt == 12'd720) begin
       // 瀹屾垚720甯у啓鍏ワ紝鍙戦€佽甯ц姹?       ch0_read_frame_req <= 1'b1;
    end
    else if (ch0_read_req_ack) begin
        // 鏀跺埌璇昏姹傚簲绛斿悗锛屾竻闄よ姹備俊鍙?        ch0_read_frame_req <= 1'b0;
    end
    else begin
        ch0_read_frame_req <= ch0_read_frame_req;
    end
end

endmodule

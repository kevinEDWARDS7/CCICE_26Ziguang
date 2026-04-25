
`timescale 1ns / 1ps
`ifndef USE_PCIE_COLORBAR_TEST
`define USE_PCIE_COLORBAR_TEST 0
`endif



module dl_fpga_prj #(
    parameter MEM_ROW_WIDTH    = 15,
    parameter MEM_COLUMN_WIDTH = 10,
    parameter MEM_BANK_WIDTH   = 3,
    parameter MEM_DQ_WIDTH     = 16,
    parameter MEM_DQS_WIDTH    = 2
)(
    input                               sys_clk,
    input                               sys_rst_n,

    output                              ddr3_cs_n,
    output                              ddr3_rst_n,
    output                              ddr3_ck,
    output                              ddr3_ck_n,
    output                              ddr3_cke,
    output                              ddr3_ras_n,
    output                              ddr3_cas_n,
    output                              ddr3_we_n,
    output                              ddr3_odt,
    output      [MEM_ROW_WIDTH-1:0]     ddr3_a,
    output      [MEM_BANK_WIDTH-1:0]    ddr3_ba,
    inout       [MEM_DQ_WIDTH/8-1:0]    ddr3_dqs,
    inout       [MEM_DQ_WIDTH/8-1:0]    ddr3_dqs_n,
    inout       [MEM_DQ_WIDTH-1:0]      ddr3_dq,
    output      [MEM_DQ_WIDTH/8-1:0]    ddr3_dm,

    input                               hdmi_pix_clk,
    input                               hdmi_vs,
    input                               hdmi_hs,
    input                               hdmi_de,
    input       [7:0]                   hdmi_r,
    input       [7:0]                   hdmi_g,
    input       [7:0]                   hdmi_b,
    output                              hdmi_rx_init_done,
    inout                               hdmi_rx_scl,
    inout                               hdmi_rx_sda,

    input                               pcie_refclk_p,
    input                               pcie_refclk_n,
    input                               pcie_perst_n,
    input       [1:0]                   pcie_rxn,
    input       [1:0]                   pcie_rxp,
    output wire [1:0]                   pcie_txn,
    output wire [1:0]                   pcie_txp
);


assign hdmi_rgb565      = {hdmi_r[7:3], hdmi_g[7:2], hdmi_b[7:3]};
assign hdmi_video_rst_n = lock && ddr_init_done && hdmi_rx_init_done;
assign hdmi_rx_init_done = hdmi_rx_init_done_i;
assign hdmi_rx_scl      = (hdmi_scl_raw == 1'b0) ? 1'b0 : 1'bz;
assign hdmi_rx_sda      = (hdmi_sda_oe && (hdmi_sda_out == 1'b0)) ? 1'b0 : 1'bz;
assign hdmi_sda_in      = hdmi_rx_sda;

ms7200_ctl u_hdmi_rx_ms7200_ctl (
    .clk        (clk_10m),
    .rstn       (lock),
    .init_over  (hdmi_rx_init_done_i),
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
    .scl        (hdmi_scl_raw),
    .sda_in     (hdmi_sda_in),
    .sda_out    (hdmi_sda_out),
    .sda_out_en (hdmi_sda_oe)
);


parameter CTRL_ADDR_WIDTH = MEM_ROW_WIDTH + MEM_BANK_WIDTH + MEM_COLUMN_WIDTH;
parameter TH_1S = 27'd33000000;
parameter REM_DQS_WIDTH = 9 - MEM_DQS_WIDTH;


reg heart_beat_led;
reg pclk_led;
reg ref_led;


wire ddrphy_cpd_lock;
wire ddr_init_done /*synthesis PAP_MARK_DEBUG="1"*/;
wire pll_lock;
wire phy_pll_lock;
wire gpll_lock;
wire rst_gpll_lock;
wire core_clk;


wire [CTRL_ADDR_WIDTH-1:0]  axi_awaddr;
wire                        axi_awuser_ap;
wire [3:0]                  axi_awuser_id;
wire [3:0]                  axi_awlen;
wire                        axi_awready;
wire                        axi_awvalid;
wire [MEM_DQ_WIDTH*8-1:0]   axi_wdata;
wire [MEM_DQ_WIDTH*8/8-1:0] axi_wstrb;
wire                        axi_wready;
wire [3:0]                  axi_wusero_id;
wire                        axi_wusero_last;


wire [CTRL_ADDR_WIDTH-1:0]  axi_araddr;
wire                        axi_aruser_ap;
wire [3:0]                  axi_aruser_id;
wire [3:0]                  axi_arlen;
wire                        axi_arready;
wire                        axi_arvalid;
wire [MEM_DQ_WIDTH*8-1:0]   axi_rdata  /* synthesis syn_keep = 1 */;
wire                        axi_rvalid /* synthesis syn_keep = 1 */;
wire [3:0]                  axi_rid;
wire                        axi_rlast;


wire resetn;
reg  [26:0] cnt;
wire [7:0]  err_cnt;
wire        free_clk_g;


wire [15:0] o_rgb565;
wire        pclk_in_test;
wire        vs_in_test;
wire        de_in_test;
wire [15:0] i_rgb565;
wire        pclk_in_test_2;
wire        vs_in_test_2;
wire        de_in_test_2;
wire [15:0] i_rgb565_2;
wire [15:0] fmc_rgb565;
wire        fmc_pclk;
wire        fmc_vs;
wire        fmc_de;
wire [15:0] hdmi_rgb565;
wire        hdmi_video_rst_n;


wire        hdmi_iic_trig;
wire        hdmi_iic_wr;
wire [15:0] hdmi_iic_addr;
wire [7:0]  hdmi_iic_wdata;
wire [7:0]  hdmi_iic_rdata;
wire [7:0]  hdmi_iic_device_id;
wire        hdmi_iic_busy;
wire        hdmi_iic_byte_over;
wire        hdmi_sda_in;
wire        hdmi_sda_out;
wire        hdmi_sda_oe;
wire        hdmi_scl_raw              /*synthesis PAP_MARK_DEBUG="1"*/;
wire        hdmi_rx_init_done_i       /*synthesis PAP_MARK_DEBUG="1"*/;


wire lock;
wire clk_10m;
wire clk_25m;
wire clk_50m;


localparam DEVICE_TYPE = 3'b000;
localparam AXIS_SLAVE_NUM = 3;


wire        pcie_cfg_ctrl_en;
wire        axis_master_tready_cfg;
wire        cfg_axis_slave0_tvalid;
wire [127:0] cfg_axis_slave0_tdata;
wire        cfg_axis_slave0_tlast;
wire        cfg_axis_slave0_tuser;

wire        axis_master_tready_mem;
wire        axis_master_tvalid_mem;
wire [127:0] axis_master_tdata_mem;
wire [3:0]  axis_master_tkeep_mem;
wire        axis_master_tlast_mem;
wire [7:0]  axis_master_tuser_mem;

wire        cross_4kb_boundary;
wire        dma_axis_slave0_tvalid;
wire [127:0] dma_axis_slave0_tdata;
wire        dma_axis_slave0_tlast;
wire        dma_axis_slave0_tuser;


wire        sync_button_rst_n;
wire        ref_core_rst_n;
wire        sync_perst_n;
wire        s_pclk_rstn;


wire        pclk_div2 /*synthesis PAP_MARK_DEBUG="1"*/;
wire        pclk      /*synthesis PAP_MARK_DEBUG="1"*/;
wire        ref_clk;
wire        core_rst_n;


wire        axis_master_tvalid;
wire        axis_master_tready;
wire [127:0] axis_master_tdata;
wire [3:0]  axis_master_tkeep;
wire        axis_master_tlast;
wire [7:0]  axis_master_tuser;


wire        axis_slave0_tready;
wire        axis_slave0_tvalid;
wire [127:0] axis_slave0_tdata;
wire        axis_slave0_tlast;
wire        axis_slave0_tuser;
wire        axis_slave1_tready;
wire        axis_slave1_tvalid;
wire [127:0] axis_slave1_tdata;
wire        axis_slave1_tlast;
wire        axis_slave1_tuser;
wire        axis_slave2_tready;
wire        axis_slave2_tvalid;
wire [127:0] axis_slave2_tdata;
wire        axis_slave2_tlast;
wire        axis_slave2_tuser;


wire [7:0] cfg_pbus_num;
wire [4:0] cfg_pbus_dev_num;
wire [2:0] cfg_max_rd_req_size;
wire [2:0] cfg_max_payload_size;
wire       cfg_rcb;
wire       cfg_ido_req_en;
wire       cfg_ido_cpl_en;
wire [7:0]  xadm_ph_cdts;
wire [11:0] xadm_pd_cdts;
wire [7:0]  xadm_nph_cdts;
wire [11:0] xadm_npd_cdts;
wire [7:0]  xadm_cplh_cdts;
wire [11:0] xadm_cpld_cdts;


wire [4:0] smlh_ltssm_state /*synthesis PAP_MARK_DEBUG="1"*/;
reg  [22:0] ref_led_cnt;
reg  [26:0] pclk_led_cnt;
wire        smlh_link_up;
wire        rdlh_link_up;


wire        uart_p_sel;
wire [3:0]  uart_p_strb;
wire [15:0] uart_p_addr;
wire [31:0] uart_p_wdata;
wire        uart_p_ce;
wire        uart_p_we;
wire        uart_p_rdy;
wire [31:0] uart_p_rdata;


wire [3:0]  p_strb;
wire [15:0] p_addr;
wire [31:0] p_wdata;
wire        p_ce;
wire        p_we;
wire        p_sel_pcie;
wire        p_sel_cfg;
wire        p_sel_dma;
wire [31:0] p_rdata_pcie;
wire [31:0] p_rdata_cfg;
wire [31:0] p_rdata_dma;
wire        p_rdy_pcie;
wire        p_rdy_cfg;
wire        p_rdy_dma;


wire          ch0_write_data_valid;
wire [15:0]   ch0_write_data;
reg           ch0_read_frame_req;
wire          ch0_read_req_ack;
wire          ch0_read_data_en /*synthesis PAP_MARK_DEBUG="1"*/;
wire  [127:0] ch0_read_data    /*synthesis PAP_MARK_DEBUG="1"*/;
wire          ch0_read_data_valid;
wire          ch1_write_data_valid;
wire [15:0]   ch1_write_data;
reg           ch1_read_frame_req;
wire          ch1_read_req_ack;
wire          ch1_read_data_en;
wire  [127:0] ch1_read_data;
wire          ch1_read_data_valid;
wire          ch2_write_data_valid;
wire [15:0]   ch2_write_data;
reg           ch2_read_frame_req;
wire          ch2_read_req_ack;
wire          ch2_read_data_en;
wire  [127:0] ch2_read_data;
wire          ch2_read_data_valid;
wire          ch3_write_data_valid;
wire [15:0]   ch3_write_data;
reg           ch3_read_frame_req;
wire          ch3_read_req_ack;
wire          ch3_read_data_en;
wire  [127:0] ch3_read_data;
wire          ch3_read_data_valid;


wire          dma_write_req /*synthesis PAP_MARK_DEBUG="1"*/;
wire [11:0]   dma_write_addr;
wire [127:0]  dma_write_data;


wire          ch0_line_full_flag /*synthesis PAP_MARK_DEBUG="1"*/;
wire          ch1_line_full_flag;
wire          ch2_line_full_flag;
wire          ch3_line_full_flag;
wire [11:0]   debug_read_line_index /*synthesis PAP_MARK_DEBUG="1"*/;
wire [11:0]   debug_read_beat_index /*synthesis PAP_MARK_DEBUG="1"*/;
wire [31:0]   debug_dma_req_line_count /*synthesis PAP_MARK_DEBUG="1"*/;
wire [31:0]   debug_dma_req_beat_count /*synthesis PAP_MARK_DEBUG="1"*/;
wire [31:0]   debug_dma_underflow_count /*synthesis PAP_MARK_DEBUG="1"*/;
wire [31:0]   debug_dma_zero_output_count /*synthesis PAP_MARK_DEBUG="1"*/;
wire [31:0]   debug_ch0_data_nonzero_count /*synthesis PAP_MARK_DEBUG="1"*/;
wire          debug_read_frame_active /*synthesis PAP_MARK_DEBUG="1"*/;
reg  [31:0]   hdmi_pix_clk_alive       /*synthesis PAP_MARK_DEBUG="1"*/;
reg  [31:0]   hdmi_vs_counter          /*synthesis PAP_MARK_DEBUG="1"*/;
reg  [31:0]   hdmi_hs_counter          /*synthesis PAP_MARK_DEBUG="1"*/;
reg  [31:0]   hdmi_de_pixel_counter    /*synthesis PAP_MARK_DEBUG="1"*/;
reg  [31:0]   hdmi_rgb_nonzero_counter /*synthesis PAP_MARK_DEBUG="1"*/;
reg  [31:0]   hdmi_frame_count         /*synthesis PAP_MARK_DEBUG="1"*/;
reg           hdmi_vs_d0;
reg           hdmi_vs_d1;
reg           hdmi_hs_d0;
reg           hdmi_hs_d1;
assign     pclk_in_test    = hdmi_pix_clk;
assign     vs_in_test      = hdmi_vs;
assign     de_in_test      = hdmi_de;
assign     i_rgb565        = hdmi_rgb565;
assign     pclk_in_test_2  = hdmi_pix_clk;
assign     vs_in_test_2    = hdmi_vs;
assign     de_in_test_2    = hdmi_de;
assign     i_rgb565_2      = hdmi_rgb565;
assign     fmc_pclk        = hdmi_pix_clk;
assign     fmc_vs          = hdmi_vs;
assign     fmc_de          = hdmi_de;
assign     fmc_rgb565      = hdmi_rgb565;


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


always @(posedge core_clk or negedge ddr_init_done) begin
   if (!ddr_init_done) begin
      cnt <= 27'd0;
   end
   else if (cnt >= TH_1S) begin
      cnt <= 27'd0;
   end
   else begin
      cnt <= cnt + 27'd1;
   end
end

always @(posedge core_clk or negedge ddr_init_done)
begin
   if (!ddr_init_done)
      heart_beat_led <= 1'b1;
   else if (cnt >= TH_1S)
      heart_beat_led <= ~heart_beat_led;
end








ddr3 #(
    .MEM_ROW_WIDTH              (MEM_ROW_WIDTH                ),
    .MEM_COLUMN_WIDTH           (MEM_COLUMN_WIDTH             ),
    .MEM_BANK_WIDTH             (MEM_BANK_WIDTH               ),
    .MEM_DQ_WIDTH               (MEM_DQ_WIDTH                 ),
    .MEM_DM_WIDTH               (MEM_DQS_WIDTH                ),
    .MEM_DQS_WIDTH              (MEM_DQS_WIDTH                ),
    .CTRL_ADDR_WIDTH            (CTRL_ADDR_WIDTH              )
  )dl_I_ips_ddr_top(
    .ref_clk                    (sys_clk                     ),
    .resetn                     (sys_rst_n                   ),
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


    .apb_clk                    (1'b0                         ),
    .apb_rst_n                  (1'b0                         ),
    .apb_sel                    (1'b0                         ),
    .apb_enable                 (1'b0                         ),
    .apb_addr                   (8'd0                         ),


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





    .dbg_gate_start             (1'b0                         ),
    .dbg_cpd_start              (1'b0                         ),
    .dbg_ddrphy_rst_n           (1'b1                         ),
    .dbg_gpll_scan_rst          (1'b0                         ),


    .samp_position_dyn_adj      (1'b0                         ),
    .init_samp_position_odd     (16'd0                        ),


    .wrcal_position_dyn_adj     (1'b0                         ),
    .init_wrcal_position        (16'd0                        ),


    .force_read_clk_ctrl        (1'b0                         ),
    .init_read_clk_ctrl         (6'd0                         ),


    .debug_calib_ctrl           (                             ),
    .dbg_dll_upd_state          (                             ),
    .dbg_slice_status           (                             ),
    .dbg_slice_state            (                             ),

    .dbg_tran_err_rst_cnt       (                             ),
    .debug_cpd_offset_adj       (1'b0                         ),
    .debug_cpd_offset_dir       (1'b0                         ),
    .debug_cpd_offset           (10'd0                        ),
    .ck_dly_en                  (1'b0                         ),
    .init_ck_dly_step           (8'd0                         ),
    .ck_dly_set_bin             (                             ),
    .align_error                (                             ),
    .debug_rst_state            (                             ),
    .debug_cpd_state            (                             )

  );




always @(posedge hdmi_pix_clk) begin
    if (!lock) begin
        hdmi_pix_clk_alive <= 32'd0;
        hdmi_vs_counter <= 32'd0;
        hdmi_hs_counter <= 32'd0;
        hdmi_de_pixel_counter <= 32'd0;
        hdmi_rgb_nonzero_counter <= 32'd0;
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
            if (hdmi_rgb565 != 16'd0) begin
                hdmi_rgb_nonzero_counter <= hdmi_rgb_nonzero_counter + 32'd1;
            end
        end

        if (hdmi_hs_d0 && !hdmi_hs_d1) begin
            hdmi_hs_counter <= hdmi_hs_counter + 32'd1;
        end
    end
end


img_data_stream_reducer dl_ch0_image_reshape(
    .clk                    (hdmi_pix_clk               ),
    .rst_n                  (hdmi_video_rst_n           ),

    .img_vs                 (hdmi_vs                    ),
    .img_data_valid         (hdmi_de                    ),
    .img_data               (hdmi_rgb565                ),
   
    .img_data_valid_out     (ch0_write_data_valid       ),
    .img_data_out           (ch0_write_data             )
);


img_data_stream_reducer dl_ch1_image_reshape(
    .clk                    (pclk_in_test),
    .rst_n                  (hdmi_video_rst_n),
    .img_vs                 (vs_in_test),
    .img_data_valid         (de_in_test),
    .img_data               (i_rgb565),
    .img_data_valid_out     (ch1_write_data_valid),
    .img_data_out           (ch1_write_data)
);

img_data_stream_reducer dl_ch2_image_reshape(
    .clk                    (pclk_in_test_2),
    .rst_n                  (hdmi_video_rst_n),
    .img_vs                 (vs_in_test_2),
    .img_data_valid         (de_in_test_2),
    .img_data               (i_rgb565_2),
    .img_data_valid_out     (ch2_write_data_valid),
    .img_data_out           (ch2_write_data)
);

img_data_stream_reducer dl_ch3_image_reshape(
    .clk                    (fmc_pclk),
    .rst_n                  (hdmi_video_rst_n),
    .img_vs                 (fmc_vs),
    .img_data_valid         (fmc_de),
    .img_data               (fmc_rgb565),
    .img_data_valid_out     (ch3_write_data_valid),
    .img_data_out           (ch3_write_data)
);



pcie_image_channel_selector dl_pcie_img_select_inst(
    .clk                         (pclk_div2),
    .rst_n                       (core_rst_n),
    .dma_sim_vs                  (ch0_read_frame_req),
    .line_full_flag              (ch0_line_full_flag),
    .ch0_data_req                (ch0_read_data_en),
    .ch0_data                    (ch0_read_data),
    .ch1_data_req                (ch1_read_data_en),
    .ch1_data                    (ch1_read_data),
    .ch2_data_req                (ch2_read_data_en),
    .ch2_data                    (ch2_read_data),
    .ch3_data_req                (ch3_read_data_en),
    .ch3_data                    (ch3_read_data),
    .dma_wr_data_req             (dma_write_req),
    .dma_wr_data                 (dma_write_data),
    .debug_read_line_index       (debug_read_line_index),
    .debug_read_beat_index       (debug_read_beat_index),
    .debug_dma_req_line_count    (debug_dma_req_line_count),
    .debug_dma_req_beat_count    (debug_dma_req_beat_count),
    .debug_dma_underflow_count   (debug_dma_underflow_count),
    .debug_dma_zero_output_count (debug_dma_zero_output_count),
    .debug_ch0_data_nonzero_count(debug_ch0_data_nonzero_count),
    .debug_read_frame_active     (debug_read_frame_active)
);


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


      .key                         ({1'b1,3'b111,4'b0000}                     ),


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



always @(posedge ref_clk or negedge sync_perst_n) begin
	if (!sync_perst_n) begin
        ref_led_cnt <= 23'd0;
		ref_led <= 1'b1;
	end else if (smlh_link_up & rdlh_link_up) begin

		ref_led_cnt <= ref_led_cnt + 23'd1;
		if(&ref_led_cnt)
			ref_led <= ~ref_led;
	end
end



always @(posedge pclk or negedge s_pclk_rstn) begin
	if (!s_pclk_rstn) begin
        pclk_led_cnt <= 27'd0;
		pclk_led <= 1'b1;
	end else if (smlh_link_up & rdlh_link_up) begin

		pclk_led_cnt <= pclk_led_cnt + 27'd1;
		if(&pclk_led_cnt)
			pclk_led <= ~pclk_led;
	end
end






pcie_dma_core #(
	.DEVICE_TYPE			(DEVICE_TYPE),
	.AXIS_SLAVE_NUM			(AXIS_SLAVE_NUM)
) dl_u_ips2l_pcie_dma (
    .clk                    (pclk_div2),
    .rst_n                  (core_rst_n),


	.i_cfg_pbus_num			(cfg_pbus_num),				
	.i_cfg_pbus_dev_num		(cfg_pbus_dev_num),			
	.i_cfg_max_rd_req_size	(cfg_max_rd_req_size),		
	.i_cfg_max_payload_size	(cfg_max_payload_size),		


	.i_axis_master_tvld		(axis_master_tvalid_mem),	
	.o_axis_master_trdy		(axis_master_tready_mem),	
	.i_axis_master_tdata	(axis_master_tdata_mem),	
	.i_axis_master_tkeep	(axis_master_tkeep_mem),	
														
	.i_axis_master_tlast	(axis_master_tlast_mem),	
	.i_axis_master_tuser	(axis_master_tuser_mem),	


	.i_axis_slave0_trdy		(axis_slave0_tready),		
	.o_axis_slave0_tvld		(dma_axis_slave0_tvalid),	
	.o_axis_slave0_tdata	(dma_axis_slave0_tdata),	
	.o_axis_slave0_tlast	(dma_axis_slave0_tlast),	
	.o_axis_slave0_tuser	(dma_axis_slave0_tuser),	


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


	.i_cfg_ido_req_en		(cfg_ido_req_en),			
	.i_cfg_ido_cpl_en		(cfg_ido_cpl_en),			
	.i_xadm_ph_cdts			(xadm_ph_cdts),				
	.i_xadm_pd_cdts			(xadm_pd_cdts),				
	.i_xadm_nph_cdts		(xadm_nph_cdts),			
	.i_xadm_npd_cdts		(xadm_npd_cdts),			
	.i_xadm_cplh_cdts		(xadm_cplh_cdts),			
	.i_xadm_cpld_cdts		(xadm_cpld_cdts),			


	.i_apb_psel				(p_sel_dma),				
	.i_apb_paddr			(p_addr[8:0]),				
	.i_apb_pwdata			(p_wdata),					
	.i_apb_pstrb			(p_strb),					
	.i_apb_pwrite			(p_we),						
	.i_apb_penable			(p_ce),						
	.o_apb_prdy				(p_rdy_dma),				
	.o_apb_prdata			(p_rdata_dma),				
	.o_cross_4kb_boundary	(cross_4kb_boundary),


    .o_dma_write_data_req   (dma_write_req  ),
    .o_dma_write_addr       (dma_write_addr      ),
    .i_dma_write_data       (dma_write_data      )
);





assign p_rdy_cfg              = 1'b0;
assign p_rdata_cfg            = 32'b0;
assign axis_slave0_tvalid     = dma_axis_slave0_tvalid;
assign axis_slave0_tlast      = dma_axis_slave0_tlast;
assign axis_slave0_tuser      = dma_axis_slave0_tuser;
assign axis_slave0_tdata      = dma_axis_slave0_tdata;
assign axis_master_tvalid_mem = axis_master_tvalid;
assign axis_master_tdata_mem  = axis_master_tdata;
assign axis_master_tkeep_mem  = axis_master_tkeep;
assign axis_master_tlast_mem  = axis_master_tlast;
assign axis_master_tuser_mem  = axis_master_tuser;
assign axis_master_tready     = axis_master_tready_mem;




pcie_test dl_u_ips2l_pcie_wrap (
	.button_rst_n				(1'b1),	
	.power_up_rst_n				(1'b1),			
	.perst_n					(1'b1),			


	.pclk						(pclk),					
	.pclk_div2					(pclk_div2),			
	.ref_clk					(ref_clk),				
	.ref_clk_n					(pcie_refclk_n),			
	.ref_clk_p					(pcie_refclk_p),			
	.core_rst_n					(core_rst_n),			


	.p_sel						(p_sel_pcie),			
	.p_strb						(uart_p_strb),			
	.p_addr						(uart_p_addr),			
	.p_wdata					(uart_p_wdata),			
	.p_ce						(uart_p_ce),			
	.p_we						(uart_p_we),			
	.p_rdy						(p_rdy_pcie),			
	.p_rdata					(p_rdata_pcie),			


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

	.pm_xtlh_block_tlp			(),						

	.cfg_send_cor_err_mux		(),						
	.cfg_send_nf_err_mux		(),						
	.cfg_send_f_err_mux			(),						
	.cfg_sys_err_rc				(),						
	.cfg_aer_rc_err_mux			(),						


	.radm_cpl_timeout			(),						


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


	.smlh_link_up				(smlh_link_up),
	.rdlh_link_up				(rdlh_link_up),
	.smlh_ltssm_state			(smlh_ltssm_state)
);






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


`timescale 1ns / 1ps

module HDMI_IN_DDR3_mid_filter_top (
    // ==========================================
    // 1. 系统时钟与复位
    // ==========================================
    input  wire        clk_p,           // 125MHz
    input  wire        clk_n,
    input  wire        rst_n,

    // ==========================================
    // 2. PCIe 接口 (纯血 484 封装)
    // ==========================================
    input  wire        pcie_refclk_p,
    input  wire        pcie_refclk_n,
    input  wire        pcie_rx_p,
    input  wire        pcie_rx_n,
    output wire        pcie_tx_p,
    output wire        pcie_tx_n,

    // ==========================================
    // 3. 视频输入及配置接口 (MS72xx)
    // ==========================================
    input  wire        pixclk_in,
    input  wire        vs_in,
    input  wire        hs_in,
    input  wire        de_in,
    input  wire [7:0]  r_in,
    input  wire [7:0]  g_in,
    input  wire [7:0]  b_in,

    output wire        rstn_out,
    inout  wire        hd_scl,
    inout  wire        hd_sda
);

    // =========================================================
    // 全局主时钟入口 
    // =========================================================
    wire clk_125Mhz;
    GTP_INBUFGDS #(
        .IOSTANDARD("DEFAULT"),
        .TERM_DIFF("ON")
    ) u_gtp (
        .O(clk_125Mhz), 
        .I(clk_p),      
        .IB(clk_n)      
    );

    // ==========================================
    // HDMI IN 配置模块工作时钟 & I2C 控制
    // ==========================================
    wire cfg_clk;
    cfg_pll cfg_pll_inst (
        .clkout0(cfg_clk), 
        .lock   (), 
        .clkin1 (clk_125Mhz) 
    );

    wire rx_init_done;
    wire init_over;
    ms72xx_ctl ms72xx_ctl(
        .clk          (cfg_clk), 
        .rst_n        (rstn_out), 
        .init_over_rx (rx_init_done), 
        .init_over    (init_over), 
        .iic_scl      (hd_scl), 
        .iic_sda      (hd_sda) 
    );

    wire locked = 1'b1; // 假锁相，因为我们不用后面的PLL了
    
    reg [15:0] rstn_1ms; 
    always @(posedge cfg_clk) begin
        if(!locked) rstn_1ms <= 16'd0;
        else begin
            if(rstn_1ms == 16'h2710) rstn_1ms <= rstn_1ms;
            else rstn_1ms <= rstn_1ms + 1'b1;
        end
    end
    assign rstn_out = (rstn_1ms == 16'h2710); 

    // 系统全局复位同步化
    reg rst_reg;
    always @(posedge clk_125Mhz) begin  
        if (~rst_n) rst_reg <= 1'b1;
        else        rst_reg <= 1'b0;
    end

    // =========================================================
    // 👇【算法暗线】：特征提取与坐标定位 (纯后台运算)
    // =========================================================

    // 1. 灰度化
    wire y_vs, y_hs, y_de;
    wire [7:0] y_data;
    RGB2YCbCr RGB2YCbCr_inst (
        .clk        (pixclk_in),  
        .rst_n      (rstn_out),   
        .vsync_in   (vs_in),      
        .hsync_in   (hs_in),      
        .de_in      (de_in),      
        .red        (r_in[7:3]),  
        .green      (g_in[7:2]),  
        .blue       (b_in[7:3]),  
        .vsync_out  (y_vs),       
        .hsync_out  (y_hs),       
        .de_out     (y_de),       
        .y          (y_data),     
        .cb         (), .cr ()            
    );

    // 提取 Vsync 下降沿
    reg y_vs_r;
    always @(posedge pixclk_in) y_vs_r <= y_vs;
    wire y_vs_falling = (~y_vs & y_vs_r);

    // 自适应环境光引擎
    reg [31:0] lum_sum; 
    reg [7:0]  avg_lum; 
    reg [7:0]  dynamic_sobel;
    always @(posedge pixclk_in or negedge rstn_out) begin
        if (!rstn_out) begin
            lum_sum <= 0; avg_lum <= 0; dynamic_sobel <= 8'd80; 
        end else if (y_vs_falling) begin 
            avg_lum <= lum_sum[27:20]; 
            lum_sum <= 0;
            if      (avg_lum > 8'd160) dynamic_sobel <= 8'd160; 
            else if (avg_lum > 8'd100) dynamic_sobel <= 8'd80;  
            else if (avg_lum > 8'd50)  dynamic_sobel <= 8'd55;  
            else                       dynamic_sobel <= 8'd47;  
        end else if (y_de) begin
            lum_sum <= lum_sum + y_data; 
        end
    end

    // 2. 高斯滤波
    wire matrix_de;
    wire [7:0] m11, m12, m13, m21, m22, m23, m31, m32, m33;
    matrix_3x3 #(.IMG_WIDTH(16'd1280), .IMG_HEIGHT(16'd720)) u_matrix_3x3 (
        .video_clk(pixclk_in), .rst_n(rstn_out), .video_vs(y_vs), .video_de(y_de), .video_data(y_data),
        .matrix_de(matrix_de), .matrix11(m11), .matrix12(m12), .matrix13(m13),
        .matrix21(m21), .matrix22(m22), .matrix23(m23), .matrix31(m31), .matrix32(m32), .matrix33(m33)
    );

    wire [7:0] gauss_data;
    wire gauss_vs, gauss_de, gauss_hs;
    gauss_filter u_gauss_filter(
        .video_clk(pixclk_in), .rst_n(rstn_out), .matrix_de(matrix_de), .matrix_vs(y_vs),
        .matrix11(m11), .matrix12(m12), .matrix13(m13), .matrix21(m21), .matrix22(m22), .matrix23(m23), .matrix31(m31), .matrix32(m32), .matrix33(m33),
        .gauss_filter_vs(gauss_vs), .gauss_filter_de(gauss_de), .gauss_filter_hs(gauss_hs), .gauss_filter_data(gauss_data)
    );

    // 3. Sobel 边缘检测
    wire sobel_matrix_de;
    wire [7:0] sm11, sm12, sm13, sm21, sm22, sm23, sm31, sm32, sm33;
    matrix_3x3 #(.IMG_WIDTH(16'd1280), .IMG_HEIGHT(16'd720)) u_matrix_3x3_sobel (
        .video_clk(pixclk_in), .rst_n(rstn_out), .video_vs(gauss_vs), .video_de(gauss_de), .video_data(gauss_data),
        .matrix_de(sobel_matrix_de), .matrix11(sm11), .matrix12(sm12), .matrix13(sm13),
        .matrix21(sm21), .matrix22(sm22), .matrix23(sm23), .matrix31(sm31), .matrix32(sm32), .matrix33(sm33)
    );

    reg [1:0] hs_delay_for_sobel;
    always @(posedge pixclk_in) hs_delay_for_sobel <= {hs_delay_for_sobel[0], gauss_hs}; 
    wire aligned_hs_for_sobel = hs_delay_for_sobel[1];

    wire [7:0] sobel_data;
    wire sobel_vs, sobel_de;
    sobel u_sobel_pipeline (
        .threshold(dynamic_sobel), .video_clk(pixclk_in), .rst_n(rstn_out), .matrix_de(sobel_matrix_de), .matrix_vs(gauss_vs), 
        .matrix11(sm11), .matrix12(sm12), .matrix13(sm13), .matrix21(sm21), .matrix22(sm22), .matrix23(sm23), .matrix31(sm31), .matrix32(sm32), .matrix33(sm33),
        .sobel_vs(sobel_vs), .sobel_de(sobel_de), .sobel_data(sobel_data)
    );
    
    reg [1:0] hs_delay_bypass_sobel;
    always @(posedge pixclk_in) hs_delay_bypass_sobel <= {hs_delay_bypass_sobel[0], aligned_hs_for_sobel}; 
    wire sobel_hs = hs_delay_bypass_sobel[1];

    // 4. 二值化 & 1D 局部密度滤镜
    wire bin_vs, bin_hs, bin_de, bin_data;
    binarization u_binarization(
        .clk(pixclk_in), .rst_n(rstn_out), .vsync_in(sobel_vs), .hsync_in(sobel_hs), .de_in(sobel_de), .y_in(sobel_data), 
        .vsync_out(bin_vs), .hsync_out(bin_hs), .de_out(bin_de), .pix(bin_data) 
    );

    reg [4:0] pixel_shift; 
    reg [1:0] c_bin_de_d, c_bin_vs_d, c_bin_hs_d;
    always @(posedge pixclk_in) begin 
        c_bin_de_d <= {c_bin_de_d[0], bin_de}; c_bin_vs_d <= {c_bin_vs_d[0], bin_vs}; c_bin_hs_d <= {c_bin_hs_d[0], bin_hs};
        pixel_shift <= {pixel_shift[3:0], bin_data}; 
    end
    wire clean_bin_de = c_bin_de_d[1], clean_bin_vs = c_bin_vs_d[1], clean_bin_hs = c_bin_hs_d[1];
    wire [2:0] ones_count = pixel_shift[4] + pixel_shift[3] + pixel_shift[2] + pixel_shift[1] + pixel_shift[0];
    wire clean_bin_data = pixel_shift[2] && (ones_count >= 3'd4);

    // 5. 一次膨胀
    wire m_de_1b, m11_1b, m12_1b, m13_1b, m21_1b, m22_1b, m23_1b, m31_1b, m32_1b, m33_1b;
    matrix_3x3_1bit #(.IMG_WIDTH(16'd1280), .IMG_HEIGHT(16'd720)) u_matrix_1b (
        .video_clk(pixclk_in), .rst_n(rstn_out), .video_vs(clean_bin_vs), .video_de(clean_bin_de), .video_data(clean_bin_data), 
        .matrix_de(m_de_1b), .matrix11(m11_1b), .matrix12(m12_1b), .matrix13(m13_1b), .matrix21(m21_1b), .matrix22(m22_1b), .matrix23(m23_1b), .matrix31(m31_1b), .matrix32(m32_1b), .matrix33(m33_1b)
    );

    reg [1:0] m1_vs_d, m1_hs_d;
    always @(posedge pixclk_in) begin m1_vs_d <= {m1_vs_d[0], clean_bin_vs}; m1_hs_d <= {m1_hs_d[0], clean_bin_hs}; end
    
    wire dilate1_vs, dilate1_de, dilate1_data;
    dilate u_dilate_1 (
        .video_clk(pixclk_in), .rst_n(rstn_out), .bin_vs(m1_vs_d[1]), .bin_de(m_de_1b), 
        .bin_data_11(m11_1b), .bin_data_12(m12_1b), .bin_data_13(m13_1b), .bin_data_21(m21_1b), .bin_data_22(m22_1b), .bin_data_23(m23_1b), .bin_data_31(m31_1b), .bin_data_32(m32_1b), .bin_data_33(m33_1b),
        .dilate_vs(dilate1_vs), .dilate_de(dilate1_de), .dilate_data(dilate1_data)
    );

    // 6. 投影定位与防抖 (求解坐标)
    wire [11:0] bx_min1, bx_max1, by_min1, by_max1, bx_min2, bx_max2, by_min2, by_max2, bx_min3, bx_max3, by_min3, by_max3;
    projection u_projection (
        .video_clk(pixclk_in), .rst_n(rstn_out), .video_vs(dilate1_vs), .video_de(dilate1_de), .video_data(dilate1_data), 
        .x_min_1(bx_min1), .x_max_1(bx_max1), .y_min_1(by_min1), .y_max_1(by_max1),
        .x_min_2(bx_min2), .x_max_2(bx_max2), .y_min_2(by_min2), .y_max_2(by_max2),
        .x_min_3(bx_min3), .x_max_3(bx_max3), .y_min_3(by_min3), .y_max_3(by_max3)
    );

    reg dilate1_vs_r; always @(posedge pixclk_in) dilate1_vs_r <= dilate1_vs;
    wire frame_end_trigger = (~dilate1_vs & dilate1_vs_r);

    reg [11:0] st_x_min1, st_x_max1, st_y_min1, st_y_max1, st_x_min2, st_x_max2, st_y_min2, st_y_max2, st_x_min3, st_x_max3, st_y_min3, st_y_max3;
    reg [4:0] b1_life, b2_life, b3_life; 
    parameter MAX_LIFE = 5'd10, DEADZONE = 12'd4, PAD_Y = 12'd10, PAD_X = 12'd15, MAX_X = 12'd1279, MAX_Y = 12'd719; 

    // 通道1防抖
    always @(posedge pixclk_in) begin
        if (frame_end_trigger) begin
            if (bx_max1 > bx_min1) begin
                b1_life <= MAX_LIFE;
                if ((bx_min1 > st_x_min1 ? bx_min1 - st_x_min1 : st_x_min1 - bx_min1) > DEADZONE) st_x_min1 <= bx_min1;
                if ((bx_max1 > st_x_max1 ? bx_max1 - st_x_max1 : st_x_max1 - bx_max1) > DEADZONE) st_x_max1 <= bx_max1;
                if ((by_min1 > st_y_min1 ? by_min1 - st_y_min1 : st_y_min1 - by_min1) > DEADZONE) st_y_min1 <= by_min1;
                if ((by_max1 > st_y_max1 ? by_max1 - st_y_max1 : st_y_max1 - by_max1) > DEADZONE) st_y_max1 <= by_max1;
            end else if (b1_life > 0) b1_life <= b1_life - 1'b1;
            else begin st_x_min1 <= 0; st_x_max1 <= 0; st_y_min1 <= 0; st_y_max1 <= 0; end
        end
    end
    
    // 通道2防抖
    always @(posedge pixclk_in) begin
        if (frame_end_trigger) begin
            if (bx_max2 > bx_min2) begin
                b2_life <= MAX_LIFE;
                if ((bx_min2 > st_x_min2 ? bx_min2 - st_x_min2 : st_x_min2 - bx_min2) > DEADZONE) st_x_min2 <= bx_min2;
                if ((bx_max2 > st_x_max2 ? bx_max2 - st_x_max2 : st_x_max2 - bx_max2) > DEADZONE) st_x_max2 <= bx_max2;
                if ((by_min2 > st_y_min2 ? by_min2 - st_y_min2 : st_y_min2 - by_min2) > DEADZONE) st_y_min2 <= by_min2;
                if ((by_max2 > st_y_max2 ? by_max2 - st_y_max2 : st_y_max2 - by_max2) > DEADZONE) st_y_max2 <= by_max2;
            end else if (b2_life > 0) b2_life <= b2_life - 1'b1;
            else begin st_x_min2 <= 0; st_x_max2 <= 0; st_y_min2 <= 0; st_y_max2 <= 0; end
        end
    end

    // 通道3防抖
    always @(posedge pixclk_in) begin
        if (frame_end_trigger) begin
            if (bx_max3 > bx_min3) begin
                b3_life <= MAX_LIFE;
                if ((bx_min3 > st_x_min3 ? bx_min3 - st_x_min3 : st_x_min3 - bx_min3) > DEADZONE) st_x_min3 <= bx_min3;
                if ((bx_max3 > st_x_max3 ? bx_max3 - st_x_max3 : st_x_max3 - bx_max3) > DEADZONE) st_x_max3 <= bx_max3;
                if ((by_min3 > st_y_min3 ? by_min3 - st_y_min3 : st_y_min3 - by_min3) > DEADZONE) st_y_min3 <= by_min3;
                if ((by_max3 > st_y_max3 ? by_max3 - st_y_max3 : st_y_max3 - by_max3) > DEADZONE) st_y_max3 <= by_max3;
            end else if (b3_life > 0) b3_life <= b3_life - 1'b1;
            else begin st_x_min3 <= 0; st_x_max3 <= 0; st_y_min3 <= 0; st_y_max3 <= 0; end
        end
    end

    // 外扩
    wire [11:0] f_xmin1 = (st_x_min1 > PAD_X) ? (st_x_min1 - PAD_X) : 12'd0; wire [11:0] f_xmax1 = ((st_x_max1 + PAD_X) < MAX_X) ? (st_x_max1 + PAD_X) : MAX_X;
    wire [11:0] f_ymin1 = (st_y_min1 > PAD_Y) ? (st_y_min1 - PAD_Y) : 12'd0; wire [11:0] f_ymax1 = ((st_y_max1 + PAD_Y) < MAX_Y) ? (st_y_max1 + PAD_Y) : MAX_Y;
    wire [11:0] f_xmin2 = (st_x_min2 > PAD_X) ? (st_x_min2 - PAD_X) : 12'd0; wire [11:0] f_xmax2 = ((st_x_max2 + PAD_X) < MAX_X) ? (st_x_max2 + PAD_X) : MAX_X;
    wire [11:0] f_ymin2 = (st_y_min2 > PAD_Y) ? (st_y_min2 - PAD_Y) : 12'd0; wire [11:0] f_ymax2 = ((st_y_max2 + PAD_Y) < MAX_Y) ? (st_y_max2 + PAD_Y) : MAX_Y;
    wire [11:0] f_xmin3 = (st_x_min3 > PAD_X) ? (st_x_min3 - PAD_X) : 12'd0; wire [11:0] f_xmax3 = ((st_x_max3 + PAD_X) < MAX_X) ? (st_x_max3 + PAD_X) : MAX_X;
    wire [11:0] f_ymin3 = (st_y_min3 > PAD_Y) ? (st_y_min3 - PAD_Y) : 12'd0; wire [11:0] f_ymax3 = ((st_y_max3 + PAD_Y) < MAX_Y) ? (st_y_max3 + PAD_Y) : MAX_Y;


    // =========================================================
    // 👇【数据明线】：零延迟旁路掩码输出 (直接吃进 HDMI 原图)
    // =========================================================
    
    reg [11:0] raw_x, raw_y;
    reg de_in_r; always @(posedge pixclk_in) de_in_r <= de_in;
    wire raw_de_falling = ~de_in & de_in_r; 

    always @(posedge pixclk_in or negedge rstn_out) begin
        if (!rstn_out) begin raw_x <= 0; raw_y <= 0; end 
        else if (vs_in) begin raw_x <= 0; raw_y <= 0; end 
        else if (de_in) raw_x <= raw_x + 1'b1;
        else if (raw_de_falling) begin raw_x <= 0; raw_y <= raw_y + 1'b1; end
    end

    wire b1_exist = (f_xmax1 > f_xmin1);
    wire b2_exist = (f_xmax2 > f_xmin2);
    wire b3_exist = (f_xmax3 > f_xmin3);
    wire any_active = b1_exist | b2_exist | b3_exist;

    wire in_r1 = b1_exist && (raw_x >= f_xmin1 && raw_x <= f_xmax1) && (raw_y >= f_ymin1 && raw_y <= f_ymax1);
    wire in_r2 = b2_exist && (raw_x >= f_xmin2 && raw_x <= f_xmax2) && (raw_y >= f_ymin2 && raw_y <= f_ymax2);
    wire in_r3 = b3_exist && (raw_x >= f_xmin3 && raw_x <= f_xmax3) && (raw_y >= f_ymin3 && raw_y <= f_ymax3);
    wire in_valid = in_r1 | in_r2 | in_r3;

    wire show_origin = (!any_active) || in_valid;

    reg [7:0] r_out, g_out, b_out;
    reg vs_out, hs_out, de_out;

    always @(posedge pixclk_in) begin
        // 零延迟同步原图时序
        vs_out <= vs_in; hs_out <= hs_in; de_out <= de_in; 
        // 掩码处理后直通输出
        r_out  <= show_origin ? r_in : 8'd0; 
        g_out  <= show_origin ? g_in : 8'd0; 
        b_out  <= show_origin ? b_in : 8'd0; 
    end

    // =========================================================
    // 🚀 终极对接：PCIe DMA 视频流装载
    // =========================================================
    wire [127:0] pcie_data_bus = {104'd0, r_out, g_out, b_out}; 

    reg vs_out_d1;
    always @(posedge pixclk_in) vs_out_d1 <= vs_out;
    wire frame_end_pulse = (~vs_out) & vs_out_d1; 

    wire pcie_user_clk, pcie_user_rst_n, pcie_link_up, pcie_tready;

    pcie u_pcie_top (
        .ref_clk_n           (pcie_refclk_n),     
        .ref_clk_p           (pcie_refclk_p),
        .rxn                 (pcie_rx_n),         
        .rxp                 (pcie_rx_p),
        .txn                 (pcie_tx_n),         
        .txp                 (pcie_tx_p),
        
        .perst_n             (rst_n),             
        .button_rst_n        (rst_n),             
        .power_up_rst_n      (1'b1),              

        .pclk                (pcie_user_clk),     
        .core_rst_n          (pcie_user_rst_n),   
        .smlh_link_up        (pcie_link_up),      

        // ⚠️ 极其注意：此处数据由 pixclk_in 产生，直接塞入 PCIe。
        // 如果板级综合后视频轻微撕裂，可能需要补一个 Async FIFO 跨时钟域
        .axis_slave0_tdata   (pcie_data_bus),     
        .axis_slave0_tvalid  (de_out),            
        .axis_slave0_tready  (pcie_tready),       
        .axis_slave0_tlast   (frame_end_pulse),   
        .axis_slave0_tuser   (1'b0),              

        .axis_master_tdata   (), .axis_master_tvalid  (), .axis_master_tready  (1'b1), .axis_master_tlast   (), .axis_master_tuser   (), .axis_master_tkeep   (),
        .axis_slave1_tdata   (128'b0), .axis_slave1_tvalid  (1'b0), .axis_slave1_tready  (), .axis_slave1_tlast   (1'b0), .axis_slave1_tuser   (1'b0),
        .axis_slave2_tdata   (128'b0), .axis_slave2_tvalid  (1'b0), .axis_slave2_tready  (), .axis_slave2_tlast   (1'b0), .axis_slave2_tuser   (1'b0),
        
        .p_sel(1'b0), .p_strb(4'b0), .p_addr(16'b0), .p_wdata(32'b0), .p_ce(1'b0), .p_we(1'b0),
        .pcs_nearend_loop(4'b0), .pma_nearend_ploop(4'b0), .pma_nearend_sloop(4'b0),
        .app_ras_des_sd_hold_ltssm(1'b0), .app_ras_des_tba_ctrl(2'b0), .diag_ctrl_bus(2'b0), .dyn_debug_info_sel(4'b0)
    );

endmodule

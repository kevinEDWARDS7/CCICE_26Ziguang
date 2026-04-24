`timescale 1ns / 1ps

module HDMI_IN_DDR3_mid_filter_top (
    // ==========================================
    // 1. System clock and reset
    // ==========================================
    input  wire clk_p,
    input  wire clk_n,
    input  wire rst_n,

    // ==========================================
    // 2. PCIe interface
    // ==========================================
    input  wire pcie_refclk_p,
    input  wire pcie_refclk_n,
    input  wire pcie_rx_p,
    input  wire pcie_rx_n,
    output wire pcie_tx_p,
    output wire pcie_tx_n,

    // ==========================================
    // 3. Video input interface (reserved, unused)
    // ==========================================
    input  wire pixclk_in,
    input  wire vs_in,
    input  wire hs_in,
    input  wire de_in,
    input  wire [7:0] r_in,
    input  wire [7:0] g_in,
    input  wire [7:0] b_in,
    output wire rstn_out,
    inout  wire hd_scl,
    inout  wire hd_sda
);

    assign rstn_out = 1'b1;
    assign hd_scl   = 1'bz;
    assign hd_sda   = 1'bz;

    wire pcie_user_clk;
    wire pcie_user_rst_n;
    wire pcie_link_up;
    wire pcie_tready;

    // =========================================================
    // Safe synchronous reset in PCIe user clock domain
    // =========================================================
    reg pcie_rst_sync_d1, pcie_rst_sync_d2;
    always @(posedge pcie_user_clk) begin
        pcie_rst_sync_d1 <= !pcie_user_rst_n || !pcie_link_up;
        pcie_rst_sync_d2 <= pcie_rst_sync_d1;
    end
    wire safe_reset = pcie_rst_sync_d2;

    // =========================================================
    // Test-pattern stream generator
    // Goal for minimum-link bring-up:
    // 1. Keep tvalid asserted continuously after reset/link-up.
    // 2. Advance x/y only on a real AXI-Stream handshake.
    // 3. Use pure RGB565 color bars by default.
    // =========================================================
    localparam DEBUG_MAGIC_ENABLE = 1'b0;

    reg [7:0]  x_beat_cnt;
    reg [9:0]  y_line_cnt;
    reg [127:0] r_tdata;
    reg         r_tvalid;
    reg         r_tlast;
    reg         r_tuser;

    wire stream_handshake;
    reg  [7:0] x_beat_cnt_next;
    reg  [9:0] y_line_cnt_next;

    assign stream_handshake = r_tvalid && pcie_tready;

    function [15:0] color_from_x;
        input [7:0] beat_x;
        begin
            if      (beat_x < 8'd20)  color_from_x = 16'hFFFF; // white
            else if (beat_x < 8'd40)  color_from_x = 16'hFFE0; // yellow
            else if (beat_x < 8'd60)  color_from_x = 16'h07FF; // cyan
            else if (beat_x < 8'd80)  color_from_x = 16'h07E0; // green
            else if (beat_x < 8'd100) color_from_x = 16'hF81F; // magenta
            else if (beat_x < 8'd120) color_from_x = 16'hF800; // red
            else if (beat_x < 8'd140) color_from_x = 16'h001F; // blue
            else                      color_from_x = 16'h0000; // black
        end
    endfunction

    function [127:0] payload_from_xy;
        input [7:0] beat_x;
        input [9:0] line_y;
        begin
            if (DEBUG_MAGIC_ENABLE && (beat_x == 8'd0) && (line_y == 10'd0))
                payload_from_xy = {16'hBEEF, 16'hDEAD, 16'hBEEF, 16'hDEAD,
                                   16'hBEEF, 16'hDEAD, 16'hBEEF, 16'hDEAD};
            else
                payload_from_xy = {8{color_from_x(beat_x)}};
        end
    endfunction

    always @(*) begin
        if (x_beat_cnt == 8'd159) begin
            x_beat_cnt_next = 8'd0;
            if (y_line_cnt == 10'd719)
                y_line_cnt_next = 10'd0;
            else
                y_line_cnt_next = y_line_cnt + 1'b1;
        end else begin
            x_beat_cnt_next = x_beat_cnt + 1'b1;
            y_line_cnt_next = y_line_cnt;
        end
    end

    always @(posedge pcie_user_clk) begin
        if (safe_reset) begin
            x_beat_cnt <= 8'd0;
            y_line_cnt <= 10'd0;
            r_tdata    <= 128'd0;
            r_tvalid   <= 1'b0;
            r_tlast    <= 1'b0;
            r_tuser    <= 1'b0;
        end else begin
            // Prime the first beat after reset/link-up.
            // No counter advance here: counters move only on handshake.
            if (!r_tvalid) begin
                r_tvalid <= 1'b1;
                r_tdata  <= payload_from_xy(x_beat_cnt, y_line_cnt);
                r_tlast  <= (x_beat_cnt == 8'd159);
                r_tuser  <= (x_beat_cnt == 8'd0) && (y_line_cnt == 10'd0);
            end else if (stream_handshake) begin
                // Current beat has been accepted by PCIe IP.
                // Advance state, then present the next beat.
                x_beat_cnt <= x_beat_cnt_next;
                y_line_cnt <= y_line_cnt_next;
                r_tdata    <= payload_from_xy(x_beat_cnt_next, y_line_cnt_next);
                r_tlast    <= (x_beat_cnt_next == 8'd159);
                r_tuser    <= (x_beat_cnt_next == 8'd0) && (y_line_cnt_next == 10'd0);
                r_tvalid   <= 1'b1;
            end
        end
    end

    // =========================================================
    // PCIe IP instance
    // =========================================================
    pcie u_pcie_top (
        .ref_clk_n      (pcie_refclk_n),
        .ref_clk_p      (pcie_refclk_p),
        .rxn            (pcie_rx_n),
        .rxp            (pcie_rx_p),
        .txn            (pcie_tx_n),
        .txp            (pcie_tx_p),
        .perst_n        (rst_n),
        .button_rst_n   (rst_n),
        .pclk           (pcie_user_clk),
        .core_rst_n     (pcie_user_rst_n),
        .smlh_link_up   (pcie_link_up),

        .axis_slave0_tdata  (r_tdata),
        .axis_slave0_tvalid (r_tvalid),
        .axis_slave0_tready (pcie_tready),
        .axis_slave0_tlast  (r_tlast),
        .axis_slave0_tuser  (r_tuser),

        .axis_master_tdata          (), .axis_master_tvalid (), .axis_master_tready (1'b1), .axis_master_tlast (), .axis_master_tuser (), .axis_master_tkeep (),
        .axis_slave1_tdata          (128'b0), .axis_slave1_tvalid (1'b0), .axis_slave1_tready (), .axis_slave1_tlast (1'b0), .axis_slave1_tuser (1'b0),
        .axis_slave2_tdata          (128'b0), .axis_slave2_tvalid (1'b0), .axis_slave2_tready (), .axis_slave2_tlast (1'b0), .axis_slave2_tuser (1'b0),
        .p_sel(1'b0), .p_strb(4'b0), .p_addr(16'b0), .p_wdata(32'b0), .p_ce(1'b0), .p_we(1'b0),
        .pcs_nearend_loop(4'b0), .pma_nearend_ploop(4'b0), .pma_nearend_sloop(4'b0),
        .app_ras_des_sd_hold_ltssm(1'b0), .app_ras_des_tba_ctrl(2'b0), .diag_ctrl_bus(2'b0), .dyn_debug_info_sel(4'b0)
    );

endmodule

`timescale 1ns / 1ps

module hdmi40in_only_debug_top (
    input  wire        sys_clk,
    input  wire        sys_rst_n,

    input  wire        hdmi_pix_clk,
    input  wire        hdmi_vs,
    input  wire        hdmi_hs,
    input  wire        hdmi_de,
    input  wire [7:0]  hdmi_r,
    input  wire [7:0]  hdmi_g,
    input  wire [7:0]  hdmi_b,
    output wire        hdmi_rx_init_done,
    inout  wire        hdmi_rx_scl,
    inout  wire        hdmi_rx_sda,

    output wire        led_pclk_alive,
    output wire        led_vsync_alive,
    output wire        led_de_seen,
    output wire        led_rgb_nonzero,

    output wire [31:0] frame_count,
    output wire [31:0] hsync_count,
    output wire [15:0] de_pixel_count_current_line,
    output wire [15:0] max_de_pixels_per_line,
    output wire [15:0] de_lines_per_frame,
    output wire [31:0] rgb_nonzero_count
);

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

assign hdmi_rx_sda = hdmi_sda_oe ? hdmi_sda_out : 1'bz;
assign hdmi_sda_in = hdmi_rx_sda;

ms7200_ctl u_hdmi_rx_ms7200_ctl (
    .clk        (sys_clk),
    .rstn       (sys_rst_n),
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
    .CLK_FRE    (27'd25_000_000),
    .IIC_FREQ   (20'd400_000),
    .T_WR       (10'd1),
    .ADDR_BYTE  (2'd2),
    .LEN_WIDTH  (8'd3),
    .DATA_BYTE  (2'd1)
) u_hdmi_rx_iic_dri (
    .clk        (sys_clk),
    .rstn       (sys_rst_n),
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

hdmi_in_debug u_hdmi_in_debug (
    .hdmi_pix_clk                 (hdmi_pix_clk),
    .hdmi_vsync                   (hdmi_vs),
    .hdmi_hsync                   (hdmi_hs),
    .hdmi_de                      (hdmi_de),
    .hdmi_r                       (hdmi_r),
    .hdmi_g                       (hdmi_g),
    .hdmi_b                       (hdmi_b),
    .rst_n                        (sys_rst_n & hdmi_rx_init_done),
    .led_pclk_alive               (led_pclk_alive),
    .led_vsync_alive              (led_vsync_alive),
    .led_de_seen                  (led_de_seen),
    .led_rgb_nonzero              (led_rgb_nonzero),
    .frame_count                  (frame_count),
    .hsync_count                  (hsync_count),
    .de_pixel_count_current_line  (de_pixel_count_current_line),
    .max_de_pixels_per_line       (max_de_pixels_per_line),
    .de_lines_per_frame           (de_lines_per_frame),
    .rgb_nonzero_count            (rgb_nonzero_count)
);

endmodule

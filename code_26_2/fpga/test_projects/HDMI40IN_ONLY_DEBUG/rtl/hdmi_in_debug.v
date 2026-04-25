`timescale 1ns / 1ps

module hdmi_in_debug (
    input  wire        hdmi_pix_clk,
    input  wire        hdmi_vsync,
    input  wire        hdmi_hsync,
    input  wire        hdmi_de,
    input  wire [7:0]  hdmi_r,
    input  wire [7:0]  hdmi_g,
    input  wire [7:0]  hdmi_b,
    input  wire        rst_n,

    output wire        led_pclk_alive,
    output reg         led_vsync_alive,
    output reg         led_de_seen,
    output reg         led_rgb_nonzero,

    output reg  [31:0] frame_count,
    output reg  [31:0] hsync_count,
    output reg  [15:0] de_pixel_count_current_line,
    output reg  [15:0] max_de_pixels_per_line,
    output reg  [15:0] de_lines_per_frame,
    output reg  [31:0] rgb_nonzero_count
);

reg [25:0] pclk_div_cnt;
reg [5:0]  vsync_led_div;
reg        vsync_d0;
reg        hsync_d0;
reg        de_d0;
reg        line_has_de;

wire vsync_rise  =  hdmi_vsync & ~vsync_d0;
wire hsync_rise  =  hdmi_hsync & ~hsync_d0;
wire de_rise     =  hdmi_de    & ~de_d0;
wire de_fall     = ~hdmi_de    &  de_d0;
wire rgb_nonzero = hdmi_de & (|hdmi_r | |hdmi_g | |hdmi_b);

assign led_pclk_alive = pclk_div_cnt[25];

always @(posedge hdmi_pix_clk or negedge rst_n) begin
    if (!rst_n) begin
        pclk_div_cnt <= 26'd0;
    end else begin
        pclk_div_cnt <= pclk_div_cnt + 26'd1;
    end
end

always @(posedge hdmi_pix_clk or negedge rst_n) begin
    if (!rst_n) begin
        led_vsync_alive             <= 1'b0;
        led_de_seen                 <= 1'b0;
        led_rgb_nonzero             <= 1'b0;
        frame_count                 <= 32'd0;
        hsync_count                 <= 32'd0;
        de_pixel_count_current_line <= 16'd0;
        max_de_pixels_per_line      <= 16'd0;
        de_lines_per_frame          <= 16'd0;
        rgb_nonzero_count           <= 32'd0;
        vsync_led_div               <= 6'd0;
        vsync_d0                    <= 1'b0;
        hsync_d0                    <= 1'b0;
        de_d0                       <= 1'b0;
        line_has_de                 <= 1'b0;
    end else begin
        vsync_d0 <= hdmi_vsync;
        hsync_d0 <= hdmi_hsync;
        de_d0    <= hdmi_de;

        if (vsync_rise) begin
            frame_count                 <= frame_count + 32'd1;
            hsync_count                 <= 32'd0;
            de_pixel_count_current_line <= 16'd0;
            max_de_pixels_per_line      <= 16'd0;
            de_lines_per_frame          <= 16'd0;
            rgb_nonzero_count           <= 32'd0;
            line_has_de                 <= 1'b0;
            vsync_led_div               <= vsync_led_div + 6'd1;
            if (&vsync_led_div) begin
                led_vsync_alive <= ~led_vsync_alive;
            end
        end else begin
            if (hsync_rise) begin
                hsync_count                 <= hsync_count + 32'd1;
                de_pixel_count_current_line <= 16'd0;
                line_has_de                 <= 1'b0;
            end

            if (de_rise && !line_has_de) begin
                de_lines_per_frame <= de_lines_per_frame + 16'd1;
                line_has_de        <= 1'b1;
            end

            if (hdmi_de) begin
                led_de_seen                 <= 1'b1;
                de_pixel_count_current_line <= de_pixel_count_current_line + 16'd1;
            end

            if (de_fall) begin
                if (de_pixel_count_current_line > max_de_pixels_per_line) begin
                    max_de_pixels_per_line <= de_pixel_count_current_line;
                end
            end

            if (rgb_nonzero) begin
                led_rgb_nonzero   <= 1'b1;
                rgb_nonzero_count <= rgb_nonzero_count + 32'd1;
            end
        end
    end
end

endmodule

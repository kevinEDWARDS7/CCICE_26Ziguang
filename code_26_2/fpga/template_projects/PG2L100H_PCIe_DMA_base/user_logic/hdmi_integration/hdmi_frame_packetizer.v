`timescale 1ns / 1ps
module hdmi_frame_packetizer #(
    parameter FRAME_WIDTH  = 1280,
    parameter FRAME_HEIGHT = 720
)(
    input              clk,
    input              rst_n,
    input              in_vsync,
    input              in_hsync,
    input              in_de,
    input      [7:0]   in_r,
    input      [7:0]   in_g,
    input      [7:0]   in_b,
    input      [31:0]  frame_timestamp,

    output reg [31:0]  out_data,
    output reg         out_valid,
    input              out_ready,
    output reg         out_sof,
    output reg         out_eol,
    output reg         out_eof
);

localparam [31:0] FRAME_MAGIC      = 32'h46524731;
localparam [15:0] PIXEL_FMT_RGB565 = 16'h0001;
localparam [15:0] FLAG_SOF         = 16'h0001;

localparam ST_IDLE   = 3'd0;
localparam ST_HDR0   = 3'd1;
localparam ST_HDR1   = 3'd2;
localparam ST_HDR2   = 3'd3;
localparam ST_HDR3   = 3'd4;
localparam ST_PIXELS = 3'd5;

reg [2:0]  state;
reg        vs_d;
reg        de_d;
reg [31:0] frame_id;
reg [15:0] x_pos;
reg [15:0] y_pos;
reg [15:0] pixel_hold;
reg        pixel_half;

wire sof_pulse = in_vsync & ~vs_d;
wire eol_pulse = ~in_de & de_d;
wire [15:0] rgb565 = {in_r[7:3], in_g[7:2], in_b[7:3]};

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state      <= ST_IDLE;
        vs_d       <= 1'b0;
        de_d       <= 1'b0;
        frame_id   <= 32'd0;
        x_pos      <= 16'd0;
        y_pos      <= 16'd0;
        pixel_hold <= 16'd0;
        pixel_half <= 1'b0;
        out_data   <= 32'd0;
        out_valid  <= 1'b0;
        out_sof    <= 1'b0;
        out_eol    <= 1'b0;
        out_eof    <= 1'b0;
    end else begin
        vs_d    <= in_vsync;
        de_d    <= in_de;
        out_sof <= 1'b0;
        out_eol <= 1'b0;
        out_eof <= 1'b0;

        if (sof_pulse) begin
            frame_id   <= frame_id + 32'd1;
            x_pos      <= 16'd0;
            y_pos      <= 16'd0;
            pixel_half <= 1'b0;
            state      <= ST_HDR0;
            out_valid  <= 1'b0;
        end

        if (state != ST_IDLE && (!out_valid || out_ready)) begin
            out_valid <= 1'b0;

            case (state)
            ST_HDR0: begin
                out_data  <= FRAME_MAGIC;
                out_valid <= 1'b1;
                out_sof   <= 1'b1;
                state     <= ST_HDR1;
            end
            ST_HDR1: begin
                out_data  <= frame_id;
                out_valid <= 1'b1;
                state     <= ST_HDR2;
            end
            ST_HDR2: begin
                out_data  <= {FRAME_WIDTH[15:0], FRAME_HEIGHT[15:0]};
                out_valid <= 1'b1;
                state     <= ST_HDR3;
            end
            ST_HDR3: begin
                out_data  <= {PIXEL_FMT_RGB565, FLAG_SOF, frame_timestamp[15:0]};
                out_valid <= 1'b1;
                state     <= ST_PIXELS;
            end
            ST_PIXELS: begin
                if (in_de) begin
                    if (!pixel_half) begin
                        pixel_hold <= rgb565;
                        pixel_half <= 1'b1;
                    end else begin
                        out_data   <= {pixel_hold, rgb565};
                        out_valid  <= 1'b1;
                        pixel_half <= 1'b0;

                        if (x_pos >= FRAME_WIDTH - 2) begin
                            x_pos <= 16'd0;
                        end else begin
                            x_pos <= x_pos + 16'd2;
                        end
                    end
                end

                if (eol_pulse) begin
                    if (pixel_half) begin
                        out_data   <= {pixel_hold, 16'd0};
                        out_valid  <= 1'b1;
                        pixel_half <= 1'b0;
                    end

                    out_eol <= 1'b1;

                    if (y_pos >= FRAME_HEIGHT - 1) begin
                        out_eof <= 1'b1;
                        state   <= ST_IDLE;
                        y_pos   <= 16'd0;
                    end else begin
                        y_pos <= y_pos + 16'd1;
                    end
                end
            end
            default: begin
                state <= ST_IDLE;
            end
            endcase
        end
    end
end

endmodule

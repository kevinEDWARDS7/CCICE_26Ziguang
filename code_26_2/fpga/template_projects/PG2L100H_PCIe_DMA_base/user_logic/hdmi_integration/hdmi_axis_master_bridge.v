`timescale 1ns / 1ps

module hdmi_axis_master_bridge #(
    parameter FRAME_WIDTH  = 1280,
    parameter FRAME_HEIGHT = 720
)(
    input              pix_clk,
    input              rst_n,
    input              hdmi_vsync,
    input              hdmi_hsync,
    input              hdmi_de,
    input      [7:0]   hdmi_r,
    input      [7:0]   hdmi_g,
    input      [7:0]   hdmi_b,

    output     [127:0] axis_tdata,
    output             axis_tvalid,
    input              axis_tready,
    output     [3:0]   axis_tkeep,
    output             axis_tlast,
    output     [7:0]   axis_tuser
);

wire [31:0] pkt_data;
wire        pkt_valid;
wire        pkt_ready;
wire        pkt_sof;
wire        pkt_eol;
wire        pkt_eof;

reg [31:0] frame_timestamp;

always @(posedge pix_clk or negedge rst_n) begin
    if (!rst_n) begin
        frame_timestamp <= 32'd0;
    end else if (hdmi_vsync) begin
        frame_timestamp <= frame_timestamp + 32'd1;
    end
end

hdmi_frame_packetizer #(
    .FRAME_WIDTH  (FRAME_WIDTH),
    .FRAME_HEIGHT (FRAME_HEIGHT)
) u_hdmi_frame_packetizer (
    .clk             (pix_clk),
    .rst_n           (rst_n),
    .in_vsync        (hdmi_vsync),
    .in_hsync        (hdmi_hsync),
    .in_de           (hdmi_de),
    .in_r            (hdmi_r),
    .in_g            (hdmi_g),
    .in_b            (hdmi_b),
    .frame_timestamp (frame_timestamp),
    .out_data        (pkt_data),
    .out_valid       (pkt_valid),
    .out_ready       (pkt_ready),
    .out_sof         (pkt_sof),
    .out_eol         (pkt_eol),
    .out_eof         (pkt_eof)
);

stream_width_adapter_32to128 u_stream_width_adapter_32to128 (
    .clk     (pix_clk),
    .rst_n   (rst_n),
    .s_data  (pkt_data),
    .s_valid (pkt_valid),
    .s_ready (pkt_ready),
    .s_sof   (pkt_sof),
    .s_eol   (pkt_eol),
    .s_eof   (pkt_eof),
    .m_data  (axis_tdata),
    .m_valid (axis_tvalid),
    .m_ready (axis_tready),
    .m_tkeep (axis_tkeep),
    .m_tuser (axis_tuser[0]),
    .m_tlast (axis_tlast)
);

assign axis_tuser[7:1] = 7'd0;

endmodule

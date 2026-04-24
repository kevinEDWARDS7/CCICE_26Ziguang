`timescale 1ns / 1ps

module stream_width_adapter_32to128(
    input              clk,
    input              rst_n,

    input      [31:0]  s_data,
    input              s_valid,
    output             s_ready,
    input              s_sof,
    input              s_eol,
    input              s_eof,

    output reg [127:0] m_data,
    output reg         m_valid,
    input              m_ready,
    output reg [3:0]   m_tkeep,
    output reg         m_tuser,
    output reg         m_tlast
);

reg [1:0] word_count;
reg       pending_sof;
reg       pending_eof;

assign s_ready = !m_valid || m_ready;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        m_data      <= 128'd0;
        m_valid     <= 1'b0;
        m_tkeep     <= 4'd0;
        m_tuser     <= 1'b0;
        m_tlast     <= 1'b0;
        word_count  <= 2'd0;
        pending_sof <= 1'b0;
        pending_eof <= 1'b0;
    end else begin
        if (m_valid && m_ready) begin
            m_valid <= 1'b0;
            m_tkeep <= 4'd0;
            m_tuser <= 1'b0;
            m_tlast <= 1'b0;
        end

        if (s_valid && s_ready) begin
            m_data[word_count * 32 +: 32] <= s_data;

            if (word_count == 2'd0) begin
                pending_sof <= s_sof;
                pending_eof <= 1'b0;
            end

            if (s_eof) begin
                pending_eof <= 1'b1;
            end

            if (word_count == 2'd3 || s_eof || s_eol) begin
                m_valid    <= 1'b1;
                m_tkeep    <= (word_count == 2'd0) ? 4'b0001 :
                              (word_count == 2'd1) ? 4'b0011 :
                              (word_count == 2'd2) ? 4'b0111 :
                                                     4'b1111;
                m_tuser    <= pending_sof | s_sof;
                m_tlast    <= pending_eof | s_eof;
                word_count <= 2'd0;
            end else begin
                word_count <= word_count + 2'd1;
            end
        end
    end
end

endmodule

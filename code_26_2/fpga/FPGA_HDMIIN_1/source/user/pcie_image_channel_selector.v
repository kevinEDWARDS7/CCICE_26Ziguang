`timescale 1ns / 1ps
module pcie_image_channel_selector(
    input                           clk,
    input                           rst_n,

    input                           line_full_flag,
    input                           dma_sim_vs              /*synthesis PAP_MARK_DEBUG="1"*/,

    output                          ch0_data_req            /*synthesis PAP_MARK_DEBUG="1"*/,
    input      [127:0]              ch0_data                /*synthesis PAP_MARK_DEBUG="1"*/,
    input                           ch0_data_valid          /*synthesis PAP_MARK_DEBUG="1"*/,

    output                          ch1_data_req            /*synthesis PAP_MARK_DEBUG="1"*/,
    input      [127:0]              ch1_data                /*synthesis PAP_MARK_DEBUG="1"*/,
    output                          ch2_data_req            /*synthesis PAP_MARK_DEBUG="1"*/,
    input      [127:0]              ch2_data                /*synthesis PAP_MARK_DEBUG="1"*/,
    output                          ch3_data_req            /*synthesis PAP_MARK_DEBUG="1"*/,
    input      [127:0]              ch3_data                /*synthesis PAP_MARK_DEBUG="1"*/,

    input                           dma_wr_data_req         /*synthesis PAP_MARK_DEBUG="1"*/,
    input      [11:0]               dma_wr_data_addr        /*synthesis PAP_MARK_DEBUG="1"*/,
    output reg [127:0]              dma_wr_data             /*synthesis PAP_MARK_DEBUG="1"*/,
    output                          dma_wr_data_valid       /*synthesis PAP_MARK_DEBUG="1"*/
);

localparam ROW_NUM = 1080;
localparam COL_NUM = 240;
localparam [11:0] ROW_LAST = 12'd1079;
localparam [8:0]  COL_LAST = 9'd239;
localparam [7:0]  PREFETCH_LIMIT = 8'd240;
localparam [7:0]  PREFETCH_LAST = 8'd239;
localparam [127:0] UNDERRUN_WORD = {8{16'hf81f}};

reg [127:0] line_buffer0 [0:COL_NUM-1];
reg [127:0] line_buffer1 [0:COL_NUM-1];

reg        line_prefetch_active;
reg [7:0]  prefetch_req_cnt;
reg [7:0]  prefetch_wr_cnt;
reg [1:0]  line_count;
reg        write_bank;
reg        read_bank;
reg [11:0] row_cnt;
reg [8:0]  col_cnt;
reg        dma_sim_vs_raw_dly;
reg        underrun_seen /*synthesis PAP_MARK_DEBUG="1"*/;

wire dma_sim_vs_start = dma_sim_vs & ~dma_sim_vs_raw_dly;
wire dma_addr_in_range = (dma_wr_data_addr < COL_NUM);
wire dma_data_ready = (line_count != 2'd0);
wire dma_line_done;
wire line_consumed;
wire prefetch_done;

assign ch0_data_req = line_prefetch_active && (prefetch_req_cnt < PREFETCH_LIMIT);
assign ch1_data_req = 1'b0;
assign ch2_data_req = 1'b0;
assign ch3_data_req = 1'b0;
assign dma_wr_data_valid = dma_wr_data_req & dma_addr_in_range;
assign dma_line_done = dma_wr_data_valid && (col_cnt == COL_LAST);
assign line_consumed = dma_line_done && dma_data_ready;
assign prefetch_done = line_prefetch_active && ch0_data_valid && (prefetch_wr_cnt == PREFETCH_LAST);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        dma_sim_vs_raw_dly <= 1'b0;
    end else begin
        dma_sim_vs_raw_dly <= dma_sim_vs;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        line_prefetch_active <= 1'b0;
        prefetch_req_cnt <= 8'd0;
        prefetch_wr_cnt <= 8'd0;
        line_count <= 2'd0;
        write_bank <= 1'b0;
        read_bank <= 1'b0;
        underrun_seen <= 1'b0;
    end else if (dma_sim_vs_start) begin
        line_prefetch_active <= 1'b0;
        prefetch_req_cnt <= 8'd0;
        prefetch_wr_cnt <= 8'd0;
        line_count <= 2'd0;
        write_bank <= 1'b0;
        read_bank <= 1'b0;
        underrun_seen <= 1'b0;
    end else begin
        if (!line_prefetch_active && (line_count < 2'd2) && line_full_flag) begin
            line_prefetch_active <= 1'b1;
            prefetch_req_cnt <= 8'd0;
            prefetch_wr_cnt <= 8'd0;
        end else if (line_prefetch_active && (prefetch_req_cnt < PREFETCH_LIMIT)) begin
            prefetch_req_cnt <= prefetch_req_cnt + 8'd1;
        end

        if (line_prefetch_active && ch0_data_valid) begin
            if (write_bank) begin
                line_buffer1[prefetch_wr_cnt] <= ch0_data;
            end else begin
                line_buffer0[prefetch_wr_cnt] <= ch0_data;
            end

            if (prefetch_done) begin
                line_prefetch_active <= 1'b0;
                prefetch_wr_cnt <= 8'd0;
                write_bank <= ~write_bank;
            end else begin
                prefetch_wr_cnt <= prefetch_wr_cnt + 8'd1;
            end
        end

        if (line_consumed) begin
            read_bank <= ~read_bank;
        end

        case ({prefetch_done, line_consumed})
            2'b10: line_count <= line_count + 2'd1;
            2'b01: line_count <= line_count - 2'd1;
            default: line_count <= line_count;
        endcase

        if (dma_wr_data_req && !dma_data_ready) begin
            underrun_seen <= 1'b1;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        row_cnt <= 12'd0;
        col_cnt <= 9'd0;
    end else if (dma_sim_vs_start) begin
        row_cnt <= 12'd0;
        col_cnt <= 9'd0;
    end else if (dma_wr_data_valid) begin
        if (col_cnt == COL_LAST) begin
            col_cnt <= 9'd0;
            if (row_cnt == ROW_LAST) begin
                row_cnt <= 12'd0;
            end else begin
                row_cnt <= row_cnt + 12'd1;
            end
        end else begin
            col_cnt <= col_cnt + 9'd1;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        dma_wr_data <= UNDERRUN_WORD;
    end else if (dma_wr_data_req && dma_addr_in_range) begin
        if (dma_data_ready) begin
            if (read_bank) begin
                dma_wr_data <= line_buffer1[dma_wr_data_addr[7:0]];
            end else begin
                dma_wr_data <= line_buffer0[dma_wr_data_addr[7:0]];
            end
        end else begin
            dma_wr_data <= UNDERRUN_WORD;
        end
    end else if (dma_wr_data_req) begin
        dma_wr_data <= UNDERRUN_WORD;
    end
end

endmodule

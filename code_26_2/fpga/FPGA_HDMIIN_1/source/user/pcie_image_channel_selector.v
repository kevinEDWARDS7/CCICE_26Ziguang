module pcie_image_channel_selector (
    input                           clk                     ,
    input                           rst_n                   ,

    input                           line_full_flag          ,
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

localparam  [11:0]  COL_NUM = 12'd240;
localparam  [11:0]  ROW_NUM = 12'd1080;

reg                   dma_sim_vs_raw_dly;
wire                  dma_sim_vs_start;

reg                   line_prefetch_active /*synthesis PAP_MARK_DEBUG="1"*/;
reg                   line_ready           /*synthesis PAP_MARK_DEBUG="1"*/;
reg [11:0]            prefetch_req_cnt     /*synthesis PAP_MARK_DEBUG="1"*/;
reg [11:0]            prefetch_wr_cnt      /*synthesis PAP_MARK_DEBUG="1"*/;
reg [11:0]            col_cnt              /*synthesis PAP_MARK_DEBUG="1"*/;
reg [11:0]            row_cnt              /*synthesis PAP_MARK_DEBUG="1"*/;

reg [127:0]           line_buffer [0:239];

wire                  dma_addr_in_range;
wire                  dma_line_done;

assign dma_sim_vs_start = dma_sim_vs & ~dma_sim_vs_raw_dly;
assign ch0_data_req = line_prefetch_active && (prefetch_req_cnt < COL_NUM);
assign ch1_data_req = 1'b0;
assign ch2_data_req = 1'b0;
assign ch3_data_req = 1'b0;
assign dma_addr_in_range = (dma_wr_data_addr < COL_NUM);
assign dma_wr_data_valid = dma_wr_data_req & line_ready & dma_addr_in_range;
assign dma_line_done = dma_wr_data_valid && (col_cnt == COL_NUM);

always @(posedge clk) begin
    if (!rst_n) begin
        dma_sim_vs_raw_dly <= 1'b0;
    end else begin
        dma_sim_vs_raw_dly <= dma_sim_vs;
    end
end

always @(posedge clk) begin
    if (!rst_n) begin
        line_prefetch_active <= 1'b0;
        line_ready <= 1'b0;
        prefetch_req_cnt <= 12'd0;
        prefetch_wr_cnt <= 12'd0;
    end else if (dma_sim_vs_start) begin
        line_prefetch_active <= 1'b0;
        line_ready <= 1'b0;
        prefetch_req_cnt <= 12'd0;
        prefetch_wr_cnt <= 12'd0;
    end else begin
        if (dma_line_done) begin
            line_ready <= 1'b0;
        end

        if (!line_prefetch_active && !line_ready && line_full_flag && (row_cnt <= ROW_NUM)) begin
            line_prefetch_active <= 1'b1;
            prefetch_req_cnt <= 12'd0;
            prefetch_wr_cnt <= 12'd0;
        end else if (line_prefetch_active && (prefetch_req_cnt < COL_NUM)) begin
            prefetch_req_cnt <= prefetch_req_cnt + 12'd1;
        end

        if (line_prefetch_active && ch0_data_valid) begin
            line_buffer[prefetch_wr_cnt[7:0]] <= ch0_data;
            if (prefetch_wr_cnt == COL_NUM - 12'd1) begin
                line_prefetch_active <= 1'b0;
                line_ready <= 1'b1;
                prefetch_wr_cnt <= 12'd0;
            end else begin
                prefetch_wr_cnt <= prefetch_wr_cnt + 12'd1;
            end
        end
    end
end

always @(posedge clk) begin
    if (!rst_n) begin
        col_cnt <= 12'd1;
    end else if (dma_sim_vs_start) begin
        col_cnt <= 12'd1;
    end else if (dma_wr_data_valid && (col_cnt == COL_NUM)) begin
        col_cnt <= 12'd1;
    end else if (dma_wr_data_valid) begin
        col_cnt <= col_cnt + 12'd1;
    end
end

always @(posedge clk) begin
    if (!rst_n) begin
        row_cnt <= 12'd1;
    end else if (dma_sim_vs_start) begin
        row_cnt <= 12'd1;
    end else if (dma_wr_data_valid && (col_cnt == COL_NUM) && (row_cnt == ROW_NUM)) begin
        row_cnt <= 12'd1;
    end else if (dma_wr_data_valid && (col_cnt == COL_NUM)) begin
        row_cnt <= row_cnt + 12'd1;
    end
end

always @(posedge clk) begin
    if (!rst_n) begin
        dma_wr_data <= 128'd0;
    end else if (dma_sim_vs_start) begin
        dma_wr_data <= 128'd0;
    end else if (dma_wr_data_req && line_ready && dma_addr_in_range) begin
        dma_wr_data <= line_buffer[dma_wr_data_addr[7:0]];
    end else if (dma_wr_data_req) begin
        dma_wr_data <= 128'd0;
    end
end

endmodule

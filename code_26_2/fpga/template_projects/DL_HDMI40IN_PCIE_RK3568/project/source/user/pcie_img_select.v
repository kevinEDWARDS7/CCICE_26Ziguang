module pcie_image_channel_selector (
    input                           clk                     ,
    input                           rst_n                   ,

    input                           line_full_flag          ,
    // 通道读帧基地址更新
    input                           dma_sim_vs              /*synhesis PAP_MARK_DEBUG="1"*/,

    // 通道0读数据请求
    output reg                      ch0_data_req            /*synthesis PAP_MARK_DEBUG="1"*/,
    input      [127:0]              ch0_data                /*synthesis PAP_MARK_DEBUG="1"*/,
    // 通道1读数据请求
    output reg                      ch1_data_req            /*synthesis PAP_MARK_DEBUG="1"*/,
    input      [127:0]              ch1_data                /*synthesis PAP_MARK_DEBUG="1"*/,
    // 通道2读数据请求
    output reg                      ch2_data_req            /*synthesis PAP_MARK_DEBUG="1"*/,
    input      [127:0]              ch2_data                /*synthesis PAP_MARK_DEBUG="1"*/,
    // 通道3读数据请求
    output reg                      ch3_data_req            /*synthesis PAP_MARK_DEBUG="1"*/,
    input      [127:0]              ch3_data                /*synthesis PAP_MARK_DEBUG="1"*/,

    // dma写数据接口
    input                           dma_wr_data_req        /*synthesis PAP_MARK_DEBUG="1"*/,
    output reg [127:0]              dma_wr_data            /*synthesis PAP_MARK_DEBUG="1"*/,

    output reg [11:0]               debug_read_line_index  /*synthesis PAP_MARK_DEBUG="1"*/,
    output reg [11:0]               debug_read_beat_index  /*synthesis PAP_MARK_DEBUG="1"*/,
    output reg [31:0]               debug_dma_req_line_count /*synthesis PAP_MARK_DEBUG="1"*/,
    output reg [31:0]               debug_dma_req_beat_count /*synthesis PAP_MARK_DEBUG="1"*/,
    output reg [31:0]               debug_dma_underflow_count /*synthesis PAP_MARK_DEBUG="1"*/,
    output reg [31:0]               debug_dma_zero_output_count /*synthesis PAP_MARK_DEBUG="1"*/,
    output reg [31:0]               debug_ch0_data_nonzero_count /*synthesis PAP_MARK_DEBUG="1"*/,
    output reg                      debug_read_frame_active /*synthesis PAP_MARK_DEBUG="1"*/
);


localparam  [11:0]  COL_NUM = 12'd80;          // 640*16/128=80
localparam  [11:0]  ROW_NUM = 12'd360;         // reducer outputs 640x360




reg                   dma_sim_vs_temp     ;
reg  [15:0]           dma_sim_vs_cnt      ;
// vs pos
reg                   dma_sim_vs_dly1     ;
reg                   dma_sim_vs_dly2     ;
reg                   dma_sim_vs_pos      ;
reg                   dma_sim_vs_neg      ;
reg                   dma_sim_vs_neg_flag ; 
reg                   dma_data_req_ahead  ;    
reg                   dma_data_req_ahead_dly;
wire                  read_frame_done;
wire                  dma_underflow;
wire                  dma_zero_output;

// ch_data_dly;
reg [127:0]           ch0_data_dly        ;
reg [127:0]           ch1_data_dly        ;
reg [127:0]           ch2_data_dly        ;
reg [127:0]           ch3_data_dly        ;

reg [11:0]            col_cnt             ;
reg [11:0]            row_cnt             ;

assign read_frame_done = dma_wr_data_req && (col_cnt == COL_NUM) && (row_cnt == ROW_NUM);
assign dma_underflow   = dma_wr_data_req && !line_full_flag;
assign dma_zero_output = dma_wr_data_req &&
                         (dma_underflow ||
                          ((~(ch0_data_req || ch1_data_req || ch2_data_req || ch3_data_req)) ?
                           (ch0_data_dly == 128'd0) : (ch0_data == 128'd0)));

always @(posedge clk)begin
    if (!rst_n)begin
        col_cnt <= 12'd1;
    end
    else if (dma_wr_data_req == 1'b1 && col_cnt == COL_NUM)begin
        col_cnt <= 12'd1;
    end
    else if (dma_sim_vs_pos == 1'b1)begin
        col_cnt <= 12'd1;
    end
    else if (dma_wr_data_req == 1'b1)begin
        col_cnt <= col_cnt + 12'd1;
    end
    else begin
        col_cnt <= col_cnt;
    end
end

always @(posedge clk)begin
    if (!rst_n)begin
        row_cnt <= 12'd1;
    end
    else if (dma_wr_data_req == 1'b1 && col_cnt == COL_NUM && row_cnt == ROW_NUM)begin
        row_cnt <= 12'd1;
    end
    else if (dma_sim_vs_pos == 1'b1)begin
        row_cnt <= 12'd1;
    end
    else if (dma_wr_data_req == 1'b1 && col_cnt == COL_NUM)begin
        row_cnt <= row_cnt + 12'd1;
    end
    else begin
        row_cnt <= row_cnt;
    end
end

always @(posedge clk)begin
    if (!rst_n)begin
        dma_sim_vs_cnt <= 16'd0;
    end
    else if (dma_sim_vs == 1'b1)begin
        dma_sim_vs_cnt <= 16'd1;
    end
    else if (dma_sim_vs_cnt != 16'd0 && dma_sim_vs_cnt < 16'd255)begin
        dma_sim_vs_cnt <= dma_sim_vs_cnt + 16'd1;
    end
    else begin
        dma_sim_vs_cnt <= 16'd0;
    end
end

always @(posedge clk)begin
    if (!rst_n)begin
        dma_sim_vs_temp <= 1'b0;
    end
    else if (dma_sim_vs_cnt >= 16'd200)begin
        dma_sim_vs_temp <= 1'b1;
    end
    else begin
        dma_sim_vs_temp <= 1'b0;
    end
end

always @(posedge clk)begin
    if (!rst_n)begin
        dma_sim_vs_dly1 <= 1'b0;
        dma_sim_vs_dly2 <= 1'b0;
        dma_sim_vs_pos  <= 1'b0;
        dma_sim_vs_neg  <= 1'b0;
    end
    else begin
        dma_sim_vs_dly1 <= dma_sim_vs_temp;
        dma_sim_vs_dly2 <= dma_sim_vs_dly1;
        dma_sim_vs_pos  <= dma_sim_vs_dly1 & (~dma_sim_vs_dly2);
        dma_sim_vs_neg  <= (~dma_sim_vs_dly1) & dma_sim_vs_dly2; 
    end
end

always @(posedge clk)begin
    if (!rst_n)begin
        dma_sim_vs_neg_flag <= 1'b0;
    end
    else if (dma_sim_vs_neg == 1'b1)begin
        dma_sim_vs_neg_flag <= 1'b1;
    end
    else if (line_full_flag == 1'b1)begin
        dma_sim_vs_neg_flag <= 1'b0;
    end
    else begin
        dma_sim_vs_neg_flag <= dma_sim_vs_neg_flag;
    end
end



always @(posedge clk)begin
    if (!rst_n)begin
        dma_data_req_ahead <= 1'b0;
    end
    else if (dma_sim_vs_neg_flag == 1'b1 && line_full_flag == 1'b1)begin
        dma_data_req_ahead <= 1'b1;
    end
    else begin
        dma_data_req_ahead <= 1'b0;
    end
end

always @(posedge clk)begin
    if (!rst_n)begin
        dma_data_req_ahead_dly <= 1'b0;
    end
    else begin
        dma_data_req_ahead_dly <= dma_data_req_ahead;
    end
end


always @(posedge clk)begin
    if (!rst_n)begin
        ch0_data_req <= 1'b0;
        ch1_data_req <= 1'b0;
        ch2_data_req <= 1'b0;
        ch3_data_req <= 1'b0;
    end
    else if (dma_data_req_ahead == 1'b1 || dma_data_req_ahead_dly == 1'b1)begin //通道选择判断会消耗一个时钟，因此需要预取数据
        ch0_data_req <= 1'b1;
        ch1_data_req <= 1'b0;
        ch2_data_req <= 1'b0;
        ch3_data_req <= 1'b0;
    end
    else if(dma_wr_data_req == 1'b1 && line_full_flag == 1'b1)begin
        ch0_data_req <= 1'b1;
        ch1_data_req <= 1'b0;
        ch2_data_req <= 1'b0;
        ch3_data_req <= 1'b0;
    end
    else begin
        ch0_data_req <= 1'b0;
        ch1_data_req <= 1'b0;
        ch2_data_req <= 1'b0;
        ch3_data_req <= 1'b0;
    end
end


always @(posedge clk)begin
    if (!rst_n)begin
        ch0_data_dly <= 128'd0;
    end
    else if (ch0_data_req == 1'b1)begin
        ch0_data_dly <= ch0_data;
    end
    else begin
        ch0_data_dly <= ch0_data_dly;
    end
end

always @(posedge clk)begin
    if (!rst_n)begin
        ch1_data_dly <= 128'd0;
    end
    else if (ch1_data_req == 1'b1)begin
        ch1_data_dly <= ch1_data;
    end
    else begin
        ch1_data_dly <= ch1_data_dly;
    end
end

always @(posedge clk)begin
    if (!rst_n)begin
        ch2_data_dly <= 128'd0;
    end
    else if (ch2_data_req == 1'b1)begin
        ch2_data_dly <= ch2_data;
    end
    else begin
        ch2_data_dly <= ch2_data_dly;
    end
end

always @(posedge clk)begin
    if (!rst_n)begin
        ch3_data_dly <= 128'd0;
    end
    else if (ch3_data_req == 1'b1)begin
        ch3_data_dly <= ch3_data;
    end
    else begin
        ch3_data_dly <= ch3_data_dly;
    end
end


always @(posedge clk)begin
    if (!rst_n)begin
        dma_wr_data <= 128'b0;
    end
    else if(dma_underflow == 1'b1)begin
        dma_wr_data <= 128'b0;
    end
    else if(dma_wr_data_req == 1'b1 && ~(ch0_data_req || ch1_data_req || ch2_data_req || ch3_data_req))begin  //通道选择判断会消耗一个时钟，因此需要预取数据
        dma_wr_data <= ch0_data_dly;
    end
    else if (dma_wr_data_req == 1'b1)begin
        dma_wr_data <= ch0_data;
    end
    else begin
        dma_wr_data <= 128'b0;
    end
end

always @(posedge clk)begin
    if (!rst_n)begin
        debug_read_line_index <= 12'd0;
        debug_read_beat_index <= 12'd0;
        debug_dma_req_line_count <= 32'd0;
        debug_dma_req_beat_count <= 32'd0;
        debug_dma_underflow_count <= 32'd0;
        debug_dma_zero_output_count <= 32'd0;
        debug_ch0_data_nonzero_count <= 32'd0;
        debug_read_frame_active <= 1'b0;
    end
    else begin
        if (dma_sim_vs_pos) begin
            debug_read_line_index <= 12'd0;
            debug_read_beat_index <= 12'd0;
            debug_read_frame_active <= 1'b1;
        end
        else if (dma_wr_data_req) begin
            debug_dma_req_beat_count <= debug_dma_req_beat_count + 32'd1;
            debug_read_beat_index <= col_cnt - 12'd1;
            debug_read_line_index <= row_cnt - 12'd1;

            if (col_cnt == COL_NUM) begin
                debug_dma_req_line_count <= debug_dma_req_line_count + 32'd1;
                debug_read_beat_index <= 12'd0;
            end

            if (read_frame_done) begin
                debug_read_frame_active <= 1'b0;
            end

            if (dma_underflow) begin
                debug_dma_underflow_count <= debug_dma_underflow_count + 32'd1;
            end

            if (dma_zero_output) begin
                debug_dma_zero_output_count <= debug_dma_zero_output_count + 32'd1;
            end

            if (ch0_data_req && (ch0_data != 128'd0)) begin
                debug_ch0_data_nonzero_count <= debug_ch0_data_nonzero_count + 32'd1;
            end
        end
    end
end

endmodule

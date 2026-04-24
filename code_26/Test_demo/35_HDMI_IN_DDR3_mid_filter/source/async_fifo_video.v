`timescale 1ns / 1ps

module async_fifo_video #(
    parameter DATA_WIDTH = 129, // 128-bit 数据 + 1-bit tlast
    parameter ADDR_WIDTH = 9    // 深度 512 (2^9)
)(
    // 写时钟域 (Video端 - pixclk_in)
    input  wire                  wclk,
    input  wire                  wrst_n,
    input  wire                  winc,    // 写使能
    input  wire [DATA_WIDTH-1:0] wdata,   // 写入数据
    output wire                  wfull,   // 写满标志

    // 读时钟域 (PCIe端 - pcie_user_clk)
    input  wire                  rclk,
    input  wire                  rrst_n,
    input  wire                  rinc,    // 读使能
    output wire [DATA_WIDTH-1:0] rdata,   // 读出数据
    output wire                  rempty   // 读空标志
);

    // 内部信号声明
    reg  [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];
    
    reg  [ADDR_WIDTH:0]   wptr_bin, rptr_bin;
    reg  [ADDR_WIDTH:0]   wptr_gray, rptr_gray;
    
    reg  [ADDR_WIDTH:0]   wq1_rptr, wq2_rptr; // 读指针同步到写时钟域
    reg  [ADDR_WIDTH:0]   rq1_wptr, rq2_wptr; // 写指针同步到读时钟域

    wire [ADDR_WIDTH-1:0] waddr = wptr_bin[ADDR_WIDTH-1:0];
    wire [ADDR_WIDTH-1:0] raddr = rptr_bin[ADDR_WIDTH-1:0];

    wire [ADDR_WIDTH:0]   wptr_gray_next, rptr_gray_next;
    wire [ADDR_WIDTH:0]   wptr_bin_next, rptr_bin_next;

    // ==========================================
    // 1. 跨时钟域同步 (双打拍)
    // ==========================================
    // 将写指针(Gray)同步到读时钟域
    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) {rq2_wptr, rq1_wptr} <= 0;
        else         {rq2_wptr, rq1_wptr} <= {rq1_wptr, wptr_gray};
    end

    // 将读指针(Gray)同步到写时钟域
    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) {wq2_rptr, wq1_rptr} <= 0;
        else         {wq2_rptr, wq1_rptr} <= {wq1_rptr, rptr_gray};
    end

    // ==========================================
    // 2. 双端口 RAM 读写逻辑
    // ==========================================
    always @(posedge wclk) begin
        if (winc && !wfull)
            mem[waddr] <= wdata;
    end

    assign rdata = mem[raddr];

    // ==========================================
    // 3. 写指针及满标志产生 (写时钟域)
    // ==========================================
    assign wptr_bin_next  = wptr_bin + (winc & ~wfull);
    assign wptr_gray_next = (wptr_bin_next >> 1) ^ wptr_bin_next;

    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wptr_bin  <= 0;
            wptr_gray <= 0;
        end else begin
            wptr_bin  <= wptr_bin_next;
            wptr_gray <= wptr_gray_next;
        end
    end

    // 当写指针和同步过来的读指针的最高两位相反，其余位相同时，FIFO 写满
    assign wfull = (wptr_gray_next == {~wq2_rptr[ADDR_WIDTH:ADDR_WIDTH-1], wq2_rptr[ADDR_WIDTH-2:0]});

    // ==========================================
    // 4. 读指针及空标志产生 (读时钟域)
    // ==========================================
    assign rptr_bin_next  = rptr_bin + (rinc & ~rempty);
    assign rptr_gray_next = (rptr_bin_next >> 1) ^ rptr_bin_next;

    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rptr_bin  <= 0;
            rptr_gray <= 0;
        end else begin
            rptr_bin  <= rptr_bin_next;
            rptr_gray <= rptr_gray_next;
        end
    end

    // 当读指针和同步过来的写指针完全相同时，FIFO 读空
    assign rempty = (rptr_gray_next == rq2_wptr);

endmodule
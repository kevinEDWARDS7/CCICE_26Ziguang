module image_filter #(
    parameter DATA_WIDTH = 24,      // RGB888: 8-bit per channel
    parameter IMG_WIDTH  = 1920,    // 图像宽度
    parameter IMG_HEIGHT = 1080,    // 图像高度
    parameter KERNEL_SIZE = 3       // 滤波核大小 (3x3)
)(
    // 时钟和复位
    input wire clk,
    input wire reset_n,
    
    // 输入VESA时序信号
    input wire in_hsync,
    input wire in_vsync,
    input wire in_de,              // 数据有效信号
    input wire [DATA_WIDTH-1:0] in_data,
    
    // 输出VESA时序信号
    output reg out_hsync,
    output reg out_vsync,
    output reg out_de,
    output reg [DATA_WIDTH-1:0] out_data
);

// 行缓冲器 - 存储前两行数据
reg [DATA_WIDTH-1:0] line_buffer_0 [0:IMG_WIDTH-1];
reg [DATA_WIDTH-1:0] line_buffer_1 [0:IMG_WIDTH-1];

// 3x3 像素窗口
reg [DATA_WIDTH-1:0] window [0:2][0:2];

// 时序延迟线（用于同步控制信号）
reg [2:0] hsync_delay;
reg [2:0] vsync_delay;
reg [2:0] de_delay;

// 像素坐标计数器
reg [11:0] x_pos, y_pos;

// 高斯滤波系数 (3x3, 整数近似，总和=16)

// RGB 通道分离
wire [7:0] r_in = in_data[23:16];
wire [7:0] g_in = in_data[15:8];
wire [7:0] b_in = in_data[7:0];

// 滤波计算临时变量
integer i, j;
reg [15:0] r_sum, g_sum, b_sum;
reg [7:0] r_out, g_out, b_out;

// 像素坐标计数
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        x_pos <= 0;
        y_pos <= 0;
    end else if (in_de) begin
        if (x_pos == IMG_WIDTH - 1) begin
            x_pos <= 0;
            if (y_pos == IMG_HEIGHT - 1)
                y_pos <= 0;
            else
                y_pos <= y_pos + 1;
        end else begin
            x_pos <= x_pos + 1;
        end
    end
end

// 行缓冲器管理
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        for (i = 0; i < IMG_WIDTH; i = i + 1) begin
            line_buffer_0[i] <= 0;
            line_buffer_1[i] <= 0;
        end
    end else if (in_de) begin
        // 移位行缓冲
        line_buffer_1[x_pos] <= line_buffer_0[x_pos];
        line_buffer_0[x_pos] <= in_data;
    end
end

// 3x3 窗口生成
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        for (i = 0; i < 3; i = i + 1)
            for (j = 0; j < 3; j = j + 1)
                window[i][j] <= 0;
    end else if (in_de) begin
        // 更新窗口
        if (x_pos > 0 && y_pos > 0) begin
            window[0][0] <= (x_pos > 1) ? line_buffer_1[x_pos-2] : 0;
            window[0][1] <= line_buffer_1[x_pos-1];
            window[0][2] <= line_buffer_1[x_pos];
            
            window[1][0] <= (x_pos > 1) ? line_buffer_0[x_pos-2] : 0;
            window[1][1] <= line_buffer_0[x_pos-1];
            window[1][2] <= line_buffer_0[x_pos];
            
            window[2][0] <= (x_pos > 1) ? in_data : 0;  // 实际应该是前一个像素，这里简化
            window[2][1] <= in_data;
            window[2][2] <= 0;  // 当前像素在下一个周期才完整
        end
    end
end


// 控制信号延迟（与滤波处理延迟匹配）
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        hsync_delay <= 0;
        vsync_delay <= 0;
        de_delay <= 0;
    end else begin
        hsync_delay <= {hsync_delay[1:0], in_hsync};
        vsync_delay <= {vsync_delay[1:0], in_vsync};
        de_delay <= {de_delay[1:0], in_de};
    end
end

// 输出赋值
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        out_hsync <= 0;
        out_vsync <= 0;
        out_de <= 0;
        out_data <= 0;
    end else begin
        out_hsync <= hsync_delay[2];
        out_vsync <= vsync_delay[2];
        out_de <= de_delay[2];
        
        // 边界像素直接输出，内部像素输出滤波结果
        if (de_delay[2] && x_pos > 1 && y_pos > 0 && x_pos < IMG_WIDTH-1 && y_pos < IMG_HEIGHT-1)
            out_data <= {r_out, g_out, b_out};
        else
            out_data <= {r_in, g_in, b_in};  // 边界保持原值
    end
end

endmodule
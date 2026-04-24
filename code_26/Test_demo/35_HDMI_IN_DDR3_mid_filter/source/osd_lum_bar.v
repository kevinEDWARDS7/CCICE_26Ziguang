module osd_lum_bar #(
    // 你可以根据你的实际分辨率修改这里，假设你是 720p (高度720)
    parameter SCREEN_HEIGHT = 12'd720, 
    parameter BAR_HEIGHT    = 12'd20   // 能量条的粗细 (占 20 行像素)
)(
    input  wire        clk,
    
    // 坐标输入 (屏幕当前的扫描位置)
    input  wire [11:0] x_cnt,
    input  wire [11:0] y_cnt,
    
    // 亮度输入 (你的 lum_sum[27:20])
    input  wire [7:0]  avg_lum,
    
    // 原始图像输入 (从上一个模块传过来的 RGB)
    input  wire [7:0]  r_in,
    input  wire [7:0]  g_in,
    input  wire [7:0]  b_in,
    
    // 叠加能量条后的最终图像输出 (送给 HDMI 模块)
    output wire [7:0]  r_out,
    output wire [7:0]  g_out,
    output wire [7:0]  b_out
);

    // ==========================================
    // 1. 计算能量条所在的结界区域 (左下角贴地)
    // ==========================================
    wire [11:0] bar_y_start = SCREEN_HEIGHT - BAR_HEIGHT; // 从 700 行开始
    wire [11:0] bar_width   = {avg_lum, 1'b0};            // 长度 = 亮度 * 2
    
    wire in_bar_area = (y_cnt >= bar_y_start) && (y_cnt < SCREEN_HEIGHT) && (x_cnt < bar_width);

    // ==========================================
    // 2. 根据平均亮度决定颜色
    // ==========================================
    reg [7:0] bar_r, bar_g, bar_b;
    
    always @(*) begin
        if (avg_lum > 8'd150) begin
            // ?? 过曝：红色
            bar_r = 8'd255; bar_g = 8'd0;   bar_b = 8'd0;
        end else if (avg_lum > 8'd80) begin
            // ?? 正常：黄色
            bar_r = 8'd255; bar_g = 8'd255; bar_b = 8'd0;
        end else begin
            // ?? 暗光：绿色
            bar_r = 8'd0;   bar_g = 8'd255; bar_b = 8'd0;
        end
    end

    // ==========================================
    // 3. 图像信号混叠 (MUX 滤镜输出)
    // ==========================================
    // 如果在能量条区域，强制输出能量条的颜色；否则原样透传原图
    assign r_out = in_bar_area ? bar_r : r_in;
    assign g_out = in_bar_area ? bar_g : g_in;
    assign b_out = in_bar_area ? bar_b : b_in;

endmodule
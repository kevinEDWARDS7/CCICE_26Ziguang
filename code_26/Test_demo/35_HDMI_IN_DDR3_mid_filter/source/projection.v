`timescale 1ns / 1ps
module projection(
    input  wire        video_clk,
    input  wire        rst_n,
    input  wire        video_vs,
    input  wire        video_de,
    input  wire        video_data,

    output reg  [11:0] x_min_1, output reg  [11:0] x_max_1, output reg  [11:0] y_min_1, output reg  [11:0] y_max_1,
    output reg  [11:0] x_min_2, output reg  [11:0] x_max_2, output reg  [11:0] y_min_2, output reg  [11:0] y_max_2,
    output reg  [11:0] x_min_3, output reg  [11:0] x_max_3, output reg  [11:0] y_min_3, output reg  [11:0] y_max_3
);

    // ==========================================
    // ⚙️ 核心调参区 (防抖与抗干扰中心) - 架构师手术刀版
    // ==========================================
    parameter MIN_Y_VALID    = 12'd150; // 物理死区：避开顶部UI菜单
    parameter JITTER_TH      = 12'd30;  // 防抖死区：过滤微小抽搐

    // ------------------------------------------
    // 🔪 手术一：基础连线特征 (杀碎点，保车牌，防乱吸)
    // ------------------------------------------
    parameter MAX_X_GAP      = 8'd20;  
    parameter MIN_LINE_WIDTH = 12'd20;  // 一根白线连续 > 30 像素才算数 (过滤格栅短碎噪点)
    parameter MAX_LINE_WIDTH = 12'd200; // 释放上限，让几百像素宽的真车牌能活下来
    
    parameter MAX_X_OVERLAP  = 12'd30;  // 横向字符间的最小宽度
    parameter MAX_Y_GAP      = 8'd6;    // 🚨 纵向容错率削弱：断层超过 3 行立马一刀两断，防吸格栅

    // ------------------------------------------
    // 🔪 手术二：物理尺寸极限过滤器 (杀巨型框)
    // ------------------------------------------
    parameter MIN_BOX_WIDTH  = 12'd80; 
    parameter MIN_BOX_HEIGHT = 12'd20; 
    parameter MAX_BOX_WIDTH  = 12'd450; // 🚨 宽度天花板：再大的车牌也不可能超 450
    parameter MAX_BOX_HEIGHT = 12'd180; // 🚨 高度天花板：再高的车牌也不可能超 180

    // ==========================================
    // --- 1. 同步信号 (原有时序，完美保留) ---
    // ==========================================
    reg video_de_r, video_vs_r;
    always @(posedge video_clk) begin
        video_de_r <= video_de;
        video_vs_r <= video_vs;
    end
    wire de_falling = (~video_de & video_de_r); 
    wire vs_rising  = (video_vs & ~video_vs_r); 

    reg [11:0] x_cnt, y_cnt;
    always @(posedge video_clk or negedge rst_n) begin
        if(!rst_n) begin
            x_cnt <= 0; y_cnt <= 0;
        end else if(vs_rising) begin 
            x_cnt <= 0; y_cnt <= 0;
        end else if(video_de) begin
            x_cnt <= x_cnt + 1;
        end else if(de_falling) begin
            x_cnt <= 0; y_cnt <= y_cnt + 1;
        end
    end

    // ==========================================
    // --- 2. 最大连续块追踪 ---
    // ==========================================
    reg [11:0] streak_w_cnt, streak_x_min, streak_x_max;
    reg [7:0]  gap_cnt; 
    reg [11:0] best_w_cnt, best_x_min, best_x_max;

    always @(posedge video_clk or negedge rst_n) begin
        if(!rst_n) begin
            streak_w_cnt <= 0; gap_cnt <= 0;
            best_w_cnt <= 0; best_x_min <= 0; best_x_max <= 0;
        end else if(vs_rising || de_falling) begin
            streak_w_cnt <= 0; gap_cnt <= 0;
            best_w_cnt <= 0; best_x_min <= 0; best_x_max <= 0;
        end else if(video_de) begin
            if(video_data == 1'b1) begin
                gap_cnt <= 0; 
                if(streak_w_cnt == 0) streak_x_min <= x_cnt; 
                streak_x_max <= x_cnt; 
                streak_w_cnt <= streak_w_cnt + 1;
            end else begin
                if(streak_w_cnt > 0) begin
                    gap_cnt <= gap_cnt + 1;
                    if(gap_cnt > MAX_X_GAP) begin
                        if((streak_w_cnt > best_w_cnt)&&(streak_w_cnt<MAX_LINE_WIDTH)) begin
                            best_w_cnt <= streak_w_cnt;
                            best_x_min <= streak_x_min;
                            best_x_max <= streak_x_max;
                        end
                        streak_w_cnt <= 0; 
                    end
                end
            end
        end
    end
    wire valid_streak=(streak_w_cnt<MAX_LINE_WIDTH);
    wire [11:0] final_best_w_cnt = (valid_streak&&(streak_w_cnt > best_w_cnt)) ? streak_w_cnt : best_w_cnt;
    wire [11:0] final_best_x_min = (valid_streak&&(streak_w_cnt > best_w_cnt)) ? streak_x_min : best_x_min;
    wire [11:0] final_best_x_max = (valid_streak&&(streak_w_cnt > best_w_cnt)) ? streak_x_max : best_x_max;

    // ==========================================
    // --- 3. 多目标队列与【三通道防抖引擎】 ---
    // ==========================================
    reg box_active;
    reg [11:0] cur_x_min, cur_x_max, cur_y_min, cur_y_max;
    reg [7:0]  box_y_gap; 

    // 缓存数组
    reg [11:0] t_x_min[0:2]; reg [11:0] t_x_max[0:2];
    reg [11:0] t_y_min[0:2]; reg [11:0] t_y_max[0:2];
    reg [1:0]  box_count;

    wire [11:0] cur_box_width  = cur_x_max - cur_x_min;
    wire [11:0] cur_box_height = cur_y_max - cur_y_min;

    // ------------------------------------------
    // 🔪 手术三：终极形态鉴别器 (尺寸与比例重塑)
    // ------------------------------------------
    // 1. 宽松但合规的比例：宽度必须大于高度，且不超过高度的 6 倍
    wire valid_ratio = (cur_box_width > cur_box_height) && (cur_box_width < (cur_box_height * 9));
    
    // 2. 绝对尺寸钳制：太小不要，太大(巨型框)直接绞杀
    wire valid_size  = (cur_box_width > MIN_BOX_WIDTH)  && (cur_box_width < MAX_BOX_WIDTH) && 
                       (cur_box_height > MIN_BOX_HEIGHT) && (cur_box_height < MAX_BOX_HEIGHT);
                       
    wire is_plate    = valid_ratio && valid_size;


    // ️ 预计算 3 个目标的新坐标 (提取缓存中的数据)
    wire [11:0] new_x_min_1 = (box_count > 0) ? t_x_min[0] : cur_x_min;
    wire [11:0] new_x_max_1 = (box_count > 0) ? t_x_max[0] : cur_x_max;
    wire [11:0] new_y_min_1 = (box_count > 0) ? t_y_min[0] : cur_y_min;
    wire [11:0] new_y_max_1 = (box_count > 0) ? t_y_max[0] : cur_y_max;

    wire [11:0] new_x_min_2 = (box_count > 1) ? t_x_min[1] : cur_x_min;
    wire [11:0] new_x_max_2 = (box_count > 1) ? t_x_max[1] : cur_x_max;
    wire [11:0] new_y_min_2 = (box_count > 1) ? t_y_min[1] : cur_y_min;
    wire [11:0] new_y_max_2 = (box_count > 1) ? t_y_max[1] : cur_y_max;

    wire [11:0] new_x_min_3 = (box_count > 2) ? t_x_min[2] : cur_x_min;
    wire [11:0] new_x_max_3 = (box_count > 2) ? t_x_max[2] : cur_x_max;
    wire [11:0] new_y_min_3 = (box_count > 2) ? t_y_min[2] : cur_y_min;
    wire [11:0] new_y_max_3 = (box_count > 2) ? t_y_max[2] : cur_y_max;

    // ️ 计算坐标偏移量 (绝对值平替算法)
    wire [11:0] diff_x_1 = (new_x_min_1 > x_min_1) ? (new_x_min_1 - x_min_1) : (x_min_1 - new_x_min_1);
    wire [11:0] diff_y_1 = (new_y_min_1 > y_min_1) ? (new_y_min_1 - y_min_1) : (y_min_1 - new_y_min_1);
    wire update_1 = (x_max_1 == 0) || (diff_x_1 > JITTER_TH) || (diff_y_1 > JITTER_TH);

    wire [11:0] diff_x_2 = (new_x_min_2 > x_min_2) ? (new_x_min_2 - x_min_2) : (x_min_2 - new_x_min_2);
    wire [11:0] diff_y_2 = (new_y_min_2 > y_min_2) ? (new_y_min_2 - y_min_2) : (y_min_2 - new_y_min_2);
    wire update_2 = (x_max_2 == 0) || (diff_x_2 > JITTER_TH) || (diff_y_2 > JITTER_TH);

    wire [11:0] diff_x_3 = (new_x_min_3 > x_min_3) ? (new_x_min_3 - x_min_3) : (x_min_3 - new_x_min_3);
    wire [11:0] diff_y_3 = (new_y_min_3 > y_min_3) ? (new_y_min_3 - y_min_3) : (y_min_3 - new_y_min_3);
    wire update_3 = (x_max_3 == 0) || (diff_x_3 > JITTER_TH) || (diff_y_3 > JITTER_TH);


    always @(posedge video_clk or negedge rst_n) begin
        if(!rst_n) begin
            cur_x_min <= 12'd4000; cur_x_max <= 0; cur_y_min <= 12'd4000; cur_y_max <= 0;
            box_active <= 0; box_y_gap <= 0; box_count <= 0;
            x_min_1 <= 0; x_max_1 <= 0; y_min_1 <= 0; y_max_1 <= 0;
            x_min_2 <= 0; x_max_2 <= 0; y_min_2 <= 0; y_max_2 <= 0;
            x_min_3 <= 0; x_max_3 <= 0; y_min_3 <= 0; y_max_3 <= 0;
        end else if(vs_rising) begin
            
            //  帧结算时刻：带防抖的通道更新
            if (box_count > 0 || (box_active && is_plate)) begin 
                if (update_1) begin
                    x_min_1 <= new_x_min_1; x_max_1 <= new_x_max_1; 
                    y_min_1 <= new_y_min_1; y_max_1 <= new_y_max_1; 
                end
            end else begin x_max_1 <= 0; end 
            
            if (box_count > 1 || (box_count == 1 && box_active && is_plate)) begin 
                if (update_2) begin
                    x_min_2 <= new_x_min_2; x_max_2 <= new_x_max_2; 
                    y_min_2 <= new_y_min_2; y_max_2 <= new_y_max_2; 
                end
            end else begin x_max_2 <= 0; end
            
            if (box_count > 2 || (box_count == 2 && box_active && is_plate)) begin 
                if (update_3) begin
                    x_min_3 <= new_x_min_3; x_max_3 <= new_x_max_3; 
                    y_min_3 <= new_y_min_3; y_max_3 <= new_y_max_3; 
                end
            end else begin x_max_3 <= 0; end
            
            // 清理状态，准备扫下一帧
            cur_x_min <= 12'd4000; cur_x_max <= 0; cur_y_min <= 12'd4000; cur_y_max <= 0;
            box_active <= 0; box_y_gap <= 0; box_count <= 0; 
            
        end else if(de_falling) begin
            
            //  核心过滤：y_cnt > MIN_Y_VALID，强行无视顶部的 UI 栏！
            if (final_best_w_cnt > MIN_LINE_WIDTH && y_cnt > MIN_Y_VALID && y_cnt < 12'd700) begin
                if (!box_active) begin
                    cur_x_min <= final_best_x_min; cur_x_max <= final_best_x_max;
                    cur_y_min <= y_cnt; cur_y_max <= y_cnt;
                    box_active <= 1'b1; box_y_gap <= 0;
                end else begin
                    // 🚨 这里就是刚才调严的 MAX_X_OVERLAP 起作用的地方！不会再去贪婪地吸车灯了！
                    if ((final_best_x_max + MAX_X_OVERLAP >= cur_x_min) && (final_best_x_min <= cur_x_max + MAX_X_OVERLAP)) begin
                        if(final_best_x_min < cur_x_min) cur_x_min <= final_best_x_min;
                        if(final_best_x_max > cur_x_max) cur_x_max <= final_best_x_max;
                        cur_y_max <= y_cnt; box_y_gap <= 0; 
                    end else begin box_y_gap <= box_y_gap + 1; end
                end
            end else begin
                if (box_active) box_y_gap <= box_y_gap + 1;
            end

            // 🚨 这里就是刚才调严的 MAX_Y_GAP 起作用的地方！断开超过3行直接结算！
            if (box_active && box_y_gap > MAX_Y_GAP) begin
                if (is_plate && box_count < 3) begin
                    t_x_min[box_count] <= cur_x_min; t_x_max[box_count] <= cur_x_max;
                    t_y_min[box_count] <= cur_y_min; t_y_max[box_count] <= cur_y_max;
                    box_count <= box_count + 1;
                end
                cur_x_min <= 12'd4000; cur_x_max <= 0; cur_y_min <= 12'd4000; cur_y_max <= 0;
                box_active <= 0; box_y_gap <= 0;
            end
        end
    end
endmodule
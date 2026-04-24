module box_display(
    input pix_clk, input rst_n, input i_de,
    input [11:0] x_act, input [11:0] y_act,
    // 接收 3 个框
    input [11:0] x_min_1, input [11:0] x_max_1, input [11:0] y_min_1, input [11:0] y_max_1,
    input [11:0] x_min_2, input [11:0] x_max_2, input [11:0] y_min_2, input [11:0] y_max_2,
    input [11:0] x_min_3, input [11:0] x_max_3, input [11:0] y_min_3, input [11:0] y_max_3,
    output o_de, output o_rgb
);
    assign o_de = i_de;

    // 分别判断当前像素是否在三个框的边缘 (线宽 2 像素)
    wire box1 = (x_max_1 > 0) && 
                ((x_act >= x_min_1 && x_act <= x_max_1 && (y_act == y_min_1 || y_act == y_max_1 || y_act == y_min_1+1 || y_act == y_max_1-1)) ||
                 (y_act >= y_min_1 && y_act <= y_max_1 && (x_act == x_min_1 || x_act == x_max_1 || x_act == x_min_1+1 || x_act == x_max_1-1)));
                 
    wire box2 = (x_max_2 > 0) && 
                ((x_act >= x_min_2 && x_act <= x_max_2 && (y_act == y_min_2 || y_act == y_max_2 || y_act == y_min_2+1 || y_act == y_max_2-1)) ||
                 (y_act >= y_min_2 && y_act <= y_max_2 && (x_act == x_min_2 || x_act == x_max_2 || x_act == x_min_2+1 || x_act == x_max_2-1)));

    wire box3 = (x_max_3 > 0) && 
                ((x_act >= x_min_3 && x_act <= x_max_3 && (y_act == y_min_3 || y_act == y_max_3 || y_act == y_min_3+1 || y_act == y_max_3-1)) ||
                 (y_act >= y_min_3 && y_act <= y_max_3 && (x_act == x_min_3 || x_act == x_max_3 || x_act == x_min_3+1 || x_act == x_max_3-1)));

    // 只要属于任何一个框，就画红线！
    assign o_rgb = box1 | box2 | box3;
endmodule
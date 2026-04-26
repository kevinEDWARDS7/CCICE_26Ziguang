`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: ms72xx_ctl (纯接收端 RX 版本)
// Description: 该版本已剥离 ms7210_ctl 发送端逻辑，专用于 ms7200 接收端的 I2C 初始化
//////////////////////////////////////////////////////////////////////////////////

`define UD #1
module ms72xx_ctl(
    input       clk,
    input       rst_n,
    
    output      init_over_rx,
    output      init_over,
    output      iic_scl,
    inout       iic_sda
);

    //=========================================================
    // 异步复位同步释放
    //=========================================================
    reg rstn_temp1, rstn_temp2;
    reg rstn;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            rstn_temp1 <= 1'b0;
        else
            rstn_temp1 <= rst_n;
    end
    
    always @(posedge clk) begin
        rstn_temp2 <= rstn_temp1;
        rstn <= rstn_temp2;
    end
    
    //=========================================================
    // 内部连线声明
    //=========================================================
    wire         init_over_rx_w;
    wire   [7:0] device_id;
    wire         iic_trig;
    wire         w_r;
    wire  [15:0] addr        /*synthesis PAP_MARK_DEBUG="true"*/;
    wire  [ 7:0] data_in;
    wire         busy;
    wire  [ 7:0] data_out    /*synthesis PAP_MARK_DEBUG="true"*/;
    wire         byte_over   /*synthesis PAP_MARK_DEBUG="true"*/;

    // 分配输出完成信号，并将 TX 的完成信号与 RX 绑定，防止顶层悬空
    assign init_over_rx = init_over_rx_w;
    assign init_over    = init_over_rx_w; 
    
    // MS7200 (RX) 的 I2C 设备地址硬编码为 8'h56
    assign device_id    = 8'h56;

    //=========================================================
    // 例化 MS7200 (RX) 状态机
    //=========================================================
    ms7200_ctl U1_ms7200_ctl(
        .clk             ( clk            ), //input               
        .rstn            ( rstn           ), //input               
                              
        .init_over       ( init_over_rx_w ), //output reg          
        .device_id       (                ), //原版为空，外部使用 assign device_id 固定地址
        .iic_trig        ( iic_trig       ), //output reg          
        .w_r             ( w_r            ), //output reg          
        .addr            ( addr           ), //output reg   [15:0] 
        .data_in         ( data_in        ), //output reg   [ 7:0] 
        .busy            ( busy           ), //input               
        .data_out        ( data_out       ), //input        [ 7:0] 
        .byte_over       ( byte_over      )  //input               
    );
    
    //=========================================================
    // 例化 I2C 底层驱动模块
    //=========================================================
    wire         sda_in      /*synthesis PAP_MARK_DEBUG="true"*/;
    wire         sda_out     /*synthesis PAP_MARK_DEBUG="true"*/;
    wire         sda_out_en  /*synthesis PAP_MARK_DEBUG="true"*/;  
    
    iic_dri #(
        .CLK_FRE        ( 27'd10_000_000 ), // parameter CLK_FRE = 27'd50_000_000, 保持参考配置，25M下略微降速更稳定
        .IIC_FREQ       ( 20'd400_000    ), // parameter IIC_FREQ = 20'd400_000, I2c clock frequency
        .T_WR           ( 10'd1          ), // parameter T_WR = 10'd5, I2c transmit delay ms
        .ADDR_BYTE      ( 2'd2           ), // parameter ADDR_BYTE = 2'd1, I2C addr byte number
        .LEN_WIDTH      ( 8'd3           ), // parameter LEN_WIDTH = 8'd3, I2C transmit byte width
        .DATA_BYTE      ( 2'd1           )  // parameter DATA_BYTE = 2'd1, I2C data byte number
    ) iic_dri (                       
        .clk            ( clk            ), // input clk,
        .rstn           ( rstn           ), // input rstn,
        .device_id      ( device_id      ), // input device_id,
        .pluse          ( iic_trig       ), // input pluse, I2C transmit trigger
        .w_r            ( w_r            ), // input w_r, I2C transmit direction 1:send  0:receive
        .byte_len       ( 4'd1           ), // input [LEN_WIDTH:0] byte_len, I2C transmit data byte length of once trigger
                   
        .addr           ( addr           ), // input [7:0] addr, I2C transmit addr
        .data_in        ( data_in        ), // input [7:0] data_in, I2C send data
                     
        .busy           ( busy           ), // output reg busy=0, I2C bus status
        
        .byte_over      ( byte_over      ), // output reg byte_over=0, I2C byte transmit over flag               
        .data_out       ( data_out       ), // output reg[7:0] data_out, I2C receive data
                                           
        .scl            ( iic_scl        ), // output scl,
        .sda_in         ( sda_in         ), // input  sda_in,
        .sda_out        ( sda_out        ), // output reg sda_out=1'b1,
        .sda_out_en     ( sda_out_en     )  // output sda_out_en
    );
    
    //=========================================================
    // I2C SDA 三态门驱动 (严格开漏配置)
    //=========================================================
    assign iic_sda = sda_out_en ? sda_out : 1'bz;
    assign sda_in  = iic_sda;
    
endmodule
module sobel  
(
	input		wire				video_clk		,
	input		wire				rst_n			,
    input       wire    [7:0]      threshold  , 
		
	//矩阵数据输入	
	input		wire				matrix_de		,
	input		wire				matrix_vs		,
	input		wire	[7:0]		matrix11 		,	
	input		wire	[7:0]   	matrix12 		,
	input		wire	[7:0]   	matrix13 		,
			
	input		wire	[7:0]		matrix21 		,
	input		wire	[7:0]   	matrix22 		,
	input		wire	[7:0]   	matrix23 		,
													
	input		wire	[7:0]		matrix31 		,
	input		wire	[7:0]   	matrix32 		,
	input		wire	[7:0]   	matrix33 		,	
    
	//sobel数据输出
	output		wire				sobel_vs		,
	output		wire				sobel_de		,
	output		wire	[7:0]		sobel_data
);

/****************************************************************
reg define
****************************************************************/
reg	[9:0]	gx_temp1;
reg	[9:0]	gx_temp2;
reg	[9:0]	gy_temp1;
reg	[9:0]	gy_temp2;

/****************************************************************
step1 计算卷积 (第1拍)
****************************************************************/
always@(posedge video_clk or negedge rst_n)	begin
	if(!rst_n) begin
		gx_temp1	<=	10'd0; 
        gx_temp2	<=	10'd0;
	end
	else if(matrix_de) begin
		gx_temp1	<=	matrix13 + 2*matrix23 + matrix33;
		gx_temp2	<=	matrix11 + 2*matrix21 + matrix31;
	end
	else begin
		gx_temp1	<=	10'd0;
        gx_temp2	<=	10'd0;
	end
end

always@(posedge video_clk or negedge rst_n)	begin
	if(!rst_n) begin
		gy_temp1	<=	10'd0;
        gy_temp2	<=	10'd0;
	end
	else if(matrix_de) begin
		gy_temp1	<=	matrix11 + 2*matrix12 + matrix13; 
		gy_temp2	<=	matrix31 + 2*matrix32 + matrix33; 
	end
	else begin
		gy_temp1	<=	10'd0;
        gy_temp2	<=	10'd0;
	end
end

/****************************************************************
step2 求卷积绝对值 (第2拍)
****************************************************************/
reg	[9:0]	gx_data;
reg	[9:0]	gy_data;
	
always@(posedge video_clk or negedge rst_n)	begin
	if(!rst_n)
		gx_data	<=	10'd0;
	else if(gx_temp1 >= gx_temp2)
		gx_data	<=	gx_temp1 - gx_temp2;
	else
		gx_data	<=	gx_temp2 - gx_temp1;
end

always@(posedge video_clk or negedge rst_n)	begin
	if(!rst_n)
		gy_data	<=	10'd0;
	else if(gy_temp1 >= gy_temp2)
		gy_data	<=	gy_temp1 - gy_temp2;
	else
		gy_data	<=	gy_temp2 - gy_temp1;
end
	
/****************************************************************
step3 绝对值相加 & 方向特征提取 (第3拍)
****************************************************************/
reg	[10:0]	sobel_data_reg;
reg         is_vertical_edge; 

always@(posedge video_clk or negedge rst_n)	begin
	if(!rst_n) begin
		sobel_data_reg	 <=	11'd0;
        is_vertical_edge <= 1'b0;
    end else begin
		sobel_data_reg	 <=	gx_data + gy_data;
        
        // ==========================================
        // 🚀 终极物理过滤：极严的垂直方向校验
        // ==========================================
        // 原来是 gx_data > (gy_data >> 2)，太松了，横向噪点全漏进来了！
        // 🚨 现在改为：gx_data > gy_data！
        // 意思是：这个边缘的【竖直倾向】必须大于【水平倾向】（角度大于45度）！
        // 车灯横边、进气格栅的横条、保险杠，瞬间全部被抹杀！！！
        is_vertical_edge <= (gx_data > gy_data);
    end
end

/************************************************************
时钟延迟 一共延迟 3clk (完美匹配 sobel_data_reg 的第3拍)
************************************************************/
reg	[2:0]	video_de_reg;
reg	[2:0]	video_vs_reg;

always@(posedge video_clk or negedge rst_n)	begin
	if(!rst_n) begin
		video_de_reg	<=	3'd0;
        video_vs_reg	<=	3'd0;
	end
	else begin
		video_de_reg	<=	{video_de_reg[1:0], matrix_de};
        video_vs_reg	<=	{video_vs_reg[1:0], matrix_vs};
	end
end

assign	sobel_vs = video_vs_reg[2];
assign	sobel_de = video_de_reg[2];

// ==========================================
// 🚀 终极输出：最干脆的单阈值 + 严格垂直特征
// ==========================================
assign sobel_data = ((sobel_data_reg >= threshold) && is_vertical_edge) ? 8'd255 : 8'd0;	

endmodule
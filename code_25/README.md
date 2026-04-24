# 2026 紫光同创赛题项目接手说明

## 1. 这份 README 是给谁看的

这份 README 不是通用开源项目说明，而是给“已经接手这个赛题项目的人”看的。

默认读者画像就是现在的我们：

- 已经有上一届学长留下来的文档和代码
- 手里已经有板卡和手册
- 目标不是重新发散方案，而是沿着已经收敛的路线继续推进
- 需要快速判断：哪块板做什么、当前代码对应哪里、下一步该怎么改

所以这份 README 的重点不是泛泛介绍，而是直接回答：

1. 今年赛题到底在考什么。
2. 当前最可行的系统链路是什么。
3. 每块板卡在系统里扮演什么角色。
4. 当前仓库代码分别对应哪一段链路。
5. 哪些模块优先复用，哪些模块需要改成今年赛题版本。

## 2. 项目当前的默认总目标

当前项目的默认目标链路已经确定为：

```text
外部视频源
-> 前端 FPGA 板进行视频输入与预处理
-> 通过高速链路送入 RK3568 异构平台
-> 异构平台 FPGA 接收、缓存、整理，并通过 PCIe 送到 RK3568
-> RK3568 完成 AI 模型推理、显示和结果输出
```

更具体地说，当前默认主线是：

```text
视频源
-> 40PIN转HDMI子卡
-> 异构平台 FPGA 接收、解包、缓存、整理
-> 通过 PCIe DMA 送给 RK3568
-> RK3568 做模型推理、Qt 显示、结果输出
```

除非后续赛题原文明确否定，否则这条链路就是当前工程默认路线。

## 3. 当前判断依据与优先级

当前目录中的关键资料如下，后续所有判断默认按优先级使用：

1. `2026年紫光同创赛题.pdf`
2. `紫光同创公司官方赛题解析.md`
3. `RK3568_MES2L50H_100H_板子资源手册_v1.1.pdf`
4. `初赛技术报告_final.docx`
5. code_25：上一届学长原码
6. 本仓库源码

执行原则：

- 赛题原文优先级最高。
- 官方解析优先级高于个人推测。
- 手册优先级高于口头型号印象。
- 上一届技术报告和代码是强参考，但不能压过赛题要求。

## 4. 赛题要求，按工程语言重新解释

结合赛题和官方解析，今年项目重点不是“做一个能显示视频的系统”，而是：

- 用 FPGA 承担视频前处理和数据整理
- 用 PCIe 打通 FPGA 到 RK3568 的高速数据路径
- 在 RK3568 上完成模型部署与识别
- 做出“软硬协同”的方案，而不是纯软件识别

官方解析里能落到工程实现上的关键信息有：

### 4.1 输入源在 FPGA 侧

官方明确提到 FPGA 侧可以接：

- HDMI 输入
- 40pin 扩展口接 OV5640

这意味着今年赛题天然允许“前端 FPGA 先接视频，再送给 RK3568”的路线。

### 4.2 FPGA 要承担前处理

官方解析明确鼓励 FPGA 做：

- RGB 转 HSV
- 颜色特征提取
- Sobel 边缘
- 形态学处理
- 倾斜矫正
- 低照增强的一部分

因此 FPGA 在今年不是“纯数据搬运工”，而是前处理加速器。

### 4.3 RK3568 做语义级识别

官方解析建议 RK3568 负责：

- 车牌字符识别
- 小型分类网络
- 更复杂的低照 / 远距离识别补偿

也就是说：

```text
FPGA 更偏前端视觉流水
RK3568 更偏后端 AI 语义识别
```

## 5. 当前已经收敛的关键判断

以下结论默认成立，除非后续从赛题原文或手册里找到更强反证：

### 5.1 RK3568 异构平台需要搭配40PIN转HDMI子卡才能做 HDMI 采集板

从 `RK3568_MES2L50H_100H_板子资源手册_v1.1.pdf` 目前能直接确认的是：

- RK3568 ARM 侧有 `HDMI OUT`
- FPGA 侧有 `SFP / FMC / 40pin / DDR3`
- FPGA 与 RK3568 之间有 `PCIe / FSPI / I2C`

因此当前需要搭配40PIN转HDMI子卡才能做 HDMI 采集板。

### 5.2 异构平台上的 FPGA 不是简单桥接器

它应该承担：

- 外部输入接收
- 板间数据接收与解包
- DDR 缓存与帧管理
- 多路数据整理与仲裁
- PCIe DMA 到 RK3568


### 5.4 上一届方案高度相关，不应放弃

上一届技术报告已经形成了非常接近今年目标的路径：

```text
前端视频输入
-> FPGA 预处理
-> 光纤传输
-> 异构平台 FPGA 接收
-> PCIe 到 RK3568
-> RK3568 上显示与识别
```

这说明当前仓库不是无关历史代码，而是非常值得复用的基础工程。


## 6. 板卡映射，必须先分清

这个项目最容易出错的地方就是型号和角色混用。

### 6.1 RK3568 异构平台

对应资料：

- `RK3568_MES2L50H_100H_板子资源手册_v1.1.pdf`

对应实物：

- `RK3568 + PG2L50H`
- `RK3568 + PG2L100H`

在系统中的推荐角色：

- 后端异构处理平台
- FPGA 汇聚与 PCIe 输出节点
- RK3568 AI 推理节点

## 7. 当前推荐的正式系统链路

### 7.1 工程主链路

```text
视频、图片源(单路即可，无需多路)
-> 40PIN转HDMI子卡

-> RK3568 异构平台 FPGA
   -> 本地输入汇聚（FMC / 40pin）
   -> 帧缓存 / 通道仲裁 / ROI 或整帧整理
   -> PCIe DMA

-> RK3568
   -> PCIe 取流
   -> RKNN / 轻量模型推理
   -> Qt 显示
   -> 结果输出
```



## 8. 当前仓库代码与系统角色的对应关系

### 8.1 `four_pinjie_video/`

这部分代码对应前端盘古视频板。

它在系统中的职责是：

- 接 HDMI / 摄像头
- 做前处理
- 写入 DDR
- 打包后通过光纤发送

当前关键入口文件：

- `four_pinjie_video/four_pinjie_video/HDMI_DDR3_OV5640/source/rtl/hdmi_ddr_ov5640_top.v`

关键模块：

- `ms7200_ctl.v`
- `ms7200_double_crtl.v`
- `ms7210_ctl.v`
- `video_scale_process.v`
- `frame_read_write.v`
- `mem_read_arbi.v`
- `mem_write_arbi.v`
- `video_packet_send.v`

结论：

- 这是当前仓库里最值得优先复用的“前端视频输入与预处理工程”。

### 8.2 `four_pinjie_basic/`

这部分代码对应中间基础板。

它在上一届系统中的职责是：

- 接收前级视频板通过光纤发来的数据
- 做本地汇聚、缓存、拼接
- 再发送给后级

当前关键入口文件：

- `four_pinjie_basic/four_pinjie_basic/HDMI_DDR3_OV5640/source/rtl/hdmi_ddr_ov5640_top.v`

关键模块：

- `video_packet_rec.v`
- `video_packet_send.v`
- `video_scale_process.v`
- `frame_read_write.v`

结论：

- 如果我们保留上一届“多板级联拼接”架构，它非常重要。
- 如果只做今年赛题最小链路，它不是第一阶段必须保留的部分。

### 8.3 `dl/`

这部分代码对应后端异构平台 FPGA 工程。

它在当前系统里的职责是：

- 接收本地摄像头 / FMC 输入
- 接收光纤输入
- 做帧缓存、通道管理、通路组织
- 通过 PCIe DMA 送给 RK3568

当前关键入口文件：

- `dl/dl/source/dl_fpga_prj.v`

关键模块分层：

#### 输入侧

- `ov5640_capture_manager.v`
- `cmos_8_16bit.v`
- `cmos_pixel_width_adapter.v`
- `reg_config.v`
- `power_on_delay.v`

#### DDR / 帧缓存

- `frame_ddr3/frame_read_write*.v`
- `frame_ddr3/frame_fifo_write*.v`
- `frame_ddr3/frame_fifo_read*.v`
- `frame_ddr3/mem_read_arbiter.v`
- `frame_ddr3/mem_write_arbiter.v`

#### PCIe / DMA

- `pcie/pcie_dma_core.v`
- `pcie/ips2l_pcie_dma.v`
- `pcie/pcie_dma_ctrl/*`

#### 自定义图像整理

- `user/img_data_stream_reducer.v`
- `user/pcie_image_channel_selector.v`
- `user/pcie_img_select.v`

结论：

- 这部分代码就是当前“异构平台 FPGA 做汇聚、缓存、PCIe 输出”的关键底座。

### 8.4 `rk_new12/pcie_yolo/`

这部分代码对应 RK3568 软件工程。

它不是 PC 端程序，而是部署到 RK3568 上运行的 Qt + RKNN 应用。

当前关键入口：

- `main.cpp`
- `mainwindow.cpp`
- `FPGA_pcie.cpp`
- `rknn_object_detector.cpp`

当前职责：

- 通过驱动读取 PCIe 图像流
- Qt 界面显示
- RKNN 模型推理

结论：

- 软件通路已经很有价值，可以直接复用。
- 但当前模型任务偏通用目标检测，必须改造成今年赛题任务。

## 9. 哪些代码优先复用

当前策略不是“重新写一套”，而是“优先移植 + 裁剪 + 重构”。

### 9.1 前端 FPGA 优先复用

- HDMI 初始化
  - `ms7200_ctl.v`
  - `ms7200_double_crtl.v`
- HDMI 输出初始化
  - `ms7210_ctl.v`
- 摄像头初始化
  - `power_on_delay.v`
  - `reg_config.v`
  - `cmos_8_16bit.v`
  - `cmos_pixel_width_adapter.v`
- 图像缩放
  - `video_scale_process.v`
- DDR 帧缓存
  - `frame_read_write.v`
  - `frame_fifo_write.v`
  - `frame_fifo_read.v`
  - `mem_write_arbi.v`
  - `mem_read_arbi.v`
- 光纤打包与收发
  - `video_packet_send.v`
  - `video_packet_rec.v`

### 9.2 异构平台 FPGA 优先复用

- 输入与摄像头采集框架
  - `ov5640_capture_manager.v`
- DDR 帧缓存框架
  - `frame_ddr3/*`
- PCIe DMA 框架
  - `pcie_dma_core.v`
  - `pcie_dma_ctrl/*`
- 图像整理 / 通道选择
  - `img_data_stream_reducer.v`
  - `pcie_image_channel_selector.v`

### 9.3 RK3568 软件优先复用

- PCIe 取流
  - `FPGA_pcie.cpp`
- Qt UI
  - `mainwindow.cpp`
  - `mainwindow.ui`
- 图像工具链
  - `image_utils.c`
- 模型推理框架
  - `rknn_object_detector.cpp`

## 10. 哪些部分必须改造

虽然现有工程很有价值，但不能直接原样交赛题。

必须改的部分包括：

### 10.1 任务定义要从“通用多路视频演示”改成“交通感知”

上一届代码和报告偏：

- 多路视频采集
- 拼接显示
- 通用目标识别

今年要改成：

- 交通感知 / 车牌识别 / 目标定位
- FPGA 前处理
- RK3568 语义识别

### 10.2 模型任务要替换

当前 `rknn_object_detector.cpp` 使用的是通用检测逻辑，类别表也是通用类别。

今年要替换成：

- 车牌 ROI 检测后字符识别
- 或者符合赛题的交通场景模型

### 10.3 FPGA 前处理要更贴近赛题评分点

当前仓库已有：

- 缩放
- 滤波
- 帧缓存
- 通道组织

后续应优先补齐：

- RGB -> HSV
- 颜色阈值
- Sobel
- 形态学
- ROI 粗定位

## 11. 代码里哪些目录不是重点

不建议优先阅读：

- `*/project/compile/`
- `*/project/device_map/`
- `*/project/generate_bitstream/`
- `*/project/place_route/`
- `*/project/report_timing/`
- `*/project/log*/`
- `*/project/ipcore/`
- `rk_new12/pcie_yolo/build-fixed/`
- `rk_new12/pcie_yolo/3rdparty/`

这些大多是：

- FPGA 工具生成产物
- 编译中间文件
- 第三方依赖

真正值得优先读的是：

- 顶层 `*.v`
- `source/rtl/`
- `source/frame_*`
- `source/pcie/*`
- `source/user/*`
- `mainwindow.cpp`
- `FPGA_pcie.cpp`
- `rknn_object_detector.cpp`

## 12. 建议阅读顺序

如果现在是新接手项目，建议按下面顺序理解：

1. `紫光同创公司官方赛题解析.md`
2. `RK3568_MES2L50H_100H_板子资源手册_v1.1.pdf`
3. `MES50H-HDMI硬件资源手册v1.1(也就是初赛文档里面的盘古20视频板).pdf`
4. `初赛技术报告_final.docx`
5. `rk_new12/pcie_yolo/mainwindow.cpp`
6. `rk_new12/pcie_yolo/FPGA_pcie.cpp`
7. `dl/dl/source/dl_fpga_prj.v`
8. `four_pinjie_video/.../rtl/hdmi_ddr_ov5640_top.v`
9. `four_pinjie_video/.../video_packet_send.v`
10. `four_pinjie_basic/.../video_packet_rec.v`

## 13. 当前建议的推进顺序

后续工作默认按这个节奏推进：

### 第一步

先锁死“最小可实现链路”：

```text
1 路视频源
-> 前端 FPGA
-> 光纤 / HSST
-> 异构平台 FPGA
-> PCIe DMA
-> RK3568 推理显示
```

### 第二步

确认前端 FPGA 保留哪些上一届模块：

- 输入初始化
- 缩放
- 滤波
- DDR 缓存
- 光纤发送

### 第三步

确认异构平台 FPGA 保留哪些上一届模块：

- 光纤接收
- DDR 缓存
- 通道选择
- PCIe DMA

### 第四步

将 RK3568 软件从“通用检测”替换成“赛题对应模型”。

### 第五步

再逐步把 ROI 和更多前处理前移到 FPGA。

## 14. 当前最终结论

如果只用一句话概括当前项目状态，那就是：

**当前仓库不是一份需要推倒重来的旧代码，而是一套已经非常接近今年赛题目标的现成工程底座，我们应该沿着“盘古前端输入 + 异构平台汇聚 + PCIe 到 RK3568 推理”的路线继续推进。**

再说得更直接一点：

- 主路线已经有了。
- 代码骨架已经有了。
- 板卡角色已经基本清楚了。
- 现在真正要做的是“赛题化改造”，不是重新找方向。

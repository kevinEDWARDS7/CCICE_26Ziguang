# PCIe -> RK3568 -> DRM -> HDMI OUT 最小显示链路调试归档报告

## 1. 文档目的

本文档用于归档本轮最小显示链路调试过程，记录：

- 调试目标与边界
- 关键代码核查结论
- 已确认的错误点
- 每轮判断依据与迭代过程
- 已实施的修复措施
- 板端验证结果
- 当前根因结论
- 后续推荐方案

本文档面向两类使用者：

- 项目成员后续复盘、继续调试
- 新接手的 AI / 工程师快速建立上下文

## 2. 调试目标与范围控制

### 2.1 本轮唯一目标

实现并验证以下最小链路：

- FPGA 输出固定 `RGB565` 色块
- 经 PCIe 传输到 RK3568
- RK3568 用户态程序通过 DRM/KMS 输出到 HDMI OUT

### 2.2 明确不纳入本轮的内容

本轮刻意不处理以下方向：

- 多路视频
- ROI
- DDR 帧缓存
- 赛题全链路
- 复杂同步协议
- DMA done 中断 / completion 框架重构
- 大规模驱动架构调整

### 2.3 调试策略

采用“最小链路优先”的工程策略：

1. 先保证链路上有稳定的非零图像数据
2. 再保证结构不漂移
3. 最后再处理颜色顺序问题

## 3. 初始已知条件

### 3.1 FPGA 侧 AXIS 握手已修正

新版 FPGA 代码已满足：

- `handshake = tvalid && tready`
- 计数器只在 handshake 成功时推进
- `tlast = line_end`
- `tuser = frame_start`

因此，本轮禁止回退到旧版错误写法，即：

- `tvalid` 绑定 `tready`
- 计数器不经 handshake 直接推进

### 3.2 RK 侧程序工作模式

RK 用户态程序当前只是 bring-up 工具，流程为：

1. 发 DMA 命令
2. 固定 busy-wait
3. `PCI_READ_FROM_KERNEL_CMD` 回读到用户态
4. 再写入 DRM framebuffer

当前没有：

- DMA 完成中断
- completion 机制
- 明确的软件帧同步协议

### 3.3 参数基线

当前链路默认参数固定为：

- 分辨率：`1280 x 720`
- 源格式：`RGB565`
- 行字节数：`2560`
- 输出接口：`HDMI-A-1`

这与 FPGA 理论发送长度一致：

- `160 beat / line`
- `16B / beat`
- `160 x 16 = 2560B / line`

## 4. 初始问题假设

调试初期的主要怀疑点包括：

1. FPGA 持续流发送，而 RK 按请求逐行拉取，双方相位可能不确定
2. FPGA 虽有 `tuser/tlast`，但 RK 软件未消费边界信息
3. FPGA 未用 `pcie_link_up` 门控输出，重训练后相位可能失控
4. RK 侧 `recv_one_line()` 采用固定 busy-wait，时序敏感
5. 若图像结构正常但颜色异常，可能是 RGB565 顺序问题

这些都是合理怀疑，但需要通过代码与实测逐步验证。

## 5. 第一阶段：代码核查

### 5.1 RK 用户态程序核查

重点文件：

- [pcie_hdmi_out_drm.c](f:\Codex\code\pcie_test_platform_v1_0(1)\pango_pcie_dma_alloc\pcie_hdmi_out\pcie_hdmi_out_drm.c)
- [pango_pci_driver.c](f:\Codex\code\pcie_test_platform_v1_0(1)\pango_pcie_dma_alloc\driver\pango_pci_driver.c)

#### 5.1.1 错误点一：DMA 方向写反

在 `pcie_hdmi_out_drm.c` 中，原始实现使用：

- `PCI_DMA_READ_CMD`

但驱动语义明确：

- `PCI_DMA_READ_CMD`：CPU 写数据到设备
- `PCI_DMA_WRITE_CMD`：CPU 从设备读数据
- `PCI_READ_FROM_KERNEL_CMD`：将 `addr_w.data_buf` 拷回用户态

因此，RK 用户态要从 FPGA 收数据，必须走：

- `PCI_DMA_WRITE_CMD`

#### 5.1.2 判断理由

该判断基于三点一致证据：

1. 驱动注释与 `op_type` 语义一致
2. 驱动中 `PCI_READ_FROM_KERNEL_CMD` 明确从 `addr_w` 回读
3. 老版 framebuffer 工具 `pcie_hdmi_out.c` 本来就走 `PCI_DMA_WRITE_CMD`

#### 5.1.3 采取措施

已完成以下修正：

- `recv_one_line()` 内：
  - `dma->cmd = PCI_DMA_WRITE_CMD`
  - `ioctl(fd, PCI_DMA_WRITE_CMD, dma)`
- `run_pipeline()` 初始化：
  - `ctx->dma.cmd = PCI_DMA_WRITE_CMD`

关键位置：

- [pcie_hdmi_out_drm.c:327](f:\Codex\code\pcie_test_platform_v1_0(1)\pango_pcie_dma_alloc\pcie_hdmi_out\pcie_hdmi_out_drm.c:327)
- [pcie_hdmi_out_drm.c:330](f:\Codex\code\pcie_test_platform_v1_0(1)\pango_pcie_dma_alloc\pcie_hdmi_out\pcie_hdmi_out_drm.c:330)
- [pcie_hdmi_out_drm.c:959](f:\Codex\code\pcie_test_platform_v1_0(1)\pango_pcie_dma_alloc\pcie_hdmi_out\pcie_hdmi_out_drm.c:959)

#### 5.1.4 修复后的意义

这一步修复了一个确定性实现错误。修复后，RK 至少具备了“按正确方向从 FPGA 取数”的前提。

### 5.2 FPGA 顶层核查

重点文件：

- [main.v](f:\Codex\code\35_HDMI_IN_DDR3_mid_filter\source\main.v)

#### 5.2.1 已确认正确点

新版 FPGA AXIS 握手逻辑本身是正确的：

- `handshake = current_tvalid && pcie_tready`
- `x/y` 计数只在 handshake 下推进
- `tlast` 表示行尾
- `tuser` 表示帧首

#### 5.2.2 未解决问题

尽管 AXIS 视频边界定义正确，但系统层面仍存在两个根本缺口：

1. RK 软件不消费 `tuser/tlast`
2. 早期 FPGA 版本中 `pcie_link_up` 未参与有效发送控制

因此，AXIS 侧带边界信息并没有转化成端到端的软件同步能力。

## 6. 第二阶段：形成两种 FPGA 方案

### 6.1 方案 A：按主机请求发送一整行

设计目标：

- 默认不持续发流
- 每次请求只发一整行
- 一行固定 `160 beat = 2560B`
- 行结束后停下，等待下一次请求

### 6.2 方案 B：持续流 + `pcie_link_up` 门控

设计目标：

- 保留持续流输出
- 用 `pcie_link_up` 门控 `tvalid`
- 链路失效或恢复后，强制从固定帧首重新开始
- 保持 AXIS 握手与边界语义不变

## 7. 第三阶段：第一次工程决策与实施

出于“最小链路优先”的考虑，最初优先尝试了方案 A。

### 7.1 第一次 A 方案的实现方式

在 FPGA 顶层中，采用以下逻辑：

- `line_active` 作为“当前是否正在发一行”
- 用 `pcie_tready` 的上升沿作为“主机发起请求”的触发条件
- 一旦开始，连续发满 `160 beat`
- 行结束后清除 `line_active`
- `x/y` 计数仍只在 handshake 下推进
- `tlast/tuser` 语义保留

### 7.1.1 当时的判断依据

当时之所以这么做，是因为在现有顶层可见信号里，没有真正意义上的“DMA 事务开始脉冲”。因此尝试将：

- `pcie_tready`

近似视为：

- “主机正在拉取一行数据”

这是一种带假设的工程试探，而不是协议级确定事实。

## 8. 第四阶段：RK 板端构建与运行验证

在 RK3568 板端完成了用户态编译与 HDMI 状态验证。

### 8.1 用户态程序编译成功

板端编译结果表明：

- `pcie_hdmi_out_drm` 正常生成
- `libdrm` 头文件与库可用
- 用户态工具链正常

### 8.2 HDMI 与 DRM 状态正常

板端检测结果显示：

- `HDMI-A-1` 状态为 `connected`
- `enabled = enabled`
- `dpms = On`

说明显示输出基础条件正常。

### 8.3 DRM 程序成功进入显示主循环

运行日志显示：

```text
DRM set: connector=175 mode=1280x720 1280x720, crtc=72, pitch=5120
start: src=1280x720 RGB565, display=1280x720, ...
```

由此确认：

- 连接器识别正常
- 模式设置成功
- framebuffer 创建成功
- 用户态主循环进入成功

### 8.3.1 阶段性结论

此时可以初步排除以下方向：

- 纯 DRM/KMS 初始化失败
- HDMI 物理链路不通
- 用户态程序无法启动

## 9. 第五阶段：开启 Debug 并获取关键数据证据

为了判断链路中实际传输内容，使用带 debug 和抓帧参数的运行方式进行验证。

### 9.1 运行命令特征

启用了：

- `--debug`
- `--debug-interval 1`
- `--dump-frames 2`

从而获得：

- DMA 成功/失败行统计
- 是否全零
- 是否变化
- framebuffer 抓图文件

### 9.2 关键实测结果

日志中最关键的输出为：

```text
[debug] t=0.57s frame=1 fps=1.74 rx=3.06 MiB dma_ok_lines=720 dma_fail_lines=0 all_zero=720 changed=0 dumped=1
last_frame: dma=DMA_OK data=ALL_ZERO fb=FB_OK ...
```

后续帧也保持同样趋势：

```text
dma_ok_lines=6480 dma_fail_lines=0 all_zero=6480 changed=0
dma_ok_lines=17280 dma_fail_lines=0 all_zero=17280 changed=0
...
```

并成功生成两张帧抓图文件：

- `debug_frame_0001.ppm`
- `debug_frame_0002.ppm`

文件尺寸、格式均正常。

## 10. 第六阶段：基于证据做系统分层判断

### 10.1 已被确认正常的层

#### 10.1.1 RK DMA 流程本身是正常的

理由：

- `dma_fail_lines = 0`
- `dma_ok_lines` 持续增长

结论：

- 用户态 -> 驱动 -> DMA ioctl 这一段没有明显失败

#### 10.1.2 DRM framebuffer 写入是正常的

理由：

- `fb = FB_OK`
- `PPM` 文件成功导出
- 显示模式切换成功

结论：

- framebuffer 更新路径正常

#### 10.1.3 HDMI 显示链路是正常的

理由：

- `connected`
- `enabled`
- `dpms On`
- 能看到 debug overlay

结论：

- 黑屏不是因为显示器没被驱动

### 10.2 已被确认异常的层

#### 10.2.1 实际收到的数据是全零

理由：

- `all_zero_lines = dma_ok_lines`
- `changed = 0`
- `data = ALL_ZERO`
- `frame_hash` 长时间重复

结论：

- 当前传过来的不是“颜色错”的图像
- 不是“行错位”的图像
- 不是“部分行失败”的图像
- 而是每一行 payload 都是全零

#### 10.2.2 因此当前黑屏的本质

当前黑屏不是“没有显示”。当前黑屏的本质是：

- DRM 正常显示了从 PCIe 收到的全零帧

## 11. 第七阶段：对方案 A 进行反证和否定

### 11.1 被否定的错误点

错误点二：将 `pcie_tready` 上升沿错误地当作“主机逐行请求开始”信号

A 方案第一次实现中，核心触发条件为：

- `request_start = pcie_link_up && !line_active && pcie_tready && !pcie_tready_d`

该实现隐含了一个未经协议保证的假设：

- 每次主机发起一行 DMA 拉取时，`pcie_tready` 都会形成一个可识别的上升沿

### 11.2 为什么这个判断是错的

`tready` 在 AXIS 中的真实语义只是：

- 接收端当前 ready

它并不等价于：

- “主机发起了一次新的逐行事务”

如果 `tready` 的真实行为是：

- 常高
- 长时间为高
- 或与 DMA 行请求无一一对应关系

那么会出现以下后果：

1. 首次可能启动一行
2. 行结束后 `line_active` 清零
3. 但因为 `tready` 没有新的有效上升沿
4. 后续永远无法再次启动发数

### 11.3 实测如何反证该方案

从板端结果看：

- 所有行都被统计为 `DMA_OK`
- 但所有行内容都为 `ALL_ZERO`

这说明：

- 当前 A 方案并没有形成主机侧可消费的非零视频流
- 这不是“参数微调”问题
- 而是发送启动模型本身不成立

### 11.4 结论

A 方案的当前实现方式已被实验否定，不能继续作为主方案。

需要强调：

- 被否定的是“用 `tready` 上升沿伪造事务开始”这件事
- 并不是抽象意义上“按请求逐行发送”永远不可能

如果未来能拿到真正的 DMA 事务启动信号，A 方案仍可能重新成立。

## 12. 第八阶段：重新评估并确定当前最优方案

### 12.1 当前为什么不适合继续坚持 A 方案

A 方案成立的前提应至少满足其一：

1. FPGA 可见真实 DMA 请求开始信号
2. PCIe DMA IP 暴露事务启动脉冲
3. 软件可显式通过寄存器/控制信号告诉 FPGA“现在发一行”

而当前系统不具备这些条件。

因此继续坚持 A 方案，只会在错误前提上继续堆逻辑。

### 12.2 当前为什么 B 方案更工程化

B 方案不伪造不存在的事务信号，而是基于现有已知可靠信号工作：

- `pcie_link_up`
- `tready`
- `tvalid`
- `tlast`
- `tuser`

其目标不是一次性解决所有同步问题，而是先保证：

1. FPGA 能持续输出稳定的非零标准视频流
2. 链路恢复后相位可从固定起点重新开始
3. RK 侧至少能稳定接收到有内容的帧

因此在当前 bring-up 阶段：

B 方案是更稳妥、更符合现有信号条件、更工程化的主方案。

## 13. 当前阶段错误清单

### 13.1 已确认并已处理的错误

错误 1：RK 用户态 DMA 方向写反

- 位置：`pcie_hdmi_out_drm.c`
- 现象：用户态逻辑与驱动语义不一致
- 依据：驱动注释、`op_type`、老版工具实现
- 处理：改为 `PCI_DMA_WRITE_CMD`
- 当前状态：已修复

### 13.2 已确认但尚未彻底修复的错误

错误 2：FPGA A 方案错误使用 `tready` 上升沿当作逐行请求信号

- 位置：`main.v`
- 现象：主机侧持续收到全零帧
- 依据：`DMA_OK + ALL_ZERO + FB_OK`
- 当前状态：已被否定，需改方案

## 14. 当前阶段结论

截至本轮结束，可以形成明确结论：

1. RK 用户态程序的 DMA 方向错误已经修复
2. RK DRM/KMS 与 HDMI OUT 通路已验证正常
3. 当前黑屏不是显示器黑屏，而是“显示了全零帧”
4. 当前 A 版 FPGA 发送策略未能构造出有效视频数据
5. 问题已从“整条链路不确定”收敛到“FPGA/PCIe 发流模型错误”
6. 下一步主方向应切换到 B 版：持续流 + `pcie_link_up` 门控 + 固定帧首复位

## 15. 后续推荐方案

### 15.1 FPGA 推荐方案

建议采用 B 版实现：

1. `current_tvalid = pcie_link_up`
2. `handshake = current_tvalid && pcie_tready`
3. `x_beat_cnt / y_line_cnt` 仅在 handshake 成功时推进
4. `!pcie_link_up` 时：
   - `x_beat_cnt <= 0`
   - `y_line_cnt <= 0`
5. `tlast = line_end`
6. `tuser = frame_start`
7. 删除当前 A 版中：
   - `line_active`
   - `request_start`
   - `pcie_tready_d` 边沿检测事务模型

### 15.2 RK 推荐策略

RK 侧当前暂不做大改动，继续保留：

- `PCI_DMA_WRITE_CMD`
- busy-wait
- debug 统计
- dump frame 能力

待 FPGA 能稳定输出非零图像后，再继续处理：

- 颜色顺序
- 帧同步增强
- 更强的 DMA 完成机制

## 16. 本轮调试的方法论总结

本轮工作体现的是典型工程迭代流程，而非一次性“猜中根因”。

### 16.1 迭代步骤

1. 先限制问题边界
   不把任务重新扩展为全链路改造。
2. 先修确定性错误
   DMA 方向错误属于明确 bug，优先修复。
3. 保留已经正确的基础
   不回退 FPGA AXIS 握手修复。
4. 提出候选方案
   A/B 两方案并行讨论，而不是单线押注。
5. 快速落地最小实验
   不停留在理论争论，直接上板验证。
6. 让实验结果否定错误假设
   `DMA_OK + ALL_ZERO` 直接否定当前 A 方案实现。
7. 重新收敛正确方向
   从“可能是很多层问题”收敛到“当前主因在 FPGA 发流模型”。

### 16.2 本轮最大成果

本轮最大的成果不是“已经完全修复黑屏”，而是：

把一个模糊的端到端黑屏问题，收敛成了一个明确、可继续工程化修复的 FPGA 发流模型问题。

这一步对于后续调试价值最高。

## 17. 交接摘要

如果后续由其他工程师或 AI 继续接手，请优先继承以下结论：

1. `pcie_hdmi_out_drm.c` 中 DMA 方向必须保持为 `PCI_DMA_WRITE_CMD`
2. RK 侧 DRM/HDMI 路径当前已验证正常，不应再作为第一嫌疑项
3. 当前抓到的不是错色图像，而是全零帧
4. 当前 A 版 FPGA 实现已被实测否定
5. 下一个主动作应是：将 FPGA 切换为 B 版持续流门控方案，再重新上板验证
